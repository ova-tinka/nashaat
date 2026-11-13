import { unlockHandler } from '../_shared/parent-pin.ts';
import { admin, issueSession, userClient } from '../_shared/supabase.ts';

Deno.serve(unlockHandler({
  async authenticate(token) {
    const { data, error } = await userClient().auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },
  async verify(childId, deviceId, secret, pin) {
    const { data, error } = await admin.rpc('bloom_verify_parent_pin', {
      p_child_id: childId, p_device_id: deviceId, p_device_secret: secret, p_pin: pin,
    });
    if (error) throw new Error('PIN verification failed');
    return typeof data === 'string' ? data : null;
  },
  async eligibleParent(parentId) {
    const result = await admin.auth.admin.getUserById(parentId);
    const user = result.data.user;
    if (result.error || !user || !user.email || !user.email_confirmed_at || user.is_sso_user || user.is_anonymous
      || (user.banned_until && Date.parse(user.banned_until) > Date.now())) return null;
    // A PIN must not bypass an account's configured MFA.
    const factors = await admin.auth.admin.mfa.listFactors({ userId: parentId });
    if (factors.error || factors.data.factors.some((factor) => factor.status === 'verified')) return null;
    return { id: user.id, email: user.email, app_metadata: user.app_metadata };
  },
  issueSession,
}));
