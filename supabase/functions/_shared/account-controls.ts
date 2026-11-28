import { preliminary, reply } from './child-pairing.ts';

export type ActiveIdentity = {
  userId: string;
  sessionId: string | null;
  lastSignInAt?: string | null;
};

export function extractJwtIat(token: string): number | null {
  const parts = token.split('.');
  if (parts.length !== 3 || !parts[1]) return null;
  try {
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4);
    const parsed: unknown = JSON.parse(atob(padded));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    const iat = (parsed as Record<string, unknown>).iat;
    return typeof iat === 'number' && Number.isFinite(iat) ? iat : null;
  } catch {
    return null;
  }
}

export function isFreshSignIn(options: {
  token: string;
  lastSignInAt?: string | null;
  maxAgeSeconds?: number;
  nowMs?: number;
}): boolean {
  const maxAgeMs = (options.maxAgeSeconds ?? 900) * 1000;
  const nowMs = options.nowMs ?? Date.now();
  if (options.lastSignInAt) {
    const parsed = Date.parse(options.lastSignInAt);
    if (Number.isFinite(parsed)) {
      return nowMs - parsed <= maxAgeMs;
    }
  }
  const iat = extractJwtIat(options.token);
  if (iat === null) return false;
  return nowMs - iat * 1000 <= maxAgeMs;
}

export type AccountExportDependencies = {
  authenticate: (token: string) => Promise<ActiveIdentity | null>;
  resolveProfileId: (token: string) => Promise<string | null>;
  exportAccountData: (profileId: string, userId: string) => Promise<{
    profile_id: string;
    exported_at: string;
    storage_paths: string[];
    data: Record<string, unknown>;
  }>;
  createSignedDownloadUrl: (storagePath: string, ttlSeconds: number) => Promise<string>;
  nowMs?: () => number;
};

export function accountExportHandler(deps: AccountExportDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });

    const auth = await deps.authenticate(token);
    if (!auth) return reply(401, { error: 'Sign in required' });
    if (!isFreshSignIn({ token, lastSignInAt: auth.lastSignInAt, nowMs: deps.nowMs?.() })) {
      return reply(403, {
        error: 'Please sign in again before exporting or deleting your account.',
        code: 'reauth_required',
      });
    }

    try {
      const profileId = await deps.resolveProfileId(token);
      if (!profileId) return reply(403, { error: 'Profile unavailable' });
      const exported = await deps.exportAccountData(profileId, auth.userId);
      const files = await Promise.all(
        (exported.storage_paths ?? []).map(async (path) => ({
          storage_path: path,
          download_url: await deps.createSignedDownloadUrl(path, 300),
          expires_in_seconds: 300,
        })),
      );
      return reply(200, {
        profile_id: exported.profile_id,
        exported_at: exported.exported_at,
        data: exported.data,
        files,
      });
    } catch {
      return reply(503, { error: 'Could not prepare your account export. Please try again.' });
    }
  };
}

export type DeletionJobRecord = {
  id: string;
  profile_id: string;
  account_scope: 'personal' | 'family_review';
  status:
    | 'queued'
    | 'revoking_access'
    | 'removing_files'
    | 'clearing_records'
    | 'deleting_auth_user'
    | 'completed'
    | 'needs_family_review'
    | 'needs_billing_cancellation';
  pending_storage_paths: string[];
  revoked_session_ids?: string[];
};

export type AccountDeleteDependencies = {
  authenticate: (token: string) => Promise<ActiveIdentity | null>;
  resolveProfileId: (token: string) => Promise<string | null>;
  requestDeletion: (profileId: string | null, userId: string) => Promise<DeletionJobRecord>;
  advanceDeletionJob: (
    jobId: string,
    step: 'revoke_access' | 'mark_files_removed' | 'clear_records' | 'finalize',
    removedPaths?: string[],
    sessionId?: string | null,
  ) => Promise<DeletionJobRecord>;
  invalidateAuthSession: (userId: string, sessionId: string) => Promise<void>;
  removeStorageFile: (storagePath: string) => Promise<void>;
  deleteAuthUser: (userId: string) => Promise<void>;
  nowMs?: () => number;
};

export function accountDeleteHandler(deps: AccountDeleteDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });

    const auth = await deps.authenticate(token);
    if (!auth) return reply(401, { error: 'Sign in required' });
    if (!isFreshSignIn({ token, lastSignInAt: auth.lastSignInAt, nowMs: deps.nowMs?.() })) {
      return reply(403, {
        error: 'Please sign in again before exporting or deleting your account.',
        code: 'reauth_required',
      });
    }

    try {
      const profileId = await deps.resolveProfileId(token);
      let job: DeletionJobRecord;
      try {
        job = await deps.requestDeletion(profileId, auth.userId);
      } catch {
        if (!profileId) return reply(403, { error: 'Profile unavailable' });
        throw new Error('Deletion request failed');
      }

      if (job.status === 'needs_family_review') {
        return reply(202, {
          status: 'needs_family_review',
          job_id: job.id,
          message: 'Active Family accounts require a reviewed deletion so other family members and their wallets stay protected.',
        });
      }

      if (job.status === 'needs_billing_cancellation') {
        return reply(409, {
          status: 'needs_billing_cancellation',
          job_id: job.id,
          error: 'Cancel your active Tap subscription and wait for any pending payments or refunds to settle before deleting your account.',
        });
      }

      if (job.status === 'queued' || job.status === 'revoking_access') {
        job = await deps.advanceDeletionJob(job.id, 'revoke_access', [], auth.sessionId);
        for (const sid of job.revoked_session_ids ?? []) {
          await deps.invalidateAuthSession(auth.userId, sid);
        }
      }

      if (job.status === 'removing_files' && job.pending_storage_paths.length > 0) {
        const removed: string[] = [];
        for (const path of job.pending_storage_paths) {
          try {
            await deps.removeStorageFile(path);
            removed.push(path);
          } catch {
            // Stop removing further files and checkpoint already-removed paths so retry resumes cleanly.
            break;
          }
        }
        if (removed.length > 0) {
          job = await deps.advanceDeletionJob(job.id, 'mark_files_removed', removed, null);
        }
        if (job.status === 'removing_files' && job.pending_storage_paths.length > 0) {
          return reply(503, {
            error: 'Account deletion paused while removing private files. Retry to resume.',
            job_id: job.id,
            remaining_files: job.pending_storage_paths.length,
          });
        }
      }

      if (job.status === 'clearing_records') {
        job = await deps.advanceDeletionJob(job.id, 'clear_records', [], null);
      }

      if (job.status === 'deleting_auth_user') {
        await deps.deleteAuthUser(auth.userId);
        job = await deps.advanceDeletionJob(job.id, 'finalize', [], auth.sessionId);
      }

      if (job.status === 'completed') {
        return reply(200, { status: 'completed', job_id: job.id });
      }

      return reply(503, { error: 'Account deletion could not complete. Retry to resume.', job_id: job.id });
    } catch {
      return reply(503, { error: 'Could not process account deletion. Please try again.' });
    }
  };
}
