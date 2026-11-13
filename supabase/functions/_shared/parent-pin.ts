import { body, preliminary, reply, type Identity, type SessionTokens } from './child-pairing.ts';

export type UnlockDependencies = {
  authenticate: (token: string) => Promise<string | null>;
  verify: (childId: string, deviceId: string, secret: string, pin: string) => Promise<string | null>;
  eligibleParent: (parentId: string) => Promise<Identity | null>;
  issueSession: (identity: Identity) => Promise<SessionTokens>;
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function unlockHandler(deps: UnlockDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    const input = await body(request);
    const deviceId = typeof input?.device_id === 'string' ? input.device_id : '';
    const secret = typeof input?.device_secret === 'string' ? input.device_secret : '';
    const pin = typeof input?.pin === 'string' ? input.pin : '';
    if (!uuid.test(deviceId) || !/^[0-9a-f]{64}$/.test(secret) || !/^[0-9]{6}$/.test(pin)) {
      return reply(400, { error: 'Enter the six-digit parent PIN' });
    }
    try {
      const childId = await deps.authenticate(token);
      if (!childId) return reply(401, { error: 'Sign in required' });
      const parentId = await deps.verify(childId, deviceId, secret, pin);
      if (!parentId) return reply(401, { error: 'PIN unavailable or incorrect' });
      const parent = await deps.eligibleParent(parentId);
      if (!parent || parent.id !== parentId || parent.app_metadata?.bloom_managed_child === true) {
        return reply(403, { error: 'Sign in with your parent account instead' });
      }
      const tokens = await deps.issueSession(parent);
      if (tokens.user_id !== parentId || !tokens.access_token || !tokens.refresh_token) throw new Error('Unexpected session identity');
      return reply(200, { access_token: tokens.access_token, refresh_token: tokens.refresh_token });
    } catch { return reply(503, { error: 'Could not switch accounts. Please try again.' }); }
  };
}
