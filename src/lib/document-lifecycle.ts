export type DocumentLifecycleStatus = 'pending' | 'ready' | 'deleting';

export type PreparedDocument = {
  id: string;
  storagePath: string;
  status: DocumentLifecycleStatus;
};

export async function checkFileByteSizeBeforeBuffer(options: {
  reportedSize?: number | null;
  maxBytes: number;
  inspectSize?: () => Promise<number | null | undefined> | number | null | undefined;
}): Promise<number> {
  const rawSize = typeof options.reportedSize === 'number' && Number.isFinite(options.reportedSize)
    ? options.reportedSize
    : await options.inspectSize?.();
  if (typeof rawSize !== 'number' || !Number.isFinite(rawSize)) {
    throw new Error('Could not verify the file size before reading it.');
  }
  if (rawSize <= 0) {
    throw new Error('This file is empty.');
  }
  if (rawSize > options.maxBytes) {
    const limitMb = Math.round(options.maxBytes / (1024 * 1024));
    throw new Error(`Choose a non-empty file smaller than ${limitMb} MB.`);
  }
  return rawSize;
}

function isStorageAlreadyExistsError(cause: unknown): boolean {
  if (!cause || typeof cause !== 'object') return false;
  const record = cause as { statusCode?: unknown; status?: unknown; message?: unknown };
  const msg = typeof record.message === 'string' ? record.message.toLowerCase() : '';
  return record.statusCode === '409'
    || record.status === 409
    || msg.includes('already exists')
    || msg.includes('duplicate');
}

function isStorageMissingError(cause: unknown): boolean {
  if (!cause || typeof cause !== 'object') return false;
  const record = cause as { statusCode?: unknown; status?: unknown; message?: unknown };
  const msg = typeof record.message === 'string' ? record.message.toLowerCase() : '';
  return record.statusCode === '404'
    || record.status === 404
    || msg.includes('not found');
}

export async function runDocumentUpload(options: {
  prepare: () => Promise<PreparedDocument>;
  uploadObject: (storagePath: string) => Promise<void>;
  confirm: (documentId: string) => Promise<void>;
}): Promise<PreparedDocument> {
  const prepared = await options.prepare();
  if (prepared.status === 'deleting') {
    throw new Error('This document is currently being deleted.');
  }
  if (prepared.status === 'pending') {
    try {
      await options.uploadObject(prepared.storagePath);
    } catch (cause) {
      if (!isStorageAlreadyExistsError(cause)) throw cause;
    }
    await options.confirm(prepared.id);
  }
  return { ...prepared, status: 'ready' };
}

export async function runDocumentDelete(options: {
  documentId: string;
  storagePath: string;
  beginDelete: (documentId: string) => Promise<void>;
  removeObject: (storagePath: string) => Promise<void>;
  finalizeDelete: (documentId: string) => Promise<void>;
}): Promise<void> {
  await options.beginDelete(options.documentId);
  try {
    await options.removeObject(options.storagePath);
  } catch (cause) {
    if (!isStorageMissingError(cause)) throw cause;
  }
  await options.finalizeDelete(options.documentId);
}

export async function reconcileIncompleteDocuments(options: {
  listIncomplete: () => Promise<{ id: string; storagePath: string; status: 'pending' | 'deleting' }[]>;
  objectExists: (storagePath: string) => Promise<boolean>;
  confirm: (documentId: string) => Promise<void>;
  removeObject: (storagePath: string) => Promise<void>;
  finalizeDelete: (documentId: string) => Promise<void>;
}): Promise<{ confirmed: number; deleted: number }> {
  const pendingOrDeleting = await options.listIncomplete();
  let confirmed = 0;
  let deleted = 0;
  for (const doc of pendingOrDeleting) {
    if (doc.status === 'deleting') {
      if (await options.objectExists(doc.storagePath)) {
        await options.removeObject(doc.storagePath);
      }
      await options.finalizeDelete(doc.id);
      deleted += 1;
      continue;
    }
    if (await options.objectExists(doc.storagePath)) {
      await options.confirm(doc.id);
      confirmed += 1;
    } else {
      await options.finalizeDelete(doc.id);
      deleted += 1;
    }
  }
  return { confirmed, deleted };
}
