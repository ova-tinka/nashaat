import { useCallback, useEffect, useState, type ReactNode } from 'react';
import { Platform, View } from 'react-native';
import BloomBlocking from '../../modules/bloom-blocking/src/BloomBlockingModule';
import type { BlockingStatus, UsageAccess } from '../../modules/bloom-blocking/src/BloomBlocking.types';
import { Body, Button, ErrorText, Eyebrow, Label, Panel } from './bloom-ui';
import { formatDiagnosticFailure, loadDatabaseDiagnostics, type DatabaseDiagnostics as DatabaseDiagnosticsSnapshot, type DiagnosticRead } from '../lib/database-diagnostics';
import { isMacDesktop, macosFilter } from '../lib/macos-blocking';
import { colors } from '../theme';

type MacFilterStatus = {
  status?: string;
  domains?: string[];
  apps?: string[];
  managedDomains?: string[];
  managedApps?: string[];
  appEnabled?: boolean;
  appConfigured?: boolean;
  appService?: string;
  websiteUsageAvailable?: boolean;
  websitePolicyBrokerStatus?: string;
  accessibilityTrusted?: boolean;
  browserName?: string;
  browserAddressStatus?: string;
  browserAutomationStatus?: string;
  supportedBrowsers?: string[];
  browserHideFailed?: boolean;
  appHideFailed?: boolean;
  managedRuleAccountId?: string;
};

type DeviceDiagnostics = {
  platform: string;
  blocking?: DiagnosticRead<BlockingStatus>;
  usage?: DiagnosticRead<UsageAccess | null>;
  websiteFilter?: DiagnosticRead<MacFilterStatus>;
  applicationFilter?: DiagnosticRead<MacFilterStatus>;
  managedRulesMatchAccount?: boolean;
  unavailable?: string;
};

async function readLocal<T>(read: () => T | Promise<T>): Promise<DiagnosticRead<T>> {
  try {
    return { status: 'ok', value: await read() };
  } catch (error) {
    return { status: 'error', ...formatDiagnosticFailure(error) };
  }
}

async function loadDeviceDiagnostics(userId: string): Promise<DeviceDiagnostics> {
  if (isMacDesktop()) {
    const [websiteFilter, applicationFilter, usage] = await Promise.all([
      readLocal(async () => await macosFilter('status') as MacFilterStatus),
      readLocal(async () => await macosFilter('appStatus') as MacFilterStatus),
      readLocal(async () => (await macosFilter('getUsageAccess')).usage ?? null),
    ]);
    return {
      platform: 'macOS', websiteFilter, applicationFilter, usage,
      managedRulesMatchAccount: applicationFilter.status === 'ok'
        ? applicationFilter.value?.managedRuleAccountId === userId
        : undefined,
    };
  }
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    const [blocking, usage] = await Promise.all([
      readLocal(() => BloomBlocking.getStatus()),
      readLocal(() => BloomBlocking.getUsageAccess()),
    ]);
    return { platform: Platform.OS, blocking, usage };
  }
  return { platform: 'Web preview', unavailable: 'Native enforcement status is available only in a signed app build.' };
}

function Section<T>({ title, result, render }: {
  title: string;
  result: DiagnosticRead<T> | undefined;
  render: (value: T | null) => ReactNode;
}) {
  return <View style={{ gap: 7 }}>
    <Label>{title}</Label>
    {!result ? <Body>Waiting for refresh.</Body> : result.status === 'error'
      ? <ErrorText>Read failed{result.code ? ` (${result.code})` : ''}: {result.message}</ErrorText>
      : render(result.value)}
  </View>;
}

function timestamp(value: string | null | undefined) {
  if (!value) return '—';
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString();
}

function duration(milliseconds: number | null | undefined) {
  if (milliseconds == null || !Number.isFinite(Number(milliseconds))) return '—';
  const minutes = Number(milliseconds) / 60_000;
  return `${minutes.toFixed(2)} min`;
}

export function DatabaseDiagnostics({ userId }: { userId: string }) {
  const [database, setDatabase] = useState<DatabaseDiagnosticsSnapshot | null>(null);
  const [device, setDevice] = useState<DeviceDiagnostics | null>(null);
  const [loading, setLoading] = useState(false);
  const [loadError, setLoadError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    const [databaseResult, deviceResult] = await Promise.allSettled([
      loadDatabaseDiagnostics(userId),
      loadDeviceDiagnostics(userId),
    ]);
    if (databaseResult.status === 'fulfilled') setDatabase(databaseResult.value);
    else setLoadError(formatDiagnosticFailure(databaseResult.reason).message);
    if (deviceResult.status === 'fulfilled') setDevice(deviceResult.value);
    else setDevice({ platform: Platform.OS, unavailable: formatDiagnosticFailure(deviceResult.reason).message });
    setLoading(false);
  }, [userId]);

  // Initial read is an external I/O effect; the refresh button calls the same function directly.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void refresh(); }, [refresh]);

  const report = (result: DiagnosticRead<unknown> | undefined) => result?.status ?? 'pending';

  return <Panel>
    <Eyebrow>Database diagnostics</Eyebrow>
    <Body>Read-only snapshot for this signed-in account. Database reads still use Supabase row-level security. Native enforcement is reported separately; saved rules alone do not prove that the operating system applied them.</Body>
    <Button label="Refresh diagnostics" secondary onPress={() => void refresh()} busy={loading} />
    {loadError && <ErrorText>Database diagnostic request failed: {loadError}</ErrorText>}
    {database && <Body>Database queries completed: {timestamp(database.capturedAt)}</Body>}

    <Section title={`Settings · ${report(database?.settings)}`} result={database?.settings} render={(value) => value
      ? <Body>Credits {value.credits_enabled ? 'enabled' : 'disabled'} · Mode {value.credit_mode} · Strategy {value.earning_strategy} · Time zone {value.credit_timezone} · Updated {timestamp(value.updated_at)}. Earning rates: reps {value.reps_per_award ?? 'unset'}/{value.rep_award_minutes ?? 'unset'} min, exercise {value.exercise_minutes_per_award ?? 'unset'} min, time {value.time_award_minutes ?? 'unset'} min, daily cap {value.super_daily_cap_minutes ?? 'unset'} min. Weekly targets: {value.weekly_workout_target ?? 'unset'} workouts / {value.weekly_credit_target_minutes ?? 'unset'} credit minutes.</Body>
      : <Body>No settings row exists for this account.</Body>} />

    <Section title={`Available credit · ${report(database?.balance)}`} result={database?.balance} render={(value) => value == null
      ? <Body>The balance query returned no value.</Body>
      : <Body>{Number(value).toFixed(2)} minutes, as calculated by the database balance function.</Body>} />

    <Section title={`Credit ledger · ${report(database?.ledger)}`} result={database?.ledger} render={(rows) => rows?.length
      ? <View style={{ gap: 5 }}>{rows.map((row, index) => <Body key={`${row.created_at}-${index}`}>{row.entry_type}: {row.amount_minutes > 0 ? '+' : ''}{row.amount_minutes} min · expires {timestamp(row.expires_at)} · recorded {timestamp(row.created_at)}</Body>)}</View>
      : <Body>No ledger entries were returned (latest 20 checked).</Body>} />

    <Section title={`Timed credit sessions · ${report(database?.creditSessions)}`} result={database?.creditSessions} render={(rows) => rows?.length
      ? <View style={{ gap: 5 }}>{rows.map((row, index) => <Body key={`${row.started_at}-${index}`}>{row.mode} · started {timestamp(row.started_at)} · ends {timestamp(row.ends_at)} · expires {timestamp(row.expires_at)} · {row.settled_at ? `settled ${timestamp(row.settled_at)}` : 'not settled'}</Body>)}</View>
      : <Body>No timed credit sessions were returned (latest 10 checked).</Body>} />

    <Section title={`Easy reservations · ${report(database?.usageReservations)}`} result={database?.usageReservations} render={(rows) => rows?.length
      ? <View style={{ gap: 5 }}>{rows.map((row, index) => <Body key={`${row.started_at}-${index}`}>Reservation {row.id.slice(0, 8)} · requested {duration(row.requested_ms)} · reserved {duration(row.reserved_ms)} · used {duration(row.used_ms)} · started {timestamp(row.started_at)} · expires {timestamp(row.expires_at)} · {row.settled_at ? `settled ${timestamp(row.settled_at)}` : row.abandoned_at ? `abandoned ${timestamp(row.abandoned_at)}` : 'open / unsettled'}</Body>)}</View>
      : <Body>No Easy reservations were returned (latest 10 checked).</Body>} />

    <Section title={`Blocking rules · ${report(database?.blockingRules)}`} result={database?.blockingRules} render={(rows) => rows?.length
      ? <View style={{ gap: 5 }}>{rows.map((row, index) => <Body key={`${row.platform}-${row.target_type}-${row.target_identifier}-${index}`}>{row.enabled ? 'Enabled' : 'Disabled'} · {row.platform} {row.target_type}: {row.target_identifier} · added {timestamp(row.created_at)}</Body>)}{rows.length === 100 && <Body>Showing the latest 100 rules.</Body>}</View>
      : <Body>No rules were returned (up to 100 checked across platforms).</Body>} />

    <View style={{ height: 1, backgroundColor: colors.border }} />
    <Eyebrow>Device enforcement · {device?.platform ?? 'pending'}</Eyebrow>
    {device?.unavailable && <Body>{device.unavailable}</Body>}
    {device?.blocking && <Section title="Blocking service" result={device.blocking} render={(value) => value
      ? <Body>Supported {String(value.supported)} · authorized {String(value.authorized)} · active {String(value.active)} · apps {value.appCount} · websites {value.websiteCount} · service {value.serviceHealth ?? 'unknown'}{value.supportedBrowsers?.length ? ` · browsers ${value.supportedBrowsers.join(', ')}` : ''}</Body>
      : <Body>No native status was returned.</Body>} />}
    {device?.websiteFilter && <Section title="macOS website filter" result={device.websiteFilter} render={(value) => value
      ? <Body>Filter state {value.status ?? 'unknown'} · configured websites [{value.domains?.join(', ') ?? ''}] · managed rule websites [{value.managedDomains?.join(', ') ?? ''}].</Body>
      : <Body>No native status was returned.</Body>} />}
    {device?.applicationFilter && <Section title="macOS app filter" result={device.applicationFilter} render={(value) => value
      ? <Body>Configured apps [{value.apps?.join(', ') ?? ''}] · managed rule apps [{value.managedApps?.join(', ') ?? ''}] · app blocking enabled {value.appEnabled === undefined ? 'unknown' : String(value.appEnabled)} · configured {value.appConfigured === undefined ? 'unknown' : String(value.appConfigured)} · monitor {value.appService ?? 'unknown'} · Accessibility trusted {value.accessibilityTrusted === undefined ? 'unknown' : String(value.accessibilityTrusted)} · app hide failure {value.appHideFailed === undefined ? 'unknown' : String(value.appHideFailed)} · website usage available {value.websiteUsageAvailable === undefined ? 'unknown' : String(value.websiteUsageAvailable)} · policy broker {value.websitePolicyBrokerStatus ?? 'unknown'} · browser {value.browserName ?? 'unknown'} · address source {value.browserAddressStatus ?? 'unknown'} · automation {value.browserAutomationStatus ?? 'unknown'} · supported browsers {value.supportedBrowsers?.join(', ') ?? 'unknown'} · browser hide failure {value.browserHideFailed === undefined ? 'unknown' : String(value.browserHideFailed)} · native managed-rule account matches signed-in account {device.managedRulesMatchAccount === undefined ? 'unknown' : String(device.managedRulesMatchAccount)}</Body>
      : <Body>No native status was returned.</Body>} />}
    {device?.usage && <Section title="Local access tracker" result={device.usage} render={(value) => value
      ? <Body>Session {value.sessionId.slice(0, 8)} · {value.closed ? 'closed' : 'open'} · tracking {String(value.tracking)} · budget {duration(value.budgetMillis)} · used {duration(value.usedMillis)} · remaining {duration(value.remainingMillis)}</Body>
      : <Body>No active local access session.</Body>} />}
  </Panel>;
}
