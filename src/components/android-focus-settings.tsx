import { useState } from 'react';
import type { ReactNode } from 'react';
import { Pressable, StyleSheet, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import type { AppCandidate, BlockingStatus } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { useBloomTheme } from '../lib/theme-context';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, LocalizedText as Text, Panel, Screen, sharedStyles } from './bloom-ui';
import { FocusAppPicker } from './focus-app-picker';

type Props = {
  status: BlockingStatus;
  loading: boolean;
  busy: boolean;
  error: string | null;
  syncError: string | null;
  apps: AppCandidate[];
  selected: string[];
  managedApps: string[];
  managedWebsites: string[];
  websiteConsent: boolean;
  websites: string[];
  websiteInput: string;
  initialSection: string;
  showEarnedAccess: boolean;
  earnedAccessContent: ReactNode;
  onBack: () => void;
  onChangeSelected: (selected: string[]) => void;
  onSaveSelection: () => Promise<boolean>;
  onCancelSelection: () => void;
  onEnableAccessibility: () => void;
  onToggleBlocking: () => void;
  onToggleWebsiteChecks: (enabled: boolean) => void;
  onChangeWebsiteInput: (value: string) => void;
  onAddWebsite: () => void;
  onRemoveWebsite: (website: string) => void;
  onToggleEarnedAccess: () => void;
};

export function AndroidFocusSettings(props: Props) {
  const { theme } = useBloomTheme();
  const [editingApps, setEditingApps] = useState(props.initialSection === 'apps');
  const [showWebsites, setShowWebsites] = useState(props.initialSection === 'websites');

  const managedTargets = props.managedApps.length + (props.websiteConsent ? props.managedWebsites.length : 0);
  const appCount = new Set([...props.selected, ...props.managedApps]).size;
  const websiteCount = props.websiteConsent ? new Set([...props.websites, ...props.managedWebsites]).size : 0;
  const targetCount = appCount + websiteCount;
  const hasTargets = targetCount > 0;
  const serviceReady = props.status.authorized && props.status.serviceConnected === true;
  const managedBlocking = managedTargets > 0;
  const protectionNeedsAttention = props.status.active && !serviceReady;
  const protectionIsOn = props.status.active && serviceReady;
  const selectedNames = props.selected
    .map((id) => props.apps.find((app) => app.id === id)?.name)
    .filter((name): name is string => Boolean(name));

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus</Eyebrow>
      <Heading>Block distractions</Heading>
      <Body>Choose the apps you want Bloom to block, then turn protection on.</Body>
      <Button label="Back to settings" variant="tertiary" onPress={props.onBack} />
    </View>

    <Panel>
      <View style={styles.statusHeading}>
        <View style={[styles.statusIcon, { backgroundColor: protectionIsOn ? theme.colors.successText : theme.colors.surfaceTinted }]}>
          <MaterialIcons name={protectionIsOn ? 'shield' : 'shield-moon'} size={22} color={protectionIsOn ? '#FFFFFF' : theme.colors.action} />
        </View>
        <View style={sharedStyles.grow}>
          <Eyebrow>{props.loading ? 'Checking this device' : protectionIsOn ? 'Protection is on' : protectionNeedsAttention ? 'Protection needs attention' : 'Protection is off'}</Eyebrow>
          <Label>{props.loading ? 'Checking status…' : `${targetCount} ${targetCount === 1 ? 'item' : 'items'} selected`}</Label>
        </View>
      </View>

      {!props.loading && !props.status.supported && <Body>App blocking is not available in this version of Bloom.</Body>}

      {!props.loading && props.status.supported && !props.status.authorized && <>
        <Body>Allow Bloom in Android Accessibility settings so it can recognize a selected app and show a block notice. You’ll return here after enabling Bloom.</Body>
        <Button label="Open Android settings" onPress={props.onEnableAccessibility} busy={props.busy} />
      </>}

      {!props.loading && props.status.authorized && props.status.serviceConnected !== true && <>
        <Body>Bloom is allowed, but its blocking service is not connected. Turn Bloom on in Android Accessibility settings, then return here.</Body>
        <Button label="Check Android settings" variant="secondary" onPress={props.onEnableAccessibility} busy={props.busy} />
      </>}

      {!props.loading && serviceReady && !hasTargets && <>
        <Body>Choose at least one app before turning protection on.</Body>
      </>}

      {!props.loading && serviceReady && hasTargets && !editingApps && <>
        {protectionIsOn && managedBlocking
          ? <Body>Protection is on. Some restrictions are managed by your family.</Body>
          : protectionNeedsAttention
            ? <Body>Reconnect Bloom in Android settings before relying on protection.</Body>
            : <Body>{props.status.active ? 'Selected apps are blocked.' : 'Your selection is ready. Turn protection on when you want Bloom to block these apps.'}</Body>}
        {!managedBlocking && <Button
          label={props.status.active ? 'Turn off blocking' : 'Turn on blocking'}
          onPress={props.onToggleBlocking}
          disabled={props.busy || protectionNeedsAttention}
          busy={props.busy}
        />}
      </>}

      {props.status.manualFocusActive || (props.status.scheduledActiveCount ?? 0) > 0
        ? <Body>Manual or scheduled Focus can also apply its own app restrictions.</Body>
        : null}
    </Panel>

    <Panel>
      <View style={styles.sectionHeading}>
        <View style={sharedStyles.grow}>
          <Eyebrow>YOUR LIST</Eyebrow>
          <Label>Apps to block</Label>
        </View>
        {!editingApps && <Text style={[styles.count, { color: theme.colors.inkMuted }]}>{appCount}</Text>}
      </View>

      {editingApps ? <>
        <Body>Select the apps Bloom should block while protection is on.</Body>
        <FocusAppPicker
          apps={props.apps}
          selected={props.selected}
          onChange={props.onChangeSelected}
          requiredIds={props.managedApps}
        />
        <Button label="Save apps" onPress={() => { void props.onSaveSelection().then((saved) => { if (saved) setEditingApps(false); }); }} busy={props.busy} disabled={props.loading} />
        <Button label="Cancel" variant="secondary" onPress={() => { props.onCancelSelection(); setEditingApps(false); }} disabled={props.busy} />
      </> : <>
        {appCount === 0
          ? <Body>No apps selected yet.</Body>
          : <View style={styles.selectedList}>
            {[...new Set([...selectedNames, ...props.managedApps.map((id) => props.apps.find((app) => app.id === id)?.name ?? 'Family-selected app')])].slice(0, 4).map((name) => (
              <View key={name} style={[styles.selectedRow, { borderColor: theme.colors.border }]}>
                <MaterialIcons name="block" size={18} color={theme.colors.action} />
                <Text style={[styles.selectedName, { color: theme.colors.ink }]}>{name}</Text>
              </View>
            ))}
            {appCount > 4 && <Body>And {appCount - 4} more</Body>}
          </View>}
        <Button label={appCount > 0 ? 'Change apps' : 'Choose apps'} variant="secondary" onPress={() => setEditingApps(true)} />
      </>}
    </Panel>

    <Panel>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Website blocking"
        accessibilityState={{ expanded: showWebsites }}
        onPress={() => setShowWebsites((open) => !open)}
        style={styles.disclosure}>
        <View style={sharedStyles.grow}>
          <Eyebrow>OPTIONAL</Eyebrow>
          <Label>Website blocking</Label>
          <Body>{props.websiteConsent ? `${props.websites.length + props.managedWebsites.length} websites · On` : 'Off'}</Body>
        </View>
        <MaterialIcons name={showWebsites ? 'expand-less' : 'expand-more'} size={24} color={theme.colors.inkMuted} />
      </Pressable>
      {showWebsites && <View style={styles.websiteDetails}>
        <Body>Bloom checks website addresses on this device in supported browsers. Addresses are not sent to Bloom.</Body>
        {props.managedWebsites.length > 0 && <Body>Your family also manages {props.managedWebsites.length} website {props.managedWebsites.length === 1 ? 'rule' : 'rules'}.</Body>}
        {!props.websiteConsent
          ? <Button label="Enable website blocking" variant="secondary" onPress={() => props.onToggleWebsiteChecks(true)} busy={props.busy} />
          : <>
            <Field label="Website domain" value={props.websiteInput} onChangeText={props.onChangeWebsiteInput} autoCapitalize="none" autoCorrect={false} keyboardType="url" placeholder="example.com" />
            <Button label="Add website" variant="secondary" onPress={props.onAddWebsite} busy={props.busy} disabled={!props.websiteInput.trim()} />
            {props.websites.map((website) => <View key={website} style={[styles.websiteRow, { borderColor: theme.colors.border }]}>
              <Text style={[styles.websiteName, { color: theme.colors.ink }]}>{website}</Text>
              <Pressable accessibilityRole="button" accessibilityLabel={`Remove ${website}`} onPress={() => props.onRemoveWebsite(website)} disabled={props.busy}>
                <Text style={[styles.removeText, { color: theme.colors.dangerText }]}>Remove</Text>
              </Pressable>
            </View>)}
            {props.managedWebsites.map((website) => (
              <View key={`managed:${website}`} style={[styles.websiteRow, { borderColor: theme.colors.border }]}>
                <Text style={[styles.websiteName, { color: theme.colors.ink }]}>{website}</Text>
                <Text style={[styles.managedText, { color: theme.colors.inkMuted }]}>Family</Text>
              </View>
            ))}
            {props.managedWebsites.length === 0 && <Button label="Turn off website blocking" variant="tertiary" onPress={() => props.onToggleWebsiteChecks(false)} busy={props.busy} />}
          </>}
      </View>}
    </Panel>

    <Panel>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel="Earned screen time"
        accessibilityState={{ expanded: props.showEarnedAccess }}
        onPress={props.onToggleEarnedAccess}
        style={styles.disclosure}>
        <View style={sharedStyles.grow}>
          <Eyebrow>OPTIONAL</Eyebrow>
          <Label>Earned screen time</Label>
          <Body>Use minutes from your shared Bloom balance</Body>
        </View>
        <MaterialIcons name={props.showEarnedAccess ? 'expand-less' : 'expand-more'} size={24} color={theme.colors.inkMuted} />
      </Pressable>
      {props.showEarnedAccess && props.earnedAccessContent}
    </Panel>

    {(props.syncError || props.error) && <ErrorText>{props.syncError || props.error}</ErrorText>}
  </Screen>;
}

const styles = StyleSheet.create({
  statusHeading: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  statusIcon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  sectionHeading: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  count: { fontSize: 14, fontWeight: '700' },
  selectedList: { gap: 8 },
  selectedRow: { minHeight: 40, flexDirection: 'row', alignItems: 'center', gap: 10, borderBottomWidth: StyleSheet.hairlineWidth },
  selectedName: { flex: 1, fontSize: 14, fontWeight: '600' },
  disclosure: { minHeight: 52, flexDirection: 'row', alignItems: 'center', gap: 12 },
  websiteDetails: { gap: 12, paddingTop: 12 },
  websiteRow: { minHeight: 42, flexDirection: 'row', alignItems: 'center', gap: 12, borderBottomWidth: StyleSheet.hairlineWidth },
  websiteName: { flex: 1, fontSize: 14, fontWeight: '600' },
  removeText: { fontSize: 13, fontWeight: '700' },
  managedText: { fontSize: 12, fontWeight: '600' },
});
