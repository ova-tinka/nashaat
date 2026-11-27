export type StorageDriver = {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
  removeItem: (key: string) => Promise<void>;
};

const CHUNK_META_PREFIX = '__bloom_chunks_v1__:';

function splitByUtf8Bytes(value: string, maxChunkBytes: number): string[] {
  const encoder = new TextEncoder();
  const chunks: string[] = [];
  let current = '';
  let currentBytes = 0;

  for (const char of value) {
    const charBytes = encoder.encode(char).length;
    if (currentBytes + charBytes > maxChunkBytes && current.length > 0) {
      chunks.push(current);
      current = char;
      currentBytes = charBytes;
    } else {
      current += char;
      currentBytes += charBytes;
    }
  }
  if (current.length > 0 || chunks.length === 0) {
    chunks.push(current);
  }
  return chunks;
}

export function createChunkedProtectedStorage(options: {
  primary: StorageDriver;
  legacy?: StorageDriver;
  maxChunkBytes?: number;
}): StorageDriver {
  const { primary, legacy } = options;
  const maxChunkBytes = options.maxChunkBytes ?? 1800;

  async function removeChunks(key: string, count: number) {
    for (let i = 0; i < count; i += 1) {
      await primary.removeItem(`${key}.chunk.${i}`);
    }
  }

  async function readPrimary(key: string): Promise<string | null> {
    const raw = await primary.getItem(key);
    if (raw === null) return null;
    if (!raw.startsWith(CHUNK_META_PREFIX)) return raw;
    const count = Number.parseInt(raw.slice(CHUNK_META_PREFIX.length), 10);
    if (!Number.isSafeInteger(count) || count <= 0 || count > 256) return null;
    const parts: string[] = [];
    for (let i = 0; i < count; i += 1) {
      const chunk = await primary.getItem(`${key}.chunk.${i}`);
      if (chunk === null) return null;
      parts.push(chunk);
    }
    return parts.join('');
  }

  async function writePrimary(key: string, value: string): Promise<void> {
    const previousMeta = await primary.getItem(key);
    const previousCount = previousMeta?.startsWith(CHUNK_META_PREFIX)
      ? Number.parseInt(previousMeta.slice(CHUNK_META_PREFIX.length), 10)
      : 0;

    const totalBytes = new TextEncoder().encode(value).length;
    if (totalBytes <= maxChunkBytes) {
      await primary.setItem(key, value);
      if (Number.isSafeInteger(previousCount) && previousCount > 0) {
        await removeChunks(key, previousCount);
      }
      return;
    }

    const chunks = splitByUtf8Bytes(value, maxChunkBytes);
    for (let i = 0; i < chunks.length; i += 1) {
      await primary.setItem(`${key}.chunk.${i}`, chunks[i]);
    }
    await primary.setItem(key, `${CHUNK_META_PREFIX}${chunks.length}`);
    if (Number.isSafeInteger(previousCount) && previousCount > chunks.length) {
      for (let i = chunks.length; i < previousCount; i += 1) {
        await primary.removeItem(`${key}.chunk.${i}`);
      }
    }
  }

  return {
    async getItem(key: string) {
      const direct = await readPrimary(key);
      if (direct !== null) return direct;
      if (!legacy) return null;
      const migrated = await legacy.getItem(key);
      if (migrated === null) return null;
      await writePrimary(key, migrated);
      await legacy.removeItem(key).catch(() => undefined);
      return migrated;
    },
    async setItem(key: string, value: string) {
      await writePrimary(key, value);
      if (legacy) {
        await legacy.removeItem(key).catch(() => undefined);
      }
    },
    async removeItem(key: string) {
      const meta = await primary.getItem(key);
      const count = meta?.startsWith(CHUNK_META_PREFIX)
        ? Number.parseInt(meta.slice(CHUNK_META_PREFIX.length), 10)
        : 0;
      await primary.removeItem(key);
      if (Number.isSafeInteger(count) && count > 0) {
        await removeChunks(key, count);
      }
      if (legacy) {
        await legacy.removeItem(key).catch(() => undefined);
      }
    },
  };
}
