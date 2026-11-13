export type Identity = { id: string; email?: string; app_metadata: Record<string, unknown> };
export type SessionTokens = { access_token: string; refresh_token: string; user_id: string };

export type ProvisionDependencies = {
  authenticate: (token: string) => Promise<string | null>;
  authorize: (token: string, profileId: string) => Promise<boolean>;
  findIdentity: (profileId: string) => Promise<Identity | null>;
  createIdentity: (profileId: string, parentId: string) => Promise<Identity>;
  issueCode: (token: string, profileId: string) => Promise<string>;
};
export type PairDependencies = {
  consume: (hash: string) => Promise<string | null>;
  findIdentity: (profileId: string) => Promise<Identity | null>;
  issueSession: (identity: Identity) => Promise<SessionTokens>;
};

const headers = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
  'cache-control': 'no-store',
  'content-type': 'application/json',
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function reply(status: number, body: unknown) { return new Response(JSON.stringify(body), { status, headers }); }
function managed(identity: Identity | null, profileId: string): identity is Identity {
  return Boolean(identity && identity.id === profileId && identity.app_metadata?.bloom_managed_child === true
    && identity.app_metadata?.bloom_profile_id === profileId);
}
export async function body(request: Request, maxBytes = 2048): Promise<Record<string, unknown> | null> {
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const item = await reader.read();
      if (item.done) break;
      length += item.value.length;
      if (length > maxBytes) { await reader.cancel(); return null; }
      chunks.push(item.value);
    }
    const bytes = new Uint8Array(length);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    const parsed: unknown = JSON.parse(new TextDecoder().decode(bytes));
    return parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed as Record<string, unknown> : null;
  } catch { return null; }
}
export function preliminary(request: Request): Response | null {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (request.method !== 'POST') return reply(405, { error: 'Method not allowed' });
  return null;
}

export function provisionHandler(deps: ProvisionDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    const input = await body(request);
    const profileId = typeof input?.profile_id === 'string' ? input.profile_id.toLowerCase() : '';
    if (!uuid.test(profileId)) return reply(400, { error: 'Invalid profile' });
    try {
      const parentId = await deps.authenticate(token);
      if (!parentId) return reply(401, { error: 'Sign in required' });
      if (!await deps.authorize(token, profileId)) return reply(403, { error: 'Parent access required' });
      let identity = await deps.findIdentity(profileId);
      if (!identity) identity = await deps.createIdentity(profileId, parentId);
      if (!managed(identity, profileId)) return reply(409, { error: 'Child identity unavailable' });
      const code = await deps.issueCode(token, profileId);
      if (!/^[0-9a-f]{64}$/.test(code)) throw new Error('Invalid code from database');
      return reply(200, { code });
    } catch { return reply(503, { error: 'Could not prepare pairing. Please retry.' }); }
  };
}

export function pairHandler(deps: PairDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const input = await body(request);
    const code = typeof input?.code === 'string' ? input.code.trim().toLowerCase() : '';
    if (!/^[0-9a-f]{64}$/.test(code)) return reply(400, { error: 'Invalid or expired pairing code' });
    try {
      const hashBytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(code));
      const hash = Array.from(new Uint8Array(hashBytes), (value) => value.toString(16).padStart(2, '0')).join('');
      const profileId = await deps.consume(hash);
      if (!profileId || !uuid.test(profileId)) return reply(400, { error: 'Invalid or expired pairing code' });
      const identity = await deps.findIdentity(profileId);
      if (!managed(identity, profileId) || !identity.email) return reply(503, { error: 'Could not complete pairing. Ask a parent for a new code.' });
      const tokens = await deps.issueSession(identity);
      if (tokens.user_id !== profileId || !tokens.access_token || !tokens.refresh_token) throw new Error('Unexpected session identity');
      return reply(200, { access_token: tokens.access_token, refresh_token: tokens.refresh_token });
    } catch { return reply(503, { error: 'Could not complete pairing. Ask a parent for a new code.' }); }
  };
}
