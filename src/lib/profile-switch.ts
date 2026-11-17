import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import { AppState, Platform } from 'react-native';
import { closeDeviceAccess } from './close-device-access';
import { supabase } from './supabase';

type DevicePin = { deviceId: string; secret: string; parentId: string };
type SavedChild = { childId: string; parentId: string; refreshToken: string };
const deviceKey = 'bloom.parent.pin.device.v1';
const childKey = 'bloom.child.refresh.v1';
const secureOptions = { keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY };
const idPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function client() { if (!supabase) throw new Error('Bloom is not configured.'); return supabase; }
async function getItem(key: string) {
  return Platform.OS === 'web' ? AsyncStorage.getItem(key) : SecureStore.getItemAsync(key, secureOptions);
}
async function setItem(key: string, value: string) {
  return Platform.OS === 'web' ? AsyncStorage.setItem(key, value) : SecureStore.setItemAsync(key, value, secureOptions);
}
async function deleteItem(key: string) {
  return Platform.OS === 'web' ? AsyncStorage.removeItem(key) : SecureStore.deleteItemAsync(key, secureOptions);
}
async function currentProfileId(): Promise<string> {
  const { data, error } = await client().rpc('bloom_current_profile');
  if (error || typeof data?.profile_id !== 'string') throw new Error('Could not load the active profile.');
  return data.profile_id;
}
function parse(raw: string | null): Record<string, unknown> | null {
  try { const value: unknown = raw ? JSON.parse(raw) : null; return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : null; }
  catch { return null; }
}

export async function getDevicePin(): Promise<DevicePin | null> {
  const value = parse(await getItem(deviceKey));
  if (typeof value?.deviceId !== 'string' || !idPattern.test(value.deviceId) || typeof value.secret !== 'string'
    || !/^[0-9a-f]{64}$/.test(value.secret) || typeof value.parentId !== 'string' || !idPattern.test(value.parentId)) return null;
  return { deviceId: value.deviceId, secret: value.secret, parentId: value.parentId };
}
export async function getSavedChild(): Promise<SavedChild | null> {
  const value = parse(await getItem(childKey));
  if (typeof value?.childId !== 'string' || !idPattern.test(value.childId) || typeof value.parentId !== 'string'
    || !idPattern.test(value.parentId) || typeof value.refreshToken !== 'string' || !value.refreshToken) return null;
  return { childId: value.childId, parentId: value.parentId, refreshToken: value.refreshToken };
}
export async function registerDevicePin(parentId: string, pin: string) {
  if (!/^[0-9]{6}$/.test(pin)) throw new Error('Enter a six-digit PIN.');
  let device = await getDevicePin();
  if (device && device.parentId !== parentId) throw new Error('The PIN on this device belongs to another parent. Sign in to that account to remove it first.');
  if (!device) {
    device = { deviceId: randomUUID(), secret: (randomUUID() + randomUUID()).replaceAll('-', ''), parentId };
    await setItem(deviceKey, JSON.stringify(device));
  }
  const { error } = await client().rpc('bloom_register_parent_pin', { p_device_id: device.deviceId, p_device_secret: device.secret, p_pin: pin });
  if (error) throw error;
}
export async function removeDevicePin(parentId: string) {
  const device = await getDevicePin();
  if (!device || device.parentId !== parentId) throw new Error('This device has no PIN for your account.');
  const { error } = await client().rpc('bloom_remove_parent_pin', { p_device_id: device.deviceId });
  if (error) throw error;
  await deleteItem(deviceKey);
}

export async function unlockParent(pin: string) {
  const db = client();
  const device = await getDevicePin();
  if (!device || !/^[0-9]{6}$/.test(pin)) throw new Error('Enter the six-digit parent PIN.');
  db.auth.stopAutoRefresh();
  try {
    const current = await db.auth.getSession();
    const child = current.data.session;
    if (current.error || !child || child.user.id === device.parentId) throw new Error('A child account must be active.');
    // Only the child's refresh token is retained for switching back.
    await setItem(childKey, JSON.stringify({ childId: child.user.id, parentId: device.parentId, refreshToken: child.refresh_token }));
    const response = await db.functions.invoke('bloom-unlock-parent', { body: { device_id: device.deviceId, device_secret: device.secret, pin } });
    if (response.error || typeof response.data?.access_token !== 'string' || typeof response.data?.refresh_token !== 'string') {
      throw new Error('PIN unavailable or incorrect. After five attempts, wait 15 minutes.');
    }
    const verified = await db.auth.getUser(response.data.access_token);
    if (verified.error || verified.data.user?.id !== device.parentId) throw new Error('Parent account could not be verified.');
    await closeDeviceAccess(await currentProfileId());
    const switched = await db.auth.setSession({ access_token: response.data.access_token, refresh_token: response.data.refresh_token });
    if (switched.error || switched.data.user?.id !== device.parentId) throw new Error('Could not switch to the parent account.');
  } finally {
    if (Platform.OS === 'web' || AppState.currentState === 'active') db.auth.startAutoRefresh();
  }
}

export async function restoreChildSession() {
  const db = client();
  const saved = await getSavedChild();
  if (!saved) throw new Error('No child profile is saved on this device.');
  const current = await db.auth.getSession();
  if (current.error) throw current.error;
  if (current.data.session) {
    if (current.data.session.user.id !== saved.parentId) throw new Error('Sign out of the current account first.');
    await closeDeviceAccess(await currentProfileId());
    const signedOut = await db.auth.signOut({ scope: 'local' });
    if (signedOut.error) throw signedOut.error;
  }
  const restored = await db.auth.refreshSession({ refresh_token: saved.refreshToken });
  if (restored.error || restored.data.user?.id !== saved.childId) {
    if (restored.data.session) await db.auth.signOut({ scope: 'local' });
    throw new Error('Could not restore the child profile. Ask a parent for a new pairing code.');
  }
  await deleteItem(childKey);
}
