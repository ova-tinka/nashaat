import { supabase } from './supabase';

export type AccountExportResult = {
  profile_id: string;
  exported_at: string;
  data: Record<string, unknown>;
  files: { storage_path: string; download_url: string; expires_in_seconds: number }[];
};

export type AccountDeletionResult =
  | { status: 'completed'; job_id: string }
  | { status: 'needs_family_review'; job_id: string; message: string };

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function requestAccountExport(): Promise<AccountExportResult> {
  const { data, error } = await client().functions.invoke('bloom-account-export', { body: {} });
  if (error || !data || typeof data.profile_id !== 'string') {
    const code = typeof data?.code === 'string' ? data.code : undefined;
    if (code === 'reauth_required') {
      throw new Error('Please sign in again before exporting your account data.');
    }
    throw new Error(typeof data?.error === 'string' ? data.error : 'Could not prepare your account export.');
  }
  return data as AccountExportResult;
}

export async function requestAccountDeletion(): Promise<AccountDeletionResult> {
  const { data, error } = await client().functions.invoke('bloom-account-delete', { body: {} });
  if (error) {
    const code = typeof data?.code === 'string' ? data.code : undefined;
    if (code === 'reauth_required') {
      throw new Error('Please sign in again before deleting your account.');
    }
    throw new Error(typeof data?.error === 'string' ? data.error : 'Could not delete your account. Please try again.');
  }
  if (data?.status === 'needs_family_review') {
    return data as AccountDeletionResult;
  }
  if (data?.status === 'completed') {
    await client().auth.signOut({ scope: 'local' }).catch(() => undefined);
    return data as AccountDeletionResult;
  }
  throw new Error('Could not complete account deletion. Please retry.');
}
