import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import { Platform } from 'react-native';
import { supabase } from './supabase';
import { defaultDeviceName, detectDevicePlatform, deviceInstallationStorageKey, loadOrCreateDeviceInstallationId } from './device-utils';
import { isMacDesktop } from './macos-blocking';

export type DevicePlatform = 'ios' | 'android' | 'macos' | 'windows' | 'web';
export type DevicePermission = 'allowed' | 'needs_setup' | 'unavailable' | 'unknown';
export type DeviceBlocking = 'on' | 'off' | 'needs_attention' | 'unavailable' | 'unknown';

export type DeviceStatus = {
  platform: DevicePlatform;
  focusSupported: boolean | null;
  permissionState: DevicePermission;
  blockingState: DeviceBlocking;
  selectedTargetCount: number | null;
};

export type BloomDevice = DeviceStatus & {
  device_id: string;
  display_name: string;
  first_seen_at: string;
  last_seen_at: string;
  status_checked_at: string;
};

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function getInstallationId(profileId: string) {
  return loadOrCreateDeviceInstallationId(profileId, AsyncStorage, randomUUID);
}

export async function getCurrentDeviceIdentity(profileId: string) {
  const deviceId = await getInstallationId(profileId);
  const platform = detectDevicePlatform(Platform.OS, isMacDesktop());
  return { deviceId, displayName: defaultDeviceName(platform, deviceId), platform };
}

export async function resetInstallationId(profileId: string) {
  const generated = randomUUID();
  await AsyncStorage.setItem(deviceInstallationStorageKey(profileId), generated);
  return generated;
}

export async function registerCurrentDevice(deviceId: string, displayName: string, status: DeviceStatus) {
  const { data, error } = await client().rpc('bloom_register_device', {
    p_device_id: deviceId,
    p_display_name: displayName,
    p_platform: status.platform,
    p_focus_supported: status.focusSupported,
    p_permission_state: status.permissionState,
    p_blocking_state: status.blockingState,
    p_selected_target_count: status.selectedTargetCount,
  });
  if (error) throw error;
  return data === true;
}

export async function loadDevices(): Promise<BloomDevice[]> {
  const { data, error } = await client().rpc('bloom_list_devices');
  if (error) throw error;
  if (!Array.isArray(data)) throw new Error('Could not read the device list.');
  return data.map((value: unknown) => {
    if (typeof value !== 'object' || value === null) throw new Error('Invalid device record.');
    const row = value as Record<string, unknown>;
    const platforms: DevicePlatform[] = ['ios', 'android', 'macos', 'windows', 'web'];
    const permissions: DevicePermission[] = ['allowed', 'needs_setup', 'unavailable', 'unknown'];
    const blocking: DeviceBlocking[] = ['on', 'off', 'needs_attention', 'unavailable', 'unknown'];
    if (typeof row.device_id !== 'string' || typeof row.display_name !== 'string'
      || typeof row.platform !== 'string' || !platforms.includes(row.platform as DevicePlatform)
      || typeof row.permission_state !== 'string' || !permissions.includes(row.permission_state as DevicePermission)
      || typeof row.blocking_state !== 'string' || !blocking.includes(row.blocking_state as DeviceBlocking)
      || typeof row.first_seen_at !== 'string' || typeof row.last_seen_at !== 'string'
      || typeof row.status_checked_at !== 'string') throw new Error('Invalid device record.');
    if (row.focus_supported !== null && typeof row.focus_supported !== 'boolean') throw new Error('Invalid device status.');
    if (row.selected_target_count !== null && typeof row.selected_target_count !== 'number') throw new Error('Invalid device status.');
    return {
      device_id: row.device_id,
      display_name: row.display_name,
      platform: row.platform as DevicePlatform,
      focusSupported: row.focus_supported,
      permissionState: row.permission_state as DevicePermission,
      blockingState: row.blocking_state as DeviceBlocking,
      selectedTargetCount: row.selected_target_count,
      first_seen_at: row.first_seen_at,
      last_seen_at: row.last_seen_at,
      status_checked_at: row.status_checked_at,
    };
  });
}

export async function loadDevice(deviceId: string): Promise<BloomDevice | null> {
  return (await loadDevices()).find((device) => device.device_id === deviceId) ?? null;
}

export async function renameDevice(deviceId: string, displayName: string) {
  const name = displayName.trim();
  if (name.length < 1 || name.length > 80) throw new Error('Enter a device name between 1 and 80 characters.');
  const { error } = await client().rpc('bloom_rename_device', { p_device_id: deviceId, p_display_name: name });
  if (error) throw error;
}

export async function removeDevice(deviceId: string) {
  const { error } = await client().rpc('bloom_remove_device', { p_device_id: deviceId });
  if (error) throw error;
}
