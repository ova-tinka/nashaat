/** Fetch concurrently, but serialize native writes and discard obsolete fetches. */
export function createBlockingRulesCoordinator() {
  let generation = 0;
  let activeScope: string | null = null;
  let writes: Promise<void> = Promise.resolve();

  return {
    async sync<T, S>(scope: string, load: () => Promise<T>, apply: (rules: T) => Promise<S>): Promise<{ rules: T; status: S } | null> {
      activeScope = scope;
      const request = ++generation;
      const rules = await load();
      if (request !== generation) return null;
      const operation = writes.catch(() => undefined).then(async () => {
        if (request !== generation) return null;
        const status = await apply(rules);
        return request === generation ? { rules, status } : null;
      });
      writes = operation.then(() => undefined, () => undefined);
      return operation;
    },
    cancel(scope: string) {
      if (activeScope === scope) { generation += 1; activeScope = null; }
    },
  };
}
