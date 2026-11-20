import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, type Href } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, ImageBackground, Pressable, StyleSheet, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Label, Panel, Screen, useIsDesktopLayout } from './bloom-ui';
import { bloomHomeImage, bloomPillarImages } from '../assets/bloom-images';
import { isDeviceStale } from '../lib/device-utils';
import type { BloomDevice } from '../lib/devices';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { useBloomTheme } from '../lib/theme-context';
import { moduleManifest } from '../lib/module-manifest';
import { useModuleVisibility } from '../lib/module-visibility';
import type { DailyCreditTotal, WeeklyGoalSummary } from '../lib/home-dashboard';
import type { GrowthOverview } from '../lib/growth-modules';

export type HomeDashboardProps = {
  weeklySummary: WeeklyGoalSummary | null;
  weeklyLoading: boolean;
  weeklyError: string | null;
  creditHistory: DailyCreditTotal[] | null;
  creditHistoryLoading: boolean;
  creditHistoryError: string | null;
  devices: BloomDevice[] | null;
  devicesLoading: boolean;
  devicesError: string | null;
  growthOverview: GrowthOverview[] | null;
  onRefresh: () => void;
};

const moduleDescriptions: Record<(typeof moduleManifest)[number]['id'], string> = {
  exercise: 'Find time to move.',
  study: 'Make room to focus.',
  read: 'Pick up where you left off.',
  tasks: 'Choose your next step.',
};

export function HomeDashboard({
  weeklySummary,
  weeklyLoading,
  weeklyError,
  creditHistory,
  creditHistoryLoading,
  creditHistoryError,
  devices,
  devicesLoading,
  devicesError,
  growthOverview,
  onRefresh,
}: HomeDashboardProps) {
  const { activeWorkout, creditsEnabled, creditBalance, dataConfirmedAt, loading, error, refresh } = useBloom();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const pillars = moduleManifest.filter((module) => module.available && visibleModules.includes(module.id)
    && (!childProfile || assignedModules.includes(module.id)));
  const walletError = error && !dataConfirmedAt ? error : null;
  const confirmedAtLabel = dataConfirmedAt
    ? new Date(dataConfirmedAt).toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
    : null;

  return <Screen safeAreaTop={false}>
    <View style={styles.content}>
      <ImageBackground source={bloomHomeImage} resizeMode="cover" style={[styles.hero, desktop && styles.desktopHero]} imageStyle={styles.heroImage}>
        <View style={styles.heroOverlay} />
        <View style={styles.heroCopy}>
          <Text style={styles.heroEyebrow}>TODAY</Text>
          <Text accessibilityRole="header" style={styles.heroHeading}>{childProfile ? 'A day at your pace.' : 'A more balanced day.'}</Text>
          <Text style={styles.heroBody}>{activeWorkout ? 'Your workout is ready when you are.' : 'Small steps in every pillar add up.'}</Text>
        </View>
        <Pressable accessibilityRole="button"
          accessibilityLabel={activeWorkout ? 'Resume your workout' : 'Open your weekly plan'}
          onPress={() => activeWorkout
            ? router.push({ pathname: '/session', params: { id: activeWorkout.id } })
            : router.push('/progress')}
          style={({ pressed }) => [styles.heroAction, pressed && styles.pressed]}>
          <MaterialIcons name="play-arrow" size={28} color="#17203B" />
        </Pressable>
      </ImageBackground>

      <View style={[styles.primaryColumns, desktop && styles.desktopColumns]}>
        <View style={desktop && styles.desktopColumn}>
          <WeeklyGoalsPanel summary={weeklySummary} loading={weeklyLoading} error={weeklyError} onRetry={onRefresh} />
        </View>
        <View style={desktop && styles.desktopColumn}>
          <ScreenTimePanel
            available={creditBalance}
            enabled={creditsEnabled}
            loading={loading}
            error={walletError}
            confirmedAtLabel={confirmedAtLabel}
            onRefresh={refresh}
          />
        </View>
      </View>

      <View style={[styles.secondaryColumns, desktop && styles.desktopColumns]}>
        <View style={desktop && styles.desktopColumn}>
          <CreditTrendsPanel totals={creditHistory} loading={creditHistoryLoading} error={creditHistoryError} onRetry={onRefresh} />
        </View>
        <View style={desktop && styles.desktopColumn}>
          <DevicesPanel devices={devices} loading={devicesLoading} error={devicesError} onRetry={onRefresh} />
        </View>
      </View>

      {pillars.length > 0 ? <View style={styles.pillarsSection}>
        <View style={styles.sectionHeading}>
          <View style={styles.sectionTitle}>
            <Text accessibilityRole="header" style={[styles.sectionHeadingText, { color: theme.colors.ink }]}>Your pillars</Text>
            <Body>Your four spaces for growth.</Body>
          </View>
          <Pressable accessibilityRole="button" accessibilityLabel="See all Bloom pillars" onPress={() => router.push('/apps')}
            style={({ pressed }) => [styles.seeAllButton, pressed && styles.pressed]}>
            <Text style={[styles.seeAllText, { color: theme.colors.inkMuted }]}>See all</Text>
            <MaterialIcons name="chevron-right" size={20} color={theme.colors.inkMuted} />
          </Pressable>
        </View>
        <View style={styles.pillarsGrid}>
          {pillars.map((module) => <PillarCard key={module.id} moduleId={module.id} />)}
        </View>
      </View> : <Panel>
        <Eyebrow>Your space</Eyebrow>
        <Label>Your pillars are ready when you are.</Label>
        <Body>Visit Settings to choose which of your Bloom spaces appear in navigation.</Body>
        <Button label="Choose your pillars" variant="secondary" onPress={() => router.push('/settings')} />
      </Panel>}

      {growthOverview && growthOverview.length > 0 && <PillarOverview rows={growthOverview} />}
      {activeWorkout && <Panel>
        <Eyebrow>Continue Exercise</Eyebrow>
        <Label>Your workout is ready when you are.</Label>
        <Button label="Resume workout" onPress={() => router.push({ pathname: '/session', params: { id: activeWorkout.id } })} />
      </Panel>}
      <View style={styles.secondaryLinks}>
        <SecondaryLink icon="insights" title="Progress" route="/progress" />
        <SecondaryLink icon="history" title="Activity history" route="/activity" />
        <SecondaryLink icon="devices" title="Connected devices" route="/devices" />
      </View>
    </View>
  </Screen>;
}

function WeeklyGoalsPanel({ summary, loading, error, onRetry }: {
  summary: WeeklyGoalSummary | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();

  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>This week</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Your weekly goals</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error ? <>
      <Body>Your weekly goals could not be loaded.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : summary && summary.totalCount > 0 ? <View style={styles.goalsLayout}>
      <GoalProgressRing percent={summary.percent} completed={summary.completedCount} total={summary.totalCount} />
      <View style={styles.goalsList}>
        {summary.goals.map((goal) => {
          const module = moduleManifest.find((entry) => entry.id === goal.module_id)!;
          const moduleColors = theme.modules[goal.module_id];
          const progress = Math.min(100, Math.round(goal.actualValue / goal.target_count * 100));
          return <View key={goal.module_id} style={styles.goalRow}>
            <View style={[styles.goalIcon, { backgroundColor: moduleColors.surface }]}>
              <MaterialIcons name={module.icon} size={17} color={moduleColors.deep} />
            </View>
            <View style={styles.goalCopy}>
              <View style={styles.goalHeading}>
                <Text style={[styles.goalName, { color: theme.colors.ink }]} numberOfLines={1}>{module.name}</Text>
                <Text style={[styles.goalTarget, { color: goal.complete ? moduleColors.deep : theme.colors.inkMuted }]}>{formatGoalValue(goal.actualValue)}/{formatGoalValue(goal.target_count)} {goalUnit(goal.unit)}</Text>
              </View>
              <View accessible accessibilityRole="progressbar" accessibilityLabel={`${module.name} weekly goal`}
                accessibilityValue={{ min: 0, max: goal.target_count, now: Math.min(goal.actualValue, goal.target_count) }}
                style={[styles.goalTrack, { backgroundColor: theme.colors.surfaceSoft }]}>
                <View style={[styles.goalFill, { width: `${progress}%`, backgroundColor: moduleColors.deep }]} />
              </View>
            </View>
          </View>;
        })}
      </View>
    </View> : <>
      <Body>Your weekly plan is ready to shape around the days that work for you.</Body>
      <Button label="Set a weekly goal" variant="secondary" onPress={() => router.push('/progress')} />
    </>}
  </Panel>;
}

function GoalProgressRing({ percent, completed, total }: { percent: number; completed: number; total: number }) {
  const { theme } = useBloomTheme();
  const segmentCount = 64;
  const activeSegments = Math.round(percent / 100 * segmentCount);
  const center = 70;
  const radius = 61;
  return <View accessible accessibilityRole="progressbar" accessibilityLabel="Weekly goals completed"
    accessibilityValue={{ min: 0, max: total, now: completed }} style={styles.goalRing}>
    {Array.from({ length: segmentCount }, (_, index) => {
      const rotation = index / segmentCount * 360 - 90;
      const radians = rotation * Math.PI / 180;
      return <View key={index} style={[styles.ringSegment, {
        left: center + Math.cos(radians) * radius - 2,
        top: center + Math.sin(radians) * radius - 5,
        transform: [{ rotate: `${rotation + 90}deg` }],
        backgroundColor: index < activeSegments ? theme.colors.action : theme.colors.surfaceSoft,
      }]} />;
    })}
    <View style={styles.goalRingCenter}>
      <Text style={[styles.goalPercent, { color: theme.colors.ink }]}>{percent}</Text>
      <Text style={[styles.goalRingLabel, { color: theme.colors.inkMuted }]}>{completed} of {total} goals</Text>
    </View>
  </View>;
}

function ScreenTimePanel({ available, enabled, loading, error, confirmedAtLabel, onRefresh }: {
  available: number;
  enabled: boolean;
  loading: boolean;
  error: string | null;
  confirmedAtLabel: string | null;
  onRefresh: () => Promise<void>;
}) {
  const { theme } = useBloomTheme();
  const [retrying, setRetrying] = useState(false);

  async function refreshWallet() {
    setRetrying(true);
    try { await onRefresh(); } finally { setRetrying(false); }
  }

  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Screen time</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Available to use</Text>
    </View>
    {loading ? <View style={styles.inlineStatus}><ActivityIndicator color={theme.colors.action} /><Body>Connecting to Bloom.</Body></View>
      : error ? <>
        <ErrorText>{error}</ErrorText>
        {confirmedAtLabel && <Body>Last confirmed at {confirmedAtLabel}.</Body>}
        <Button label="Try again" variant="secondary" busy={retrying} onPress={() => void refreshWallet()} />
      </> : enabled ? <>
        <View style={styles.balanceRow}>
          <Text accessibilityLabel={`${formatCreditAmount(available)} screen-time minutes`} style={[styles.balanceAmount, { color: theme.colors.ink }]}>{formatCreditAmount(available)}</Text>
          <Text style={[styles.balanceUnit, { color: theme.colors.inkMuted }]}>min</Text>
        </View>
        <View style={styles.balanceStatus}>
          <MaterialIcons name="verified" size={16} color={theme.colors.successText} />
          <Text style={[styles.statusText, { color: theme.colors.inkMuted }]}>{confirmedAtLabel ? `Confirmed at ${confirmedAtLabel}` : 'Balance confirmed by Bloom'}</Text>
        </View>
      </> : <>
        <Text style={[styles.creditsOff, { color: theme.colors.ink } ]}>Screen-time credits are off.</Text>
        <Body>Credits remain available to review in your ledger.</Body>
      </>}
    <View style={[styles.panelActions, { borderTopColor: theme.colors.border }]}>
      <SecondaryLink icon="history" title="Credit history" route="/credit-history" />
      <SecondaryLink icon="do-not-disturb-on" title="Focus settings" route="/focus" />
    </View>
  </Panel>;
}

function CreditTrendsPanel({ totals, loading, error, onRetry }: {
  totals: DailyCreditTotal[] | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();
  const weeklyTotal = totals?.reduce((total, day) => total + day.minutes, 0) ?? 0;
  const peak = Math.max(0, ...(totals?.map((day) => day.minutes) ?? []));

  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Screen-time credits</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Earned this week</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error || !totals ? <>
      <Body>Your weekly credit activity is temporarily unavailable.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : <>
      <Text accessibilityLabel={`${formatCreditDuration(weeklyTotal)} of screen-time credits earned during the last seven days`} style={[styles.trendAmount, { color: theme.colors.ink }]}>{formatCreditDuration(weeklyTotal)}</Text>
      <View accessibilityLabel="Screen-time credits earned in each of the last seven calendar days" style={styles.chart}>
        {totals.map((day) => {
          const barHeight = day.minutes <= 0 ? 2 : Math.max(9, Math.round((day.minutes / (peak || 1)) * 72));
          return <View key={day.dateKey} style={styles.chartDay}>
            <View style={[styles.chartArea, { backgroundColor: theme.colors.surfaceSoft }]}>
              <View style={[styles.chartBar, {
                height: barHeight,
                backgroundColor: day.minutes > 0 ? theme.colors.action : theme.colors.border,
              }]} />
            </View>
            <Text style={[styles.chartLabel, { color: theme.colors.inkMuted }]}>{day.label}</Text>
          </View>;
        })}
      </View>
    </>}
  </Panel>;
}

function DevicesPanel({ devices, loading, error, onRetry }: {
  devices: BloomDevice[] | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();
  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Your devices</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Last check-in</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error || !devices ? <>
      <Body>Connected device reports are temporarily unavailable.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : devices.length > 0 ? devices.slice(0, 3).map((device) => {
      const stale = isDeviceStale(device.last_seen_at);
      return <Pressable key={device.device_id} accessibilityRole="button"
        accessibilityLabel={`${device.display_name}. ${stale ? 'The last report is over a day old.' : 'Recently checked in.'} Review connected devices.`}
        onPress={() => router.push({ pathname: '/device-detail', params: { deviceId: device.device_id } })}
        style={styles.deviceRow}>
        <View style={[styles.deviceIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
          <MaterialIcons name={deviceIcon(device.platform)} size={19} color={theme.colors.inkMuted} />
        </View>
        <View style={styles.deviceCopy}>
          <Text style={[styles.deviceName, { color: theme.colors.ink }]} numberOfLines={1}>{device.display_name}</Text>
          <Text style={[styles.deviceDetail, { color: theme.colors.inkMuted }]}>{stale ? 'Last report over a day ago' : `Last seen ${formatDeviceTime(device.last_seen_at)}`}</Text>
        </View>
        <MaterialIcons name="chevron-right" size={19} color={theme.colors.inkSubtle} />
      </Pressable>;
    }) : <Body>Your devices will appear here after their first check-in.</Body>}
    <View style={[styles.panelActions, { borderTopColor: theme.colors.border }]}>
      <SecondaryLink icon="devices" title="Manage devices" route="/devices" />
    </View>
  </Panel>;
}

function PillarCard({ moduleId }: { moduleId: (typeof moduleManifest)[number]['id'] }) {
  const { theme } = useBloomTheme();
  const module = moduleManifest.find((item) => item.id === moduleId)!;
  const colors = theme.modules[moduleId];
  return <Pressable accessibilityRole="button" accessibilityLabel={`Open ${module.name}. ${module.description}`}
    accessibilityHint={`Opens the ${module.name} pillar.`}
    onPress={() => { if (module.route) router.push(module.route as Href); }}
    style={({ pressed }) => [styles.pillarCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, pressed && styles.pressed]}>
    <ImageBackground source={bloomPillarImages[moduleId]} resizeMode="cover" style={styles.pillarPhoto} imageStyle={styles.pillarPhotoImage}>
      <View style={[styles.pillarIcon, { backgroundColor: theme.colors.surface }]}>
        <MaterialIcons name={module.icon} size={20} color={colors.deep} />
      </View>
    </ImageBackground>
    <View style={styles.pillarCopy}>
      <Text style={[styles.pillarName, { color: theme.colors.ink }]}>{module.name}</Text>
      <Text style={[styles.pillarDescription, { color: theme.colors.inkMuted }]}>{moduleDescriptions[moduleId]}</Text>
    </View>
  </Pressable>;
}

function PillarOverview({ rows }: { rows: GrowthOverview[] }) {
  const { theme } = useBloomTheme();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const modules = moduleManifest.filter((module) => visibleModules.includes(module.id)
    && (!childProfile || assignedModules.includes(module.id)));
  const visibleRows = modules.flatMap((module) => {
    const row = rows.find((item) => item.module_id === module.id);
    return row ? [row] : [];
  });

  if (visibleRows.length === 0) return null;
  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Across Bloom</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Your activity</Text>
    </View>
    <View style={styles.overviewRows}>
      {visibleRows.map((row) => {
        const module = moduleManifest.find((item) => item.id === row.module_id)!;
        const growthText = row.module_id === 'study' ? `${row.minutes_this_week} min focused this week`
          : row.module_id === 'read' ? `${row.active_items} ${row.active_items === 1 ? 'book' : 'books'} in progress`
            : `${row.active_items} ${row.active_items === 1 ? 'task' : 'tasks'} to do`;
        return <View key={row.module_id} style={styles.overviewRow}>
          <View style={[styles.goalIcon, { backgroundColor: theme.modules[row.module_id].surface }]}>
            <MaterialIcons name={module.icon} size={17} color={theme.modules[row.module_id].deep} />
          </View>
          <View style={styles.deviceCopy}>
            <Text style={[styles.deviceName, { color: theme.colors.ink }]}>{module.name}</Text>
            <Text style={[styles.deviceDetail, { color: theme.colors.inkMuted }]}>{growthText}</Text>
          </View>
          {row.module_id === 'tasks' && row.due_today > 0 && <Text style={[styles.deviceDetail, { color: theme.colors.inkMuted }]}>{row.due_today} due today</Text>}
        </View>;
      })}
    </View>
  </Panel>;
}

function SecondaryLink({ icon, title, route }: { icon: 'insights' | 'history' | 'devices' | 'do-not-disturb-on'; title: string; route: Href }) {
  const { theme } = useBloomTheme();
  return <Pressable accessibilityRole="button" accessibilityLabel={title} onPress={() => router.push(route)}
    style={({ pressed }) => [styles.quickLink, pressed && styles.pressed]}>
    <MaterialIcons name={icon} size={18} color={theme.colors.action} />
    <Text style={[styles.quickLinkText, { color: theme.colors.inkMuted }]}>{title}</Text>
    <MaterialIcons name="chevron-right" size={17} color={theme.colors.inkSubtle} />
  </Pressable>;
}

function deviceIcon(platform: BloomDevice['platform']): 'phone-iphone' | 'phone-android' | 'laptop-mac' | 'devices' {
  if (platform === 'ios') return 'phone-iphone';
  if (platform === 'android') return 'phone-android';
  if (platform === 'macos') return 'laptop-mac';
  return 'devices';
}

function formatDeviceTime(value: string) {
  const date = new Date(value);
  return Number.isFinite(date.getTime())
    ? date.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' })
    : 'Time unavailable';
}

function formatGoalValue(value: number) {
  return value.toLocaleString(undefined, { maximumFractionDigits: 1 });
}

function goalUnit(unit: WeeklyGoalSummary['goals'][number]['unit']) {
  if (unit === 'workouts') return 'wkts';
  if (unit === 'minutes') return 'min';
  return unit;
}

function formatCreditAmount(value: number) {
  return value.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

function formatCreditDuration(value: number) {
  const rounded = Math.round(value);
  const hours = Math.floor(rounded / 60);
  const minutes = rounded % 60;
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes} min`;
}

const styles = StyleSheet.create({
  content: { width: '100%', gap: 16 },
  hero: { minHeight: 194, overflow: 'hidden', justifyContent: 'flex-end', borderRadius: 27, padding: 20 },
  desktopHero: { minHeight: 274, padding: 30 },
  heroImage: { borderRadius: 27 },
  heroOverlay: { position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: 'rgba(17, 27, 53, 0.39)' },
  heroCopy: { flex: 1, justifyContent: 'flex-end', paddingEnd: 62, gap: 5 },
  heroEyebrow: { color: 'rgba(255, 255, 255, 0.96)', fontSize: 13, fontWeight: '700', letterSpacing: 1.05 },
  heroHeading: { color: '#FFFFFF', fontSize: 28, lineHeight: 34, fontWeight: '700', letterSpacing: -0.6 },
  heroBody: { color: 'rgba(255, 255, 255, 0.95)', fontSize: 15, lineHeight: 21 },
  heroAction: { position: 'absolute', right: 17, bottom: 17, width: 46, height: 46, alignItems: 'center', justifyContent: 'center', borderRadius: 23, backgroundColor: '#FFFFFF', shadowColor: '#141B35', shadowOpacity: 0.12, shadowOffset: { width: 0, height: 3 }, shadowRadius: 8, elevation: 3 },
  primaryColumns: { gap: 16 },
  secondaryColumns: { gap: 16 },
  desktopColumns: { flexDirection: 'row', alignItems: 'stretch' },
  desktopColumn: { flex: 1, minWidth: 0 },
  panelHeading: { gap: 2 },
  panelTitle: { fontSize: 18, lineHeight: 24, fontWeight: '700', letterSpacing: -0.3 },
  goalsLayout: { flexDirection: 'row', alignItems: 'center', gap: 13, paddingVertical: 5 },
  goalRing: { width: 140, height: 140, alignItems: 'center', justifyContent: 'center' },
  ringSegment: { position: 'absolute', width: 4, height: 10, borderRadius: 4 },
  goalRingCenter: { width: 98, height: 98, borderRadius: 49, alignItems: 'center', justifyContent: 'center', gap: 0 },
  goalPercent: { fontSize: 39, lineHeight: 44, fontWeight: '700', letterSpacing: -1.1, fontVariant: ['tabular-nums'] },
  goalRingLabel: { fontSize: 11, lineHeight: 17, fontWeight: '600', textAlign: 'center' },
  goalsList: { flex: 1, gap: 11, minWidth: 0 },
  goalRow: { flexDirection: 'row', alignItems: 'center', gap: 8, minHeight: 27 },
  goalIcon: { width: 26, height: 26, borderRadius: 9, alignItems: 'center', justifyContent: 'center' },
  goalCopy: { flex: 1, gap: 4, minWidth: 0 },
  goalHeading: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 4 },
  goalName: { fontSize: 13, lineHeight: 16, fontWeight: '600', flex: 1 },
  goalTarget: { fontSize: 12, lineHeight: 16, fontWeight: '600', fontVariant: ['tabular-nums'] },
  goalTrack: { height: 6, overflow: 'hidden', borderRadius: 999 },
  goalFill: { height: '100%', borderRadius: 999 },
  balanceRow: { flexDirection: 'row', alignItems: 'baseline', gap: 7 },
  balanceAmount: { fontSize: 40, lineHeight: 47, fontWeight: '700', letterSpacing: -1, fontVariant: ['tabular-nums'] },
  balanceUnit: { fontSize: 16, fontWeight: '600' },
  balanceStatus: { flexDirection: 'row', alignItems: 'center', gap: 6, minHeight: 22 },
  statusText: { fontSize: 12, lineHeight: 17 },
  creditsOff: { fontSize: 19, lineHeight: 26, fontWeight: '600' },
  inlineStatus: { minHeight: 56, flexDirection: 'row', alignItems: 'center', gap: 9 },
  panelActions: { gap: 3, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: 8, marginTop: 3 },
  quickLink: { minHeight: 40, flexDirection: 'row', alignItems: 'center', gap: 9 },
  quickLinkText: { flex: 1, fontSize: 13, lineHeight: 19, fontWeight: '600' },
  trendAmount: { fontSize: 30, lineHeight: 37, fontWeight: '700', letterSpacing: -0.65, fontVariant: ['tabular-nums'] },
  chart: { minHeight: 105, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', gap: 8, paddingTop: 8 },
  chartDay: { flex: 1, minWidth: 0, alignItems: 'center', gap: 7 },
  chartArea: { width: '100%', maxWidth: 32, height: 70, alignItems: 'center', justifyContent: 'flex-end', overflow: 'hidden', borderTopLeftRadius: 9, borderTopRightRadius: 9 },
  chartBar: { width: '78%', borderTopLeftRadius: 8, borderTopRightRadius: 8 },
  chartLabel: { fontSize: 11, lineHeight: 15, fontWeight: '500' },
  deviceRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 11 },
  deviceIcon: { width: 35, height: 35, alignItems: 'center', justifyContent: 'center', borderRadius: 12 },
  deviceCopy: { flex: 1, minWidth: 0, gap: 1 },
  deviceName: { fontSize: 14, lineHeight: 20, fontWeight: '600' },
  deviceDetail: { fontSize: 12, lineHeight: 17 },
  pillarsSection: { gap: 11, paddingTop: 1 },
  sectionHeading: { minHeight: 36, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 10 },
  sectionTitle: { flex: 1, gap: 2 },
  sectionHeadingText: { fontSize: 22, lineHeight: 27, fontWeight: '700', letterSpacing: -0.5 },
  seeAllButton: { minHeight: 44, flexDirection: 'row', alignItems: 'center', gap: 3, paddingHorizontal: 2 },
  seeAllText: { fontSize: 14, fontWeight: '600' },
  pillarsGrid: { flexDirection: 'row', flexWrap: 'wrap', alignItems: 'stretch', gap: 12 },
  pillarCard: { flexGrow: 1, flexBasis: 146, minWidth: 138, borderRadius: 20, borderWidth: 1, overflow: 'hidden' },
  pillarPhoto: { height: 105, justifyContent: 'flex-end', alignItems: 'flex-start', padding: 10 },
  pillarPhotoImage: { borderTopLeftRadius: 19, borderTopRightRadius: 19 },
  pillarIcon: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center', borderRadius: 18 },
  pillarCopy: { minHeight: 62, justifyContent: 'center', paddingHorizontal: 12, paddingVertical: 8, gap: 1 },
  pillarName: { fontSize: 15, lineHeight: 20, fontWeight: '700' },
  pillarDescription: { fontSize: 12, lineHeight: 17 },
  overviewRows: { gap: 7 },
  overviewRow: { minHeight: 38, flexDirection: 'row', alignItems: 'center', gap: 10 },
  secondaryLinks: { gap: 7, paddingBottom: 4 },
  pressed: { opacity: 0.78 },
});
