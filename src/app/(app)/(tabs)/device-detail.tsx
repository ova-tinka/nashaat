import { getAppLocale } from '../../../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useFocusEffect, useLocalSearchParams } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles, useIsDesktopColumns } from '../../../components/bloom-ui';
import { useBloomTheme } from '../../../lib/theme-context';
import { useAuth } from '../../../lib/auth';
import { getInstallationId, loadDevice, removeDevice, renameDevice, type BloomDevice } from '../../../lib/devices';
import { isDeviceStale } from '../../../lib/device-utils';

export default function DeviceDetailScreen() {
  const { deviceId } = useLocalSearchParams<{ deviceId?: string }>();
  const { theme } = useBloomTheme();
  const desktopColumns = useIsDesktopColumns();
  const { profileId } = useAuth();
  const [device, setDevice] = useState<BloomDevice | null>(null);
  const [currentDeviceId, setCurrentDeviceId] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [reviewName, setReviewName] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const loadRequest = useRef(0);
  const loadedTarget = useRef<string | null>(null);

  const load = useCallback(async () => {
    const request = ++loadRequest.current;
    const target = `${profileId ?? 'unavailable'}:${typeof deviceId === 'string' ? deviceId : 'missing'}`;
    if (loadedTarget.current !== target) {
      loadedTarget.current = target;
      setDevice(null);
      setCurrentDeviceId(null);
      setName('');
      setError(null);
    }
    if (typeof deviceId !== 'string' || !profileId) {
      setDevice(null);
      setError(typeof deviceId !== 'string' ? 'This device link is missing its device identifier.' : 'The active Bloom profile is not ready.');
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      const [found, currentId] = await Promise.all([loadDevice(deviceId), getInstallationId(profileId)]);
      if (request !== loadRequest.current) return;
      setDevice(found);
      setCurrentDeviceId(currentId);
      setName(found?.display_name ?? '');
      setError(found ? null : 'This device is no longer in this profile’s device list.');
      setReviewName(false);
      setConfirmRemove(false);
    } catch {
      if (request === loadRequest.current) setError('Could not load this device. Check your connection and try again.');
    } finally {
      if (request === loadRequest.current) setLoading(false);
    }
  }, [deviceId, profileId]);

  useFocusEffect(useCallback(() => {
    void load();
    return () => { loadRequest.current += 1; };
  }, [load]));

  async function saveName() {
    if (!device) return;
    setBusy(true); setError(null);
    try {
      await renameDevice(device.device_id, name);
      setReviewName(false);
      await load();
    } catch {
      setError('Could not save this device name. Keep it between 1 and 80 characters and retry.');
    } finally {
      setBusy(false);
    }
  }

  async function deleteFromList() {
    if (!device) return;
    setBusy(true); setError(null);
    try {
      await removeDevice(device.device_id);
      router.replace('/devices');
    } catch {
      setError('Could not remove this device from the profile list. Refresh and try again.');
      setBusy(false);
    }
  }

  const stale = device ? isDeviceStale(device.last_seen_at) : false;
  const current = Boolean(device && currentDeviceId === device.device_id);

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Devices · This profile</Eyebrow>
      <Heading>{device?.display_name ?? 'Device details'}</Heading>
      <Body>Permissions and selected targets belong to this installation and are reported by Bloom on that device.</Body>
    </View>
    {loading && <ActivityIndicator color={theme.colors.action} />}
    {error && <ErrorText>{error}</ErrorText>}
    {device && <View style={[styles.workspace, desktopColumns && styles.desktopWorkspace]}>
      <View style={[styles.column, desktopColumns && styles.desktopColumn]}>
        <Panel>
          <View style={sharedStyles.row}>
            <MaterialIcons name={device.platform === 'ios' ? 'phone-iphone' : device.platform === 'android' ? 'phone-android' : device.platform === 'macos' ? 'laptop-mac' : 'devices'} size={25} color={theme.colors.action} />
            <View style={sharedStyles.grow}><Label>{device.platform}</Label><Body>{current ? 'This device' : 'Registered to this profile'}</Body></View>
          </View>
          <View style={sharedStyles.row}><Body>First seen</Body><Label>{new Date(device.first_seen_at).toLocaleString(getAppLocale())}</Label></View>
          <View style={sharedStyles.row}><Body>Last seen</Body><Label>{new Date(device.last_seen_at).toLocaleString(getAppLocale())}</Label></View>
          <View style={sharedStyles.row}><Body>Focus support</Body><Label>{device.focusSupported === true ? 'Supported' : device.focusSupported === false ? 'Unavailable' : 'Unknown'}</Label></View>
          <View style={sharedStyles.row}><Body>Permission</Body><Label>{device.permissionState === 'allowed' ? 'Allowed' : device.permissionState === 'needs_setup' ? 'Needs setup' : device.permissionState === 'unavailable' ? 'Unavailable' : 'Unknown'}</Label></View>
          <View style={sharedStyles.row}><Body>Blocking</Body><Label>{device.blockingState === 'on' ? 'On' : device.blockingState === 'off' ? 'Off' : device.blockingState === 'needs_attention' ? 'Needs attention' : device.blockingState === 'unavailable' ? 'Unavailable' : 'Unknown'}</Label></View>
          <View style={sharedStyles.row}><Body>Selected targets</Body><Label>{device.selectedTargetCount === null ? 'Unknown' : device.selectedTargetCount.toLocaleString(getAppLocale())}</Label></View>
          <Body>Status last checked {new Date(device.status_checked_at).toLocaleString(getAppLocale())}.</Body>
          {stale && <Body>This device has not checked in for over 24 hours. Its reported permission and blocking state may be out of date.</Body>}
        </Panel>
        <Panel>
          <Eyebrow>Troubleshooting</Eyebrow>
          <Body>{device.platform === 'ios'
            ? 'On this iPhone or iPad, open Bloom to review Screen Time access and the apps selected for Focus.'
            : device.platform === 'android'
              ? 'On this Android device, open Bloom to review Accessibility access and the blocking service connection.'
              : device.platform === 'macos'
                ? 'On this Mac, open Bloom to review the website filter, browser extension and app blocking permissions.'
                : 'Open Bloom on this device to review its local permissions and available Focus controls.'}</Body>
          {current && <Button label="Open Focus controls on this device" onPress={() => router.push('/focus')} />}
          {!current && <Body>For privacy, Bloom cannot change another device’s operating-system permissions from here.</Body>}
        </Panel>
      </View>
      <View style={[styles.column, desktopColumns && styles.desktopColumn]}>
        <Panel>
          <Label>Device name</Label>
          <Field label="Name shown in this profile" value={name} onChangeText={(value) => { setName(value); setReviewName(false); }} maxLength={80} editable={!busy} />
          {!reviewName
            ? <Button label="Review device name" secondary onPress={() => setReviewName(true)} disabled={busy || !name.trim() || name.trim() === device.display_name} />
            : <View style={sharedStyles.column}>
              <Body>Rename {device.display_name} to {name.trim()} in this profile’s device list?</Body>
              <Button label="Confirm device name" onPress={() => void saveName()} busy={busy} />
              <Button label="Keep current name" secondary onPress={() => setReviewName(false)} disabled={busy} />
            </View>}
        </Panel>
        <Panel>
          <Eyebrow>Remove from list</Eyebrow>
          <Body>Removing a device deletes its inventory entry for this profile. It does not sign that device out or disable its Bloom session.</Body>
          {!confirmRemove
            ? <Button label="Review removing this device" variant="destructive" onPress={() => setConfirmRemove(true)} disabled={busy} />
            : <View style={sharedStyles.column}>
              <Body>Remove {device.display_name} from this profile’s device list? That device will need a new installation ID to appear here again.</Body>
              <Button label="Confirm remove from list" variant="destructive" onPress={() => void deleteFromList()} busy={busy} />
              <Button label="Keep device" secondary onPress={() => setConfirmRemove(false)} disabled={busy} />
            </View>}
        </Panel>
      </View>
    </View>}
    <Button label="Back to devices" variant="secondary" onPress={() => router.replace('/devices')} disabled={busy} />
  </Screen>;
}

const styles = StyleSheet.create({
  workspace: { gap: 16 },
  desktopWorkspace: { flexDirection: 'row', alignItems: 'flex-start' },
  column: { flex: 1, gap: 16 },
  desktopColumn: { minWidth: 320 },
});
