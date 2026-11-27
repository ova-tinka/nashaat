import { body, preliminary, reply } from './child-pairing.ts';

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function extractJwtSessionId(token: string): string | null {
  const parts = token.split('.');
  if (parts.length !== 3 || !parts[1]) return null;
  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    const decoded = atob(padded);
    const parsed: unknown = JSON.parse(decoded);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    const sessionId = (parsed as Record<string, unknown>).session_id;
    return typeof sessionId === 'string' && uuidPattern.test(sessionId) ? sessionId : null;
  } catch {
    return null;
  }
}

export type RevokeDeviceDependencies = {
  authenticate: (token: string) => Promise<{ userId: string } | null>;
  revokeDevice: (token: string, deviceId: string) => Promise<{ sessionId: string | null }>;
  invalidateAuthSession: (userId: string, sessionId: string) => Promise<void>;
};

export function revokeDeviceHandler(deps: RevokeDeviceDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    const input = await body(request, 2048);
    const deviceId = typeof input?.device_id === 'string' ? input.device_id : '';
    if (!uuidPattern.test(deviceId)) return reply(400, { error: 'Invalid device identifier' });

    const auth = await deps.authenticate(token);
    if (!auth) return reply(401, { error: 'Sign in required' });

    try {
      const revoked = await deps.revokeDevice(token, deviceId);
      if (revoked.sessionId) {
        await deps.invalidateAuthSession(auth.userId, revoked.sessionId);
      }
      return reply(200, { revoked: true, device_id: deviceId, session_revoked: Boolean(revoked.sessionId) });
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : '';
      if (message.includes('Device was not found')) {
        return reply(404, { error: 'Device was not found' });
      }
      if (message.includes('Sign in')) {
        return reply(401, { error: 'Sign in required' });
      }
      return reply(503, { error: 'Could not revoke this device. Please try again.' });
    }
  };
}
