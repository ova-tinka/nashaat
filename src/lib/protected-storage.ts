import AsyncStorage from '@react-native-async-storage/async-storage';
import { invoke } from '@tauri-apps/api/core';
import * as SecureStore from 'expo-secure-store';
import { Platform } from 'react-native';
import { isMacDesktop } from './macos-blocking';
import { createChunkedProtectedStorage, type StorageDriver } from './protected-storage-core';

const secureStoreOptions: SecureStore.SecureStoreOptions = {
  keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY,
};

const mobileSecureDriver: StorageDriver = {
  getItem: (key) => SecureStore.getItemAsync(key, secureStoreOptions),
  setItem: (key, value) => SecureStore.setItemAsync(key, value, secureStoreOptions),
  removeItem: (key) => SecureStore.deleteItemAsync(key, secureStoreOptions),
};

const macosKeychainDriver: StorageDriver = {
  async getItem(key) {
    const value = await invoke<string | null>('macos_secure_storage_get', { key });
    return typeof value === 'string' ? value : null;
  },
  async setItem(key, value) {
    await invoke('macos_secure_storage_set', { key, value });
  },
  async removeItem(key) {
    await invoke('macos_secure_storage_delete', { key });
  },
};

const webLocalStorageLegacyDriver: StorageDriver = {
  async getItem(key) {
    return typeof window !== 'undefined' && window.localStorage ? window.localStorage.getItem(key) : null;
  },
  async setItem(key, value) {
    if (typeof window !== 'undefined' && window.localStorage) window.localStorage.setItem(key, value);
  },
  async removeItem(key) {
    if (typeof window !== 'undefined' && window.localStorage) window.localStorage.removeItem(key);
  },
};

export function isProtectedStorageSupported(): boolean {
  return Platform.OS === 'ios' || Platform.OS === 'android' || isMacDesktop();
}

export function createProtectedKeyValueStorage(): StorageDriver {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    return createChunkedProtectedStorage({
      primary: mobileSecureDriver,
      legacy: AsyncStorage,
      maxChunkBytes: 1800,
    });
  }
  if (isMacDesktop()) {
    return createChunkedProtectedStorage({
      primary: macosKeychainDriver,
      legacy: webLocalStorageLegacyDriver,
      maxChunkBytes: 16384,
    });
  }
  return webLocalStorageLegacyDriver;
}

export function createBloomAuthStorage(): StorageDriver | undefined {
  if (Platform.OS === 'ios' || Platform.OS === 'android' || isMacDesktop()) {
    return createProtectedKeyValueStorage();
  }
  return undefined;
}
