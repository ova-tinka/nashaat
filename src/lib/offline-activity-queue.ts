export type QueueStorage = {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
};

export type OfflineScope = {
  profileId: string;
  deviceId: string;
};

export type OfflineWorkoutResult = {
  exercise_id: string;
  sets_completed: number;
  reps_completed?: number;
  duration_seconds?: number;
  weight_kg?: number;
  distance_km?: number;
};

export type OfflineActivityPayload =
  | {
      kind: 'exercise_session';
      planId: string | null;
      title: string;
      startedAt: string;
      completedAt: string;
      durationSeconds: number;
      results: OfflineWorkoutResult[];
    }
  | {
      kind: 'study_session' | 'read_session';
      moduleId: 'study' | 'read';
      itemId: string;
      itemTitle: string;
      sourceDeviceId: string;
      sourceDeviceName: string;
      startedAt: string;
      completedAt: string;
      durationSeconds: number;
    }
  | {
      kind: 'task_completion';
      itemId: string;
      itemTitle: string;
      completedAt: string;
    };

export type QueuedOfflineActivity = {
  activityId: string;
  profileId: string;
  deviceId: string;
  status: 'pending';
  createdAt: string;
  attempts: number;
  lastError: string | null;
  payload: OfflineActivityPayload;
};

export type OfflineSyncExecutor = (entry: QueuedOfflineActivity) => Promise<'accepted' | 'archived'>;

export function offlineQueueStorageKey(scope: OfflineScope): string {
  return `bloom.offline-activity-queue.v1:${scope.profileId}:${scope.deviceId}`;
}

export function offlineCatalogCacheKey(profileId: string, namespace: string): string {
  return `bloom.offline-catalog-cache.v1:${profileId}:${namespace}`;
}

export async function loadOfflineQueue(storage: QueueStorage, scope: OfflineScope): Promise<QueuedOfflineActivity[]> {
  const raw = await storage.getItem(offlineQueueStorageKey(scope));
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter((entry): entry is QueuedOfflineActivity => Boolean(
      entry
      && typeof entry === 'object'
      && typeof (entry as QueuedOfflineActivity).activityId === 'string'
      && (entry as QueuedOfflineActivity).profileId === scope.profileId
      && (entry as QueuedOfflineActivity).deviceId === scope.deviceId
      && (entry as QueuedOfflineActivity).status === 'pending',
    ));
  } catch {
    return [];
  }
}

async function saveOfflineQueue(storage: QueueStorage, scope: OfflineScope, entries: QueuedOfflineActivity[]) {
  await storage.setItem(offlineQueueStorageKey(scope), JSON.stringify(entries));
}

export async function enqueueOfflineActivity(
  storage: QueueStorage,
  scope: OfflineScope,
  activityId: string,
  payload: OfflineActivityPayload,
  nowIso = new Date().toISOString(),
): Promise<QueuedOfflineActivity> {
  const current = await loadOfflineQueue(storage, scope);
  const existing = current.find((entry) => entry.activityId === activityId);
  if (existing) return existing;

  const next: QueuedOfflineActivity = {
    activityId,
    profileId: scope.profileId,
    deviceId: scope.deviceId,
    status: 'pending',
    createdAt: nowIso,
    attempts: 0,
    lastError: null,
    payload,
  };
  await saveOfflineQueue(storage, scope, [...current, next]);
  return next;
}

export async function syncOfflineQueue(
  storage: QueueStorage,
  scope: OfflineScope,
  executor: OfflineSyncExecutor,
): Promise<{ accepted: number; archived: number; remaining: QueuedOfflineActivity[] }> {
  const queue = await loadOfflineQueue(storage, scope);
  if (queue.length === 0) {
    return { accepted: 0, archived: 0, remaining: [] };
  }
  let accepted = 0;
  let archived = 0;
  const remaining: QueuedOfflineActivity[] = [];

  for (let i = 0; i < queue.length; i += 1) {
    const entry = queue[i];
    try {
      const outcome = await executor(entry);
      if (outcome === 'archived') archived += 1;
      else accepted += 1;
    } catch (cause) {
      const failed: QueuedOfflineActivity = {
        ...entry,
        attempts: entry.attempts + 1,
        lastError: cause instanceof Error ? cause.message : 'Sync interrupted',
      };
      remaining.push(failed);
      if (failed.attempts < 3) {
        remaining.push(...queue.slice(i + 1));
        break;
      }
    }
  }

  await saveOfflineQueue(storage, scope, remaining);
  return { accepted, archived, remaining };
}

export async function cacheOfflineSnapshot<T>(
  storage: QueueStorage,
  profileId: string,
  namespace: string,
  snapshot: T,
): Promise<void> {
  await storage.setItem(offlineCatalogCacheKey(profileId, namespace), JSON.stringify(snapshot));
}

export async function loadOfflineSnapshot<T>(
  storage: QueueStorage,
  profileId: string,
  namespace: string,
): Promise<T | null> {
  const raw = await storage.getItem(offlineCatalogCacheKey(profileId, namespace));
  if (!raw) return null;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return null;
  }
}

export function canSpendScreenTimeFromPendingQueue(_pendingCount: number): false {
  // Pending offline activities never grant or unlock Screen Time; a server grant is required.
  return false;
}
