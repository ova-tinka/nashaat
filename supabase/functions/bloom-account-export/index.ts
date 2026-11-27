import { accountExportHandler } from '../_shared/account-controls.ts';
import { admin, authenticateActiveUser, userClient } from '../_shared/supabase.ts';

Deno.serve(accountExportHandler({
  async authenticate(token) {
    const active = await authenticateActiveUser(token);
    if (!active) return null;
    return {
      userId: active.user.id,
      sessionId: active.sessionId,
      lastSignInAt: active.user.last_sign_in_at ?? null,
    };
  },
  async resolveProfileId(token) {
    const { data, error } = await userClient(token).rpc('bloom_current_profile');
    if (error || typeof data?.profile_id !== 'string') return null;
    return data.profile_id;
  },
  async exportAccountData(profileId, userId) {
    const { data, error } = await admin.rpc('bloom_export_my_account_data', {
      p_profile_id: profileId,
      p_user_id: userId,
    });
    if (error || !data || typeof data !== 'object') throw new Error('Export failed');
    return data as {
      profile_id: string;
      exported_at: string;
      storage_paths: string[];
      data: Record<string, unknown>;
    };
  },
  async createSignedDownloadUrl(storagePath, ttlSeconds) {
    const { data, error } = await admin.storage.from('bloom-growth-content').createSignedUrl(storagePath, ttlSeconds);
    if (error || !data?.signedUrl) throw new Error('Signed URL unavailable');
    return data.signedUrl;
  },
}));
