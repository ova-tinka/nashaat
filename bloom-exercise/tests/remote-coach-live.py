"""Run a bounded adult-only Fireworks check against the designated test project.

Creates a disposable verified account and synthetic workout data. The account and
data remain in the test project; credentials and session tokens stay in memory.
The operator must deploy the test-only account restriction before continuing.
"""
import datetime
import importlib.util
import select
import secrets
import sys
import time
import uuid
from pathlib import Path

spec = importlib.util.spec_from_file_location('family_smoke', Path(__file__).with_name('remote-family-smoke.py'))
family = importlib.util.module_from_spec(spec)
spec.loader.exec_module(family)


def main():
    base, key = family.public_config('wlvsbjuvubpbxoroqdnu')
    anonymous = family.Client(base, key)
    email = 'bloom-coach-qa-' + secrets.token_hex(12) + '@example.com'
    password = secrets.token_urlsafe(36) + 'A1!'
    _, signup = anonymous.request('POST', '/auth/v1/signup', {'email': email, 'password': password}, expected=(200, 201))
    user = signup.get('user', signup) if isinstance(signup, dict) else {}
    user_id = user.get('id')
    if not user.get('email_confirmed_at') or not isinstance(user_id, str):
        raise RuntimeError('Disposable account was not confirmed; no provider requests made')
    _, login = anonymous.request('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': password})
    password = None
    parent = family.temporary_session(base, key, login['access_token'])
    preferences = {'p_consent': True, 'p_adult_attested': True, 'p_goals': 'Build a gentle exercise routine',
                   'p_experience': 'beginner', 'p_equipment': []}
    parent.rpc('bloom_set_coach_preferences', preferences)
    _, exercise = parent.rpc('bloom_create_custom_exercise', {'p_name': 'QA gentle movement',
        'p_description': 'Synthetic test exercise', 'p_measurement': 'reps_only'})
    parent.rpc('bloom_create_workout_plan', {'p_title': 'QA starter plan', 'p_exercises': [
        {'exercise_id': exercise, 'sets': 1, 'target': 8}]})
    expiry_time = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(minutes=25)
    expiry = expiry_time.strftime('%Y-%m-%dT%H:%M:%SZ')
    print('Test account ID:', user_id, flush=True)
    print('Test access expires:', expiry, flush=True)
    print('Awaiting test-only configuration and deployment. Press Enter to run; type stop to cancel.', flush=True)
    try:
        ready, _, _ = select.select([sys.stdin], [], [], max(0, expiry_time.timestamp() - time.time() - 7 * 60))
        if not ready:
            print('Test preparation expired before deployment.', flush=True)
            return
        if input().strip().lower() == 'stop':
            return
        prompts = [
            ('chat', 'Please propose a gentle beginner plan using an existing exercise in my plan.'),
            ('chat', 'Please suggest a small change to my plan and explain it.'),
            ('weekly', 'Review my recent activity and propose a balanced adjustment to my plan.'),
            ('weekly', 'Review my current routine and propose a gentle weekly schedule.'),
            ('chat', 'Please propose another gentle beginner workout plan using existing exercises.'),
            ('weekly', 'Review my recent workouts and explain a reasonable next step.'),
            ('weekly', 'Give me a supportive review of my routine and recovery schedule.'),
        ]
        if '--weekly-only' in sys.argv:
            prompts = [
                ('weekly', 'Review my recent activity and propose a balanced adjustment to my plan.'),
                ('weekly', 'Review my current routine and propose a gentle weekly schedule.'),
            ]
        if '--chat-once' in sys.argv:
            prompts = [('chat', 'Please propose a gentle beginner plan using an existing exercise in my plan.')]
        if '--weekly-once' in sys.argv:
            prompts = [('weekly', 'Review my recent activity and propose a balanced adjustment to my plan.')]
        requests, failures, decisions = 0, 0, []
        for i, (kind, prompt) in enumerate(prompts):
            if i and i % 2 == 0:
                print('Waiting for the per-account request limit to reset...', flush=True)
                time.sleep(62)
            request_id = str(uuid.uuid4())
            status, result = parent.function('bloom-coach', {'request_id': request_id, 'kind': kind, 'prompt': prompt},
                expected=(200, 401, 403, 409, 429, 500, 503))
            requests += 1
            if status != 200 or not isinstance(result, dict) or result.get('status') != 'completed':
                failures += 1
                stage = result.get('stage') if isinstance(result, dict) else None
                provider_status = result.get('provider_status') if isinstance(result, dict) else None
                provider_reason = result.get('provider_reason') if isinstance(result, dict) else None
                safe_stage = stage if stage in ('request_setup', 'context', 'provider', 'response_validation', 'save') else 'unavailable'
                safe_status = provider_status if isinstance(provider_status, int) and 400 <= provider_status <= 599 else None
                safe_reason = provider_reason if provider_reason in ('timeout', 'network', 'http', 'response_body', 'truncated', 'invalid_content', 'response_json') else 'unavailable'
                print(f'{kind} request {i + 1}: HTTP {status}, stage {safe_stage}, provider reason {safe_reason}, provider HTTP {safe_status}', flush=True)
                if failures >= 2:
                    print('Stopped after two failed requests to limit spending.', flush=True)
                    break
                continue
            _, messages = parent.request('GET', '/rest/v1/bloom_coach_messages?select=role&request_id=eq.' + request_id)
            if not any(row.get('role') == 'assistant' for row in messages):
                failures += 1
                print(f'{kind} request {i + 1}: response not stored', flush=True)
                continue
            _, rows = parent.request('GET', '/rest/v1/bloom_coach_proposals?select=id,status&request_id=eq.' + request_id)
            print(f'{kind} request {i + 1}: passed; proposal ' + ('present' if rows else 'not returned'), flush=True)
            pending = [row['id'] for row in rows if row.get('status') == 'pending']
            if pending and len(decisions) < 4:
                approve = len(decisions) % 2 == 1
                _, created = parent.rpc('bloom_decide_coach_proposal', {'p_proposal_id': pending[0], 'p_approve': approve})
                _, updated = parent.request('GET', '/rest/v1/bloom_coach_proposals?select=status&id=eq.' + pending[0])
                expected = 'approved' if approve else 'rejected'
                if len(updated) != 1 or updated[0].get('status') != expected or (approve and not created):
                    raise RuntimeError('Proposal decision was not saved')
                decisions.append(expected)
                print(f'Proposal {expected}: passed', flush=True)
        print(f'Proposal decisions verified: {len(decisions)} of 4 requested', flush=True)
        print(f'Live requests attempted: {requests}; incomplete or failed: {failures}', flush=True)
    finally:
        try:
            parent.rpc('bloom_set_coach_preferences', {**preferences, 'p_consent': False})
            print('Disposable account coaching consent revoked.', flush=True)
        except Exception:
            print('Could not revoke disposable account consent; test window still expires automatically.', flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print('Live coaching check stopped:', str(error), flush=True)
        sys.exit(1)
