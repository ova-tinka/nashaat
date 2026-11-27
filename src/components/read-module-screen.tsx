import { getAppLocale } from '../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { randomUUID } from 'expo-crypto';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, ImageBackground, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { router, useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import {
  Body, Button, ErrorText, Eyebrow, Field, Heading, Label, LocalizedText as Text, Panel, ProgressBar, Screen, sharedStyles, useIsDesktopColumns, useIsDesktopLayout,
} from './bloom-ui';
import { GrowthDocumentLibraryPanel } from './growth-document-panels';
import { GrowthRecordPanel, ReadingDiscoveryPanel } from './growth-feature-panels';
import { WeeklyPillarPlanner } from './weekly-pillar-planner';
import {
  cancelGrowthSession, createGrowthItem, finishGrowthSession, formatElapsed, getReadingStatus, GrowthDataQueryError, loadGrowthDocuments, loadGrowthModule,
  loadGrowthRewards, loadReadSessionsSince, loadWeeklyPillarGoals, startGrowthSession, updateGrowthItem,
  updateGrowthReadingDetails, type GrowthDocument, type GrowthItem, type GrowthRecord, type GrowthRewardEvent,
  type GrowthRewardRule, type GrowthSession, type ReadingKind, type ReadingStatus, type WeeklyPillarGoal,
} from '../lib/growth-modules';
import { getCurrentDeviceIdentity } from '../lib/devices';
import { flushOfflineActivitiesForProfile, getPendingOfflineCount, queueOfflineActivityForProfile } from '../lib/offline-sync-service';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { useBloomTheme } from '../lib/theme-context';
import { dateKeyInTimeZone } from '../lib/date-utils';
import { bloomPillarCollectionImages, bloomPillarImages } from '../assets/bloom-images';

type ReadSection = 'today' | 'library' | 'discover' | 'progress' | 'item' | 'add' | 'edit' | 'session' | 'session-complete';
type LibraryFilter = 'want_to_read' | 'currently_reading' | 'finished';
type ProgressPeriod = 'day' | 'week' | 'month';
type ItemTab = 'overview' | 'sessions' | 'notes' | 'files';
type AddReturnSection = 'today' | 'library';
const localTabs: { id: ReadSection; label: string }[] = [
  { id: 'today', label: 'Today' }, { id: 'library', label: 'Library' },
  { id: 'discover', label: 'Discover' }, { id: 'progress', label: 'Progress' },
];

function routeFor(section: ReadSection, itemId?: string, editPages = false): Href {
  if (section === 'today') return '/read';
  return { pathname: '/apps/read/[section]', params: { section, ...(itemId ? { itemId } : {}), ...(editPages ? { editPages: '1' } : {}) } };
}

function addRouteFor(returnTo: AddReturnSection): Href {
  return { pathname: '/apps/read/[section]', params: { section: 'add', returnTo } };
}

function statusLabel(status: ReadingStatus) {
  if (status === 'currently_reading') return 'Currently reading';
  if (status === 'finished') return 'Finished';
  return 'Want to read';
}

function searchItems(items: GrowthItem[], query: string) {
  const value = query.trim().toLocaleLowerCase();
  if (!value) return items;
  return items.filter((item) => [item.title, item.author, item.genre, item.notes].some((part) => part.toLocaleLowerCase().includes(value)));
}

function periodLabel(period: ProgressPeriod) {
  if (period === 'day') return 'Today';
  if (period === 'month') return 'This month';
  return 'This week';
}

function kindLabel(kind: ReadingKind | null) {
  return kind === 'article' ? 'Article' : 'Book';
}

function formatMinutes(seconds: number) {
  if (seconds > 0 && seconds < 60) return Math.floor(seconds) + 's';
  const minutes = Math.floor(Math.max(0, seconds) / 60);
  const hours = Math.floor(minutes / 60);
  return hours ? hours + 'h ' + (minutes % 60 ? (minutes % 60) + 'm' : '') : minutes + 'm';
}

function startOfWeekKey(dateKey: string) {
  const date = new Date(dateKey + 'T12:00:00Z');
  date.setUTCDate(date.getUTCDate() - date.getUTCDay());
  return date.toISOString().slice(0, 10);
}

function addDateDays(dateKey: string, amount: number) {
  const date = new Date(dateKey + 'T12:00:00Z');
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
}

function formatClock(value: string) {
  return new Date(value).toLocaleTimeString(getAppLocale(), { hour: 'numeric', minute: '2-digit' });
}

export function ReadModuleScreen({ sectionId }: { sectionId?: string }) {
  const params = useLocalSearchParams<{ itemId?: string | string[]; editPages?: string | string[]; returnTo?: string | string[]; durationSeconds?: string | string[]; rewardStatus?: string | string[]; rewardMinutes?: string | string[] }>();
  const routeItemId = typeof params.itemId === 'string' ? params.itemId : undefined;
  const completionSeconds = typeof params.durationSeconds === 'string' ? Number(params.durationSeconds) : 0;
  const completionRewardStatus = typeof params.rewardStatus === 'string' ? params.rewardStatus : '';
  const completionRewardMinutes = typeof params.rewardMinutes === 'string' ? Number(params.rewardMinutes) : 0;
  const routeSection = sectionId === 'notes' ? 'item' : sectionId === 'reader' ? 'library' : sectionId;
  const section: ReadSection = (localTabs.some((tab) => tab.id === routeSection) || ['item', 'add', 'edit', 'session', 'session-complete'].includes(routeSection ?? '')
    ? routeSection : 'today') as ReadSection;
  const { profileId } = useAuth();
  const { creditSettings } = useBloom();
  const { theme } = useBloomTheme();
  const desktop = useIsDesktopLayout();
  const desktopColumns = useIsDesktopColumns();
  const accent = theme.modules.read;
  const timeZone = creditSettings?.credit_timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone ?? 'UTC';
  const [items, setItems] = useState<GrowthItem[]>([]);
  const [sessions, setSessions] = useState<GrowthSession[]>([]);
  const [records, setRecords] = useState<GrowthRecord[]>([]);
  const [documents, setDocuments] = useState<GrowthDocument[]>([]);
  const [reportSessions, setReportSessions] = useState<GrowthSession[]>([]);
  const [rewardRules, setRewardRules] = useState<GrowthRewardRule[]>([]);
  const [rewardEvents, setRewardEvents] = useState<GrowthRewardEvent[]>([]);
  const [goals, setGoals] = useState<WeeklyPillarGoal[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [pendingOfflineCount, setPendingOfflineCount] = useState(0);
  const [tick, setTick] = useState(0);
  const [libraryFilter, setLibraryFilter] = useState<LibraryFilter>('currently_reading');
  const [libraryMode, setLibraryMode] = useState<'list' | 'documents'>(sectionId === 'reader' ? 'documents' : 'list');
  const [librarySearch, setLibrarySearch] = useState('');
  const [progressPeriod, setProgressPeriod] = useState<ProgressPeriod>('week');
  const [itemTab, setItemTab] = useState<ItemTab>('overview');
  const [confirmCancel, setConfirmCancel] = useState(false);
  const requestVersion = useRef(0);
  const pendingStart = useRef<{ itemId: string; requestId: string } | null>(null);

  const refresh = useCallback(async () => {
    const version = ++requestVersion.current;
    if (!profileId) {
      setItems([]); setSessions([]); setRecords([]); setDocuments([]); setLoading(false);
      setError('Your Bloom profile is unavailable. Refresh your profile and try again.');
      return;
    }
    setLoading(true);
    setError(null);
    try {
      await flushOfflineActivitiesForProfile(profileId).catch(() => undefined);
      setPendingOfflineCount(await getPendingOfflineCount(profileId).catch(() => 0));
      const rangeStart = new Date(Date.now() - 45 * 24 * 60 * 60 * 1000).toISOString();
      const [moduleData, nextDocuments, rewards, nextGoals, nextReportSessions] = await Promise.all([
        loadGrowthModule(profileId, 'read'),
        loadGrowthDocuments('read'),
        loadGrowthRewards(profileId),
        loadWeeklyPillarGoals(),
        loadReadSessionsSince(profileId, rangeStart),
      ]);
      if (version !== requestVersion.current) return;
      setItems(moduleData.items);
      setSessions(moduleData.sessions);
      setRecords(moduleData.records);
      setDocuments(nextDocuments);
      setRewardRules(rewards.rules);
      setRewardEvents(rewards.events);
      setGoals(nextGoals);
      setReportSessions(nextReportSessions);
      setTick(Date.now());
    } catch (cause) {
      if (version === requestVersion.current) {
        const diagnostic = __DEV__ && cause instanceof GrowthDataQueryError
          ? ` [${cause.resource}${cause.code ? ` · ${cause.code}` : ''}]` : '';
        setError(`Read data isn’t available right now. Retry when your connection is back.${diagnostic}`);
      }
    } finally {
      if (version === requestVersion.current) setLoading(false);
    }
  }, [profileId]);

  useFocusEffect(useCallback(() => {
    void refresh();
    return () => { requestVersion.current += 1; };
  }, [refresh]));

  const activeSession = useMemo(() => sessions.find((session) => session.status === 'in_progress') ?? null, [sessions]);
  const activeSessionItem = activeSession ? items.find((item) => item.id === activeSession.item_id) ?? null : null;
  useEffect(() => {
    if (!activeSession) return undefined;
    const timer = setInterval(() => setTick(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [activeSession]);

  const readingItems = items.filter((item) => item.item_type === 'reading');
  const currentlyReading = readingItems.filter((item) => item.state === 'active' && getReadingStatus(item) === 'currently_reading');
  const wantToRead = readingItems.filter((item) => item.state === 'active' && getReadingStatus(item) === 'want_to_read');
  const finished = readingItems.filter((item) => item.state === 'completed' || getReadingStatus(item) === 'finished');
  const todayKey = dateKeyInTimeZone(tick, timeZone);
  const weekStart = startOfWeekKey(todayKey);
  const todaySessions = reportSessions.filter((session) => session.status === 'completed' && session.completed_at
    && dateKeyInTimeZone(Date.parse(session.completed_at), timeZone) === todayKey);
  const weekSessions = reportSessions.filter((session) => session.status === 'completed' && session.completed_at
    && dateKeyInTimeZone(Date.parse(session.completed_at), timeZone) >= weekStart
    && dateKeyInTimeZone(Date.parse(session.completed_at), timeZone) <= todayKey);
  const todaySeconds = todaySessions.reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0);
  const weekGoal = goals.find((goal) => goal.module_id === 'read');
  const recentPrivateRecord = records.find((record) => record.item_id && ['reading_note', 'reading_annotation', 'reflection'].includes(record.kind)
    && record.title !== 'Reading interests');

  async function startSession(item: GrowthItem) {
    if (!profileId) return;
    setSaving(true); setError(null); setNotice(null);
    try {
      if (activeSession && activeSession.item_id !== item.id) throw new Error('Finish or cancel the active reading session first.');
      if (activeSession?.item_id === item.id) {
        router.push(routeFor('session'));
        return;
      }
      if (pendingStart.current?.itemId !== item.id) pendingStart.current = { itemId: item.id, requestId: randomUUID() };
      const status = getReadingStatus(item);
      await updateGrowthReadingDetails(item.id, {
        author: item.author, genre: item.genre, pageCount: item.page_count,
        currentPage: status === 'finished' && item.page_count ? 0 : item.current_page,
        status: 'currently_reading', readingKind: item.reading_kind ?? 'book',
      });
      const device = await getCurrentDeviceIdentity(profileId);
      await startGrowthSession('read', item.id, device, pendingStart.current.requestId);
      pendingStart.current = null;
      await refresh();
      router.replace(routeFor('session'));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not start the session. Check your connection and retry.');
    } finally { setSaving(false); }
  }

  async function endSession(cancel: boolean) {
    if (!activeSession) return;
    setSaving(true); setError(null); setNotice(null);
    try {
      if (cancel) {
        await cancelGrowthSession(activeSession.id);
        setConfirmCancel(false);
        await refresh();
        router.replace('/read');
        return;
      }
      const result = await finishGrowthSession(activeSession.id);
      let rewardStatus = 'unavailable';
      let rewardMinutes = 0;
      if (profileId) {
        try {
          const rewards = await loadGrowthRewards(profileId);
          const event = rewards.events.find((entry) => entry.source_type === 'session' && entry.source_id === activeSession.id);
          const rule = rewards.rules.find((entry) => entry.module_id === 'read');
          if (event) { rewardStatus = event.status; rewardMinutes = event.awarded_minutes; }
          else rewardStatus = rule?.enabled ? 'unavailable' : 'not_eligible';
        } catch { /* The server-confirmed session remains valid if wallet status cannot be read. */ }
      }
      await refresh();
      router.replace({ pathname: '/apps/read/[section]', params: {
        section: 'session-complete', itemId: activeSession.item_id,
        durationSeconds: String(result.durationSeconds), rewardStatus, rewardMinutes: String(rewardMinutes),
      } });
    } catch {
      if (cancel) {
        if (profileId) {
          try {
            const latest = await loadGrowthModule(profileId, 'read');
            const confirmed = latest.sessions.find((entry) => entry.id === activeSession.id);
            if (confirmed?.status === 'cancelled') {
              await refresh();
              router.replace('/read');
              return;
            }
          } catch { /* If the recovery read is offline, leave the cancellation unconfirmed. */ }
        }
        setError('Bloom could not confirm the cancellation. Reconnect and retry; the session outcome is still unconfirmed.');
        return;
      }
      if (profileId) {
        try {
          const latest = await loadGrowthModule(profileId, 'read');
          const confirmed = latest.sessions.find((entry) => entry.id === activeSession.id);
          if (confirmed?.status === 'completed' && confirmed.duration_seconds !== null) {
            await refresh();
            router.replace({ pathname: '/apps/read/[section]', params: {
              section: 'session-complete', itemId: activeSession.item_id,
              durationSeconds: String(confirmed.duration_seconds), rewardStatus: 'unavailable', rewardMinutes: '0',
            } });
            return;
          }
        } catch {
          try {
            const device = await getCurrentDeviceIdentity(profileId);
            const durationSeconds = Math.max(1, Math.min(43200, Math.floor((Date.now() - Date.parse(activeSession.started_at)) / 1000)));
            await queueOfflineActivityForProfile(profileId, {
              kind: 'read_session',
              moduleId: 'read',
              itemId: activeSession.item_id,
              itemTitle: activeSessionItem?.title ?? 'Reading session',
              sourceDeviceId: device.deviceId,
              sourceDeviceName: device.displayName,
              startedAt: activeSession.started_at,
              completedAt: new Date().toISOString(),
              durationSeconds,
            });
            setPendingOfflineCount(await getPendingOfflineCount(profileId));
            setNotice('Reading session saved offline as Pending. It will sync as self-reported history when connected without automatic time-based credit.');
            return;
          } catch { /* Fall through if local persistence also failed. */ }
        }
      }
      setError('Bloom could not save the session yet. Reconnect and retry. It will count as complete after it is saved.');
    } finally { setSaving(false); }
  }

  async function changeStatus(item: GrowthItem, status: ReadingStatus) {
    setSaving(true); setError(null); setNotice(null);
    try {
      const currentPage = status === 'finished' && item.page_count
        ? item.page_count
        : status === 'currently_reading' && getReadingStatus(item) === 'finished'
          ? (item.page_count ? 0 : null)
          : item.current_page;
      await updateGrowthReadingDetails(item.id, {
        author: item.author, genre: item.genre, pageCount: item.page_count, currentPage,
        status, readingKind: item.reading_kind ?? 'book',
      });
      setNotice(status === 'finished' ? 'Marked finished. Your notes and session history stay with this item.' : 'Reading status updated.');
      await refresh();
    } catch { setError('Could not update this reading item. Check your connection and retry.'); }
    finally { setSaving(false); }
  }

  async function savePageProgress(item: GrowthItem, pageCountValue: string, currentPageValue: string): Promise<boolean> {
    const pageCount = Number(pageCountValue);
    const currentPage = Number(currentPageValue);
    if (!Number.isInteger(pageCount) || pageCount < 1 || pageCount > 100000
      || !Number.isInteger(currentPage) || currentPage < 0 || currentPage > pageCount) {
      setError('Enter a current page from 0 through the total page count.');
      return false;
    }
    setSaving(true); setError(null); setNotice(null);
    try {
      await updateGrowthReadingDetails(item.id, {
        author: item.author, genre: item.genre, pageCount, currentPage, status: 'currently_reading',
        readingKind: item.reading_kind ?? 'book',
      });
      setNotice('Page position saved. Page progress is separate from timed reading activity.');
      await refresh();
      return true;
    } catch { setError('Could not save these pages. Check the page numbers and retry.'); }
    finally { setSaving(false); }
    return false;
  }

  async function saveItem(item: GrowthItem | null, details: {
    title: string; kind: ReadingKind; author: string; genre: string; pageCount: number | null; notes: string; status: ReadingStatus;
  }, requestId: string): Promise<boolean> {
    if (!profileId) return false;
    setSaving(true); setError(null); setNotice(null);
    try {
      let itemId = item?.id;
      if (item) {
        await updateGrowthItem(item, { title: details.title, notes: details.notes });
      } else {
        itemId = await createGrowthItem({ moduleId: 'read', title: details.title, notes: details.notes, requestId });
      }
      await updateGrowthReadingDetails(itemId!, {
        author: details.author, genre: details.genre, pageCount: details.pageCount,
        currentPage: details.status === 'finished'
          ? details.pageCount
          : item && getReadingStatus(item) === 'finished'
            ? (details.pageCount ? 0 : null)
            : item && item.page_count === details.pageCount
              ? item.current_page
              : details.pageCount ? (item?.current_page ?? 0) : null,
        status: details.status, readingKind: details.kind,
      });
      await refresh();
      router.replace(routeFor(item ? 'item' : 'library', itemId));
      return true;
    } catch {
      setError('Could not save this entry. It is still in the form; check your connection and try again.');
      return false;
    } finally { setSaving(false); }
  }

  const currentItem = routeItemId ? readingItems.find((item) => item.id === routeItemId) ?? null
    : sectionId === 'notes' ? currentlyReading[0] ?? readingItems[0] ?? null : null;
  const selectedReportSessions = reportSessions.filter((session) => {
    if (session.status !== 'completed' || !session.completed_at) return false;
    const key = dateKeyInTimeZone(Date.parse(session.completed_at), timeZone);
    if (progressPeriod === 'day') return key === todayKey;
    if (progressPeriod === 'week') return key >= weekStart && key <= todayKey;
    const monthStart = todayKey.slice(0, 7) + '-01';
    return key >= monthStart && key <= todayKey;
  });
  const selectedReadItem = currentItem;

  function selectSection(next: ReadSection) {
    setError(null); setNotice(null);
    router.replace(routeFor(next));
  }

  return <Screen safeAreaTop={['item', 'add', 'edit', 'session', 'session-complete'].includes(section)}>
    {!desktop && !['item', 'add', 'edit', 'session', 'session-complete'].includes(section) && <>
      <View style={styles.header}>
        <View style={[styles.headerIcon, { backgroundColor: accent.surface }]}><MaterialIcons name="menu-book" size={23} color={accent.deep} /></View>
        <View style={sharedStyles.grow}><Eyebrow>Bloom · Read</Eyebrow><Heading>Read</Heading><Text style={[styles.tagline, { color: theme.colors.inkMuted }]}>Read. Reflect. Grow.</Text></View>
        {section === 'library' && <Pressable accessibilityRole="button" accessibilityLabel="Add a book or article" onPress={() => router.push(addRouteFor('library'))} style={[styles.iconButton, { backgroundColor: accent.surface }]}>
          <MaterialIcons name="add" size={23} color={accent.deep} />
        </Pressable>}
      </View>
      <LocalNavigation selected={localTabs.some((tab) => tab.id === section) ? section : 'library'} onSelect={selectSection} />
    </>}

    {loading && <View style={styles.loading}><ActivityIndicator color={accent.deep} /></View>}
    {!loading && error && section !== 'session' && <Panel><ErrorText>{error}</ErrorText><Body>Your saved reading records remain private and available when the connection returns.</Body><Button label="Try again" variant="secondary" onPress={() => void refresh()} /></Panel>}
    {!loading && notice && section !== 'session-complete' && <View style={[styles.notice, { backgroundColor: accent.surface }]}><MaterialIcons name="check-circle-outline" size={19} color={accent.deep} /><Text style={[styles.noticeText, { color: accent.deep }]}>{notice}</Text></View>}
    {!loading && pendingOfflineCount > 0 && <Panel>
      <Label>Pending offline activity · {pendingOfflineCount}</Label>
      <Body>Saved on this device and waiting for connection. Pending records never unlock Screen Time.</Body>
      {profileId && <Button label="Sync pending activity" variant="secondary" onPress={() => void flushOfflineActivitiesForProfile(profileId).then(async () => { setPendingOfflineCount(await getPendingOfflineCount(profileId)); await refresh(); }).catch(() => undefined)} />}
    </Panel>}

    {!loading && !error && section === 'today' && <>
      <ImageBackground source={bloomPillarCollectionImages.read} resizeMode="cover" imageStyle={styles.heroImage} style={[styles.hero, desktop && styles.heroDesktop]}>
        <View style={styles.heroShade} />
        <View style={styles.heroCopy}>
          <Text style={styles.heroEyebrow}>A QUIET MOMENT FOR IDEAS</Text>
          <Text style={styles.heroTitle}>A few pages can change your perspective.</Text>
          <Text style={styles.heroSubtitle}>Make room for ideas worth remembering.</Text>
        </View>
      </ImageBackground>
      {activeSession && <Panel>
        <View style={styles.row}>
          <View style={[styles.smallIcon, { backgroundColor: accent.surface }]}><MaterialIcons name="timer" size={20} color={accent.deep} /></View>
          <View style={sharedStyles.grow}><Eyebrow>Reading session in progress</Eyebrow><Label>{activeSessionItem?.title ?? 'Reading item'}</Label></View>
          <Text style={[styles.timerSmall, { color: accent.deep }]}>{elapsedFromStart(activeSession.started_at, tick)}</Text>
        </View>
        <Body>Your timer starts when you begin reading. Bloom saves the total time when you finish.</Body>
        <Button label="Return to session" onPress={() => router.push(routeFor('session'))} />
      </Panel>}
      <View style={[styles.todayColumns, desktopColumns && styles.todayColumnsDesktop]}>
        <View style={sharedStyles.grow}>
          <SectionTitle eyebrow="Pick up where you left off" title="Continue reading" />
          {currentlyReading[0] ? <ContinueCard item={currentlyReading[0]} saving={saving}
            onOpen={() => router.push(routeFor('item', currentlyReading[0].id))}
            onStart={() => void startSession(currentlyReading[0])}
            onProgress={() => router.push(routeFor('item', currentlyReading[0].id, true))} />
            : <Panel>
              <Eyebrow>Your next read</Eyebrow>
              <Label>{wantToRead[0]?.title ?? 'Choose something for your shelf'}</Label>
              <Body>{wantToRead[0] ? 'Start a timed session when you are ready. Page position is optional.' : 'Add a book or article to keep your reading plans together.'}</Body>
              <Button label={wantToRead[0] ? 'Start reading session' : 'Add your first book'} onPress={() => wantToRead[0] ? void startSession(wantToRead[0]) : router.push(addRouteFor('today'))} busy={saving} />
              {wantToRead[0] && <Button label="View reading list" variant="tertiary" onPress={() => router.push(routeFor('item', wantToRead[0].id))} />}
            </Panel>}
        </View>
        <Panel>
          <Eyebrow>Today, from completed sessions</Eyebrow>
          <Text style={[styles.metric, { color: theme.colors.ink }]}>{formatMinutes(todaySeconds)}</Text>
          <Body>Recorded reading time</Body>
          <View style={[styles.metricDivider, { borderColor: theme.colors.border }]} />
          <View style={styles.metricPair}>
            <View><Label>{weekSessions.length}</Label><Body>sessions this week</Body></View>
            <View><Label>{currentlyReading.length}</Label><Body>currently reading</Body></View>
          </View>
          {weekGoal && <View style={styles.goalBlock}>
            <View style={styles.row}><View style={sharedStyles.grow}><Eyebrow>Weekly goal</Eyebrow><Label>{Math.min(weekSessions.length, weekGoal.target_count)} of {weekGoal.target_count} sessions</Label></View><MaterialIcons name="auto-awesome" size={19} color={accent.deep} /></View>
            <ProgressBar value={Math.min(100, weekSessions.length / Math.max(1, weekGoal.target_count) * 100)} label="Weekly reading sessions" color={accent.deep} />
          </View>}
        </Panel>
      </View>
      <View style={styles.sectionHeaderRow}>
        <SectionTitle eyebrow="On your shelf" title="Currently reading" />
        <Button label="Open Library" variant="tertiary" onPress={() => selectSection('library')} />
      </View>
      {currentlyReading.length ? <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={[styles.shelf, desktop && styles.shelfDesktop]}>
        {currentlyReading.slice(0, 6).map((item) => <ReadingShelfCard key={item.id} item={item} onPress={() => router.push(routeFor('item', item.id))} />)}
      </ScrollView> : <Panel><Body>No current reading item. Choose one from Want to read or add a new title.</Body><Button label={wantToRead.length ? 'Choose from Want to read' : 'Add a reading item'} variant="secondary" onPress={() => selectSection('library')} /></Panel>}
      <SessionActivityChart sessions={weekSessions} period="week" timeZone={timeZone} todayKey={todayKey} />
      {recentPrivateRecord && <Pressable accessibilityRole="button" onPress={() => { setItemTab('notes'); router.push(routeFor('item', recentPrivateRecord.item_id ?? undefined)); }}>
        <Panel><Eyebrow>From your private notebook</Eyebrow><Label>{recentPrivateRecord.title || 'A recent reflection'}</Label><Text numberOfLines={2} style={[styles.preview, { color: theme.colors.inkMuted }]}>{recentPrivateRecord.body}</Text><Text style={[styles.inlineLink, { color: accent.deep }]}>Reopen reflection</Text></Panel>
      </Pressable>}
      {rewardRules.some((rule) => rule.module_id === 'read') && <RewardSummary
        rule={rewardRules.find((rule) => rule.module_id === 'read')!}
        event={rewardEvents.find((entry) => entry.module_id === 'read') ?? null} />}
    </>}

    {!loading && !error && section === 'library' && <>
      <SectionTitle eyebrow="Your personal collection" title="My Library" subtitle="Books and articles to read, reading now, and finished." />
      <View style={[styles.switchRow, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
        {([{ id: 'list', label: 'Reading List' }, { id: 'documents', label: 'Documents' }] as const).map((entry) =>
          <Segment key={entry.id} label={entry.label} selected={libraryMode === entry.id} onPress={() => setLibraryMode(entry.id)} />)}
      </View>
      {libraryMode === 'list' ? <>
        <Field label="Search your reading list" value={librarySearch} onChangeText={setLibrarySearch} placeholder="Title, author, or topic" />
        <View style={styles.filterRow}>
          {([{ id: 'want_to_read', label: 'Want to read', count: wantToRead.length }, { id: 'currently_reading', label: 'Currently reading', count: currentlyReading.length }, { id: 'finished', label: 'Finished', count: finished.length }] as const).map((entry) =>
            <Segment key={entry.id} label={entry.label + ' · ' + entry.count} selected={libraryFilter === entry.id} onPress={() => setLibraryFilter(entry.id)} />)}
        </View>
        {libraryFilter === 'want_to_read' && <ReadingCollection items={searchItems(wantToRead, librarySearch)} filter="want_to_read" saving={saving} searchTerm={librarySearch}
          onOpen={(item) => router.push(routeFor('item', item.id))}
          onStart={(item) => void changeStatus(item, 'currently_reading')}
          onSession={(item) => void startSession(item)} />}
        {libraryFilter === 'currently_reading' && <ReadingCollection items={searchItems(currentlyReading, librarySearch)} filter="currently_reading" saving={saving} searchTerm={librarySearch}
          onOpen={(item) => router.push(routeFor('item', item.id))}
          onStart={(item) => void startSession(item)}
          onSession={(item) => void startSession(item)}
          onFinish={(item) => void changeStatus(item, 'finished')} />}
        {libraryFilter === 'finished' && <ReadingCollection items={searchItems(finished, librarySearch)} filter="finished" saving={saving} searchTerm={librarySearch}
          onOpen={(item) => router.push(routeFor('item', item.id))}
          onStart={(item) => void changeStatus(item, 'currently_reading')}
          onSession={(item) => void startSession(item)} />}
        <Button label="Add a book or article" onPress={() => router.push(addRouteFor('library'))} />
      </> : <>
        <Body>Private PDF and EPUB files · maximum 25 MB each. The integrated reader is available on web where supported.</Body>
        <GrowthDocumentLibraryPanel moduleId="read" items={items} records={records} documents={documents}
          initialItemId={routeItemId} readOnly={false} onSaved={() => void refresh()} />
      </>}
    </>}

    {!loading && !error && section === 'discover' && <>
      <View style={[styles.discoverIntro, { backgroundColor: accent.surface }]}>
        <Eyebrow>Thoughtful discovery</Eyebrow><Heading>Find your next read</Heading>
        <Body>Explore book information and save titles to your Reading List. Bloom does not provide full book text.</Body>
      </View>
      <ReadingDiscoveryPanel profileId={profileId} items={items} records={records} readOnly={false} onSaved={() => void refresh()} />
    </>}

    {!loading && !error && section === 'progress' && <>
      <SectionTitle eyebrow="Reading activity" title="Your progress" subtitle="Timed sessions and page positions are tracked separately." />
      <View style={styles.filterRow}>
        {([{ id: 'day', label: 'Day' }, { id: 'week', label: 'Week' }, { id: 'month', label: 'Month' }] as const).map((entry) =>
          <Segment key={entry.id} label={entry.label} selected={progressPeriod === entry.id} onPress={() => setProgressPeriod(entry.id)} />)}
      </View>
      <View style={[styles.progressColumns, desktopColumns && styles.progressColumnsDesktop]}>
        <Panel><Eyebrow>Completed sessions</Eyebrow><Text style={[styles.metric, { color: theme.colors.ink }]}>{selectedReportSessions.length}</Text><Body>{periodLabel(progressPeriod)}</Body></Panel>
        <Panel><Eyebrow>Recorded reading time</Eyebrow><Text style={[styles.metric, { color: theme.colors.ink }]}>{formatMinutes(selectedReportSessions.reduce((sum, entry) => sum + (entry.duration_seconds ?? 0), 0))}</Text><Body>Completed sessions only</Body></Panel>
        <Panel><Eyebrow>Reading list</Eyebrow><View style={styles.metricPair}><View><Label>{currentlyReading.length}</Label><Body>in progress</Body></View><View><Label>{finished.length}</Label><Body>finished</Body></View></View></Panel>
      </View>
      {progressPeriod === 'week' && <Panel>
        <View style={styles.row}><View style={sharedStyles.grow}><Eyebrow>Weekly reading goal</Eyebrow><Label>{weekGoal ? (Math.min(weekSessions.length, weekGoal.target_count) + ' of ' + weekGoal.target_count + ' sessions') : 'No weekly goal set'}</Label></View>
          <MaterialIcons name="calendar-month" size={21} color={accent.deep} /></View>
        {weekGoal && <ProgressBar value={Math.min(100, weekSessions.length / Math.max(1, weekGoal.target_count) * 100)} label="Sessions completed toward your weekly goal" color={accent.deep} />}
        <Body>A session goal measures sessions, not reading hours or page count.</Body>
      </Panel>}
      <SessionActivityChart sessions={selectedReportSessions} period={progressPeriod} timeZone={timeZone} todayKey={todayKey} />
      <Panel>
        <Eyebrow>Reading list progress</Eyebrow><Label>Current page positions</Label>
        {currentlyReading.length === 0 ? <Body>No current reading positions yet.</Body> : currentlyReading.map((item) =>
          <View key={item.id} style={styles.progressItem}>
            <View style={styles.row}><View style={sharedStyles.grow}><Label>{item.title}</Label><Body>{item.page_count ? 'Page ' + (item.current_page ?? 0) + ' of ' + item.page_count : 'Page progress unavailable'}</Body></View>
              {item.page_count ? <Label>{Math.round(item.progress_percent)}%</Label> : null}</View>
            {item.page_count ? <ProgressBar value={item.progress_percent} label={item.title + ' page progress'} color={accent.deep} /> : null}
          </View>)}
      </Panel>
      <Panel>
        <Eyebrow>Recent sessions</Eyebrow>
        {selectedReportSessions.length === 0 ? <Body>No completed reading sessions in this period.</Body> : selectedReportSessions.slice(0, 12).map((session) => {
          const item = items.find((entry) => entry.id === session.item_id);
          return <View key={session.id} style={styles.sessionHistoryRow}>
            <View style={[styles.smallIcon, { backgroundColor: accent.surface }]}><MaterialIcons name="menu-book" size={18} color={accent.deep} /></View>
            <View style={sharedStyles.grow}><Label>{item?.title ?? 'Reading session'}</Label><Body>{session.completed_at ? new Date(session.completed_at).toLocaleDateString(getAppLocale()) + ' · ' + formatClock(session.started_at) : ''}</Body></View>
            <Label>{formatMinutes(session.duration_seconds ?? 0)}</Label>
          </View>;
        })}
      </Panel>
      <Panel><Eyebrow>Plan your reading rhythm</Eyebrow><Body>Choose a weekly goal from 1 to 100 sessions and select the days you want to make time.</Body><WeeklyPillarPlanner allowedModules={['read']} /></Panel>
      <RewardSummary rule={rewardRules.find((rule) => rule.module_id === 'read') ?? null} event={rewardEvents.find((entry) => entry.module_id === 'read') ?? null} />
    </>}

    {!loading && !error && (section === 'add' || section === 'edit') && <ReadItemForm
      key={`${profileId ?? 'no-profile'}:${section}:${section === 'edit' ? currentItem?.id ?? 'missing' : 'new'}`}
      item={section === 'edit' ? currentItem : null} saving={saving}
      draftKey={profileId ? `bloom.read-item-draft.v1:${profileId}:${section === 'edit' ? currentItem?.id ?? 'missing' : 'new'}` : null}
      onCancel={() => section === 'add'
        ? router.replace(routeFor(params.returnTo === 'today' ? 'today' : 'library'))
        : router.back()} onSave={saveItem} />}

    {!loading && !error && section === 'item' && (desktopColumns
      ? <View style={styles.libraryWorkspace}>
        <View style={styles.libraryColumn}>
          <SectionTitle eyebrow="Your personal collection" title="My Library" />
          <Field label="Search your reading list" value={librarySearch} onChangeText={setLibrarySearch} placeholder="Title, author, or topic" />
          <View style={styles.filterRow} accessibilityRole="tablist" accessibilityLabel="Reading list filters">
            {([{ id: 'want_to_read', label: 'Want to read', count: wantToRead.length }, { id: 'currently_reading', label: 'Currently reading', count: currentlyReading.length }, { id: 'finished', label: 'Finished', count: finished.length }] as const).map((entry) =>
              <Segment key={entry.id} label={entry.label + ' · ' + entry.count} selected={libraryFilter === entry.id} onPress={() => setLibraryFilter(entry.id)} />)}
          </View>
          {libraryFilter === 'want_to_read' && <ReadingCollection items={searchItems(wantToRead, librarySearch)} filter="want_to_read" saving={saving} searchTerm={librarySearch}
            onOpen={(item) => router.replace(routeFor('item', item.id))}
            onStart={(item) => void changeStatus(item, 'currently_reading')}
            onSession={(item) => void startSession(item)} />}
          {libraryFilter === 'currently_reading' && <ReadingCollection items={searchItems(currentlyReading, librarySearch)} filter="currently_reading" saving={saving} searchTerm={librarySearch}
            onOpen={(item) => router.replace(routeFor('item', item.id))}
            onStart={(item) => void startSession(item)}
            onSession={(item) => void startSession(item)}
            onFinish={(item) => void changeStatus(item, 'finished')} />}
          {libraryFilter === 'finished' && <ReadingCollection items={searchItems(finished, librarySearch)} filter="finished" saving={saving} searchTerm={librarySearch}
            onOpen={(item) => router.replace(routeFor('item', item.id))}
            onStart={(item) => void changeStatus(item, 'currently_reading')}
            onSession={(item) => void startSession(item)} />}
          <Button label="Add a book or article" variant="secondary" onPress={() => router.push(addRouteFor('library'))} />
        </View>
        <View style={styles.detailColumn}>
          <ItemDetail
            item={selectedReadItem} items={items} sessions={sessions} records={records} documents={documents}
            activeSession={activeSession} saving={saving} selectedTab={sectionId === 'notes' ? 'notes' : itemTab} setSelectedTab={setItemTab}
            editPages={params.editPages === '1'}
            onSavePages={(pageCount, currentPage) => selectedReadItem ? savePageProgress(selectedReadItem, pageCount, currentPage) : Promise.resolve(false)}
            onEdit={() => selectedReadItem && router.push(routeFor('edit', selectedReadItem.id))}
            onStart={() => selectedReadItem && void startSession(selectedReadItem)}
            onStatus={(status) => selectedReadItem && void changeStatus(selectedReadItem, status)}
            onSaved={() => void refresh()} />
        </View>
      </View>
      : <ItemDetail
        item={selectedReadItem} items={items} sessions={sessions} records={records} documents={documents}
        activeSession={activeSession} saving={saving} selectedTab={sectionId === 'notes' ? 'notes' : itemTab} setSelectedTab={setItemTab}
        editPages={params.editPages === '1'}
        onSavePages={(pageCount, currentPage) => selectedReadItem ? savePageProgress(selectedReadItem, pageCount, currentPage) : Promise.resolve(false)}
        onEdit={() => selectedReadItem && router.push(routeFor('edit', selectedReadItem.id))}
        onStart={() => selectedReadItem && void startSession(selectedReadItem)}
        onStatus={(status) => selectedReadItem && void changeStatus(selectedReadItem, status)}
        onSaved={() => void refresh()} />)}

    {!loading && section === 'session' && <SessionScreen
      session={activeSession} item={activeSessionItem} elapsed={activeSession ? elapsedFromStart(activeSession.started_at, tick) : null}
      saving={saving} error={error} confirmCancel={confirmCancel} setConfirmCancel={setConfirmCancel}
      onFinish={() => void endSession(false)} onCancel={() => void endSession(true)} />}

    {!loading && !error && section === 'session-complete' && <SessionComplete
      item={currentItem} durationSeconds={completionSeconds} rewardStatus={completionRewardStatus}
      rewardMinutes={completionRewardMinutes}
      onItem={() => currentItem && router.replace(routeFor('item', currentItem.id, true))}
      onReflect={() => { if (currentItem) { setItemTab('notes'); router.replace(routeFor('item', currentItem.id)); } }}
      onHome={() => router.replace('/read')} />}
  </Screen>;
}

function LocalNavigation({ selected, onSelect }: { selected: ReadSection; onSelect: (section: ReadSection) => void }) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <View accessibilityRole="tablist" style={[styles.localNavigation, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
    {localTabs.map((tab) => <Pressable key={tab.id} accessibilityRole="tab" accessibilityState={{ selected: selected === tab.id }}
      onPress={() => onSelect(tab.id)} style={[styles.localTab, selected === tab.id && { backgroundColor: theme.colors.surface }]}>
      <Text style={[styles.localTabText, { color: selected === tab.id ? accent.deep : theme.colors.inkMuted }]}>{tab.label}</Text>
    </Pressable>)}
  </View>;
}

function SectionTitle({ eyebrow, title, subtitle }: { eyebrow: string; title: string; subtitle?: string }) {
  return <View style={styles.sectionTitle}><Eyebrow>{eyebrow}</Eyebrow><Heading>{title}</Heading>{subtitle ? <Body>{subtitle}</Body> : null}</View>;
}

function Segment({ label, selected, disabled = false, onPress }: { label: string; selected: boolean; disabled?: boolean; onPress: () => void }) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <Pressable accessibilityRole="button" accessibilityState={{ selected, disabled }} disabled={disabled} onPress={onPress}
    style={[styles.segment, { borderColor: selected ? accent.deep : theme.colors.border, backgroundColor: selected ? accent.surface : theme.colors.surface }]}>
    <Text style={[styles.segmentText, { color: selected ? accent.deep : theme.colors.inkMuted }]}>{label}</Text>
  </Pressable>;
}

function ContinueCard({ item, saving, onOpen, onStart, onProgress }: {
  item: GrowthItem; saving: boolean; onOpen: () => void; onStart: () => void; onProgress: () => void;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <Panel>
    <Pressable accessibilityRole="button" accessibilityLabel={'Open ' + item.title} onPress={onOpen} style={styles.continueTop}>
      <BookCover item={item} size="small" />
      <View style={sharedStyles.grow}>
        <Eyebrow>{kindLabel(item.reading_kind).toUpperCase()} · CURRENTLY READING</Eyebrow>
        <Label>{item.title}</Label>
        <Body>{item.author || 'Author not added'}</Body>
        {item.page_count ? <Body>Page {item.current_page ?? 0} of {item.page_count}</Body> : <Body>Page progress unavailable</Body>}
      </View>
      <MaterialIcons name="chevron-right" size={22} color={theme.colors.inkMuted} />
    </Pressable>
    {item.page_count ? <ProgressBar value={item.progress_percent} label={item.title + ' page progress'} color={accent.deep} /> : null}
    <Button label="Start reading session" onPress={onStart} busy={saving} />
    <Button label="Update page position" variant="tertiary" onPress={onProgress} disabled={saving} />
  </Panel>;
}

function BookMark({ kind }: { kind: ReadingKind | null }) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <View style={[styles.bookMark, { backgroundColor: accent.surface }]}>
    <MaterialIcons name={kind === 'article' ? 'article' : 'menu-book'} size={26} color={accent.deep} />
    <Text style={[styles.bookKind, { color: accent.deep }]}>{kind === 'article' ? 'ARTICLE' : 'BOOK'}</Text>
  </View>;
}

function BookCover({ item, size }: { item: GrowthItem; size: 'small' | 'large' }) {
  const { theme } = useBloomTheme();
  return <ImageBackground source={bloomPillarImages.read} resizeMode="cover" imageStyle={styles.bookCoverImage}
    accessibilityRole="image" accessibilityLabel={`${item.title}, ${kindLabel(item.reading_kind).toLowerCase()} cover placeholder`}
    style={[styles.bookCover, size === 'large' ? styles.bookCoverLarge : styles.bookCoverSmall]}>
    <View style={[styles.bookCoverShade, { backgroundColor: 'rgba(25, 20, 47, 0.55)' }]} />
    <Text numberOfLines={1} style={[styles.bookCoverKind, { color: '#F1E8FF' }]}>{kindLabel(item.reading_kind).toUpperCase()}</Text>
    <Text numberOfLines={size === 'large' ? 4 : 3} style={[styles.bookCoverTitle, { color: '#FFFFFF' }]}>{item.title}</Text>
    <Text numberOfLines={1} style={[styles.bookCoverAuthor, { color: theme.colors.surfaceSoft }]}>{item.author || 'Author not added'}</Text>
  </ImageBackground>;
}

function ReadingShelfCard({ item, onPress }: { item: GrowthItem; onPress: () => void }) {
  const { theme } = useBloomTheme();
  return <Pressable accessibilityRole="button" onPress={onPress} style={[styles.shelfCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
    <BookCover item={item} size="large" />
    <Text numberOfLines={2} style={[styles.shelfTitle, { color: theme.colors.ink }]}>{item.title}</Text>
    <Text numberOfLines={1} style={[styles.shelfAuthor, { color: theme.colors.inkMuted }]}>{item.author || 'Author not added'}</Text>
    <Text style={[styles.shelfProgress, { color: theme.modules.read.deep }]}>{item.page_count ? Math.round(item.progress_percent) + '% · page ' + (item.current_page ?? 0) : 'Page progress unavailable'}</Text>
  </Pressable>;
}

function ReadingCollection({ items, filter, saving, searchTerm, onOpen, onStart, onSession, onFinish }: {
  items: GrowthItem[]; filter: LibraryFilter; saving: boolean; searchTerm?: string; onOpen: (item: GrowthItem) => void;
  onStart: (item: GrowthItem) => void; onSession: (item: GrowthItem) => void; onFinish?: (item: GrowthItem) => void;
}) {
  const { theme } = useBloomTheme();
  const emptyCopy = filter === 'want_to_read' ? 'Save a book or article you want to read next.' : filter === 'finished' ? 'Finished books and articles will collect here.' : 'Move a title here when you begin reading.';
  if (!items.length) return <Panel><Eyebrow>{searchTerm?.trim() ? 'Search results' : statusLabel(filter)}</Eyebrow><Label>{searchTerm?.trim() ? 'No matching items' : 'Your shelf is ready'}</Label><Body>{searchTerm?.trim() ? 'Try another title, author, or topic, or clear the search.' : emptyCopy}</Body>{!searchTerm?.trim() && <>
    <Button label="Add a book or article" variant="secondary" onPress={() => router.push(addRouteFor('library'))} />
    <Button label="Browse the Discover catalog" variant="tertiary" onPress={() => router.push(routeFor('discover'))} />
  </>}</Panel>;
  return <View style={styles.collection}>
    {items.map((item) => <Panel key={item.id}>
      <Pressable accessibilityRole="button" onPress={() => onOpen(item)} style={styles.collectionTop}>
        <BookCover item={item} size="small" />
        <View style={sharedStyles.grow}>
          <View style={styles.row}><Eyebrow>{kindLabel(item.reading_kind).toUpperCase()}</Eyebrow><View style={[styles.statusPill, { backgroundColor: theme.modules.read.surface }]}><Text style={[styles.statusPillText, { color: theme.modules.read.deep }]}>{statusLabel(getReadingStatus(item))}</Text></View></View>
          <Label>{item.title}</Label><Body>{item.author || 'Author not added'}{item.genre ? ' · ' + item.genre : ''}</Body>
          {filter === 'currently_reading' ? <Body>{item.page_count ? 'Page ' + (item.current_page ?? 0) + ' of ' + item.page_count : 'Page progress unavailable'}</Body> : null}
        </View>
        <MaterialIcons name="chevron-right" size={22} color={theme.colors.inkMuted} />
      </Pressable>
      {filter === 'currently_reading' && item.page_count ? <ProgressBar value={item.progress_percent} label={item.title + ' page progress'} color={theme.modules.read.deep} /> : null}
      <View style={styles.actionRow}>
        {filter === 'want_to_read' && <Button label="Move to Currently reading" variant="tertiary" disabled={saving} onPress={() => onStart(item)} />}
        {filter === 'currently_reading' && <Button label="Start session" variant="secondary" disabled={saving} onPress={() => onSession(item)} />}
        {filter === 'currently_reading' && onFinish && <Button label="Mark finished" variant="tertiary" disabled={saving} onPress={() => onFinish(item)} />}
        {filter === 'finished' && <Button label="Read again" variant="tertiary" disabled={saving} onPress={() => onStart(item)} />}
      </View>
    </Panel>)}
  </View>;
}

type ReadItemDetails = { title: string; kind: ReadingKind; author: string; genre: string; pageCount: number | null; notes: string; status: ReadingStatus };
type ReadItemDraft = ReadItemDetails & { version: 1; pageCountText: string };

function parseReadItemDraft(raw: string | null): ReadItemDraft | null {
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object') return null;
    const draft = value as Partial<ReadItemDraft>;
    if (draft.version !== 1 || typeof draft.title !== 'string' || draft.title.length > 120
      || !['book', 'article'].includes(draft.kind ?? '') || typeof draft.author !== 'string' || draft.author.length > 160
      || typeof draft.genre !== 'string' || draft.genre.length > 80 || typeof draft.notes !== 'string' || draft.notes.length > 2000
      || !['want_to_read', 'currently_reading', 'finished'].includes(draft.status ?? '')
      || typeof draft.pageCountText !== 'string' || draft.pageCountText.length > 6
      || (draft.pageCount !== null && (typeof draft.pageCount !== 'number' || !Number.isInteger(draft.pageCount) || draft.pageCount < 1 || draft.pageCount > 100000))) return null;
    return draft as ReadItemDraft;
  } catch { return null; }
}

function ReadItemForm({ item, saving, draftKey, onCancel, onSave }: {
  item: GrowthItem | null; saving: boolean; draftKey: string | null; onCancel: () => void;
  onSave: (item: GrowthItem | null, details: ReadItemDetails, requestId: string) => Promise<boolean>;
}) {
  const [title, setTitle] = useState(item?.title ?? '');
  const [kind, setKind] = useState<ReadingKind>(item?.reading_kind ?? 'book');
  const [author, setAuthor] = useState(item?.author ?? '');
  const [genre, setGenre] = useState(item?.genre ?? '');
  const [pageCount, setPageCount] = useState(item?.page_count?.toString() ?? '');
  const [notes, setNotes] = useState(item?.notes ?? '');
  const [status, setStatus] = useState<ReadingStatus>(item ? getReadingStatus(item) : 'want_to_read');
  const [formError, setFormError] = useState<string | null>(null);
  const [draftReady, setDraftReady] = useState(draftKey === null);
  const pendingRequest = useRef<{ signature: string; requestId: string } | null>(null);
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;

  useEffect(() => {
    let active = true;
    if (!draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      const draft = parseReadItemDraft(raw);
      if (!draft) return;
      setTitle(draft.title); setKind(draft.kind); setAuthor(draft.author); setGenre(draft.genre);
      setPageCount(draft.pageCountText); setNotes(draft.notes); setStatus(draft.status);
    }).catch(() => undefined).finally(() => { if (active) setDraftReady(true); });
    return () => { active = false; };
  }, [draftKey]);

  useEffect(() => {
    if (!draftKey || !draftReady || saving) return;
    const parsedPageCount = pageCount.trim() ? Number(pageCount) : null;
    const pageCountValue = parsedPageCount !== null && Number.isInteger(parsedPageCount) && parsedPageCount > 0
      ? parsedPageCount : null;
    const draft: ReadItemDraft = { version: 1, title, kind, author, genre, pageCountText: pageCount,
      pageCount: pageCountValue, notes, status };
    void AsyncStorage.setItem(draftKey, JSON.stringify(draft)).catch(() => undefined);
  }, [author, draftKey, draftReady, genre, kind, notes, pageCount, saving, status, title]);

  async function submit() {
    if (!draftReady || saving) return;
    if (!title.trim()) { setFormError('Add a title to your reading list.'); return; }
    const count = pageCount.trim() ? Number(pageCount) : null;
    if (count !== null && (!Number.isInteger(count) || count < 1 || count > 100000)) { setFormError('Enter a total page count from 1 to 100,000, or leave it blank.'); return; }
    if (item && status !== 'finished' && count !== null && item.current_page !== null && item.current_page > count) {
      setFormError('The current page is above this total. Update the page position before lowering the page count.');
      return;
    }
    if (author.trim().length > 160 || genre.trim().length > 80 || notes.trim().length > 2000) { setFormError('Shorten one of the fields to fit the allowed length.'); return; }
    setFormError(null);
    const details = { title: title.trim(), kind, author: author.trim(), genre: genre.trim(), pageCount: count, notes: notes.trim(), status };
    const signature = JSON.stringify(details);
    if (pendingRequest.current?.signature !== signature) pendingRequest.current = { signature, requestId: randomUUID() };
    const saved = await onSave(item, details, pendingRequest.current.requestId);
    if (saved && draftKey) await AsyncStorage.removeItem(draftKey).catch(() => undefined);
  }

  async function cancel() {
    if (!draftReady || saving) return;
    if (draftKey) await AsyncStorage.removeItem(draftKey).catch(() => undefined);
    onCancel();
  }

  return <>
    <View style={styles.formHeader}><Eyebrow>PERSONAL READING LIST</Eyebrow><Heading>{item ? 'Edit reading item' : 'Add to your Library'}</Heading><Body>Keep your edition and reading position organized. Bloom does not include the book text.</Body></View>
    <Panel>
      {!draftReady && <Body>Restoring your unsaved reading details…</Body>}
      <Field label="Title" value={title} onChangeText={setTitle} placeholder="Book or article title" maxLength={120} editable={draftReady && !saving} />
      <Body>Type</Body>
      <View style={styles.filterRow}>
        {([{ id: 'book', label: 'Book', icon: 'menu-book' }, { id: 'article', label: 'Article', icon: 'article' }] as const).map((entry) =>
          <Pressable key={entry.id} accessibilityRole="radio" accessibilityState={{ selected: kind === entry.id, disabled: !draftReady || saving }} disabled={!draftReady || saving} onPress={() => setKind(entry.id)}
            style={[styles.kindChoice, { backgroundColor: kind === entry.id ? accent.surface : theme.colors.surface, borderColor: kind === entry.id ? accent.deep : theme.colors.border }]}>
            <MaterialIcons name={entry.icon} size={18} color={kind === entry.id ? accent.deep : theme.colors.inkMuted} /><Text style={[styles.segmentText, { color: kind === entry.id ? accent.deep : theme.colors.ink }]}>{entry.label}</Text>
          </Pressable>)}
      </View>
      <Field label="Author (optional)" value={author} onChangeText={setAuthor} placeholder="Author or publication" maxLength={160} editable={draftReady && !saving} />
      <Field label="Genre or topic (optional)" value={genre} onChangeText={setGenre} placeholder="History, science, essays…" maxLength={80} editable={draftReady && !saving} />
      <Field label="Total pages (optional)" value={pageCount} onChangeText={setPageCount} placeholder="For a printed edition" keyboardType="number-pad" maxLength={6} editable={draftReady && !saving}
        helperText="You can save an article without knowing its page count." />
      <Field label="Private notes (optional)" value={notes} onChangeText={setNotes} placeholder="A source, reminder, or reason you saved it" maxLength={2000} multiline editable={draftReady && !saving} />
      <Body>Reading status</Body>
      <View style={styles.filterRow}>
        {(['want_to_read', 'currently_reading', 'finished'] as const).map((value) =>
          <Segment key={value} label={statusLabel(value)} selected={status === value} disabled={!draftReady || saving} onPress={() => setStatus(value)} />)}
      </View>
      {formError && <ErrorText>{formError}</ErrorText>}
      <Button label={item ? 'Save changes' : 'Add to Reading List'} onPress={() => void submit()} busy={saving} disabled={!draftReady} />
      <Button label="Cancel" variant="tertiary" disabled={!draftReady || saving} onPress={() => void cancel()} />
    </Panel>
  </>;
}

function ItemDetail({ item, items, sessions, records, documents, activeSession, saving, selectedTab, setSelectedTab, editPages,
  onSavePages, onEdit, onStart, onStatus, onSaved }: {
  item: GrowthItem | null; items: GrowthItem[]; sessions: GrowthSession[]; records: GrowthRecord[]; documents: GrowthDocument[];
  activeSession: GrowthSession | null; saving: boolean; selectedTab: ItemTab; setSelectedTab: (tab: ItemTab) => void;
  editPages: boolean; onSavePages: (pageCount: string, currentPage: string) => Promise<boolean>;
  onEdit: () => void; onStart: () => void; onStatus: (status: ReadingStatus) => void; onSaved: () => void;
}) {
  const { theme } = useBloomTheme();
  const { profileId } = useAuth();
  const [showPageEditor, setShowPageEditor] = useState(editPages);
  const [pageCountText, setPageCountText] = useState(item?.page_count?.toString() ?? '');
  const [currentPageText, setCurrentPageText] = useState(item?.current_page?.toString() ?? '0');
  const accent = theme.modules.read;
  if (!item) return <Panel><Eyebrow>Reading item</Eyebrow><Label>This item isn’t available</Label><Body>It may have been removed or is no longer in this Reading List.</Body><Button label="Return to Library" onPress={() => router.replace(routeFor('library'))} /></Panel>;
  const itemSessions = sessions.filter((session) => session.item_id === item.id).sort((a, b) => Date.parse(b.started_at) - Date.parse(a.started_at));
  const itemRecords = records.filter((record) => record.item_id === item.id);
  const itemDocuments = documents.filter((document) => document.item_id === item.id);
  return <>
    <Pressable accessibilityRole="button" onPress={() => router.replace(routeFor('library'))} style={styles.backLink}><MaterialIcons name="arrow-back" size={19} color={accent.deep} /><Text style={[styles.inlineLink, { color: accent.deep }]}>Library</Text></Pressable>
    <Panel>
      <View style={styles.detailHeader}>
        <BookMark kind={item.reading_kind} />
        <View style={sharedStyles.grow}><Eyebrow>{kindLabel(item.reading_kind).toUpperCase()} · {statusLabel(getReadingStatus(item)).toUpperCase()}</Eyebrow><Heading>{item.title}</Heading><Body>{item.author || 'Author not added'}{item.genre ? ' · ' + item.genre : ''}</Body></View>
        <Pressable accessibilityRole="button" accessibilityLabel="Edit reading details" onPress={onEdit} style={[styles.iconButton, { backgroundColor: accent.surface }]}><MaterialIcons name="edit" size={19} color={accent.deep} /></Pressable>
      </View>
      {item.page_count ? <>
        <View style={styles.row}><View style={sharedStyles.grow}><Eyebrow>Page position</Eyebrow><Label>Page {item.current_page ?? 0} of {item.page_count}</Label></View><Label>{Math.round(item.progress_percent)}%</Label></View>
        <ProgressBar value={item.progress_percent} label={item.title + ' page progress'} color={accent.deep} />
      </> : <Body>Page progress unavailable until you add a total page count.</Body>}
      <View style={styles.actionRow}>
        {getReadingStatus(item) !== 'finished' && <Button label="Start reading session" onPress={onStart} busy={saving} />}
        {getReadingStatus(item) !== 'finished' && <Button label="Update page" variant="secondary" onPress={() => {
          setPageCountText(item.page_count?.toString() ?? '');
          setCurrentPageText(item.current_page?.toString() ?? '0');
          setShowPageEditor((value) => !value);
        }} disabled={saving} />}
        {getReadingStatus(item) === 'currently_reading' && <Button label="Mark finished" variant="tertiary" onPress={() => onStatus('finished')} disabled={saving} />}
        {getReadingStatus(item) === 'want_to_read' && <Button label="Move to Currently reading" variant="tertiary" onPress={() => onStatus('currently_reading')} disabled={saving} />}
        {getReadingStatus(item) === 'finished' && <Button label="Read again" variant="secondary" onPress={() => onStatus('currently_reading')} disabled={saving} />}
      </View>
      {showPageEditor && <View style={[styles.pageEditor, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
        <Eyebrow>Update page position</Eyebrow>
        <Field label="Current page" value={currentPageText} onChangeText={setCurrentPageText} keyboardType="number-pad" maxLength={6} />
        <Field label="Total pages" value={pageCountText} onChangeText={setPageCountText} keyboardType="number-pad" maxLength={6} />
        {Number(pageCountText) > 0 && Number(currentPageText) >= 0 && Number(currentPageText) <= Number(pageCountText)
          ? <Body>Preview · {Math.round(Number(currentPageText) / Number(pageCountText) * 100)}% of this edition</Body> : null}
        <View style={styles.actionRow}><Button label="Save page position" onPress={() => void onSavePages(pageCountText, currentPageText).then((saved) => { if (saved) setShowPageEditor(false); })} busy={saving} /><Button label="Cancel" variant="tertiary" onPress={() => setShowPageEditor(false)} disabled={saving} /></View>
      </View>}
    </Panel>
    <View style={[styles.detailTabs, { borderBottomColor: theme.colors.border }]} accessibilityRole="tablist">
      {([{ id: 'overview', label: 'Overview' }, { id: 'sessions', label: 'Sessions' }, { id: 'notes', label: 'Notes' }, { id: 'files', label: 'Files' }] as const).map((tab) =>
        <Pressable key={tab.id} accessibilityRole="tab" accessibilityState={{ selected: selectedTab === tab.id }} onPress={() => setSelectedTab(tab.id)}
          style={[styles.detailTab, selectedTab === tab.id && { borderBottomColor: accent.deep }]}>
          <Text style={[styles.detailTabText, { color: selectedTab === tab.id ? accent.deep : theme.colors.inkMuted }]}>{tab.label}</Text>
        </Pressable>)}
    </View>
    {selectedTab === 'overview' && <>
      <Panel><Eyebrow>About this reading item</Eyebrow><Body>{item.notes || 'No private notes added yet.'}</Body><View style={styles.metricPair}><View><Label>{itemSessions.filter((entry) => entry.status === 'completed').length}</Label><Body>completed sessions</Body></View><View><Label>{itemRecords.length}</Label><Body>private notebook entries</Body></View><View><Label>{itemDocuments.length}</Label><Body>private documents</Body></View></View></Panel>
      {activeSession?.item_id === item.id && <Panel><Eyebrow>Session active</Eyebrow><Body>Continue in the focused session screen.</Body><Button label="Return to session" onPress={() => router.push(routeFor('session'))} /></Panel>}
    </>}
    {selectedTab === 'sessions' && <Panel><Eyebrow>Timed reading history</Eyebrow>{itemSessions.length ? itemSessions.map((session) =>
      <View key={session.id} style={styles.sessionHistoryRow}><View style={sharedStyles.grow}><Label>{session.status === 'completed' ? 'Completed session' : session.status === 'cancelled' ? 'Cancelled session' : 'In progress'}</Label><Body>{new Date(session.started_at).toLocaleString(getAppLocale())}</Body></View><Label>{session.status === 'completed' ? formatMinutes(session.duration_seconds ?? 0) : '—'}</Label></View>)
      : <Body>Completed and cancelled sessions will appear here. Page position does not count as timed activity.</Body>}</Panel>}
    {selectedTab === 'notes' && <GrowthRecordPanel key={`${profileId ?? 'no-profile'}:read:${item.id}`} profileId={profileId} moduleId="read" items={items} records={records} documents={documents}
      initialItemId={item.id} readOnly={false} onSaved={onSaved} />}
    {selectedTab === 'files' && <>
      <Panel><Eyebrow>Private documents</Eyebrow><Body>Upload authorized PDF or EPUB files for your own profile. The integrated reader is available on web where supported.</Body></Panel>
      <GrowthDocumentLibraryPanel moduleId="read" items={items} records={records} documents={documents} initialItemId={item.id} readOnly={false} onSaved={onSaved} />
    </>}
  </>;
}

function SessionScreen({ session, item, elapsed, saving, error, confirmCancel, setConfirmCancel, onFinish, onCancel }: {
  session: GrowthSession | null; item: GrowthItem | null; elapsed: string | null; saving: boolean; error: string | null;
  confirmCancel: boolean; setConfirmCancel: (value: boolean) => void; onFinish: () => void; onCancel: () => void;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <View style={styles.sessionScreen}>
    <View style={[styles.sessionGlyph, { backgroundColor: accent.surface }]}><MaterialIcons name="menu-book" size={26} color={accent.deep} /></View>
    <Eyebrow>READING SESSION</Eyebrow>
    <Heading>{item?.title ?? 'Reading session'}</Heading>
    {session ? <>
      <Text accessibilityRole="timer" style={[styles.sessionTimer, { color: accent.deep }]}>{elapsed ?? '00:00'}</Text>
      <Label>Time since you started</Label>
      <Body>Bloom saves your total reading time when you finish.</Body>
      <View style={styles.sessionControls}>
        <Button label="Finish reading" onPress={onFinish} busy={saving} />
        {!confirmCancel ? <Button label="Cancel session" variant="tertiary" onPress={() => setConfirmCancel(true)} disabled={saving} /> : <Panel>
          <Eyebrow>Cancel this session?</Eyebrow><Body>It will remain marked cancelled and won’t count as a completed session or reward.</Body>
          <Button label="Confirm cancellation" variant="destructive" onPress={onCancel} busy={saving} />
          <Button label="Keep reading" variant="tertiary" onPress={() => setConfirmCancel(false)} disabled={saving} />
        </Panel>}
      </View>
    </> : <Panel><Eyebrow>No active session</Eyebrow><Body>There is no reading session to resume.</Body><Button label="Back to Read Today" onPress={() => router.replace('/read')} /></Panel>}
    {error && <ErrorText>{error}</ErrorText>}
    <Button label="Return to Read Today" variant="tertiary" onPress={() => router.replace('/read')} disabled={saving} />
  </View>;
}

function SessionComplete({ item, durationSeconds, rewardStatus, rewardMinutes, onItem, onReflect, onHome }: {
  item: GrowthItem | null; durationSeconds: number; rewardStatus: string; rewardMinutes: number;
  onItem: () => void; onReflect: () => void; onHome: () => void;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  return <View style={styles.sessionComplete}>
    <View style={[styles.sessionGlyph, { backgroundColor: accent.surface }]}><MaterialIcons name="check" size={28} color={accent.deep} /></View>
    <Eyebrow>SESSION RECORDED</Eyebrow><Heading>A moment well spent.</Heading>
    <Text style={[styles.sessionTimer, { color: accent.deep }]}>{formatMinutes(durationSeconds)}</Text>
    <Label>{item?.title ?? 'Reading session'}</Label>
    <Body>Recorded duration confirmed by Bloom.</Body>
    <RewardStatus status={rewardStatus} minutes={rewardMinutes} />
    <Button label="Update page position" onPress={onItem} />
    <Button label="Write a reflection" variant="tertiary" onPress={onReflect} />
    <Button label="Back to Read Today" variant="secondary" onPress={onHome} />
  </View>;
}

function RewardSummary({ rule, event }: { rule: GrowthRewardRule | null; event: GrowthRewardEvent | null }) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  if (!rule) return <Panel><Eyebrow>Reading rewards</Eyebrow><Body>Rewards are optional. Session tracking works when rewards are disabled.</Body><Button label="Manage reward settings" variant="tertiary" onPress={() => router.push('/settings' as Href)} /></Panel>;
  return <Panel>
    <View style={styles.row}><View style={sharedStyles.grow}><Eyebrow>Bloom reading rewards</Eyebrow><Label>{rule.enabled ? 'Enabled' : 'Disabled'}</Label></View><MaterialIcons name="schedule" size={20} color={accent.deep} /></View>
    <View style={styles.rewardGrid}>
      <RewardDatum label="Minimum session" value={rule.minimum_session_minutes + ' min'} />
      <RewardDatum label="Reward" value={rule.reward_minutes + ' min'} />
      <RewardDatum label="Daily cap" value={rule.daily_cap_minutes + ' min'} />
      <RewardDatum label="Weekly cap" value={rule.weekly_cap_minutes + ' min'} />
    </View>
    <Body>{rule.require_parent_approval ? 'Parent approval is required.' : 'Parent approval is not required.'} Credits use Bloom’s shared wallet.</Body>
    {event && <View style={[styles.rewardEvent, { backgroundColor: accent.surface }]}><Eyebrow>Most recent reward</Eyebrow><RewardStatus status={event.status} minutes={event.awarded_minutes} /></View>}
    {!event && <Body>No reading reward event has been recorded yet.</Body>}
    <Button label="Manage reward settings" variant="tertiary" onPress={() => router.push('/settings' as Href)} />
  </Panel>;
}

function RewardDatum({ label, value }: { label: string; value: string }) {
  return <View style={styles.rewardDatum}><Body>{label}</Body><Label>{value}</Label></View>;
}

function RewardStatus({ status, minutes }: { status: string; minutes: number }) {
  const labels: Record<string, string> = {
    pending: 'Pending parent approval', awarded: minutes > 0 ? 'Approved and credited · ' + minutes + ' min' : 'Approved and credited',
    capped: 'Not awarded · reward cap reached', rejected: 'Not awarded · rejected', unavailable: 'Reward status is unavailable',
    eligible: 'Eligible, awaiting processing', not_eligible: 'Not eligible under the current reward rules',
  };
  return <Body>{labels[status] ?? 'Eligible reward is awaiting processing'}</Body>;
}

function SessionActivityChart({ sessions, period, timeZone, todayKey }: {
  sessions: GrowthSession[]; period: ProgressPeriod; timeZone: string; todayKey: string;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.read;
  const buckets = period === 'day'
    ? Array.from({ length: 12 }, (_, index) => ({ label: String(index * 2).padStart(2, '0'), key: index }))
    : period === 'week'
      ? Array.from({ length: 7 }, (_, index) => ({ label: ['S', 'M', 'T', 'W', 'T', 'F', 'S'][index], key: addDateDays(startOfWeekKey(todayKey), index) }))
      : Array.from({ length: 5 }, (_, index) => ({ label: 'W' + (index + 1), key: index }));
  const amounts = buckets.map((bucket) => sessions.filter((session) => {
    if (!session.completed_at) return false;
    const date = new Date(session.completed_at);
    if (period === 'day') {
      const localHour = Number(new Intl.DateTimeFormat('en', { timeZone, hour: '2-digit', hourCycle: 'h23' }).format(date));
      return dateKeyInTimeZone(date, timeZone) === todayKey && Math.floor(localHour / 2) === bucket.key;
    }
    const localKey = dateKeyInTimeZone(date, timeZone);
    if (period === 'week') return localKey === bucket.key;
    const monthStart = todayKey.slice(0, 7) + '-01';
    const day = Number(localKey.slice(8, 10));
    const group = Math.min(4, Math.floor((day - 1) / 7));
    return localKey >= monthStart && localKey <= todayKey && group === bucket.key;
  }).reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0) / 60);
  const max = Math.max(1, ...amounts);
  return <Panel><Eyebrow>Recorded reading time</Eyebrow><Label>{period === 'day' ? 'Today by two-hour block' : period === 'week' ? 'This week by day' : 'This month by week'}</Label>
    <View style={styles.chart}>{amounts.map((value, index) => <View key={String(buckets[index].key)} style={styles.chartColumn}>
      <Text style={[styles.chartValue, { color: theme.colors.inkMuted }]}>{value ? Math.round(value) + 'm' : ''}</Text>
      <View style={[styles.chartTrack, { backgroundColor: theme.colors.surfaceSoft }]}><View style={[styles.chartBar, { backgroundColor: accent.deep, height: Math.max(value ? 8 : 2, value / max * 104) }]} /></View>
      <Text style={[styles.chartLabel, { color: theme.colors.inkMuted }]}>{buckets[index].label}</Text>
    </View>)}</View>
  </Panel>;
}

function elapsedFromStart(startedAt: string, now: number) {
  return formatElapsed(Math.max(0, Math.floor((now - Date.parse(startedAt)) / 1000)));
}

const styles = StyleSheet.create({
  header: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 2, paddingTop: 4 },
  headerIcon: { width: 48, height: 48, borderRadius: 17, alignItems: 'center', justifyContent: 'center' },
  tagline: { fontSize: 13, lineHeight: 18, marginTop: 1 },
  iconButton: { width: 42, height: 42, borderRadius: 15, alignItems: 'center', justifyContent: 'center' },
  localNavigation: { flexDirection: 'row', gap: 3, borderWidth: 1, borderRadius: 18, padding: 4, marginTop: 16, marginBottom: 16 },
  localTab: { flex: 1, minHeight: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 13 },
  localTabText: { fontSize: 13, fontWeight: '600' },
  loading: { padding: 20 },
  notice: { padding: 12, borderRadius: 14, flexDirection: 'row', gap: 8, alignItems: 'center', marginBottom: 12 },
  noticeText: { flex: 1, fontSize: 13, fontWeight: '600' },
  hero: { height: 185, borderRadius: 28, overflow: 'hidden', justifyContent: 'flex-end', marginBottom: 16 },
  heroDesktop: { height: 210 },
  heroImage: { borderRadius: 28 },
  heroShade: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(22, 21, 44, 0.38)' },
  heroCopy: { paddingHorizontal: 22, paddingBottom: 22, maxWidth: 580 },
  heroEyebrow: { color: '#F0E7FF', fontSize: 10, fontWeight: '700', letterSpacing: 1.5, marginBottom: 8 },
  heroTitle: { color: '#FFFFFF', fontSize: 25, lineHeight: 31, fontWeight: '700', letterSpacing: -0.4 },
  heroSubtitle: { color: '#F1EDF8', fontSize: 13, lineHeight: 19, marginTop: 6 },
  row: { flexDirection: 'row', alignItems: 'center', gap: 11 },
  smallIcon: { width: 38, height: 38, borderRadius: 13, justifyContent: 'center', alignItems: 'center' },
  timerSmall: { fontSize: 17, fontWeight: '700', fontVariant: ['tabular-nums'] },
  todayColumns: { gap: 14 },
  todayColumnsDesktop: { flexDirection: 'row', alignItems: 'stretch' },
  libraryWorkspace: { flexDirection: 'row', alignItems: 'flex-start', gap: 16 },
  libraryColumn: { flex: 0.9, minWidth: 300, gap: 12 },
  detailColumn: { flex: 1.1, minWidth: 340, gap: 12 },
  sectionTitle: { gap: 5, marginTop: 8, marginBottom: 12 },
  sectionHeaderRow: { flexDirection: 'row', alignItems: 'flex-end', justifyContent: 'space-between', marginTop: 18 },
  continueTop: { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 16 },
  bookMark: { width: 67, height: 88, borderRadius: 13, justifyContent: 'center', alignItems: 'center', gap: 8 },
  bookKind: { fontSize: 8, fontWeight: '700', letterSpacing: 1 },
  bookCover: { overflow: 'hidden', justifyContent: 'flex-end', padding: 8, gap: 3 },
  bookCoverSmall: { width: 76, height: 100, borderRadius: 14 },
  bookCoverLarge: { width: 94, height: 126, borderRadius: 15 },
  bookCoverImage: { borderRadius: 15 },
  bookCoverShade: { ...StyleSheet.absoluteFill },
  bookCoverKind: { fontSize: 7, lineHeight: 10, fontWeight: '800', letterSpacing: 0.7 },
  bookCoverTitle: { fontSize: 10, lineHeight: 13, fontWeight: '800' },
  bookCoverAuthor: { fontSize: 8, lineHeight: 11, fontWeight: '600' },
  metric: { fontSize: 33, lineHeight: 40, fontWeight: '700', letterSpacing: -0.8, marginTop: 5 },
  metricDivider: { borderBottomWidth: StyleSheet.hairlineWidth, marginVertical: 16 },
  metricPair: { flexDirection: 'row', gap: 22, justifyContent: 'space-between', marginTop: 13 },
  goalBlock: { gap: 10, marginTop: 18 },
  shelf: { flexDirection: 'row', gap: 12, paddingBottom: 4 },
  shelfDesktop: { gap: 14 },
  shelfCard: { width: 178, minHeight: 190, borderWidth: 1, borderRadius: 19, padding: 13, gap: 8 },
  shelfTitle: { fontSize: 14, lineHeight: 18, fontWeight: '700' },
  shelfAuthor: { fontSize: 12 },
  shelfProgress: { fontSize: 11, fontWeight: '600', marginTop: 'auto' },
  preview: { fontSize: 14, lineHeight: 21, marginTop: 5 },
  inlineLink: { fontSize: 13, fontWeight: '600', marginTop: 8 },
  switchRow: { flexDirection: 'row', gap: 4, borderWidth: 1, borderRadius: 18, padding: 4, marginBottom: 14 },
  filterRow: { flexDirection: 'row', gap: 8, flexWrap: 'wrap', marginBottom: 14 },
  segment: { minHeight: 38, paddingHorizontal: 13, borderRadius: 14, borderWidth: 1, justifyContent: 'center', alignItems: 'center' },
  segmentText: { fontSize: 12, fontWeight: '600' },
  collection: { gap: 12 },
  collectionTop: { flexDirection: 'row', alignItems: 'center', gap: 12, marginBottom: 12 },
  statusPill: { borderRadius: 99, paddingHorizontal: 8, paddingVertical: 4, marginLeft: 4 },
  statusPillText: { fontSize: 9, fontWeight: '700' },
  actionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 7, marginTop: 8 },
  discoverIntro: { borderRadius: 24, padding: 20, gap: 8, marginBottom: 14 },
  progressColumns: { gap: 10 },
  progressColumnsDesktop: { flexDirection: 'row' },
  progressItem: { gap: 8, marginTop: 14 },
  sessionHistoryRow: { flexDirection: 'row', alignItems: 'center', gap: 11, paddingVertical: 9, borderBottomWidth: StyleSheet.hairlineWidth, borderColor: '#E6EAF1' },
  chart: { height: 155, flexDirection: 'row', alignItems: 'flex-end', gap: 5, marginTop: 16 },
  chartColumn: { flex: 1, alignItems: 'center', justifyContent: 'flex-end', gap: 5 },
  chartValue: { height: 14, fontSize: 9, textAlign: 'center' },
  chartTrack: { height: 106, width: '72%', borderRadius: 99, justifyContent: 'flex-end', overflow: 'hidden' },
  chartBar: { width: '100%', borderRadius: 99, minHeight: 2 },
  chartLabel: { height: 15, fontSize: 9 },
  formHeader: { gap: 6, marginTop: 6, marginBottom: 12 },
  kindChoice: { flexDirection: 'row', alignItems: 'center', gap: 7, borderWidth: 1, paddingHorizontal: 14, height: 40, borderRadius: 14 },
  backLink: { flexDirection: 'row', alignItems: 'center', gap: 5, paddingVertical: 4 },
  detailHeader: { flexDirection: 'row', alignItems: 'center', gap: 14, marginBottom: 17 },
  detailTabs: { flexDirection: 'row', borderBottomWidth: 1, gap: 3, marginVertical: 12 },
  detailTab: { flex: 1, minHeight: 42, justifyContent: 'center', alignItems: 'center', borderBottomWidth: 2, borderBottomColor: 'transparent' },
  detailTabText: { fontSize: 12, fontWeight: '600' },
  pageEditor: { gap: 4, borderRadius: 16, borderWidth: 1, padding: 12, marginTop: 14 },
  sessionScreen: { flex: 1, minHeight: 520, alignItems: 'center', justifyContent: 'center', gap: 12, paddingHorizontal: 20, paddingVertical: 32 },
  sessionGlyph: { width: 58, height: 58, borderRadius: 21, alignItems: 'center', justifyContent: 'center' },
  sessionTimer: { fontSize: 52, lineHeight: 62, fontWeight: '600', fontVariant: ['tabular-nums'], letterSpacing: -1.4, marginTop: 18 },
  sessionControls: { width: '100%', maxWidth: 440, gap: 8, marginTop: 18 },
  sessionComplete: { flex: 1, minHeight: 500, alignItems: 'center', justifyContent: 'center', gap: 12, paddingVertical: 40 },
  rewardGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 14, marginVertical: 14 },
  rewardDatum: { minWidth: '42%', flexGrow: 1, gap: 3 },
  rewardEvent: { borderRadius: 14, padding: 12, gap: 5, marginTop: 10 },
});
