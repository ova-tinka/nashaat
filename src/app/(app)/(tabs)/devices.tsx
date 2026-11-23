import { getAppLocale } from '../../../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useFocusEffect, type Href } from 'expo-router';
import { useCallback, useRef, useState } from 'react';
import { ActivityIndicator, I18nManager, Platform, Pressable, StyleSheet, View } from 'react-native';
import BloomBlocking from '../../../../modules/bloom-blocking/src/BloomBlockingModule';
import type { BlockingStatus } from '../../../../modules/bloom-blocking/src/BloomBlocking.types';
import { Body, Button, ErrorText, Eyebrow, Heading, Label, Panel, Screen, sharedStyles, useIsDesktopLayout } from '../../../components/bloom-ui';
import { isMacDesktop, macosFilter } from '../../../lib/macos-blocking';
import { useBloom } from '../../../lib/bloom-context';
import { useAuth } from '../../../lib/auth';
import { getInstallationId, loadDevices, registerCurrentDevice, resetInstallationId, type BloomDevice, type DevicePlatform, type DeviceStatus } from '../../../lib/devices';
import { defaultDeviceName, detectDevicePlatform, deviceRegistryErrorMessage, isDeviceStale, sumKnownTargetCounts, verifiedTargetCount } from '../../../lib/device-utils';
import { useBloomTheme } from '../../../lib/theme-context';

type DeviceSummary = { platform: string; checkedAt: string; checks: { label: string; value: string }[]; error?: string; unavailable?: string; help?: string };

function runtimePlatform(): DevicePlatform {
  return detectDevicePlatform(Platform.OS, isMacDesktop());
}

function DeviceRow({ device, current = false, onPress }: { device: BloomDevice; current?: boolean; onPress: () => void }) {
  const { theme } = useBloomTheme();
  const stale = isDeviceStale(device.last_seen_at);
  const icon = device.platform === 'ios' ? 'phone-iphone' : device.platform === 'android' ? 'phone-android' : device.platform === 'macos' ? 'laptop-mac' : 'devices';
  return <Pressable accessibilityRole="button" accessibilityLabel={`${device.display_name}, ${device.platform}, ${current ? 'this device' : 'open device details'}`} onPress={onPress} style={({ pressed }) => [styles.deviceRow, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, pressed && styles.pressed]}>
    <MaterialIcons name={icon} size={22} color={theme.colors.action} />
    <View style={sharedStyles.grow}>
      <Label>{device.display_name}</Label>
      <Body>{current ? 'This device' : device.platform} · last seen {new Date(device.last_seen_at).toLocaleString(getAppLocale())}</Body>
      <Body>{stale ? 'Status may be out of date; this device has not checked in recently.' : `${device.blockingState === 'on' ? 'Blocking on' : device.blockingState === 'off' ? 'Blocking off' : device.blockingState === 'needs_attention' ? 'Blocking needs attention' : 'Blocking status unavailable'} · ${device.permissionState === 'allowed' ? 'permission allowed' : device.permissionState === 'needs_setup' ? 'permission needs setup' : 'permission status unavailable'}`}</Body>
    </View>
    <MaterialIcons name="chevron-right" size={22} color={theme.colors.inkMuted} style={I18nManager.isRTL ? styles.directionalIcon : undefined} />
  </Pressable>;
}

export default function DevicesScreen() {
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const { profileId } = useAuth();
  const { blockingRulesSyncError, blockingRulesSyncedAt, blockingRulesSyncStatus } = useBloom();
  const [device, setDevice] = useState<DeviceSummary | null>(null);
  const [devices, setDevices] = useState<BloomDevice[]>([]);
  const [deviceId, setDeviceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [registryError, setRegistryError] = useState<string | null>(null);
  const [removedFromRegistry, setRemovedFromRegistry] = useState(false);
  const [registryProfileId, setRegistryProfileId] = useState<string | null>(null);
  const refreshRequest = useRef(0);
  const lastProfileId = useRef<string | null>(null);

  const refresh = useCallback(async () => {
    const request = ++refreshRequest.current;
    const isCurrentRequest = () => request === refreshRequest.current;
    setLoading(true);
    if (!profileId) {
      if (isCurrentRequest()) {
        lastProfileId.current = null;
        setRegistryProfileId(null);
        setDevices([]);
        setDeviceId(null);
        setRegistryError('Could not load the active Bloom profile. Try refreshing the profile and device list.');
        setLoading(false);
      }
      return;
    }
    if (lastProfileId.current !== profileId) {
      lastProfileId.current = profileId;
      setRegistryProfileId(profileId);
      setDevices([]);
      setDeviceId(null);
      setRemovedFromRegistry(false);
      setRegistryError(null);
    }
    const platform = runtimePlatform();
    let status: DeviceStatus = {
      platform,
      focusSupported: false,
      permissionState: 'unavailable',
      blockingState: 'unavailable',
      selectedTargetCount: null,
    };

    if (isMacDesktop()) {
      const [website, application] = await Promise.allSettled([macosFilter('status'), macosFilter('appStatus')]);
      if (!isCurrentRequest()) return;
      const checks: DeviceSummary['checks'] = [];
      if (website.status === 'fulfilled') checks.push({ label: 'Website filter', value: website.value.status === 'enabled' ? 'On' : website.value.status === 'disabled' ? 'Off' : 'Unknown' });
      else checks.push({ label: 'Website filter', value: 'Could not check' });
      if (application.status === 'fulfilled') checks.push({ label: 'App blocking', value: application.value.appEnabled === true ? 'On' : application.value.appEnabled === false ? 'Off' : 'Unknown' });
      else checks.push({ label: 'App blocking', value: 'Could not check' });
      const anyOn = (website.status === 'fulfilled' && website.value.status === 'enabled') || (application.status === 'fulfilled' && application.value.appEnabled === true);
      const knownOff = (website.status === 'fulfilled' && website.value.status === 'disabled') || (application.status === 'fulfilled' && application.value.appEnabled === false);
      status = {
        ...status,
        focusSupported: true,
        permissionState: 'unknown',
        blockingState: anyOn ? 'on' : knownOff ? 'off' : 'unknown',
        selectedTargetCount: sumKnownTargetCounts(
          website.status === 'fulfilled' ? website.value.domains?.length ?? null : null,
          application.status === 'fulfilled' ? application.value.apps?.length ?? null : null,
        ),
      };
      setDevice({
        platform: 'macOS',
        checkedAt: new Date().toISOString(),
        checks,
        error: website.status === 'rejected' && application.status === 'rejected' ? 'Could not read native Focus status on this Mac.' : undefined,
      });
    } else if (Platform.OS === 'ios' || Platform.OS === 'android') {
      try {
        const nativeStatus: BlockingStatus = await BloomBlocking.getStatus();
        if (!isCurrentRequest()) return;
        const checks = [
          { label: 'Focus support', value: nativeStatus.supported ? 'Supported on this device' : 'Unavailable in this app build' },
          { label: 'Permission', value: nativeStatus.supported ? nativeStatus.authorized ? 'Allowed' : 'Needs setup' : 'Not available' },
          { label: 'Blocking', value: nativeStatus.supported ? nativeStatus.active ? 'On' : 'Off' : 'Not available' },
          { label: 'Selected targets', value: (nativeStatus.appCount + nativeStatus.websiteCount + nativeStatus.categoryCount).toLocaleString(getAppLocale()) },
        ];
        if (Platform.OS === 'android' && nativeStatus.active && nativeStatus.serviceConnected === false) {
          checks[2] = { label: 'Blocking service', value: 'Needs attention' };
        }
        const help = !nativeStatus.supported
          ? 'Native Focus is not available in this app build.'
          : !nativeStatus.authorized
            ? 'Open Focus controls to see the permission steps for this device.'
            : Platform.OS === 'android' && nativeStatus.active && nativeStatus.serviceConnected === false
              ? 'The Android blocking service reported a connection issue. Open Focus controls for recovery steps.'
              : undefined;
        status = {
          ...status,
          focusSupported: nativeStatus.supported,
          permissionState: !nativeStatus.supported ? 'unavailable' : nativeStatus.authorized ? 'allowed' : 'needs_setup',
          blockingState: !nativeStatus.supported ? 'unavailable' : Platform.OS === 'android' && nativeStatus.active && nativeStatus.serviceConnected === false ? 'needs_attention' : nativeStatus.active ? 'on' : 'off',
          selectedTargetCount: verifiedTargetCount(nativeStatus.supported,
            nativeStatus.appCount + nativeStatus.websiteCount + nativeStatus.categoryCount),
        };
        setDevice({ platform: Platform.OS === 'ios' ? 'iPhone or iPad' : 'Android', checkedAt: new Date().toISOString(), checks, help });
      } catch {
        if (!isCurrentRequest()) return;
        status = { ...status, focusSupported: null, permissionState: 'unknown', blockingState: 'unknown', selectedTargetCount: null };
        setDevice({ platform: Platform.OS === 'ios' ? 'iPhone or iPad' : 'Android', checkedAt: new Date().toISOString(), checks: [], error: 'Could not read native Focus status. Rebuild the app or open Focus settings to retry.' });
      }
    } else {
      setDevice({
        platform: platform === 'windows' ? 'Windows PC' : 'Web preview',
        checkedAt: new Date().toISOString(),
        checks: [],
        unavailable: 'This runtime does not provide Bloom’s native Focus permission or enforcement controls.',
      });
    }

    try {
      const id = await getInstallationId(profileId);
      if (!isCurrentRequest()) return;
      setDeviceId(id);
      const registered = await registerCurrentDevice(id, defaultDeviceName(platform, id), status);
      if (!isCurrentRequest()) return;
      setRemovedFromRegistry(!registered);
      const entries = await loadDevices();
      if (!isCurrentRequest()) return;
      setDevices(entries);
      setRegistryError(null);
    } catch (error) {
      if (isCurrentRequest()) setRegistryError(deviceRegistryErrorMessage(error));
    } finally {
      if (isCurrentRequest()) setLoading(false);
    }
  }, [profileId]);

  useFocusEffect(useCallback(() => {
    void refresh();
    return () => { refreshRequest.current += 1; };
  }, [refresh]));

  async function addThisDeviceAgain() {
    if (!profileId) return;
    try {
      await resetInstallationId(profileId);
      await refresh();
    } catch {
      setRegistryError('Could not add this device to the profile list. Check your connection and try again.');
    }
  }

  const profileMatchesRegistry = Boolean(profileId && registryProfileId === profileId);
  const visibleDevices = profileMatchesRegistry ? devices : [];
  const visibleDeviceId = profileMatchesRegistry ? deviceId : null;
  const visibleRemovedFromRegistry = profileMatchesRegistry && removedFromRegistry;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Shared service · Current profile</Eyebrow>
      <Heading>Devices</Heading>
      <Body>Each profile has its own device list. Permissions and enforcement are reported by the device that checked them.</Body>
    </View>
    <View style={[styles.workspace, desktop && styles.desktopWorkspace]}>
      <View style={[styles.column, desktop && styles.desktopColumn]}>
        <Panel>
          <View style={sharedStyles.row}>
            <View style={[sharedStyles.row, sharedStyles.grow]}>
              <View style={[styles.deviceIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
                <MaterialIcons name={Platform.OS === 'ios' ? 'phone-iphone' : Platform.OS === 'android' ? 'phone-android' : 'laptop-mac'} size={21} color={theme.colors.action} />
              </View>
              <View style={sharedStyles.grow}>
                <Eyebrow>This device</Eyebrow>
                <Label>{device?.platform ?? 'Checking platform…'}</Label>
              </View>
            </View>
            {loading && <ActivityIndicator color={theme.colors.action} />}
          </View>
          {device?.error && <ErrorText>{device.error}</ErrorText>}
          {device?.unavailable && <Body>{device.unavailable}</Body>}
          {device?.help && <Body>{device.help}</Body>}
          {device?.checks.map((check) => <View key={check.label} style={sharedStyles.row}>
            <View style={sharedStyles.grow}><Body>{check.label}</Body></View><Label>{check.value}</Label>
          </View>)}
          {device?.checkedAt && <Body>Checked {new Date(device.checkedAt).toLocaleTimeString(getAppLocale())} on this device.</Body>}
          {visibleDeviceId && <Button label="Open this device’s details" variant="secondary" onPress={() => router.push({ pathname: '/device-detail', params: { deviceId: visibleDeviceId } } as unknown as Href)} />}
          <Button label="Refresh device status" variant="secondary" onPress={() => void refresh()} busy={loading} />
          <Button label="Open Focus controls" onPress={() => router.push('/focus')} />
        </Panel>
        {profileMatchesRegistry && registryError && <ErrorText>{registryError}</ErrorText>}
        {visibleRemovedFromRegistry && <Panel>
          <Eyebrow>Device removed from list</Eyebrow>
          <Body>Removing a device hides its inventory entry; it does not sign that device out. Sign out there to end its Bloom session, or add this installation back to the list.</Body>
          <Button label="Add this installation again" secondary onPress={() => void addThisDeviceAgain()} busy={loading} />
        </Panel>}
        {(isMacDesktop() || Platform.OS === 'ios' || Platform.OS === 'android') && <Panel>
          <Eyebrow>Rule sync</Eyebrow>
          {blockingRulesSyncError ? <>
            <ErrorText>{blockingRulesSyncError}</ErrorText>
            {blockingRulesSyncedAt && <Body>Last successful sync: {new Date(blockingRulesSyncedAt).toLocaleString(getAppLocale())}.</Body>}
            {!blockingRulesSyncedAt && <Body>No successful sync has been recorded on this device yet.</Body>}
          </> : blockingRulesSyncedAt
            ? <Body>{blockingRulesSyncStatus ?? 'Current'} · last confirmed {new Date(blockingRulesSyncedAt).toLocaleString(getAppLocale())}</Body>
            : <Body>Bloom has not confirmed a rule sync on this device yet.</Body>}
        </Panel>}
      </View>
      <View style={[styles.column, desktop && styles.desktopColumn]}>
        <Panel>
          <Eyebrow>Devices on this profile</Eyebrow>
          <Label>{profileMatchesRegistry && registryError && visibleDevices.length === 0
            ? 'Device list unavailable'
            : `${visibleDevices.length} ${visibleDevices.length === 1 ? 'device' : 'devices'}`}</Label>
          {profileMatchesRegistry && !loading && !registryError && visibleDevices.length === 0 && <Body>No device has checked in to this profile yet.</Body>}
          {visibleDevices.map((entry) => <DeviceRow key={entry.device_id} device={entry} current={entry.device_id === visibleDeviceId} onPress={() => router.push({ pathname: '/device-detail', params: { deviceId: entry.device_id } } as unknown as Href)} />)}
          {(loading || !profileMatchesRegistry) && visibleDevices.length === 0 && <ActivityIndicator color={theme.colors.action} />}
        </Panel>
        <Panel>
          <Eyebrow>What this status means</Eyebrow>
          <Body>“On” is the status last reported by that device. A stale report does not prove that blocking is still active. OS permissions and selected targets stay specific to each device.</Body>
        </Panel>
      </View>
    </View>
  </Screen>;
}

const styles = StyleSheet.create({
  workspace: { gap: 16 },
  desktopWorkspace: { flexDirection: 'row', alignItems: 'flex-start' },
  column: { flex: 1, gap: 16 },
  desktopColumn: { minWidth: 320 },
  deviceIcon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  deviceRow: { minHeight: 86, flexDirection: 'row', alignItems: 'center', gap: 12, borderWidth: 1, borderRadius: 14, padding: 12 },
  pressed: { opacity: 0.8 },
  directionalIcon: { transform: [{ scaleX: -1 }] },
});
