import { provisionHandler } from '../_shared/child-pairing.ts';
import { admin, findIdentity, userClient } from '../_shared/supabase.ts';

Deno.serve(provisionHandler({
  async authenticate(token) {
    const { data, error } = await userClient().auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },
  async authorize(token, profileId) {
    const { data, error } = await userClient(token).rpc('bloom_authorize_child_provisioning', { p_profile_id: profileId });
    return !error && data === profileId;
  },
  findIdentity,
  async createIdentity(profileId, parentId) {
    const { data, error } = await admin.auth.admin.createUser({
      id: profileId,
      email: `child-${profileId}@bloom.invalid`,
      email_confirm: true,
      app_metadata: { bloom_managed_child: true, bloom_profile_id: profileId, bloom_parent_id: parentId },
    });
    if (error || !data.user) {
      // A concurrent request may already have provisioned this exact profile.
      const existing = await findIdentity(profileId);
      if (existing) return existing;
      throw new Error('Could not provision child identity');
    }
    return { id: data.user.id, email: data.user.email, app_metadata: data.user.app_metadata };
  },
  async issueCode(token, profileId) {
    const { data, error } = await userClient(token).rpc('bloom_create_child_pairing_code', { p_profile_id: profileId });
    if (error || typeof data !== 'string') throw new Error('Could not issue pairing code');
    return data;
  },
}));
