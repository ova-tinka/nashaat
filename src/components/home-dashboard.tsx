import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, type Href } from 'expo-router';
import { ActivityIndicator, ImageBackground, Pressable, StyleSheet, Text, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Label, Panel, Screen, useIsDesktopLayout } from './bloom-ui';
import { bloomHomeImage, bloomPillarImages } from '../assets/bloom-images';
import type { BloomDevice } from '../lib/devices';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { useBloomTheme } from '../lib/theme-context';
import { moduleManifest } from '../lib/module-manifest';
import { useModuleVisibility } from '../lib/module-visibility';
import { summarizeTodayPillars, type DailyScreenTimeTotal, type TodayPillarProgress, type WeeklyGoalSummary } from '../lib/home-dashboard';
import type { GrowthActivityEvent } from '../lib/growth-modules';

export type HomeDashboardProps = {
  weeklySummary: WeeklyGoalSummary | null;
  weeklyLoading: boolean;
  weeklyError: string | null;
  growthActivity: GrowthActivityEvent[] | null;
  growthActivityLoading: boolean;
  growthActivityError: string | null;
  creditHistory: DailyScreenTimeTotal[] | null;
  creditHistoryLoading: boolean;
  creditHistoryError: string | null;
  devices: BloomDevice[] | null;
  devicesLoading: boolean;
  devicesError: string | null;
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
  growthActivity,
  growthActivityLoading,
  growthActivityError,
  creditHistory,
  creditHistoryLoading,
  creditHistoryError,
  devices,
  devicesLoading,
  devicesError,
  onRefresh,
}: HomeDashboardProps) {
  const { activeWorkout, creditsEnabled, creditBalance, creditSettings, dataConfirmedAt, loading, error, refresh, workoutAnalytics } = useBloom();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const pillars = moduleManifest.filter((module) => module.available && visibleModules.includes(module.id)
    && (!childProfile || assignedModules.includes(module.id)));
  const walletError = error && !dataConfirmedAt ? error : null;
  const todayPillars = summarizeTodayPillars(weeklySummary?.goals ?? [], growthActivity ?? [],
    workoutAnalytics?.history.map((session) => session.completed_at) ?? [], new Date(), creditSettings?.credit_timezone ?? 'UTC')
    .filter((entry) => pillars.some((pillar) => pillar.id === entry.module_id));

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

      <View style={styles.balanceGoalsRow}>
        <View style={styles.balanceColumn}>
          <BalancePanel available={creditBalance} enabled={creditsEnabled} loading={loading} error={walletError} onRefresh={refresh} />
        </View>
        <View style={styles.goalsColumn}>
          <TodayPillarsPanel progress={todayPillars} loading={weeklyLoading || growthActivityLoading}
            error={weeklyError ?? growthActivityError} onRetry={onRefresh} />
        </View>
      </View>

      <WeeklyScreenTimePanel totals={creditHistory} loading={creditHistoryLoading} error={creditHistoryError} onRetry={onRefresh} />

      <View style={styles.insightColumns}>
        <View style={styles.desktopColumn}>
          <ByDevicePanel devices={devices} loading={devicesLoading} error={devicesError} onRetry={onRefresh} />
        </View>
        <View style={styles.desktopColumn}>
          <InsightsPanel summary={weeklySummary} loading={weeklyLoading} error={weeklyError} />
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

    </View>
  </Screen>;
}

function TodayPillarsPanel({ progress, loading, error, onRetry }: {
  progress: TodayPillarProgress[];
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();
  const completedCount = progress.filter((pillar) => pillar.complete).length;

  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Today’s plan</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>{progress.length > 0 ? `${completedCount} of ${progress.length} done` : 'A flexible day'}</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error ? <>
      <Body>Today’s pillar plan could not be loaded.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : progress.length > 0 ? <View style={styles.todayPillarList}>
      {progress.map((pillar) => {
        const module = moduleManifest.find((entry) => entry.id === pillar.module_id)!;
        const moduleColors = theme.modules[pillar.module_id];
        return <View key={pillar.module_id} style={styles.todayPillarRow}>
          <MaterialIcons name={module.icon} size={16} color={moduleColors.deep} />
          <Text style={[styles.todayPillarName, { color: theme.colors.ink }]} numberOfLines={1}>{module.name}</Text>
          <Text style={[styles.todayPillarStatus, { color: pillar.complete ? moduleColors.deep : theme.colors.inkMuted }]}>{pillar.complete ? 'Done' : 'Planned'}</Text>
        </View>;
      })}
    </View> : <>
      <Body>No pillar is scheduled today. Keep the day flexible or choose a weekly plan.</Body>
      <Button label="Edit weekly plan" variant="secondary" onPress={() => router.push('/progress')} />
    </>}
  </Panel>;
}

function BalancePanel({ available, enabled, loading, error, onRefresh }: {
  available: number;
  enabled: boolean;
  loading: boolean;
  error: string | null;
  onRefresh: () => Promise<void>;
}) {
  const { theme } = useBloomTheme();
  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Screen-time balance</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>This week</Text>
    </View>
    {loading ? <View style={styles.inlineStatus}><ActivityIndicator color={theme.colors.action} /><Body>Connecting to Bloom.</Body></View>
      : error ? <>
        <ErrorText>{error}</ErrorText>
        <Button label="Retry" variant="secondary" onPress={() => void onRefresh()} />
      </> : enabled ? <>
        <View style={styles.balanceRow}>
          <Text accessibilityLabel={`${formatCreditDuration(available)} of screen time available in your balance`} style={[styles.balanceAmount, { color: theme.colors.ink }]}>{formatCreditHours(available)}</Text>
          <Text style={[styles.balanceUnit, { color: theme.colors.inkMuted }]}>h</Text>
        </View>
        <Text style={[styles.balanceNote, { color: theme.colors.inkMuted }]}>Available for screen time</Text>
      </> : <>
        <Text style={[styles.creditsOff, { color: theme.colors.ink }]}>Credits are off</Text>
      </>}
  </Panel>;
}

function WeeklyScreenTimePanel({ totals, loading, error, onRetry }: {
  totals: DailyScreenTimeTotal[] | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();
  const weekMinutes = totals?.reduce((total, day) => total + day.minutes, 0) ?? 0;
  const peak = Math.max(0, ...(totals?.map((day) => day.minutes) ?? []));

  return <Panel>
    <View style={styles.screenTimeHeader}>
      <View style={styles.panelHeading}>
        <Eyebrow>Screen time</Eyebrow>
        <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>This week</Text>
      </View>
      {!loading && !error && totals && <Text accessibilityLabel={`${formatCreditDuration(weekMinutes)} screen time used this week`} style={[styles.trendAmount, { color: theme.colors.ink }]}>{formatCreditDuration(weekMinutes)}</Text>}
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error || !totals ? <>
      <Body>Screen-time activity is temporarily unavailable.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : <>
      <View accessibilityLabel="Screen time used on each of the last seven days, in minutes" style={styles.chart}>
        {totals.map((day) => {
          const barHeight = day.minutes <= 0 ? 2 : Math.max(9, Math.round((day.minutes / (peak || 1)) * 84));
          return <View key={day.dateKey} style={styles.chartDay}>
            <Text style={[styles.chartValue, { color: theme.colors.inkMuted }]}>{day.minutes > 0 ? formatCompactDuration(day.minutes) : '—'}</Text>
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
    <View style={[styles.panelActions, { borderTopColor: theme.colors.border }]}>
      <SecondaryLink icon="history" title="Screen-time history" route="/credit-history" />
    </View>
  </Panel>;
}

function ByDevicePanel({ devices, loading, error, onRetry }: {
  devices: BloomDevice[] | null;
  loading: boolean;
  error: string | null;
  onRetry: () => void;
}) {
  const { theme } = useBloomTheme();
  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>By device</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Usage hours</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error || !devices ? <>
      <Body>Connected devices are temporarily unavailable.</Body>
      <Button label="Try again" variant="secondary" onPress={onRetry} />
    </> : devices.length > 0 ? <>
      <Body>Bloom does not report screen-time hours by device yet.</Body>
      {devices.slice(0, 3).map((device) => <Pressable key={device.device_id} accessibilityRole="button"
        accessibilityLabel={`${device.display_name}. Per-device screen-time totals are not available yet.`}
        onPress={() => router.push({ pathname: '/device-detail', params: { deviceId: device.device_id } })}
        style={styles.deviceRow}>
        <View style={[styles.deviceIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
          <MaterialIcons name={deviceIcon(device.platform)} size={19} color={theme.colors.inkMuted} />
        </View>
        <View style={styles.deviceCopy}>
          <Text style={[styles.deviceName, { color: theme.colors.ink }]} numberOfLines={1}>{device.display_name}</Text>
          <Text style={[styles.deviceDetail, { color: theme.colors.inkMuted }]}>Hours not reported</Text>
        </View>
        <Text style={[styles.unknownHours, { color: theme.colors.inkMuted }]}>—</Text>
      </Pressable>)}
    </> : <Body>Your devices will appear here after their first check-in.</Body>}
    <View style={[styles.panelActions, { borderTopColor: theme.colors.border }]}>
      <SecondaryLink icon="devices" title="Manage devices" route="/devices" />
    </View>
  </Panel>;
}

function InsightsPanel({ summary, loading, error }: { summary: WeeklyGoalSummary | null; loading: boolean; error: string | null }) {
  const { theme } = useBloomTheme();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const goals = summary?.goals.filter((goal) => visibleModules.includes(goal.module_id)
    && (!childProfile || assignedModules.includes(goal.module_id))) ?? [];
  const completed = goals.filter((goal) => goal.complete).length;
  const nextGoal = goals.find((goal) => !goal.complete);
  return <Panel>
    <View style={styles.panelHeading}>
      <Eyebrow>Insight</Eyebrow>
      <Text accessibilityRole="header" style={[styles.panelTitle, { color: theme.colors.ink }]}>Your week</Text>
    </View>
    {loading ? <ActivityIndicator color={theme.colors.action} /> : error ? <Body>Your weekly insight is temporarily unavailable.</Body>
      : goals.length > 0 ? <>
        <Text style={[styles.insightMetric, { color: theme.colors.ink }]}>{completed} of {goals.length}</Text>
        <Body>{nextGoal ? `${moduleName(nextGoal.module_id)} is ready for your next step.` : 'Every active weekly goal is complete.'}</Body>
      </> : <Body>Set a weekly pillar goal to see a progress insight here.</Body>}
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

function SecondaryLink({ icon, title, route }: { icon: 'history' | 'devices'; title: string; route: Href }) {
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

function moduleName(moduleId: WeeklyGoalSummary['goals'][number]['module_id']) {
  return moduleManifest.find((module) => module.id === moduleId)?.name ?? 'Your next pillar';
}

function formatCreditHours(minutes: number) {
  return (minutes / 60).toLocaleString(undefined, { maximumFractionDigits: 1 });
}

function formatCompactDuration(minutes: number) {
  return minutes >= 60 ? `${formatCreditHours(minutes)}h` : `${Math.round(minutes)}m`;
}

function formatCreditDuration(value: number) {
  const rounded = Math.round(value);
  const hours = Math.floor(rounded / 60);
  const minutes = rounded % 60;
  return hours > 0 ? `${hours}h ${minutes}m` : `${minutes} min`;
}

const styles = StyleSheet.create({
  content: { width: '100%', gap: 12, marginTop: -8 },
  hero: { minHeight: 194, overflow: 'hidden', justifyContent: 'flex-end', borderRadius: 27, padding: 20 },
  desktopHero: { minHeight: 274, padding: 30 },
  heroImage: { borderRadius: 27 },
  heroOverlay: { position: 'absolute', top: 0, right: 0, bottom: 0, left: 0, backgroundColor: 'rgba(17, 27, 53, 0.39)' },
  heroCopy: { flex: 1, justifyContent: 'flex-end', paddingEnd: 62, gap: 5 },
  heroEyebrow: { color: 'rgba(255, 255, 255, 0.96)', fontSize: 13, fontWeight: '700', letterSpacing: 1.05 },
  heroHeading: { color: '#FFFFFF', fontSize: 28, lineHeight: 34, fontWeight: '700', letterSpacing: -0.6 },
  heroBody: { color: 'rgba(255, 255, 255, 0.95)', fontSize: 15, lineHeight: 21 },
  heroAction: { position: 'absolute', right: 17, bottom: 17, width: 46, height: 46, alignItems: 'center', justifyContent: 'center', borderRadius: 23, backgroundColor: '#FFFFFF', shadowColor: '#141B35', shadowOpacity: 0.12, shadowOffset: { width: 0, height: 3 }, shadowRadius: 8, elevation: 3 },
  balanceGoalsRow: { flexDirection: 'row', alignItems: 'stretch', gap: 12 },
  balanceColumn: { flex: 1, minWidth: 0 },
  goalsColumn: { flex: 2, minWidth: 0 },
  insightColumns: { flexDirection: 'row', alignItems: 'stretch', gap: 12 },
  desktopColumn: { flex: 1, minWidth: 0 },
  panelHeading: { gap: 2 },
  panelTitle: { fontSize: 18, lineHeight: 24, fontWeight: '700', letterSpacing: -0.3 },
  todayPillarList: { gap: 8 },
  todayPillarRow: { minHeight: 24, flexDirection: 'row', alignItems: 'center', gap: 7 },
  todayPillarName: { flex: 1, minWidth: 0, fontSize: 13, lineHeight: 18, fontWeight: '600' },
  todayPillarStatus: { fontSize: 12, lineHeight: 16, fontWeight: '600' },
  balanceRow: { flexDirection: 'row', alignItems: 'baseline', gap: 3 },
  balanceAmount: { fontSize: 25, lineHeight: 32, fontWeight: '700', letterSpacing: -0.6, fontVariant: ['tabular-nums'] },
  balanceUnit: { fontSize: 14, fontWeight: '600' },
  balanceNote: { fontSize: 13, lineHeight: 19, fontWeight: '500' },
  screenTimeHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  creditsOff: { fontSize: 19, lineHeight: 26, fontWeight: '600' },
  inlineStatus: { minHeight: 56, flexDirection: 'row', alignItems: 'center', gap: 9 },
  panelActions: { gap: 3, borderTopWidth: StyleSheet.hairlineWidth, paddingTop: 8, marginTop: 3 },
  quickLink: { minHeight: 40, flexDirection: 'row', alignItems: 'center', gap: 9 },
  quickLinkText: { flex: 1, fontSize: 13, lineHeight: 19, fontWeight: '600' },
  trendAmount: { fontSize: 30, lineHeight: 37, fontWeight: '700', letterSpacing: -0.65, fontVariant: ['tabular-nums'] },
  chart: { minHeight: 126, flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', gap: 8, paddingTop: 8 },
  chartDay: { flex: 1, minWidth: 0, alignItems: 'center', gap: 5 },
  chartValue: { minHeight: 15, fontSize: 10, lineHeight: 14, fontWeight: '500', fontVariant: ['tabular-nums'] },
  chartArea: { width: '100%', maxWidth: 34, height: 84, alignItems: 'center', justifyContent: 'flex-end', overflow: 'hidden', borderTopLeftRadius: 9, borderTopRightRadius: 9 },
  chartBar: { width: '78%', borderTopLeftRadius: 8, borderTopRightRadius: 8 },
  chartLabel: { fontSize: 11, lineHeight: 15, fontWeight: '500' },
  deviceRow: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 11 },
  deviceIcon: { width: 35, height: 35, alignItems: 'center', justifyContent: 'center', borderRadius: 12 },
  deviceCopy: { flex: 1, minWidth: 0, gap: 1 },
  deviceName: { fontSize: 14, lineHeight: 20, fontWeight: '600' },
  deviceDetail: { fontSize: 12, lineHeight: 17 },
  unknownHours: { minWidth: 16, fontSize: 18, fontWeight: '600', textAlign: 'right' },
  insightMetric: { fontSize: 28, lineHeight: 34, fontWeight: '700', letterSpacing: -0.6, fontVariant: ['tabular-nums'] },
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
  pressed: { opacity: 0.78 },
});
