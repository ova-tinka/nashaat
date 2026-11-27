import AsyncStorage from '@react-native-async-storage/async-storage';
import { AppState, Platform } from 'react-native';
import { closeDeviceAccess } from './close-device-access';
import { createProtectedKeyValueStorage, isProtectedStorageSupported } from './protected-storage';
import { supabase } from './supabase';

type SavedChild = { childId: string; parentId?: string; refreshToken: string };
const legacyPinDeviceKey = 'bloom.parent.pin.device.v1';
const childKey = 'bloom.child.refresh.v1';
const idPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

const protectedStorage = createProtectedKeyValueStorage();

async function currentProfileId(): Promise<string> {
  const { data, error } = await client().rpc('bloom_current_profile');
  if (error || typeof data?.profile_id !== 'string') throw new Error('Could not load the active profile.');
  return data.profile_id;
}

function parse(raw: string | null): Record<string, unknown> | null {
  try {
    const value: unknown = raw ? JSON.parse(raw) : null;
    return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}

export async function clearLegacyParentPinState() {
  await protectedStorage.removeItem(legacyPinDeviceKey).catch(() => undefined);
  await AsyncStorage.removeItem(legacyPinDeviceKey).catch(() => undefined);
}

export async function getSavedChild(): Promise<SavedChild | null> {
  if (!isProtectedStorageSupported()) return null;
  const value = parse(await protectedStorage.getItem(childKey));
  if (typeof value?.childId !== 'string' || !idPattern.test(value.childId)
    || typeof value?.refreshToken !== 'string' || !value.refreshToken) {
    return null;
  }
  const parentId = typeof value.parentId === 'string' && idPattern.test(value.parentId) ? value.parentId : undefined;
  return { childId: value.childId, parentId, refreshToken: value.refreshToken };
}

export async function beginSwitchToParent(): Promise<{ savedChildForQuickReturn: boolean }> {
  const db = client();
  await clearLegacyParentPinState();
  db.auth.stopAutoRefresh();
  try {
    const current = await db.auth.getSession();
    const child = current.data.session;
    if (current.error || !child) throw new Error('Sign in to switch profiles.');
    const canKeepChild = isProtectedStorageSupported();
    if (canKeepChild) {
      await protectedStorage.setItem(
        childKey,
        JSON.stringify({ childId: child.user.id, refreshToken: child.refresh_token }),
      );
    }
    await closeDeviceAccess(await currentProfileId());
    const signedOut = await db.auth.signOut({ scope: 'local' });
    if (signedOut.error) throw signedOut.error;
    return { savedChildForQuickReturn: canKeepChild };
  } finally {
    if (Platform.OS === 'web' || AppState.currentState === 'active') db.auth.startAutoRefresh();
  }
}

export async function restoreChildSession() {
  if (!isProtectedStorageSupported()) {
    throw new Error('Quick return to a child profile is only available on mobile and macOS devices.');
  }
  const db = client();
  const saved = await getSavedChild();
  if (!saved) throw new Error('No child profile is saved on this device.');
  const current = await db.auth.getSession();
  if (current.error) throw current.error;
  if (current.data.session) {
    if (saved.parentId && current.data.session.user.id !== saved.parentId) {
      throw new Error('Sign out of the current account first.');
    }
    await closeDeviceAccess(await currentProfileId());
    const signedOut = await db.auth.signOut({ scope: 'local' });
    if (signedOut.error) throw signedOut.error;
  }
  const restored = await db.auth.refreshSession({ refresh_token: saved.refreshToken });
  if (restored.error || restored.data.user?.id !== saved.childId) {
    if (restored.data.session) await db.auth.signOut({ scope: 'local' });
    throw new Error('Could not restore the child profile. Ask a parent for a new pairing code.');
  }
  await protectedStorage.removeItem(childKey);
}

export async function clearSavedChildSession() {
  await protectedStorage.removeItem(childKey);
  await AsyncStorage.removeItem(childKey).catch(() => undefined);
}
