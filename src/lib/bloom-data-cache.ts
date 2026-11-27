export type SectionLoadResult<T extends Record<string, unknown>> = {
  values: { [K in keyof T]?: T[K] };
  errors: { [K in keyof T]?: unknown };
};

export function createProfileQueryCoordinator() {
  const initialized = new Set<string>();
  const initInFlight = new Map<string, Promise<void>>();
  const inFlight = new Map<string, Promise<unknown>>();
  const cached = new Map<string, unknown>();

  function cacheKey(profileId: string, key: string) {
    return `${profileId}:${key}`;
  }

  return {
    async ensureInitializedOnce(profileId: string, initFn: () => Promise<void>): Promise<void> {
      if (initialized.has(profileId)) return;
      const existing = initInFlight.get(profileId);
      if (existing) return existing;
      const promise = initFn()
        .then(() => {
          initialized.add(profileId);
        })
        .finally(() => {
          initInFlight.delete(profileId);
        });
      initInFlight.set(profileId, promise);
      return promise;
    },

    async runDeduplicated<T>(profileId: string, key: string, loader: () => Promise<T>, useCache = false): Promise<T> {
      const fullKey = cacheKey(profileId, key);
      if (useCache && cached.has(fullKey)) {
        return cached.get(fullKey) as T;
      }
      const existing = inFlight.get(fullKey) as Promise<T> | undefined;
      if (existing) return existing;
      const promise = loader()
        .then((result) => {
          if (useCache) cached.set(fullKey, result);
          return result;
        })
        .finally(() => {
          inFlight.delete(fullKey);
        });
      inFlight.set(fullKey, promise);
      return promise;
    },

    invalidate(profileId: string, keys?: string[]) {
      if (!keys) {
        for (const k of [...cached.keys()]) {
          if (k.startsWith(`${profileId}:`)) cached.delete(k);
        }
        return;
      }
      for (const key of keys) {
        cached.delete(cacheKey(profileId, key));
      }
    },

    resetProfile(profileId: string) {
      initialized.delete(profileId);
      initInFlight.delete(profileId);
      this.invalidate(profileId);
    },
  };
}

export async function loadSectionsIndependently<T extends Record<string, unknown>>(
  loaders: { [K in keyof T]: () => Promise<T[K]> },
): Promise<SectionLoadResult<T>> {
  const entries = Object.entries(loaders) as [keyof T, () => Promise<T[keyof T]>][];
  const settled = await Promise.allSettled(entries.map(([, fn]) => fn()));
  const values: { [K in keyof T]?: T[K] } = {};
  const errors: { [K in keyof T]?: unknown } = {};

  entries.forEach(([key], index) => {
    const result = settled[index];
    if (result.status === 'fulfilled') {
      values[key] = result.value;
    } else {
      errors[key] = result.reason;
    }
  });

  return { values, errors };
}
