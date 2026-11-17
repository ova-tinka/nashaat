"""Exercise child identity provisioning against an isolated local GoTrue instance.

Requires cached postgres:16-alpine and Supabase GoTrue images. No existing
project or credentials are used. Containers and their test data are removed.
"""
import base64
import hashlib
import hmac
import json
import os
from pathlib import Path
import secrets
import subprocess
import time
import urllib.error
import urllib.request
import uuid

suffix = uuid.uuid4().hex[:12]
network = f'bloom-auth-check-{suffix}'
database = f'bloom-auth-db-{suffix}'
auth = f'bloom-auth-service-{suffix}'
test_secret = secrets.token_hex(32)


def run(*args, env=None, input_text=None, check=True):
    return subprocess.run(args, env=env, input=input_text, text=True, check=check, capture_output=True)


def encode(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()


def token(role):
    head = encode(json.dumps({'alg': 'HS256', 'typ': 'JWT'}, separators=(',', ':')).encode())
    body = encode(json.dumps({'role': role, 'aud': 'authenticated', 'iat': int(time.time()),
                              'exp': int(time.time()) + 600}, separators=(',', ':')).encode())
    signature = encode(hmac.new(test_secret.encode(), f'{head}.{body}'.encode(), hashlib.sha256).digest())
    return f'{head}.{body}.{signature}'


def request(url, payload, authorization=None):
    headers = {'content-type': 'application/json'}
    if authorization:
        headers['authorization'] = f'Bearer {authorization}'
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers=headers, method='POST')
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def sql(statement):
    result = run('docker', 'exec', '-i', database, 'psql', '-qAt', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres',
                 input_text=statement, check=False)
    if result.returncode:
        raise RuntimeError('Isolated database fixture failed: ' + result.stderr.strip().splitlines()[-1])
    return result.stdout.strip()


try:
    run('docker', 'network', 'create', network)
    run('docker', 'run', '-d', '--name', database, '--network', network,
        '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', 'postgres:16-alpine')
    for _ in range(40):
        if run('docker', 'exec', database, 'pg_isready', '-U', 'postgres', check=False).returncode == 0:
            break
        time.sleep(0.25)
    else:
        raise RuntimeError('Isolated PostgreSQL did not start')

    for _ in range(40):
        initialized = run('docker', 'exec', '-i', database, 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres',
                          input_text='create schema if not exists auth; alter role postgres set search_path = auth, public;', check=False)
        if initialized.returncode == 0:
            break
        time.sleep(0.25)
    else:
        raise RuntimeError('Isolated PostgreSQL could not initialize the Auth schema')

    env = os.environ.copy()
    env.update({
        'GOTRUE_API_HOST': '0.0.0.0', 'PORT': '9999', 'GOTRUE_DB_DRIVER': 'postgres',
        'GOTRUE_DB_DATABASE_URL': f'postgres://postgres@{database}:5432/postgres?sslmode=disable',
        'DB_NAMESPACE': 'auth', 'GOTRUE_DB_AUTOMIGRATE': 'true',
        'GOTRUE_SITE_URL': 'http://localhost:3000', 'API_EXTERNAL_URL': 'http://localhost:9999',
        'GOTRUE_JWT_SECRET': test_secret, 'GOTRUE_JWT_EXP': '3600',
        'GOTRUE_JWT_AUD': 'authenticated', 'GOTRUE_JWT_DEFAULT_GROUP_NAME': 'authenticated',
        'GOTRUE_JWT_ADMIN_ROLES': 'service_role', 'GOTRUE_EXTERNAL_EMAIL_ENABLED': 'true',
        'GOTRUE_MAILER_AUTOCONFIRM': 'true', 'GOTRUE_DISABLE_SIGNUP': 'false', 'GOTRUE_LOG_LEVEL': 'error',
    })
    args = ['docker', 'run', '-d', '--name', auth, '--network', network, '-p', '127.0.0.1::9999']
    for key in env.keys() & {'GOTRUE_API_HOST', 'PORT', 'GOTRUE_DB_DRIVER', 'GOTRUE_DB_DATABASE_URL',
                              'DB_NAMESPACE', 'GOTRUE_DB_AUTOMIGRATE', 'GOTRUE_SITE_URL', 'API_EXTERNAL_URL',
                              'GOTRUE_JWT_SECRET', 'GOTRUE_JWT_EXP', 'GOTRUE_JWT_AUD', 'GOTRUE_JWT_DEFAULT_GROUP_NAME',
                              'GOTRUE_JWT_ADMIN_ROLES', 'GOTRUE_EXTERNAL_EMAIL_ENABLED', 'GOTRUE_MAILER_AUTOCONFIRM',
                              'GOTRUE_DISABLE_SIGNUP', 'GOTRUE_LOG_LEVEL'}:
        args.extend(['-e', key])
    args.append('public.ecr.aws/supabase/gotrue:v2.197.0')
    run(*args, env=env)
    port = run('docker', 'port', auth, '9999/tcp').stdout.strip().rsplit(':', 1)[-1]
    base = f'http://127.0.0.1:{port}'
    for _ in range(80):
        try:
            with urllib.request.urlopen(f'{base}/health', timeout=1) as response:
                if response.status == 200:
                    break
        except (OSError, urllib.error.URLError):
            time.sleep(0.25)
    else:
        logs = run('docker', 'logs', auth, check=False)
        messages = []
        for line in (logs.stdout + logs.stderr).splitlines():
            try:
                entry = json.loads(line)
                if entry.get('level') in ('fatal', 'error'):
                    message = str(entry.get('msg', 'Auth startup error')).replace(test_secret, '[redacted]')
                    messages.append(message.rsplit(': ERROR:', 1)[-1][-300:])
            except (ValueError, AttributeError):
                pass
        raise RuntimeError('Isolated Auth service did not start: ' + '; '.join(messages[-2:]))

    parent = str(uuid.uuid4())
    sql('''
      create role anon nologin;
      create role authenticated nologin;
      create role service_role nologin bypassrls;
      grant usage on schema auth, public to anon, authenticated;
      grant execute on function auth.uid() to anon, authenticated;
      create table public.profiles (id uuid primary key references auth.users(id) on delete cascade,
        email text unique not null, first_name text, last_name text, username text, streak_count integer default 0,
        last_workout_date date, timezone text default 'UTC');
      create function public.handle_new_user() returns trigger language plpgsql security definer
        set search_path = pg_catalog, pg_temp as $$ begin
        insert into public.profiles(id, email) values (new.id, new.email); return new; end $$;
      create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
      create table public.exercises (id uuid primary key, name text unique not null, description text,
        instructions text[] not null default '{}', media_link text, measurement_type text not null, is_system boolean not null default true);
      alter table public.exercises enable row level security;
      create policy "Exercise catalog is publicly readable" on public.exercises for select to anon, authenticated using (true);
      grant select on public.exercises to anon, authenticated;
    ''')
    migration_dir = Path(__file__).resolve().parents[2] / 'supabase' / 'migrations'
    for migration in sorted(migration_dir.glob('*bloom*.sql')):
        sql(migration.read_text())
    status, created_parent = request(f'{base}/admin/users', {
        'id': parent, 'email': f'parent-{parent}@bloom.invalid', 'email_confirm': True,
    }, token('service_role'))
    if status not in (200, 201) or created_parent.get('id') != parent:
        raise RuntimeError(f'Auth did not create the parent fixture (HTTP {status})')
    family = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_create_household('Test family');").splitlines()[-1]
    child = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_create_child_profile('{family}', 'Child', '{uuid.uuid4()}');").splitlines()[-1]
    sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_authorize_child_provisioning('{child}');")
    email = f'child-{child}@bloom.invalid'
    status, created = request(f'{base}/admin/users', {
        'id': child, 'email': email, 'email_confirm': True,
        'app_metadata': {'bloom_managed_child': True, 'bloom_profile_id': child, 'bloom_parent_id': parent},
    }, token('service_role'))
    if status not in (200, 201) or created.get('id') != child:
        logs = run('docker', 'logs', auth, check=False)
        errors = []
        for line in (logs.stdout + logs.stderr).splitlines():
            try:
                entry = json.loads(line)
                if entry.get('level') in ('fatal', 'error'):
                    errors.append(str(entry.get('error', entry.get('msg', ''))).replace(test_secret, '[redacted]')[-250:])
            except (ValueError, AttributeError):
                pass
        raise RuntimeError(f'Auth did not create the managed identity (HTTP {status}): ' + '; '.join(errors[-2:]))
    if created.get('app_metadata', {}).get('bloom_profile_id') != child:
        raise RuntimeError('Auth did not preserve trusted profile metadata')
    code = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_create_child_pairing_code('{child}');").splitlines()[-1]
    digest = hashlib.sha256(code.encode()).hexdigest()
    consumed = sql(f"set role service_role; select public.bloom_consume_child_pairing_code('{digest}');").splitlines()[-1]
    if consumed != child:
        raise RuntimeError('Pairing code resolved to the wrong profile')
    settings = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{child}', false); update public.bloom_settings set credits_enabled = false where user_id = '{child}' returning 1;").splitlines()
    if len(settings) != 1:
        raise RuntimeError('Child can change parent-controlled settings')
    status, link = request(f'{base}/admin/generate_link', {'type': 'magiclink', 'email': email}, token('service_role'))
    if status != 200 or link.get('id') != child or not link.get('hashed_token'):
        raise RuntimeError(f'Auth did not create a child login token (HTTP {status})')
    status, session = request(f'{base}/verify', {'type': 'magiclink', 'token_hash': link['hashed_token']})
    if status != 200 or session.get('user', {}).get('id') != child or not session.get('refresh_token'):
        raise RuntimeError(f'Auth did not issue the expected child session (HTTP {status})')
    device = str(uuid.uuid4())
    device_secret = secrets.token_hex(32)
    sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_register_parent_pin('{device}', '{device_secret}', '123456');")
    unlocked = sql(f"set role service_role; select public.bloom_verify_parent_pin('{child}', '{device}', '{device_secret}', '123456');").splitlines()[-1]
    if unlocked != parent:
        raise RuntimeError('PIN did not resolve to the expected parent')
    status, parent_link = request(f'{base}/admin/generate_link', {'type': 'magiclink', 'email': f'parent-{parent}@bloom.invalid'}, token('service_role'))
    if status != 200 or parent_link.get('id') != parent or not parent_link.get('hashed_token'):
        raise RuntimeError(f'Auth did not create a parent login token (HTTP {status})')
    status, parent_session = request(f'{base}/verify', {'type': 'magiclink', 'token_hash': parent_link['hashed_token']})
    if status != 200 or parent_session.get('user', {}).get('id') != parent:
        raise RuntimeError(f'Auth did not issue the expected parent session (HTTP {status})')
    status, _ = request(f'{base}/logout?scope=local', {}, parent_session['access_token'])
    if status not in (200, 204):
        raise RuntimeError(f'Auth did not revoke the parent session (HTTP {status})')
    status, restored = request(f'{base}/token?grant_type=refresh_token', {'refresh_token': session['refresh_token']})
    if status != 200 or restored.get('user', {}).get('id') != child:
        raise RuntimeError(f'Child session could not be restored (HTTP {status})')
    status, _ = request(f'{base}/token?grant_type=refresh_token', {'refresh_token': parent_session['refresh_token']})
    if status == 200:
        raise RuntimeError('Signed-out parent refresh token remained usable')
    exercise = str(uuid.uuid4())
    sql(f"insert into public.exercises(id, name, measurement_type, is_system) values ('{exercise}', 'Test exercise', 'reps_only', true);")
    plan = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{child}', false); select public.bloom_create_workout_plan('Preserved plan', '[{{\"exercise_id\":\"{exercise}\",\"sets\":1,\"target\":10}}]'::jsonb);").splitlines()[-1]
    sql(f"insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key, expires_at) values ('{child}', 12, 'adjustment', 'auth-conversion-test', now() + interval '1 day');")
    link_code = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{parent}', false); select public.bloom_create_child_account_link('{child}');").splitlines()[-1]
    independent = str(uuid.uuid4())
    independent_email = f'independent-{independent}@bloom.invalid'
    independent_password = secrets.token_urlsafe(24)
    status, account = request(f'{base}/admin/users', {'id': independent, 'email': independent_email,
                              'password': independent_password, 'email_confirm': True}, token('service_role'))
    if status not in (200, 201) or account.get('id') != independent:
        raise RuntimeError(f'Auth did not create the independent account (HTTP {status})')
    linked = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{independent}', false); select public.bloom_accept_child_account_link('{link_code}');").splitlines()[-1]
    if linked != child:
        raise RuntimeError('Email account linked to the wrong profile')
    status, independent_session = request(f'{base}/token?grant_type=password', {'email': independent_email, 'password': independent_password})
    if status != 200 or independent_session.get('user', {}).get('id') != independent:
        raise RuntimeError(f'Independent email account could not sign in (HTTP {status})')
    visible = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{independent}', false); select count(*) from public.bloom_workout_plans where id = '{plan}' and user_id = '{child}';").splitlines()[-1]
    balance = sql(f"set role authenticated; select set_config('request.jwt.claim.sub', '{independent}', false); select public.bloom_credit_balance();").splitlines()[-1]
    if visible != '1' or float(balance) != 12:
        raise RuntimeError(f'Independent account did not retain plan or credit balance: plan count {visible}, balance {balance}')
    print('Isolated Auth paired and switched sessions, then linked an email account without losing plan or credits.')
finally:
    run('docker', 'rm', '-f', auth, database, check=False)
    run('docker', 'network', 'rm', network, check=False)
