"""Exercise pairing and competitions using a dedicated, verified test parent.

The test creates a synthetic family, managed child, exercise, and private
competition in the specified test project. Those records remain for an admin
to remove; never run this against a production project or a real family.
Credentials and session tokens stay in memory and are not printed.
"""
import argparse
import atexit
import datetime
import decimal
import getpass
import json
from pathlib import Path
import re
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid


AUTH_ERROR_HINTS = {
    'invalid_credentials': 'The email or password was not accepted by this test project.',
    'email_not_confirmed': 'The account email has not been confirmed.',
    'user_banned': 'The account is currently disabled.',
    'over_request_rate_limit': 'The test project is rate-limiting sign-in; try again later.',
    'email_provider_disabled': 'Email and password sign-in is disabled in the test project.',
}
SAFE_DATABASE_MESSAGES = {
    'Use a new account with no existing activity',
    'Use a new, unlinked account',
    'A verified email account is required',
    'Invalid or expired link code',
    'Coaching consent and eligibility are required',
}


def public_config(expected_ref):
    path = Path(__file__).resolve().parents[1] / '.env.notary-test.local'
    values = {}
    for line in path.read_text(encoding='utf-8').splitlines():
        match = re.match(r'^\s*(BLOOM_TEST_PROJECT_REF|BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY)\s*=\s*([^#]*?)\s*$', line)
        if match:
            values[match.group(1)] = match.group(2).strip('"\'')
    ref = values.get('BLOOM_TEST_PROJECT_REF', '')
    key = values.get('BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY', '')
    if ref != expected_ref or not re.fullmatch(r'[a-z0-9]{20}', ref) or not key.startswith('sb_publishable_'):
        raise RuntimeError('Test-project configuration does not match the requested project')
    return f'https://{ref}.supabase.co', key


class Client:
    def __init__(self, base, key, token=None):
        self.base, self.key, self.token = base, key, token

    def request(self, method, path, payload=None, expected=(200,)):
        headers = {'apikey': self.key, 'content-type': 'application/json', 'accept': 'application/json'}
        if self.token:
            headers['authorization'] = f'Bearer {self.token}'
        body = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(self.base + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                status, raw = response.status, response.read()
        except urllib.error.HTTPError as exc:
            status, raw = exc.code, exc.read()
        except (urllib.error.URLError, OSError):
            raise RuntimeError('Test-project request failed') from None
        if status not in expected:
            route = urllib.parse.urlsplit(path).path
            detail = ''
            try:
                error = json.loads(raw)
                if isinstance(error, dict):
                    hint = AUTH_ERROR_HINTS.get(error.get('error_code'))
                    if hint is None and error.get('message') in SAFE_DATABASE_MESSAGES:
                        hint = error['message']
                    if hint:
                        detail = ' ' + hint
            except (ValueError, TypeError):
                pass
            raise RuntimeError(f'{route} returned HTTP {status}.{detail}')
        return status, json.loads(raw) if raw else None

    def rpc(self, name, payload, expected=(200, 204)):
        return self.request('POST', '/rest/v1/rpc/' + name, payload, expected)

    def function(self, name, payload, expected=(200,)):
        return self.request('POST', '/functions/v1/' + name, payload, expected)


def temporary_session(base, key, token):
    client = Client(base, key, token)

    def revoke():
        try:
            client.request('POST', '/auth/v1/logout?scope=local', {}, expected=(200, 204, 401, 403))
        except RuntimeError:
            pass

    atexit.register(revoke)
    return client


def check(condition, label):
    if not condition:
        raise RuntimeError(label + ' failed')
    print(label + ': passed', flush=True)


def check_coaching_privacy(parent, child, child_id):
    preferences = {'p_consent': True, 'p_adult_attested': False, 'p_goals': 'Synthetic activity',
                   'p_experience': 'beginner', 'p_equipment': []}
    child.rpc('bloom_set_coach_preferences', preferences)
    request = {'p_request_id': str(uuid.uuid4()), 'p_kind': 'chat', 'p_prompt': 'Synthetic coaching test'}
    child.rpc('bloom_begin_coach_request', request, expected=(400, 401, 403))
    check(True, 'Child coaching blocked without parent consent')
    parent_enabled = False
    try:
        parent.rpc('bloom_set_child_coaching', {'p_child_id': child_id, 'p_enabled': True, 'p_eligible': True, 'p_consent': True})
        parent_enabled = True
        _, started = child.rpc('bloom_begin_coach_request', request)
        check(isinstance(started, dict) and started.get('status') == 'pending', 'Child coaching consent enforced')
        path = '/rest/v1/bloom_coach_messages?select=id&profile_id=eq.' + urllib.parse.quote(child_id)
        _, own_messages = child.request('GET', path)
        _, parent_messages = parent.request('GET', path)
        check(len(own_messages) == 1 and len(parent_messages) == 0, 'Child coaching conversation remains private')
        parent.rpc('bloom_set_child_coaching', {'p_child_id': child_id, 'p_enabled': False, 'p_eligible': False, 'p_consent': False})
        parent_enabled = False
        request['p_request_id'] = str(uuid.uuid4())
        child.rpc('bloom_begin_coach_request', request, expected=(400, 401, 403))
        check(True, 'Coaching stops after consent withdrawal')
    finally:
        if parent_enabled:
            parent.rpc('bloom_set_child_coaching', {'p_child_id': child_id, 'p_enabled': False, 'p_eligible': False, 'p_consent': False})
        preferences['p_consent'] = False
        child.rpc('bloom_set_coach_preferences', preferences)


def check_workout_scoring(parent, child, child_id, exercise_id, event_id, starts_at, label):
    _, plan = child.rpc('bloom_create_workout_plan', {'p_title': label,
        'p_exercises': [{'exercise_id': exercise_id, 'sets': 1, 'target': 10}]})
    parent.rpc('bloom_parent_adjust_credit', {'p_child_id': child_id, 'p_request_id': str(uuid.uuid4()),
                                             'p_minutes': 12, 'p_reason': 'Synthetic test credit'})
    delay = max(0.0, (starts_at - datetime.datetime.now(datetime.timezone.utc)).total_seconds() + 1.0)
    if delay > 30:
        raise RuntimeError('Competition start time is too far away for this check')
    if delay:
        print('Waiting briefly for the test competition to start...', flush=True)
        time.sleep(delay)
    _, rows = child.rpc('bloom_start_workout', {'p_plan_id': plan})
    session_id = rows[0]['session_id']
    child.rpc('bloom_set_workout_timer', {'p_session_id': session_id, 'p_running': True})
    child.rpc('bloom_set_workout_timer', {'p_session_id': session_id, 'p_running': False})
    session_path = '/rest/v1/bloom_workout_sessions?select=active_duration_seconds,timer_started_at&id=eq.' + urllib.parse.quote(session_id)
    _, first = child.request('GET', session_path)
    time.sleep(1)
    _, second = child.request('GET', session_path)
    check(len(first) == 1 and len(second) == 1 and first[0]['timer_started_at'] is None
          and first[0]['active_duration_seconds'] == second[0]['active_duration_seconds'], 'Paused timer does not count time')
    results = [{'exercise_id': exercise_id, 'sets_completed': 1, 'reps_completed': 10}]
    child.rpc('bloom_complete_workout', {'p_session_id': session_id, 'p_results': results})
    child.rpc('bloom_complete_workout', {'p_session_id': session_id, 'p_results': results})
    _, standings = child.rpc('bloom_competition_results', {'p_id': event_id})
    check(any(row.get('is_self') and decimal.Decimal(str(row.get('score'))) == 1 for row in standings),
          'Completed workout scores once after retry')
    _, balance = child.rpc('bloom_credit_balance', {})
    check(decimal.Decimal(str(balance)) >= 12, 'Synthetic child credit recorded')
    return plan, session_id, balance


def check_conversion(parent, child, independent, child_id, family_id, exercise_id, plan, session_id, balance):
    print('The independent test account will be permanently linked to this synthetic child profile.')
    if input('Type LINK to confirm this test-account conversion: ').strip() != 'LINK':
        raise RuntimeError('Test-account conversion was not confirmed')
    _, code = parent.rpc('bloom_create_child_account_link', {'p_profile_id': child_id})
    _, linked = independent.rpc('bloom_accept_child_account_link', {'p_token': code})
    _, retried = independent.rpc('bloom_accept_child_account_link', {'p_token': code})
    check(linked == child_id and retried == child_id, 'Account conversion is retry-safe')
    _, identity = independent.rpc('bloom_current_profile', {})
    check(identity.get('profile_id') == child_id and identity.get('child_profile') is True,
          'Independent account retains child profile')
    for table, record_id, label in [('bloom_workout_plans', plan, 'plan'),
                                    ('bloom_workout_sessions', session_id, 'workout'),
                                    ('exercises', exercise_id, 'custom exercise')]:
        _, rows = independent.request('GET', '/rest/v1/' + table + '?select=id&id=eq.' + urllib.parse.quote(record_id))
        check(len(rows) == 1, 'Converted account retains ' + label)
    _, members = independent.rpc('bloom_family_members', {'p_household_id': family_id})
    check(any(member.get('user_id') == child_id and member.get('role') == 'child' for member in members),
          'Converted account retains family relationship')
    _, after = independent.rpc('bloom_credit_balance', {})
    check(decimal.Decimal(str(after)) == decimal.Decimal(str(balance)), 'Converted account retains credit balance')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-ref', required=True, help='Confirmed non-production project reference')
    parser.add_argument('--extended', action='store_true', help='Test coaching privacy and workout scoring')
    parser.add_argument('--convert', action='store_true', help='Also link a second empty, verified test account')
    args = parser.parse_args()
    if args.convert and not args.extended:
        parser.error('--convert requires --extended')
    base, key = public_config(args.project_ref)
    print('Use a dedicated verified test parent. Synthetic family and competition records will remain in the test project.')
    email = input('Test parent email: ').strip()
    password = getpass.getpass('Test parent password: ')
    anonymous = Client(base, key)
    try:
        _, login = anonymous.request('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
    except RuntimeError as error:
        raise RuntimeError(f'Parent account sign-in failed. {error}') from None
    password = None
    token = login.get('access_token') if isinstance(login, dict) else None
    check(isinstance(token, str), 'Verified parent sign-in')
    parent = temporary_session(base, key, token)
    _, identity = parent.rpc('bloom_current_profile', {})
    check(isinstance(identity, dict) and isinstance(identity.get('profile_id'), str)
          and not identity.get('child_profile'), 'Parent profile access')
    parent_id = identity['profile_id']
    independent = None
    if args.convert:
        print('Enter a second verified test account with no existing Bloom activity.')
        other_email = input('Independent test account email: ').strip()
        other_password = getpass.getpass('Independent test account password: ')
        try:
            _, other_login = anonymous.request('POST', '/auth/v1/token?grant_type=password',
                                               {'email': other_email, 'password': other_password})
        except RuntimeError as error:
            raise RuntimeError(f'Independent test account sign-in failed. {error}') from None
        other_password = None
        other_token = other_login.get('access_token') if isinstance(other_login, dict) else None
        check(isinstance(other_token, str), 'Independent test account sign-in')
        independent = temporary_session(base, key, other_token)
        _, other_identity = independent.rpc('bloom_current_profile', {})
        check(other_identity.get('profile_id') != parent_id and not other_identity.get('child_profile'),
              'Independent account is separate from parent')
    suffix = secrets.token_hex(4)
    label = 'QA-' + suffix
    _, family_id = parent.rpc('bloom_create_household', {'p_name': label})
    _, child_id = parent.rpc('bloom_create_child_profile', {'p_household_id': family_id, 'p_name': label,
                                                            'p_request_id': str(uuid.uuid4())})
    _, issued = parent.function('bloom-provision-child', {'profile_id': child_id})
    code = issued.get('code') if isinstance(issued, dict) else None
    check(isinstance(code, str) and len(code) == 64, 'Parent-authorized child provisioning')
    _, paired = anonymous.function('bloom-pair-child', {'code': code})
    check(isinstance(paired, dict) and isinstance(paired.get('access_token'), str), 'Child device pairing')
    anonymous.function('bloom-pair-child', {'code': code}, expected=(400,))
    check(True, 'One-use pairing code')
    child = temporary_session(base, key, paired['access_token'])
    _, child_identity = child.rpc('bloom_current_profile', {})
    check(child_identity.get('profile_id') == child_id and child_identity.get('managed_child') is True,
          'Restricted child session')

    settings_path = '/rest/v1/bloom_settings?select=credits_enabled&user_id=eq.' + urllib.parse.quote(child_id)
    _, settings = child.request('GET', settings_path)
    check(isinstance(settings, list) and len(settings) == 1, 'Child settings readable')
    original = settings[0]['credits_enabled']
    child.request('PATCH', settings_path, {'credits_enabled': not original}, expected=(200, 204, 401, 403))
    _, after = child.request('GET', settings_path)
    check(len(after) == 1 and after[0]['credits_enabled'] == original, 'Parent-controlled settings protected')

    device_id, device_secret = str(uuid.uuid4()), secrets.token_hex(32)
    pin = str(secrets.randbelow(899999) + 100000)
    wrong_pin = '000000'
    registered = False
    try:
        parent.rpc('bloom_register_parent_pin', {'p_device_id': device_id, 'p_device_secret': device_secret, 'p_pin': pin})
        registered = True
        unlock = {'device_id': device_id, 'device_secret': device_secret, 'pin': wrong_pin}
        child.function('bloom-unlock-parent', unlock, expected=(401,))
        unlock['pin'] = pin
        _, parent_session = child.function('bloom-unlock-parent', unlock)
        restored_parent = temporary_session(base, key, parent_session.get('access_token'))
        _, restored_identity = restored_parent.rpc('bloom_current_profile', {})
        check(restored_identity.get('profile_id') == parent_id, 'PIN-protected parent switch')
    finally:
        if registered:
            parent.rpc('bloom_remove_parent_pin', {'p_device_id': device_id})

    _, exercise_id = child.rpc('bloom_create_custom_exercise', {'p_name': label, 'p_description': 'Synthetic test exercise',
                                                                'p_measurement': 'reps_only'})
    _, exercises = child.request('GET', '/rest/v1/exercises?select=id&id=eq.' + urllib.parse.quote(exercise_id))
    check(isinstance(exercises, list) and len(exercises) == 1, 'Custom exercise persistence')

    _, social = parent.request('GET', '/rest/v1/bloom_social_profiles?select=profile_id&profile_id=eq.' + urllib.parse.quote(parent_id))
    if not social:
        parent.rpc('bloom_set_social_profile', {'p_name': label, 'p_searchable': False})
    child.rpc('bloom_set_social_profile', {'p_name': label, 'p_searchable': True})
    _, found = parent.rpc('bloom_search_people', {'p_query': label})
    check(all(person.get('profile_id') != child_id for person in found), 'Child search is private by default')
    parent.rpc('bloom_set_child_search', {'p_child_id': child_id, 'p_enabled': True})
    _, found = parent.rpc('bloom_search_people', {'p_query': label})
    check(any(person.get('profile_id') == child_id for person in found), 'Parent opt-in enables child search')
    parent.rpc('bloom_set_child_search', {'p_child_id': child_id, 'p_enabled': False})

    now = datetime.datetime.now(datetime.timezone.utc)
    starts_at = now + (datetime.timedelta(seconds=20) if args.extended else datetime.timedelta(hours=1))
    _, event_id = parent.rpc('bloom_create_competition', {'p_title': label, 'p_description': 'Synthetic test event',
        'p_metric': 'workouts', 'p_visibility': 'private', 'p_max': 2,
        'p_starts': starts_at.isoformat(), 'p_ends': (starts_at + datetime.timedelta(hours=1)).isoformat()})
    _, invite = parent.rpc('bloom_create_competition_link', {'p_id': event_id})
    child.rpc('bloom_accept_competition_link', {'p_token': invite})
    participants = '/rest/v1/bloom_competition_participants?select=status&competition_id=eq.' + urllib.parse.quote(event_id) + '&profile_id=eq.' + urllib.parse.quote(child_id)
    _, participation = child.request('GET', participants)
    check(len(participation) == 1 and participation[0]['status'] == 'pending_parent', 'Child competition requires approval')
    child.rpc('bloom_approve_competition_child', {'p_id': event_id, 'p_child_id': child_id, 'p_approve': True}, expected=(400, 401, 403))
    parent.rpc('bloom_approve_competition_child', {'p_id': event_id, 'p_child_id': child_id, 'p_approve': True})
    _, participation = child.request('GET', participants)
    check(len(participation) == 1 and participation[0]['status'] == 'approved', 'Parent approves competition')
    if args.extended:
        check_coaching_privacy(parent, child, child_id)
        plan, session_id, balance = check_workout_scoring(parent, child, child_id, exercise_id, event_id, starts_at, label)
        if independent:
            check_conversion(parent, child, independent, child_id, family_id, exercise_id, plan, session_id, balance)
    print('Remote smoke checks finished. No Fireworks requests were made.')


if __name__ == '__main__':
    try:
        main()
    except RuntimeError as error:
        print(f'Remote smoke check stopped: {error}', file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, TypeError):
        print('Remote smoke check stopped. Check the preceding result and test account setup.', file=sys.stderr)
        sys.exit(1)
