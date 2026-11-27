import { accountDeleteHandler, type DeletionJobRecord } from '../_shared/account-controls.ts';
import { admin, authenticateActiveUser, invalidateAuthSession, userClient } from '../_shared/supabase.ts';

Deno.serve(accountDeleteHandler({
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
  async requestDeletion(profileId, userId) {
    const { data, error } = await admin.rpc('bloom_request_account_deletion', {
      p_profile_id: profileId,
      p_user_id: userId,
    });
    if (error || !data || typeof data !== 'object') throw new Error('Deletion request failed');
    return data as DeletionJobRecord;
  },
  async advanceDeletionJob(jobId, step, removedPaths = [], sessionId = null) {
    const { data, error } = await admin.rpc('bloom_advance_account_deletion_job', {
      p_job_id: jobId,
      p_step: step,
      p_removed_paths: removedPaths,
      p_session_id: sessionId,
    });
    if (error || !data || typeof data !== 'object') throw new Error('Deletion advance failed');
    return data as DeletionJobRecord;
  },
  invalidateAuthSession,
  async removeStorageFile(storagePath) {
    const { error } = await admin.storage.from('bloom-growth-content').remove([storagePath]);
    if (error) throw error;
  },
  async deleteAuthUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
}));
