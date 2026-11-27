import { createClient } from 'npm:@supabase/supabase-js@2.118.0';
import type { Identity, SessionTokens } from './child-pairing.ts';
import { extractJwtSessionId } from './session-revocation.ts';

function configuredKey(legacyName: string, collectionName: string): string {
  const legacy = Deno.env.get(legacyName);
  if (legacy) return legacy;
  const collection = Deno.env.get(collectionName);
  if (!collection) throw new Error('Server configuration is incomplete');
  const parsed: unknown = JSON.parse(collection);
  if (!parsed || typeof parsed !== 'object' || !('default' in parsed) || typeof parsed.default !== 'string') {
    throw new Error('Server configuration is incomplete');
  }
  return parsed.default;
}
const url = Deno.env.get('SUPABASE_URL');
if (!url) throw new Error('Server configuration is incomplete');
const publishable = configuredKey('SUPABASE_ANON_KEY', 'SUPABASE_PUBLISHABLE_KEYS');
const secret = configuredKey('SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_SECRET_KEYS');
const options = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  global: { fetch: (input: RequestInfo | URL, init?: RequestInit) => fetch(input, { ...init, signal: AbortSignal.timeout(10_000) }) } };
export const admin = createClient(url, secret, options);
export function userClient(token?: string) {
  return createClient(url!, publishable, { ...options, global: { ...options.global,
    ...(token ? { headers: { Authorization: `Bearer ${token}` } } : {}) } });
}

export async function authenticateActiveUser(token: string) {
  const { data, error } = await userClient().auth.getUser(token);
  if (error || !data.user) return null;
  const sessionId = extractJwtSessionId(token);
  if (sessionId) {
    const { data: revoked, error: revokeError } = await admin.rpc('bloom_is_session_revoked', { p_session_id: sessionId });
    if (revokeError || revoked === true) return null;
  }
  return { user: data.user, sessionId };
}

export async function invalidateAuthSession(userId: string, sessionId: string) {
  const response = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(userId)}/sessions/${encodeURIComponent(sessionId)}`, {
    method: 'DELETE',
    headers: {
      apikey: secret,
      authorization: `Bearer ${secret}`,
    },
    signal: AbortSignal.timeout(10_000),
  });
  if (!response.ok && response.status !== 404) {
    throw new Error('Could not terminate the device Auth session');
  }
}

export async function findIdentity(profileId: string): Promise<Identity | null> {
  const { data, error } = await admin.auth.admin.getUserById(profileId);
  if (error) {
    if (error.status === 404 || error.code === 'user_not_found') return null;
    throw new Error('Identity lookup failed');
  }
  return data.user ? { id: data.user.id, email: data.user.email, app_metadata: data.user.app_metadata } : null;
}

export async function issueSession(identity: Identity): Promise<SessionTokens> {
  if (!identity.email) throw new Error('Identity has no login address');
  const link = await admin.auth.admin.generateLink({ type: 'magiclink', email: identity.email });
  if (link.error || link.data.user?.id !== identity.id || !link.data.properties?.hashed_token) {
    throw new Error('Could not create session');
  }
  const verified = await userClient().auth.verifyOtp({ type: 'magiclink', token_hash: link.data.properties.hashed_token });
  if (verified.error || !verified.data.session || verified.data.user?.id !== identity.id) {
    throw new Error('Could not create session');
  }
  return { access_token: verified.data.session.access_token, refresh_token: verified.data.session.refresh_token, user_id: verified.data.user.id };
}
