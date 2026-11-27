import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import { syncOfflineWorkout } from './bloom';
import { getCurrentDeviceIdentity } from './devices';
import { syncOfflineGrowthSession, syncOfflineTaskCompletion } from './growth-modules';
import {
  cacheOfflineSnapshot,
  enqueueOfflineActivity,
  loadOfflineQueue,
  loadOfflineSnapshot,
  syncOfflineQueue,
  type OfflineActivityPayload,
  type OfflineScope,
  type QueuedOfflineActivity,
} from './offline-activity-queue';

async function resolveScope(profileId: string): Promise<OfflineScope> {
  const identity = await getCurrentDeviceIdentity(profileId);
  return { profileId, deviceId: identity.deviceId };
}

export async function queueOfflineActivityForProfile(
  profileId: string,
  payload: OfflineActivityPayload,
  activityId = randomUUID(),
): Promise<QueuedOfflineActivity> {
  const scope = await resolveScope(profileId);
  return enqueueOfflineActivity(AsyncStorage, scope, activityId, payload);
}

export async function getPendingOfflineCount(profileId: string): Promise<number> {
  const scope = await resolveScope(profileId);
  const queue = await loadOfflineQueue(AsyncStorage, scope);
  return queue.length;
}

export async function flushOfflineActivitiesForProfile(profileId: string) {
  const scope = await resolveScope(profileId);
  return syncOfflineQueue(AsyncStorage, scope, async (entry) => {
    switch (entry.payload.kind) {
      case 'exercise_session': {
        await syncOfflineWorkout({
          activityId: entry.activityId,
          planId: entry.payload.planId,
          startedAt: entry.payload.startedAt,
          completedAt: entry.payload.completedAt,
          durationSeconds: entry.payload.durationSeconds,
          results: entry.payload.results,
        });
        return 'accepted';
      }
      case 'study_session':
      case 'read_session': {
        await syncOfflineGrowthSession({
          activityId: entry.activityId,
          moduleId: entry.payload.moduleId,
          itemId: entry.payload.itemId,
          sourceDeviceId: entry.payload.sourceDeviceId,
          sourceDeviceName: entry.payload.sourceDeviceName,
          startedAt: entry.payload.startedAt,
          completedAt: entry.payload.completedAt,
          durationSeconds: entry.payload.durationSeconds,
        });
        return 'accepted';
      }
      case 'task_completion': {
        const res = await syncOfflineTaskCompletion(entry.activityId, entry.payload.itemId);
        return res.status === 'archived' ? 'archived' : 'accepted';
      }
    }
  });
}

export async function saveOfflineModuleSnapshot<T>(profileId: string, namespace: string, snapshot: T) {
  await cacheOfflineSnapshot(AsyncStorage, profileId, namespace, snapshot);
}

export async function readOfflineModuleSnapshot<T>(profileId: string, namespace: string): Promise<T | null> {
  return loadOfflineSnapshot<T>(AsyncStorage, profileId, namespace);
}
