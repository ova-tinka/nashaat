import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import type { ReactNode } from 'react';
import type { BlockingStatus, SafariContentBlockerState } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import type { ChildRule, WebsiteRule, WebsiteRuleScope } from '../lib/family';
import { useBloomTheme } from '../lib/theme-context';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from './bloom-ui';

type Props = {
  status: BlockingStatus;
  loading: boolean;
  busy: boolean;
  error: string | null;
  syncError: string | null;
  websiteRules: WebsiteRule[];
  managedRules: ChildRule[];
  userId: string | null;
  safariBlocker: SafariContentBlockerState | null;
  websiteInput: string;
  websiteRuleScope: WebsiteRuleScope;
  blockingRulesSyncedAt: number | null;
  childProfile: boolean;
  initialSection: string;
  showEarnedAccess: boolean;
  earnedAccessContent: ReactNode;
  onBack: () => void;
  onChooseTargets: () => void;
  onToggleBlocking: () => void;
  onAuthorizeAlwaysWebsites: () => void;
  onRemoveWebsiteRule: (rule: WebsiteRule) => void;
  onWebsiteInputChange: (value: string) => void;
  onWebsiteScopeChange: (scope: WebsiteRuleScope) => void;
  onSaveWebsiteRule: () => void;
  onRecheckSafari: () => void;
  onToggleEarnedAccess: () => void;
  onManageFamilyRules: () => void;
};

export function IosFocusSettings(props: Props) {
  const { theme } = useBloomTheme();
  const [showWebsites, setShowWebsites] = useState(props.initialSection === 'websites');
  const targetCount = props.status.appCount + props.status.websiteCount + props.status.categoryCount;
  const focusWebsites = props.websiteRules.filter((rule) => rule.scope === 'focus');
  const alwaysWebsites = props.websiteRules.filter((rule) => rule.scope === 'always');
  const parentWebsites = props.managedRules.filter((rule) => rule.platform === 'ios' && rule.target_type === 'website');
  const siteCount = alwaysWebsites.length + focusWebsites.length + parentWebsites.length;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Focus</Eyebrow>
      <Heading>Block distractions</Heading>
      <Body>Choose apps or websites to block on this iPhone or iPad.</Body>
      <Button label="Back to settings" variant="tertiary" onPress={props.onBack} />
    </View>

    <Panel>
      <View style={styles.statusHeading}>
        <View style={[styles.statusIcon, { backgroundColor: props.status.active ? theme.colors.successText : theme.colors.surfaceTinted }]}>
          <MaterialIcons name={props.status.active ? 'shield' : 'shield-moon'} size={22} color={props.status.active ? '#FFFFFF' : theme.colors.action} />
        </View>
        <View style={sharedStyles.grow}>
          <Eyebrow>{props.loading ? 'Checking this device' : !props.status.authorized ? 'Setup needed' : props.status.active ? 'Protection is on' : 'Protection is off'}</Eyebrow>
          <Label>{props.loading ? 'Checking status…' : `${targetCount} blocking ${targetCount === 1 ? 'target' : 'targets'} selected`}</Label>
        </View>
      </View>

      {!props.loading && !props.status.authorized
        ? <>
          <Body>Apple Screen Time access lets Bloom apply the apps you choose. Bloom will show Apple’s permission prompt next.</Body>
          <Button label="Set up Screen Time" onPress={props.onChooseTargets} busy={props.busy} />
        </>
        : <>
          <Body>{props.status.active ? 'Your selected apps and categories are currently blocked.' : targetCount ? 'Your selected apps and categories are ready to block.' : 'Choose the apps and categories Bloom should block.'}</Body>
          <Button
            label={!targetCount ? 'Choose apps to block' : props.status.active ? 'Turn off app blocking' : 'Turn on app blocking'}
            onPress={targetCount ? props.onToggleBlocking : props.onChooseTargets}
            busy={props.busy}
            disabled={props.loading}
          />
          {targetCount > 0 && <Button label="Change selected apps and categories" variant="secondary" onPress={props.onChooseTargets} busy={props.busy} disabled={props.loading} />}
        </>}

      {props.status.scheduleError || props.status.manualFocusError
        ? <Body>Bloom could not check a Focus schedule or manual session. Open the Focus settings to review it.</Body>
        : null}
      {(props.status.manualFocusActive || (props.status.scheduledActiveCount ?? 0) > 0)
        ? <Body>Manual or scheduled Focus may apply additional app restrictions.</Body>
        : null}
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
          <Body>{siteCount === 0 ? 'Off' : `${siteCount} ${siteCount === 1 ? 'website' : 'websites'} configured`}</Body>
        </View>
        <MaterialIcons name={showWebsites ? 'expand-less' : 'expand-more'} size={24} color={theme.colors.inkMuted} />
      </Pressable>
      {showWebsites && <View style={styles.details}>
        <Body>Add a domain to block it always or only while Focus is on. Website rules and Safari extension availability are managed separately from app blocking.</Body>
        {props.safariBlocker && !props.safariBlocker.bundled
          ? <Body>The Safari extension is not included in this app build.</Body>
          : props.safariBlocker && !props.safariBlocker.stateAvailable
            ? <Body>Safari could not confirm whether Bloom’s extension is enabled. Check Settings → Apps → Safari → Extensions.</Body>
            : props.safariBlocker && !props.safariBlocker.enabled
              ? <Body>Enable Bloom in Settings → Apps → Safari → Extensions for Focus-only website rules.</Body>
              : !props.safariBlocker && !props.loading
                ? <Body>Safari extension status is unavailable. Check Settings → Apps → Safari → Extensions.</Body>
                : null}

        {alwaysWebsites.length > 0 && !props.status.authorized && <>
          <Body>Always-blocked websites are saved. Allow Screen Time access to apply them on this iPhone.</Body>
          <Button label="Allow Screen Time for websites" variant="secondary" onPress={props.onAuthorizeAlwaysWebsites} busy={props.busy} />
        </>}

        <Label>Always blocked</Label>
        {alwaysWebsites.map((rule) => <WebsiteRuleRow key={rule.id} rule={rule} userId={props.userId} busy={props.busy} onRemove={props.onRemoveWebsiteRule} />)}
        {alwaysWebsites.length === 0 && <Body>No always-blocked websites.</Body>}

        <Label>Blocked while Focus is on</Label>
        {focusWebsites.map((rule) => <WebsiteRuleRow key={rule.id} rule={rule} userId={props.userId} busy={props.busy} onRemove={props.onRemoveWebsiteRule} />)}
        {parentWebsites.map((rule) => <View key={`parent:${rule.id}`} style={[styles.websiteRow, { borderColor: theme.colors.border }]}>
          <Text style={[styles.websiteName, { color: theme.colors.ink }]}>{rule.target_identifier}</Text>
          <Text style={[styles.managedText, { color: theme.colors.inkMuted }]}>Family</Text>
        </View>)}
        {focusWebsites.length + parentWebsites.length === 0 && <Body>No Focus-only websites.</Body>}

        <Field label="Website or URL" value={props.websiteInput} onChangeText={props.onWebsiteInputChange} autoCapitalize="none" autoCorrect={false} keyboardType="url" placeholder="example.com" />
        <View style={styles.scopeRow}>
          {(['always', 'focus'] as const).map((scope) => <Pressable
            key={scope}
            accessibilityRole="radio"
            accessibilityState={{ selected: props.websiteRuleScope === scope }}
            onPress={() => props.onWebsiteScopeChange(scope)}
            style={[styles.scopeChoice, { borderColor: props.websiteRuleScope === scope ? theme.colors.action : theme.colors.border, backgroundColor: props.websiteRuleScope === scope ? theme.colors.surfaceTinted : theme.colors.surface }]}>
            <Text style={[styles.scopeText, { color: props.websiteRuleScope === scope ? theme.colors.action : theme.colors.inkMuted }]}>{scope === 'always' ? 'Always' : 'During Focus'}</Text>
          </Pressable>)}
        </View>
        <Button label={props.websiteRuleScope === 'always' ? 'Add always-blocked website' : 'Add Focus website'} onPress={props.onSaveWebsiteRule} busy={props.busy} disabled={props.loading || !props.websiteInput.trim()} />
        <Button label="Check Safari extension" variant="tertiary" onPress={props.onRecheckSafari} busy={props.busy} />
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

    {props.blockingRulesSyncedAt && !props.syncError && <Body>Family rules last synced {new Date(props.blockingRulesSyncedAt).toLocaleTimeString()}.</Body>}
    {props.syncError && <ErrorText>{props.syncError}</ErrorText>}
    {props.error && <ErrorText>{props.error}</ErrorText>}
    {!props.childProfile && <Button label="Manage family rules" variant="tertiary" onPress={props.onManageFamilyRules} />}
  </Screen>;
}

function WebsiteRuleRow({ rule, userId, busy, onRemove }: { rule: WebsiteRule; userId: string | null; busy: boolean; onRemove: (rule: WebsiteRule) => void }) {
  const { theme } = useBloomTheme();
  const managed = rule.created_by !== userId;
  return <View style={[styles.websiteRow, { borderColor: theme.colors.border }]}>
    <Text style={[styles.websiteName, { color: theme.colors.ink }]}>{rule.domain}</Text>
    {managed
      ? <Text style={[styles.managedText, { color: theme.colors.inkMuted }]}>Family</Text>
      : <Pressable accessibilityRole="button" accessibilityLabel={`Remove ${rule.domain}`} onPress={() => onRemove(rule)} disabled={busy}>
        <Text style={[styles.removeText, { color: theme.colors.dangerText }]}>Remove</Text>
      </Pressable>}
  </View>;
}

const styles = StyleSheet.create({
  statusHeading: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  statusIcon: { width: 42, height: 42, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  disclosure: { minHeight: 52, flexDirection: 'row', alignItems: 'center', gap: 12 },
  details: { gap: 12, paddingTop: 12 },
  websiteRow: { minHeight: 42, flexDirection: 'row', alignItems: 'center', gap: 12, borderBottomWidth: StyleSheet.hairlineWidth },
  websiteName: { flex: 1, fontSize: 14, fontWeight: '600' },
  removeText: { fontSize: 13, fontWeight: '700' },
  managedText: { fontSize: 12, fontWeight: '600' },
  scopeRow: { flexDirection: 'row', gap: 8 },
  scopeChoice: { flex: 1, minHeight: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 12, paddingHorizontal: 10 },
  scopeText: { fontSize: 13, fontWeight: '700' },
});
