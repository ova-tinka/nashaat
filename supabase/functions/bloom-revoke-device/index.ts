import { revokeDeviceHandler } from '../_shared/session-revocation.ts';
import { authenticateActiveUser, invalidateAuthSession, userClient } from '../_shared/supabase.ts';

Deno.serve(revokeDeviceHandler({
  async authenticate(token) {
    const active = await authenticateActiveUser(token);
    return active ? { userId: active.user.id } : null;
  },
  async revokeDevice(token, deviceId) {
    const { data, error } = await userClient(token).rpc('bloom_revoke_device', { p_device_id: deviceId });
    if (error) throw new Error(error.message || 'Could not revoke device');
    const row = (data ?? {}) as { session_id?: unknown };
    return { sessionId: typeof row.session_id === 'string' ? row.session_id : null };
  },
  invalidateAuthSession,
}));
