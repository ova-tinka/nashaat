const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Test mode is fail-closed and permits only one explicitly configured account. */
export function coachAccess(config: {
  enabled: boolean; providerApproved: boolean; modelVerified: boolean;
  model: string; apiKeyPresent: boolean; testMode: boolean; testUserId: string; testExpiresAt: string;
}) {
  const testAccountValid = uuid.test(config.testUserId);
  const expiry = Date.parse(config.testExpiresAt);
  const testWindowValid = () => Number.isFinite(expiry) && expiry > Date.now() && expiry <= Date.now() + 30 * 60 * 1000;
  const enabled = config.enabled && config.providerApproved && Boolean(config.model && config.apiKeyPresent)
    && (config.testMode ? testAccountValid && testWindowValid() : config.modelVerified);
  return {
    enabled,
    permits: (userId: string) => enabled && (!config.testMode || (testWindowValid() && userId.toLowerCase() === config.testUserId.toLowerCase())),
  };
}
