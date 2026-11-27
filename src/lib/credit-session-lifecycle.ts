export type UsageReservationRecord = {
  userId: string;
  requestId: string;
  deviceKey: string;
  requestedMillis: number;
  sessionId?: string | null;
  state: 'pending' | 'active' | 'closing';
};

export type ReservationStorage = {
  getItem(key: string): Promise<string | null>;
  setItem(key: string, value: string): Promise<void>;
  removeItem(key: string): Promise<void>;
};

export type NativeUsageSession = {
  sessionId: string;
  userId: string;
};

export type ServerUsageSession = {
  id: string;
  settled_at: string | null;
};

export type UsageReconcileOutcome = {
  status: 'none' | 'active' | 'pending_server_settlement' | 'settled_cleanup' | 'recovery_key_missing';
  record: UsageReservationRecord | null;
  serverSessionId?: string | null;
  message?: string;
};

export type EnforcementConfirmationInput = {
  platform: 'macos' | 'ios' | 'android' | 'web' | 'windows';
  configured: boolean;
  authorized: boolean;
  active: boolean;
  providerHealthy?: boolean;
  hideFailed?: boolean;
  brokerAcknowledged?: boolean;
};

export type EnforcementConfirmation = {
  confirmed: boolean;
  status: 'confirmed' | 'degraded' | 'inactive' | 'unsupported';
  reason: string | null;
};

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function parseUsageReservationRecord(raw: string | null, expectedUserId?: string): UsageReservationRecord | null {
  if (!raw) return null;
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    const value = parsed as Record<string, unknown>;
    if (typeof value.requestId !== 'string' || !uuidPattern.test(value.requestId)) return null;
    if (typeof value.deviceKey !== 'string' || !uuidPattern.test(value.deviceKey)) return null;
    if (!Number.isSafeInteger(value.requestedMillis) || Number(value.requestedMillis) < 1000 || Number(value.requestedMillis) > 604_800_000) {
      return null;
    }

    const storedUserId = typeof value.userId === 'string' && value.userId.length > 0 ? value.userId : expectedUserId;
    if (!storedUserId) return null;
    if (expectedUserId && storedUserId !== expectedUserId) return null;

    const sessionId = typeof value.sessionId === 'string' && uuidPattern.test(value.sessionId) ? value.sessionId : null;
    const state = value.state === 'active' || value.state === 'closing' ? value.state : 'pending';
    return {
      userId: storedUserId,
      requestId: value.requestId,
      deviceKey: value.deviceKey,
      requestedMillis: Number(value.requestedMillis),
      sessionId,
      state,
    };
  } catch {
    return null;
  }
}

/**
 * Persist the owning request and deviceKey BEFORE issuing a reservation so any
 * crash, route change, or network failure can reconcile the exact same owner.
 */
export async function prepareOrRecoverUsageReservation(
  storage: ReservationStorage,
  key: string,
  userId: string,
  create: () => { requestId: string; deviceKey: string; requestedMillis: number },
  hasNativeSession: boolean,
): Promise<UsageReservationRecord> {
  const raw = await storage.getItem(key);
  if (raw !== null) {
    const saved = parseUsageReservationRecord(raw, userId);
    if (!saved) {
      throw new Error('The saved reservation key is invalid. Contact support before creating another reservation.');
    }
    return saved;
  }
  if (hasNativeSession) {
    throw new Error('The device key for this reservation is unavailable on this device. Your reservation will expire automatically at the server deadline.');
  }
  const draft = create();
  const record: UsageReservationRecord = {
    userId,
    requestId: draft.requestId,
    deviceKey: draft.deviceKey,
    requestedMillis: draft.requestedMillis,
    sessionId: null,
    state: 'pending',
  };
  await storage.setItem(key, JSON.stringify(record));
  return record;
}

export async function reconcileUsageReservation(args: {
  storage: ReservationStorage;
  key: string;
  userId: string;
  nativeSession: NativeUsageSession | null | undefined;
  findServerSession: (userId: string, requestId: string) => Promise<ServerUsageSession | null>;
}): Promise<UsageReconcileOutcome> {
  const { storage, key, userId, nativeSession, findServerSession } = args;
  const raw = await storage.getItem(key);
  const record = parseUsageReservationRecord(raw, userId);

  if (!record) {
    if (nativeSession && nativeSession.userId === userId) {
      return {
        status: 'recovery_key_missing',
        record: null,
        serverSessionId: nativeSession.sessionId,
        message: 'The device key for this reservation is unavailable on this device. Wait for the reservation window to expire or sign in where it started.',
      };
    }
    return { status: 'none', record: null };
  }

  const server = await findServerSession(userId, record.requestId);
  if (nativeSession) {
    if (nativeSession.userId !== userId || !server || server.id !== nativeSession.sessionId) {
      return {
        status: 'recovery_key_missing',
        record,
        serverSessionId: server?.id ?? null,
        message: 'This screen-time session belongs to a different account or reservation.',
      };
    }
    if (record.sessionId !== nativeSession.sessionId || record.state !== 'active') {
      const updated: UsageReservationRecord = { ...record, sessionId: nativeSession.sessionId, state: 'active' };
      await storage.setItem(key, JSON.stringify(updated));
      return { status: 'active', record: updated, serverSessionId: server.id };
    }
    return { status: 'active', record, serverSessionId: server.id };
  }

  if (server && !server.settled_at) {
    return {
      status: 'pending_server_settlement',
      record: { ...record, sessionId: server.id },
      serverSessionId: server.id,
      message: 'This screen-time reservation ended locally and is ready to settle unused credits.',
    };
  }

  await storage.removeItem(key);
  return { status: 'settled_cleanup', record: null, serverSessionId: server?.id ?? null };
}

export async function settleUsageReservation(args: {
  storage: ReservationStorage;
  key: string;
  userId: string;
  getNativeSession: () => Promise<NativeUsageSession | null | undefined>;
  closeNativeSession: (userId: string) => Promise<NativeUsageSession | null | undefined>;
  clearNativeSession: (userId: string, sessionId: string) => Promise<void>;
  findServerSession: (userId: string, requestId: string) => Promise<ServerUsageSession | null>;
  finishServerSession: (sessionId: string, deviceKey: string) => Promise<void>;
}): Promise<{ settledSessionId: string }> {
  const { storage, key, userId, getNativeSession, closeNativeSession, clearNativeSession, findServerSession, finishServerSession } = args;
  const record = parseUsageReservationRecord(await storage.getItem(key), userId);
  if (!record) {
    throw new Error('This saved screen-time request is unavailable. Refresh your account and try again.');
  }

  const local = await getNativeSession();
  const server = await findServerSession(userId, record.requestId);
  if (!server) {
    throw new Error('This screen-time request belongs to a different account or session.');
  }

  let targetSessionId = server.id;
  if (local) {
    if (local.userId !== userId || local.sessionId !== server.id) {
      throw new Error('This screen-time request belongs to a different account or session.');
    }
    const closed = await closeNativeSession(userId);
    if (!closed || closed.sessionId !== server.id || closed.userId !== userId) {
      throw new Error('The screen-time session changed. Retry sync.');
    }
    targetSessionId = closed.sessionId;
  }

  if (!server.settled_at) {
    await finishServerSession(targetSessionId, record.deviceKey);
  }
  await clearNativeSession(userId, targetSessionId);
  await storage.removeItem(key);
  return { settledSessionId: targetSessionId };
}

export function resolveEnforcementConfirmation(input: EnforcementConfirmationInput): EnforcementConfirmation {
  if (input.platform === 'web' || input.platform === 'windows') {
    return {
      confirmed: false,
      status: 'unsupported',
      reason: input.platform === 'windows'
        ? 'Windows enforcement is not supported yet.'
        : 'Browser enforcement requires a native Bloom device.',
    };
  }
  if (!input.configured) {
    return { confirmed: false, status: 'inactive', reason: 'Select apps or websites to enforce first.' };
  }
  if (!input.authorized) {
    return { confirmed: false, status: 'degraded', reason: 'OS blocking permissions are missing or revoked.' };
  }
  if (!input.active) {
    return { confirmed: false, status: 'inactive', reason: 'Protection is currently turned off.' };
  }
  if (input.providerHealthy === false) {
    return { confirmed: false, status: 'degraded', reason: 'The system protection provider is not reporting healthy.' };
  }
  if (input.brokerAcknowledged === false) {
    return { confirmed: false, status: 'degraded', reason: 'The policy broker has not acknowledged the active rules.' };
  }
  if (input.hideFailed) {
    return { confirmed: false, status: 'degraded', reason: 'A blocked app or browser window could not be hidden automatically.' };
  }
  return { confirmed: true, status: 'confirmed', reason: null };
}
