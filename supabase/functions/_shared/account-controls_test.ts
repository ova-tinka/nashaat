import { accountDeleteHandler, accountExportHandler, type DeletionJobRecord } from './account-controls.ts';

function assert(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

function makeJwt(payload: Record<string, unknown>): string {
  const encode = (value: unknown) => btoa(JSON.stringify(value)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return `${encode({ alg: 'HS256', typ: 'JWT' })}.${encode(payload)}.signature`;
}

Deno.test('accountExportHandler rejects stale sign-in and returns owned data with short-lived URLs', async () => {
  const nowMs = 1_700_000_000_000;
  const staleToken = makeJwt({ sub: 'u1', iat: Math.floor((nowMs - 3600_000) / 1000) });
  const freshToken = makeJwt({ sub: 'u1', iat: Math.floor((nowMs - 60_000) / 1000) });

  const handler = accountExportHandler({
    authenticate: async () => ({ userId: 'u1', sessionId: 's1' }),
    resolveProfileId: async () => 'p1',
    exportAccountData: async () => ({
      profile_id: 'p1',
      exported_at: '2026-11-27T00:00:00Z',
      storage_paths: ['p1/read/doc1.pdf'],
      data: { profile: { id: 'p1' } },
    }),
    createSignedDownloadUrl: async (path, ttl) => {
      assert(ttl === 300, `Expected 300s TTL, got ${ttl}`);
      return `https://signed.example/${path}?ttl=${ttl}`;
    },
    nowMs: () => nowMs,
  });

  const staleRes = await handler(new Request('http://localhost/', { method: 'POST', headers: { authorization: `Bearer ${staleToken}` } }));
  assert(staleRes.status === 403, `Expected 403 for stale sign-in, got ${staleRes.status}`);

  const freshRes = await handler(new Request('http://localhost/', { method: 'POST', headers: { authorization: `Bearer ${freshToken}` } }));
  assert(freshRes.status === 200 && freshRes.headers.get('cache-control') === 'no-store', 'Expected 200 no-store export');
  const payload = await freshRes.json() as { files: { storage_path: string; expires_in_seconds: number }[] };
  assert(payload.files.length === 1 && payload.files[0].expires_in_seconds === 300, 'Expected short-lived file URL');
});

Deno.test('accountDeleteHandler routes active Family accounts to review and resumes partial personal deletion', async () => {
  const nowMs = 1_700_000_000_000;
  const freshToken = makeJwt({ sub: 'u1', iat: Math.floor((nowMs - 30_000) / 1000) });

  // 1. Family account routes to needs_family_review with zero deletions.
  let authDeleted = false;
  const familyRes = await accountDeleteHandler({
    authenticate: async () => ({ userId: 'u-fam', sessionId: 's-fam' }),
    resolveProfileId: async () => 'p-fam',
    requestDeletion: async () => ({
      id: 'job-fam',
      profile_id: 'p-fam',
      account_scope: 'family_review',
      status: 'needs_family_review',
      pending_storage_paths: [],
    }),
    advanceDeletionJob: async () => {
      throw new Error('must not advance family review job');
    },
    invalidateAuthSession: async () => {},
    removeStorageFile: async () => {},
    deleteAuthUser: async () => { authDeleted = true; },
    nowMs: () => nowMs,
  })(new Request('http://localhost/', { method: 'POST', headers: { authorization: `Bearer ${freshToken}` } }));
  assert(familyRes.status === 202 && !authDeleted, 'Family account must return 202 without deleting');

  // 2. Personal account with 2 files fails on 2nd file, then retry resumes only 2nd file and completes.
  let job: DeletionJobRecord = {
    id: 'job-1',
    profile_id: 'p1',
    account_scope: 'personal',
    status: 'queued',
    pending_storage_paths: ['p1/read/a.pdf', 'p1/read/b.pdf'],
  };
  let failSecondFile = true;
  const deletedFiles: string[] = [];
  const personalHandler = accountDeleteHandler({
    authenticate: async () => ({ userId: 'u1', sessionId: 's1' }),
    resolveProfileId: async () => 'p1',
    requestDeletion: async () => job,
    advanceDeletionJob: async (_jobId, step, removed = []) => {
      if (step === 'revoke_access') {
        job = { ...job, status: 'removing_files', revoked_session_ids: ['s1'] };
      } else if (step === 'mark_files_removed') {
        const remaining = job.pending_storage_paths.filter((p) => !removed.includes(p));
        job = { ...job, pending_storage_paths: remaining, status: remaining.length ? 'removing_files' : 'clearing_records' };
      } else if (step === 'clear_records') {
        job = { ...job, status: 'completed' };
      }
      return job;
    },
    invalidateAuthSession: async () => {},
    removeStorageFile: async (path) => {
      if (path === 'p1/read/b.pdf' && failSecondFile) {
        failSecondFile = false;
        throw new Error('storage timeout');
      }
      deletedFiles.push(path);
    },
    deleteAuthUser: async () => { authDeleted = true; },
    nowMs: () => nowMs,
  });

  const firstAttempt = await personalHandler(new Request('http://localhost/', { method: 'POST', headers: { authorization: `Bearer ${freshToken}` } }));
  assert(firstAttempt.status === 503 && !authDeleted, 'Partial failure should pause with 503');
  assert(job.pending_storage_paths.length === 1 && job.pending_storage_paths[0] === 'p1/read/b.pdf', 'Only remaining file should stay pending');

  const retryAttempt = await personalHandler(new Request('http://localhost/', { method: 'POST', headers: { authorization: `Bearer ${freshToken}` } }));
  assert(retryAttempt.status === 200 && authDeleted, 'Retry should complete deletion');
  assert(deletedFiles.length === 2 && deletedFiles[0] === 'p1/read/a.pdf' && deletedFiles[1] === 'p1/read/b.pdf', 'Each file deleted once');
});
