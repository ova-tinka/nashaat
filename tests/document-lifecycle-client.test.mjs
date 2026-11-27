import assert from 'node:assert/strict';
import test from 'node:test';
import {
  checkFileByteSizeBeforeBuffer,
  reconcileIncompleteDocuments,
  runDocumentDelete,
  runDocumentUpload,
} from '../src/lib/document-lifecycle.ts';

test('checkFileByteSizeBeforeBuffer rejects empty, missing, and oversized files without buffering', async () => {
  await assert.rejects(
    () => checkFileByteSizeBeforeBuffer({ reportedSize: 0, maxBytes: 1024 }),
    /empty/,
  );
  await assert.rejects(
    () => checkFileByteSizeBeforeBuffer({ reportedSize: 2048, maxBytes: 1024 }),
    /smaller/,
  );
  await assert.rejects(
    () => checkFileByteSizeBeforeBuffer({ reportedSize: undefined, maxBytes: 1024, inspectSize: () => null }),
    /Could not verify/,
  );
  assert.equal(await checkFileByteSizeBeforeBuffer({ reportedSize: undefined, maxBytes: 1024, inspectSize: () => 512 }), 512);
});

test('runDocumentUpload recovers after interrupted upload or confirm on retry using same request', async () => {
  let status = 'pending';
  let objectUploaded = false;
  let confirmCalls = 0;

  // Attempt 1: upload succeeds, confirm fails due to network drop.
  await assert.rejects(() => runDocumentUpload({
    prepare: async () => ({ id: 'doc-1', storagePath: 'p/study/doc-1.pdf', status }),
    uploadObject: async () => {
      objectUploaded = true;
    },
    confirm: async () => {
      confirmCalls += 1;
      if (confirmCalls === 1) throw new Error('network lost');
      status = 'ready';
    },
  }), /network lost/);
  assert.equal(objectUploaded, true);

  // Attempt 2: prepare returns existing pending doc, storage returns 409 duplicate, confirm succeeds.
  const finalDoc = await runDocumentUpload({
    prepare: async () => ({ id: 'doc-1', storagePath: 'p/study/doc-1.pdf', status }),
    uploadObject: async () => {
      const err = new Error('The resource already exists');
      err.statusCode = '409';
      throw err;
    },
    confirm: async () => {
      confirmCalls += 1;
      status = 'ready';
    },
  });
  assert.equal(finalDoc.status, 'ready');
  assert.equal(confirmCalls, 2);
});

test('runDocumentDelete and reconcileIncompleteDocuments finish interrupted deletes and abandoned uploads', async () => {
  const storage = new Set(['p/read/deleting.pdf', 'p/read/pending-uploaded.pdf']);
  const docs = new Map([
    ['d1', { id: 'd1', storagePath: 'p/read/deleting.pdf', status: 'deleting' }],
    ['d2', { id: 'd2', storagePath: 'p/read/pending-uploaded.pdf', status: 'pending' }],
    ['d3', { id: 'd3', storagePath: 'p/read/pending-abandoned.pdf', status: 'pending' }],
  ]);

  // Simulate delete interrupted after beginDelete:
  await assert.rejects(() => runDocumentDelete({
    documentId: 'd1',
    storagePath: 'p/read/deleting.pdf',
    beginDelete: async () => {},
    removeObject: async () => {
      throw new Error('offline');
    },
    finalizeDelete: async () => {},
  }), /offline/);

  const result = await reconcileIncompleteDocuments({
    listIncomplete: async () => [...docs.values()],
    objectExists: async (path) => storage.has(path),
    confirm: async (id) => {
      docs.delete(id);
    },
    removeObject: async (path) => {
      storage.delete(path);
    },
    finalizeDelete: async (id) => {
      docs.delete(id);
    },
  });

  assert.deepEqual(result, { confirmed: 1, deleted: 2 });
  assert.equal(docs.size, 0);
  assert.equal(storage.has('p/read/deleting.pdf'), false);
  assert.equal(storage.has('p/read/pending-uploaded.pdf'), true);
});
