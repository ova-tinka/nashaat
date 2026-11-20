import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { randomUUID } from 'expo-crypto';
import type { ComponentProps } from 'react';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, View } from 'react-native';
import { router, useFocusEffect, type Href } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, FeatureTile, Field, Heading, Label, Panel, ProgressBar, Screen, sharedStyles } from './bloom-ui';
import { cancelGrowthSession, createGrowthItem, createGrowthProject, finishGrowthSession, formatElapsed, loadGrowthDocuments, loadGrowthModule, startGrowthSession, updateGrowthItem, updateGrowthReadingDetails, updateGrowthTaskMetadata, type GrowthDocument, type GrowthItem, type GrowthModuleId, type GrowthSession, type GrowthRecord, type GrowthRecordAttachment, type StudyPlanChange, type StudyPlanSlot, type TaskFocusSession, type TaskPriority, type ReadingStatus } from '../lib/growth-modules';
import { GrowthHierarchyPanel, GrowthRecordPanel, ReadingDiscoveryPanel, StudyPlanPanel, StudyPracticeReviewPanel, StudyTutorPanel, TaskBreakdownPanel, TaskFocusPanel } from './growth-feature-panels';
import { MockExamPanel } from './mock-exam-panel';
import { GrowthDocumentLibraryPanel, StudyDocumentHelpPanel } from './growth-document-panels';
import { growthModuleSnapshotKey } from '../lib/growth-module-state';
import { useAuth } from '../lib/auth';
import { useBloomTheme } from '../lib/theme-context';
import { useBloom } from '../lib/bloom-context';
import { dateKeyInTimeZone, formatDateOnly } from '../lib/date-utils';
import { getCurrentDeviceIdentity } from '../lib/devices';

const moduleContent: Record<GrowthModuleId, { title: string; description: string; icon: 'school' | 'menu-book' | 'check-box' }> = {
  study: {
    title: 'Study',
    description: 'Make room for focused learning, one session at a time.',
    icon: 'school',
  },
  read: {
    title: 'Read',
    description: 'Keep the books and articles you want to finish in one quiet place.',
    icon: 'menu-book',
  },
  tasks: {
    title: 'Tasks',
    description: 'Capture priorities, give them a date, and make progress visible.',
    icon: 'check-box',
  },
};

type GrowthSection = { id: string; label: string; title: string; description: string; icon: ComponentProps<typeof MaterialIcons>['name'] };
function sectionHref(moduleId: GrowthModuleId, sectionId: string): Href {
  const params = { section: sectionId };
  switch (moduleId) {
    case 'study': return { pathname: '/apps/study/[section]', params };
    case 'read': return { pathname: '/apps/read/[section]', params };
    case 'tasks': return { pathname: '/apps/tasks/[section]', params };
  }
}

const moduleSections: Record<GrowthModuleId, GrowthSection[]> = {
  study: [
    { id: 'today', label: 'Today', title: 'Your subjects', description: 'Start a focus session or add a subject.', icon: 'today' },
    { id: 'plan', label: 'Weekly plan', title: 'A plan that can move with you', description: 'Set a target and choose flexible study days.', icon: 'calendar-month' },
    { id: 'courses', label: 'Courses and lessons', title: 'Your learning map', description: 'Organize courses, lessons, and assignments.', icon: 'account-tree' },
    { id: 'practice', label: 'Practice and review', title: 'Practice and retrieval', description: 'Practice questions and spaced reviews.', icon: 'quiz' },
    { id: 'exams', label: 'Mock exams', title: 'Prepare with a focused attempt', description: 'Take a mock exam and review the result.', icon: 'assignment' },
    { id: 'tutor', label: 'Study tutor', title: 'Ask the Study tutor', description: 'Ask for a clear explanation.', icon: 'forum' },
    { id: 'resources', label: 'Documents', title: 'Your study documents', description: 'Manage private learning files.', icon: 'folder-open' },
    { id: 'document-help', label: 'Document help', title: 'Ask about a source', description: 'Ask source-based questions with citations.', icon: 'manage-search' },
    { id: 'learning-check', label: 'Learning check', title: 'Reflect on a study session', description: 'Save an answer or learning artifact.', icon: 'fact-check' },
  ],
  read: [
    { id: 'library', label: 'Reading list', title: 'Your reading list', description: 'Continue a book, update progress, or see recent sessions.', icon: 'bookmarks' },
    { id: 'discover', label: 'Discover', title: 'Find your next read', description: 'Explore public-domain books and free catalog metadata.', icon: 'explore' },
    { id: 'notes', label: 'Notes and reflection', title: 'Notes and reflection', description: 'Save notes, vocabulary, and reflections by page or section.', icon: 'edit-note' },
    { id: 'reader', label: 'Reader files', title: 'Your document reader', description: 'Open authorized files supported on this device.', icon: 'auto-stories' },
  ],
  tasks: [
    { id: 'today', label: 'Today', title: 'Your next steps', description: 'Capture tasks and clear today’s list.', icon: 'today' },
    { id: 'projects', label: 'Projects', title: 'Projects and milestones', description: 'Break outcomes into milestones and tasks.', icon: 'account-tree' },
    { id: 'focus', label: 'Task focus', title: 'Focus on one step', description: 'Link a server-recorded Focus session to a task.', icon: 'timer' },
    { id: 'breakdown', label: 'Break down a task', title: 'Make a task easier to start', description: 'Edit and approve AI drafted steps.', icon: 'format-list-bulleted' },
  ],
};

export function GrowthModuleScreen({ moduleId, sectionId }: { moduleId: GrowthModuleId; sectionId?: string }) {
  const content = moduleContent[moduleId];
  const { profileId } = useAuth();
  const { creditSettings } = useBloom();
  const { theme } = useBloomTheme();
  const accent = theme.modules[moduleId];
  const [items, setItems] = useState<GrowthItem[]>([]);
  const [sessions, setSessions] = useState<GrowthSession[]>([]);
  const [records, setRecords] = useState<GrowthRecord[]>([]);
  const [recordAttachments, setRecordAttachments] = useState<GrowthRecordAttachment[]>([]);
  const [documents, setDocuments] = useState<GrowthDocument[]>([]);
  const [studyPlan, setStudyPlan] = useState<StudyPlanSlot[]>([]);
  const [studyPlanChanges, setStudyPlanChanges] = useState<StudyPlanChange[]>([]);
  const [taskFocusSessions, setTaskFocusSessions] = useState<TaskFocusSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [snapshotTargetKey, setSnapshotTargetKey] = useState<string | null>(null);
  const [hasStaleSnapshot, setHasStaleSnapshot] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [notes, setNotes] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [targetMinutes, setTargetMinutes] = useState('');
  const [author, setAuthor] = useState('');
  const [genre, setGenre] = useState('');
  const [pageCount, setPageCount] = useState('');
  const [readingStatus, setReadingStatus] = useState<ReadingStatus>('want_to_read');
  const [projectTitle, setProjectTitle] = useState('');
  const [projectNotes, setProjectNotes] = useState('');
  const [tick, setTick] = useState(0);
  const [lastSyncCheckedAt, setLastSyncCheckedAt] = useState<number | null>(null);
  const [taskFilter, setTaskFilter] = useState<'today' | 'overdue' | 'upcoming' | 'postponed' | 'completed' | 'archived'>('today');
  const [taskPriority, setTaskPriority] = useState<TaskPriority>('medium');
  const [showMoreStudyTools, setShowMoreStudyTools] = useState(false);
  const snapshotTargetRef = useRef<string | null>(null);
  const viewedTargetRef = useRef<string | null>(null);
  const refreshRequest = useRef(0);
  const activeTargetKey = growthModuleSnapshotKey(profileId, moduleId);
  const hasSnapshot = Boolean(activeTargetKey && snapshotTargetKey === activeTargetKey);
  const sections = moduleSections[moduleId];
  const primarySections = moduleId === 'study' ? sections.slice(0, 4) : sections;
  const moreStudySections = moduleId === 'study' ? sections.slice(4) : [];
  const activeSection = sections.find((section) => section.id === sectionId);
  const pendingCreate = useRef<{ signature: string; requestId: string } | null>(null);
  const pendingStart = useRef<{ itemId: string; requestId: string } | null>(null);

  const refresh = useCallback(async () => {
    const request = ++refreshRequest.current;
    const targetKey = growthModuleSnapshotKey(profileId, moduleId);
    if (!profileId || !targetKey) {
      viewedTargetRef.current = null;
      snapshotTargetRef.current = null;
      setItems([]); setSessions([]); setRecords([]); setRecordAttachments([]); setDocuments([]); setStudyPlan([]); setStudyPlanChanges([]); setTaskFocusSessions([]); setSnapshotTargetKey(null); setLastSyncCheckedAt(null);
      setLoading(false); setHasStaleSnapshot(false); setError('Your Bloom profile is unavailable. Refresh your profile and try again.');
      return;
    }
    if (viewedTargetRef.current !== targetKey) {
      viewedTargetRef.current = targetKey;
      snapshotTargetRef.current = null;
      pendingCreate.current = null; pendingStart.current = null;
      setItems([]); setSessions([]); setRecords([]); setRecordAttachments([]); setDocuments([]); setStudyPlan([]); setStudyPlanChanges([]); setTaskFocusSessions([]); setSnapshotTargetKey(null); setLastSyncCheckedAt(null);
      setTitle(''); setNotes(''); setDueDate(''); setTargetMinutes(''); setAuthor(''); setGenre(''); setPageCount(''); setReadingStatus('want_to_read'); setProjectTitle(''); setProjectNotes(''); setTaskFilter('today'); setTaskPriority('medium');
    }
    setLoading(true); setError(null); setHasStaleSnapshot(false);
    try {
      const [result, nextDocuments] = await Promise.all([
        loadGrowthModule(profileId, moduleId), moduleId === 'tasks' ? Promise.resolve([]) : loadGrowthDocuments(moduleId),
      ]);
      if (request !== refreshRequest.current) return;
      setItems(result.items);
      setSessions(result.sessions);
      setRecords(result.records);
      setRecordAttachments(result.recordAttachments);
      setDocuments(nextDocuments);
      setStudyPlan(result.studyPlan);
      setStudyPlanChanges(result.studyPlanChanges);
      setTaskFocusSessions(result.taskFocusSessions);
      setSnapshotTargetKey(targetKey);
      snapshotTargetRef.current = targetKey;
      setHasStaleSnapshot(false);
      const now = Date.now();
      setTick(now);
      setLastSyncCheckedAt(now);
    } catch {
      if (request !== refreshRequest.current) return;
      setHasStaleSnapshot(snapshotTargetRef.current === targetKey);
      setError(`${content.title} data isn’t available right now. Retry in a moment.`);
    } finally { if (request === refreshRequest.current) setLoading(false); }
  }, [content.title, moduleId, profileId]);

  useFocusEffect(useCallback(() => {
    void refresh();
    return () => { refreshRequest.current += 1; };
  }, [refresh]));
  const activeSession = useMemo(() => sessions.find((session) => session.status === 'in_progress') ?? null, [sessions]);
  useEffect(() => {
    if (error) return;
    const timer = setInterval(() => setTick(Date.now()), activeSession ? 1000 : 60_000);
    return () => clearInterval(timer);
  }, [activeSession, error]);

  async function addItem() {
    const cleanTitle = title.trim();
    if (!cleanTitle) { setError(moduleId === 'study' ? 'Enter a subject name.' : moduleId === 'read' ? 'Enter a book or article title.' : 'Enter a task.'); return; }
    const parsedTarget = moduleId === 'study' ? Number(targetMinutes) : null;
    if (moduleId === 'study' && (!Number.isInteger(parsedTarget) || Number(parsedTarget) < 1 || Number(parsedTarget) > 10080)) {
      setError('Set a weekly target from 1 to 10,080 minutes.'); return;
    }
    if (moduleId === 'tasks' && dueDate.trim() && !isValidDate(dueDate.trim())) {
      setError('Enter a due date as YYYY-MM-DD, or leave it blank.'); return;
    }
    const parsedPageCount = moduleId === 'read' && pageCount.trim() ? Number(pageCount) : null;
    if (moduleId === 'read' && parsedPageCount !== null && (!Number.isInteger(parsedPageCount) || parsedPageCount < 1 || parsedPageCount > 100000)) {
      setError('Enter a total page count from 1 to 100,000, or leave it blank.'); return;
    }
    const signature = JSON.stringify([moduleId, cleanTitle, notes.trim(), moduleId === 'tasks' ? dueDate.trim() || null : null, parsedTarget]);
    if (pendingCreate.current?.signature !== signature) pendingCreate.current = { signature, requestId: randomUUID() };
    setSaving(true); setError(null); setNotice(null);
    try {
      const createdId = await createGrowthItem({ moduleId, title: cleanTitle, notes: notes.trim(), dueDate: moduleId === 'tasks' ? dueDate.trim() || null : null, targetMinutes: parsedTarget, requestId: pendingCreate.current.requestId });
      if (moduleId === 'tasks') await updateGrowthTaskMetadata(createdId, taskPriority, null);
      if (moduleId === 'read') await updateGrowthReadingDetails(createdId, { author: author.trim(), genre: genre.trim(), pageCount: parsedPageCount,
        currentPage: parsedPageCount ? (readingStatus === 'finished' ? parsedPageCount : 0) : null, status: readingStatus });
      pendingCreate.current = null;
      setTitle(''); setNotes(''); setDueDate(''); setTargetMinutes(''); setTaskPriority('medium'); setAuthor(''); setGenre(''); setPageCount(''); setReadingStatus('want_to_read');
      setNotice(moduleId === 'study' ? 'Subject added.' : moduleId === 'read' ? 'Added to your reading list.' : 'Task added.');
      await refresh();
    } catch {
      setError('Could not save this item. Your entry is still in the form; check your connection and try again.');
    } finally { setSaving(false); }
  }

  async function addProject() {
    if (!projectTitle.trim()) { setError('Enter a project name.'); return; }
    setSaving(true); setError(null); setNotice(null);
    try {
      await createGrowthProject({ title: projectTitle.trim(), notes: projectNotes.trim(), dueDate: null, requestId: randomUUID() });
      setProjectTitle(''); setProjectNotes(''); setNotice('Project added. Add milestones and tasks underneath it.'); await refresh();
    } catch { setError('Could not save this project. Your entry is still in the form; check your connection and try again.'); }
    finally { setSaving(false); }
  }

  async function beginSession(item: GrowthItem) {
    setSaving(true); setError(null); setNotice(null);
    try {
      if (pendingStart.current?.itemId !== item.id) pendingStart.current = { itemId: item.id, requestId: randomUUID() };
      if (!profileId) throw new Error('Your Bloom profile is unavailable.');
      if (moduleId === 'read' && item.reading_status !== 'currently_reading') {
        await updateGrowthReadingDetails(item.id, { author: item.author, genre: item.genre, pageCount: item.page_count,
          currentPage: item.reading_status === 'finished' ? (item.page_count ? 0 : null) : item.current_page, status: 'currently_reading' });
      }
      const sourceDevice = await getCurrentDeviceIdentity(profileId);
      await startGrowthSession(moduleId as 'study' | 'read', item.id, sourceDevice, pendingStart.current.requestId);
      pendingStart.current = null;
      await refresh();
      setNotice('Session started. Bloom records its start on the server.');
    } catch (cause) {
      setError(cause instanceof Error && cause.message.includes('active session')
        ? 'Finish or cancel the current session before starting another.'
        : 'Could not start the session. Check your connection and try again.');
    } finally { setSaving(false); }
  }

  async function endSession(session: GrowthSession, cancel: boolean) {
    setSaving(true); setError(null); setNotice(null);
    try {
      if (cancel) {
        await cancelGrowthSession(session.id);
        setNotice('Session cancelled; it was not added to your completed history.');
      } else {
        const result = await finishGrowthSession(session.id);
        setNotice(`Session saved · ${formatDuration(result.durationSeconds)}. No screen-time credits were awarded.`);
      }
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error && cause.message.toLowerCase().includes('session has expired')
        ? 'This server session expired after 12 hours. Cancel it to clear the session, then start a new one.'
        : 'Could not save the session. Your server session remains available to retry.');
    } finally { setSaving(false); }
  }

  async function changeItem(item: GrowthItem, update: Parameters<typeof updateGrowthItem>[1], success: string) {
    setSaving(true); setError(null); setNotice(null);
    try { await updateGrowthItem(item, update); setNotice(success); await refresh(); }
    catch { setError('Could not update this item. Check your connection and retry.'); }
    finally { setSaving(false); }
  }

  async function changeTaskMetadata(item: GrowthItem, priority: TaskPriority, postponedUntil: string | null, success: string) {
    setSaving(true); setError(null); setNotice(null);
    try { await updateGrowthTaskMetadata(item.id, priority, postponedUntil); setNotice(success); await refresh(); }
    catch { setError('Could not update this task. Check your connection and retry.'); }
    finally { setSaving(false); }
  }

  async function changeReadingStatus(item: GrowthItem, status: ReadingStatus, success: string) {
    setSaving(true); setError(null); setNotice(null);
    try {
      await updateGrowthReadingDetails(item.id, { author: item.author, genre: item.genre, pageCount: item.page_count, currentPage: item.current_page, status });
      setNotice(success); await refresh();
    } catch { setError('Could not update this reading item. Check your connection and retry.'); }
    finally { setSaving(false); }
  }

  async function changeReadingProgress(item: GrowthItem, pageCount: number, currentPage: number) {
    setSaving(true); setError(null); setNotice(null);
    try {
      await updateGrowthReadingDetails(item.id, { author: item.author, genre: item.genre, pageCount, currentPage, status: 'currently_reading' });
      setNotice(`Saved page ${currentPage} of ${pageCount} for ${item.title}.`); await refresh();
    } catch { setError('Could not save these pages. Check the page numbers and try again.'); }
    finally { setSaving(false); }
  }

  async function restartReading(item: GrowthItem) {
    setSaving(true); setError(null); setNotice(null);
    try {
      await updateGrowthReadingDetails(item.id, { author: item.author, genre: item.genre, pageCount: item.page_count,
        currentPage: item.page_count ? 0 : null, status: 'want_to_read' });
      setNotice(`${item.title} is back on your Want to read list.`); await refresh();
    } catch { setError('Could not restart this book. Check your connection and retry.'); }
    finally { setSaving(false); }
  }

  const openItems = items.filter((item) => item.state === 'active');
  const completedItems = items.filter((item) => item.state === 'completed');
  const sessionItem = activeSession ? items.find((item) => item.id === activeSession.item_id) : null;
  const readOnly = !hasSnapshot || hasStaleSnapshot;
  const elapsed = activeSession ? Math.max(0, Math.floor(((tick || Date.parse(activeSession.started_at)) - Date.parse(activeSession.started_at)) / 1000)) : 0;
  const sessionsByItem = new Map(items.map((item) => [item.id, item]));
  const taskTimeZone = creditSettings?.credit_timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';
  const todayInProfileTimeZone = dateKeyInTimeZone(tick, taskTimeZone);
  const visibleTasks = moduleId !== 'tasks' ? [] : items.filter((item) => {
    if (!['task', 'checklist'].includes(item.item_type)) return false;
    if (taskFilter === 'archived') return item.state === 'archived';
    if (taskFilter === 'completed') return item.state === 'completed';
    if (item.state !== 'active') return false;
    const postponed = Boolean(item.postponed_until && item.postponed_until >= todayInProfileTimeZone);
    if (taskFilter === 'postponed') return postponed;
    if (postponed) return false;
    if (taskFilter === 'overdue') return Boolean(item.due_date && item.due_date < todayInProfileTimeZone);
    if (taskFilter === 'upcoming') return Boolean(item.due_date && item.due_date > todayInProfileTimeZone);
    return !item.due_date || item.due_date === todayInProfileTimeZone;
  });
  const activeStudyItems = openItems.filter((item) => ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type));
  const activeReadings = openItems.filter((item) => item.item_type === 'reading');
  const completedReadings = completedItems.filter((item) => item.item_type === 'reading');
  const wantToRead = activeReadings.filter((item) => (item.reading_status ?? (item.progress_percent > 0 ? 'currently_reading' : 'want_to_read')) === 'want_to_read');
  const currentlyReading = activeReadings.filter((item) => (item.reading_status ?? (item.progress_percent > 0 ? 'currently_reading' : 'want_to_read')) === 'currently_reading');
  const completedStudySessions = sessions.filter((session) => session.status === 'completed');
  const openTaskCount = openItems.filter((item) => ['task', 'checklist'].includes(item.item_type)).length;

  return <Screen safeAreaTop={false}>
    <View style={[styles.moduleHero, { backgroundColor: accent.surface, borderColor: theme.colors.border }]}>
      <View style={styles.moduleTitleRow}>
        <View style={[styles.moduleIcon, { backgroundColor: theme.colors.surface }]}><MaterialIcons name={content.icon} size={25} color={accent.deep} /></View>
        <View style={sharedStyles.grow}>
          <Eyebrow>{sectionId ? `${content.title} section` : 'Your Bloom space'}</Eyebrow>
          <Heading>{content.title}</Heading>
        </View>
        <Button label={sectionId ? `${content.title} home` : 'All apps'} variant="tertiary"
          onPress={() => router.replace(sectionId ? `/apps/${moduleId}` as Href : '/apps' as Href)} />
      </View>
      {!sectionId && <Body>{content.description}</Body>}
    </View>

    {sectionId && activeSection && <View style={styles.sectionHeading}>
      <Eyebrow>{activeSection.label}</Eyebrow>
      <Heading>{activeSection.title}</Heading>
      <Body>{activeSection.description}</Body>
    </View>}

    {loading && <ActivityIndicator color={accent.deep} />}
    {error && <View style={[styles.connectionNotice, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
      <MaterialIcons name="cloud-off" size={19} color={theme.colors.dangerText} />
      <View style={sharedStyles.grow}>
      <ErrorText>{error}</ErrorText>
        <Body>{hasStaleSnapshot ? 'Showing the last server snapshot. Reconnect to edit.' : 'Read-only until connected. Changes are not saved offline.'}</Body>
      </View>
      <Button label="Retry" variant="tertiary" onPress={() => void refresh()} />
    </View>}
    {notice && <Panel><Body>{notice}</Body></Panel>}

    {!sectionId && !loading && <>
      <DashboardSummary moduleId={moduleId} hasSnapshot={hasSnapshot}
        activeSession={activeSession} activeStudyItems={activeStudyItems} activeReadings={activeReadings}
        completedReadings={completedReadings} completedStudySessions={completedStudySessions.length}
        openTaskCount={openTaskCount} tasksDueToday={visibleTasks.length} />
      <View style={styles.dashboardSection}>
        <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Eyebrow>Explore {content.title}</Eyebrow><Heading>Choose a space</Heading></View>
        </View>
        <View style={styles.dashboardGrid}>
          {primarySections.map((section) => <View key={section.id} style={styles.dashboardTile}>
            <FeatureTile title={section.label} subtitle={section.description} icon={section.icon} accentColor={accent.deep} backgroundColor={accent.surface}
              onPress={() => router.push(sectionHref(moduleId, section.id))} />
          </View>)}
        </View>
        {moreStudySections.length > 0 && <View style={styles.moreTools}>
          <Button label={showMoreStudyTools ? 'Hide extra Study tools' : `Show all Study tools · ${moreStudySections.length}`} variant="secondary"
            onPress={() => setShowMoreStudyTools((current) => !current)} />
          {!showMoreStudyTools && <Body>Mock exams · Tutor · Documents · Document help · Learning check</Body>}
          {showMoreStudyTools && <View style={styles.dashboardGrid}>
            {moreStudySections.map((section) => <View key={section.id} style={styles.dashboardTile}>
              <FeatureTile title={section.label} subtitle={section.description} icon={section.icon} accentColor={accent.deep} backgroundColor={accent.surface}
                onPress={() => router.push(sectionHref(moduleId, section.id))} />
            </View>)}
          </View>}
        </View>}
      </View>
    </>}

    {sectionId && !activeSection && <Panel><Eyebrow>{content.title}</Eyebrow><Label>Section not found</Label><Body>This page isn’t part of this pillar.</Body></Panel>}

    {!loading && sectionId === 'today' && moduleId === 'study' && <>
      {activeSession && <Panel>
        <Eyebrow>Focus session · in progress</Eyebrow>
        <Heading>{formatElapsed(elapsed)}</Heading>
        <Label>{sessionItem?.title ?? 'Study subject'}</Label>
        <Body>Started on {activeSession.source_device_name} · server time {new Date(activeSession.started_at).toLocaleString()}{lastSyncCheckedAt ? ` · last checked ${new Date(lastSyncCheckedAt).toLocaleString()}` : ''}.</Body>
        <Button label="Finish session" onPress={() => void endSession(activeSession, false)} busy={saving} disabled={readOnly} />
        <Button label="Cancel session" variant="secondary" onPress={() => void endSession(activeSession, true)} disabled={saving || readOnly} />
      </Panel>}
      <Panel>
        <Eyebrow>Add to Study</Eyebrow>
        <Label>Add a subject</Label>
        <Field label="Subject" value={title} onChangeText={setTitle} placeholder="e.g. Biology" maxLength={120} editable={!readOnly} />
        <Field label="Weekly study target in minutes" value={targetMinutes} onChangeText={setTargetMinutes} keyboardType="number-pad" placeholder="e.g. 240" editable={!readOnly} />
        <Field label="Notes (optional)" value={notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Topics or a short plan" editable={!readOnly} />
        <Button label="Add subject" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
      </Panel>
      <Panel>
        <Eyebrow>Current subjects · {openItems.length}</Eyebrow>
        {openItems.filter((item) => ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)).length === 0 ? <Body>Add your first subject to begin a focus session.</Body> : openItems.filter((item) => ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)).map((item) => <View key={item.id} style={styles.itemRow}>
          <View style={sharedStyles.grow}><Label>{item.title}</Label><Body>{item.target_minutes} min weekly target{item.notes ? ` · ${item.notes}` : ''}</Body></View>
          <Button label="Start" variant="tertiary" disabled={readOnly || saving || Boolean(activeSession)} onPress={() => void beginSession(item)} />
        </View>)}
      </Panel>
      <SessionHistory sessions={sessions} items={sessionsByItem} moduleId="study" />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'plan' && <>
      <StudyPlanPanel key={profileId} items={items} slots={studyPlan} changes={studyPlanChanges} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'courses' && <>
      <GrowthHierarchyPanel moduleId="study" items={items} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'practice' && <StudyPracticeReviewPanel items={items} records={records} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && sectionId === 'exams' && <>
      <MockExamPanel key={profileId} profileId={profileId ?? ''} items={items} records={records} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'learning-check' && <>
      <GrowthRecordPanel profileId={profileId} moduleId="study" items={items} records={records} documents={documents} attachments={recordAttachments} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'tutor' && <StudyTutorPanel key={profileId} profileId={profileId ?? ''} items={items} readOnly={readOnly} />}

    {!loading && moduleId === 'study' && sectionId === 'resources' && <>
      <GrowthDocumentLibraryPanel moduleId="study" items={items} records={records} documents={documents} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && sectionId === 'document-help' && <>
      <StudyDocumentHelpPanel key={`study-document-help:${profileId}`} profileId={profileId} documents={documents} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'read' && sectionId === 'library' && <>
      {activeSession && <Panel>
        <Eyebrow>Reading session · in progress</Eyebrow>
        <Heading>{formatElapsed(elapsed)}</Heading>
        <Label>{sessionItem?.title ?? 'Reading item'}</Label>
        <Body>Started on {activeSession.source_device_name} · server time {new Date(activeSession.started_at).toLocaleString()}{lastSyncCheckedAt ? ` · last checked ${new Date(lastSyncCheckedAt).toLocaleString()}` : ''}. Finish to save the server-timed reading session.</Body>
        <Button label="Finish reading session" onPress={() => void endSession(activeSession, false)} busy={saving} disabled={readOnly} />
        <Button label="Cancel session" variant="secondary" onPress={() => void endSession(activeSession, true)} disabled={saving || readOnly} />
      </Panel>}
      <Panel>
        <Eyebrow>Reading list</Eyebrow>
        <Label>Add a book or article</Label>
        <Field label="Title" value={title} onChangeText={setTitle} placeholder="What would you like to read?" maxLength={120} editable={!readOnly} />
        <Field label="Author (optional)" value={author} onChangeText={setAuthor} maxLength={160} placeholder="Author" editable={!readOnly} />
        <Field label="Genre (optional)" value={genre} onChangeText={setGenre} maxLength={80} placeholder="Fiction, history, science…" editable={!readOnly} />
        <Field label="Total pages (optional)" value={pageCount} onChangeText={setPageCount} keyboardType="number-pad" maxLength={6} placeholder="e.g. 320" editable={!readOnly} />
        <Body>Reading status</Body>
        <View style={styles.filterRow} accessibilityRole="radiogroup" accessibilityLabel="New reading status">
          {(['want_to_read', 'currently_reading', 'finished'] as const).map((status) => <Pressable key={status} accessibilityRole="radio"
            accessibilityState={{ selected: readingStatus === status }} disabled={readOnly || saving} onPress={() => setReadingStatus(status)}
            style={[styles.filter, { backgroundColor: readingStatus === status ? theme.colors.surfaceTinted : theme.colors.surface, borderColor: readingStatus === status ? accent.deep : theme.colors.border }]}>
            <Label>{readingStatusLabel(status)}</Label>
          </Pressable>)}
        </View>
        <Field label="Source or notes (optional)" value={notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Publication or a reminder" editable={!readOnly} />
        <Button label="Add to reading list" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
      </Panel>
      <Panel>
        <Eyebrow>Want to read · {wantToRead.length}</Eyebrow>
        {wantToRead.length === 0 ? <Body>Books you plan to read will appear here.</Body> : wantToRead.map((item) => <ReadingItemCard key={item.id} item={item} saving={saving} readOnly={readOnly} startLabel="Start reading"
          onStart={() => void changeReadingStatus(item, 'currently_reading', `${item.title} moved to Currently reading.`)}
          onRead={() => void beginSession(item)} onProgress={(total, current) => void changeReadingProgress(item, total, current)} />)}
      </Panel>
      <Panel>
        <Eyebrow>Currently reading · {currentlyReading.length}</Eyebrow>
        {currentlyReading.length === 0 ? <Body>When you start a book, it will appear here.</Body> : currentlyReading.map((item) => <ReadingItemCard key={item.id} item={item} saving={saving} readOnly={readOnly} startLabel="Move to Want to read"
          onStart={() => void changeReadingStatus(item, 'want_to_read', `${item.title} moved to Want to read.`)}
          onRead={() => void beginSession(item)} onFinish={() => void changeReadingStatus(item, 'finished', `${item.title} marked as finished.`)}
          onProgress={(total, current) => void changeReadingProgress(item, total, current)} />)}
      </Panel>
      <Panel>
        <Eyebrow>Finished · {completedReadings.length}</Eyebrow>
        {completedReadings.length === 0 ? <Body>Books you finish will be collected here.</Body> : completedReadings.map((item) => <ReadingItemCard key={item.id} item={item} saving={saving} readOnly={readOnly} startLabel="Read again"
          onStart={() => void restartReading(item)}
          onRead={() => void beginSession(item)} onProgress={(total, current) => void changeReadingProgress(item, total, current)} />)}
      </Panel>
      <SessionHistory sessions={sessions} items={sessionsByItem} moduleId="read" />
    </>}

    {!loading && moduleId === 'read' && sectionId === 'discover' && <ReadingDiscoveryPanel key={profileId} profileId={profileId} items={items} records={records} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'read' && sectionId === 'notes' && <GrowthRecordPanel profileId={profileId} moduleId="read" items={items} records={records} documents={documents} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'read' && sectionId === 'reader' && <GrowthDocumentLibraryPanel moduleId="read" items={items} records={records} documents={documents} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'tasks' && sectionId === 'today' && <>
      <Panel>
        <Eyebrow>Quick add</Eyebrow>
        <Label>What needs doing?</Label>
        <Field label="Task" value={title} onChangeText={setTitle} placeholder="A small next step" maxLength={120} editable={!readOnly} />
        <Body>Priority</Body>
        <View style={styles.filterRow} accessibilityRole="radiogroup" accessibilityLabel="New task priority">
          {(['low', 'medium', 'high', 'urgent'] as const).map((value) => <Pressable key={value} accessibilityRole="radio" accessibilityState={{ selected: taskPriority === value }} onPress={() => setTaskPriority(value)} style={[styles.filter, { backgroundColor: taskPriority === value ? theme.colors.surfaceTinted : theme.colors.surface, borderColor: taskPriority === value ? accent.deep : theme.colors.border }]}>
            <Label>{value[0].toUpperCase() + value.slice(1)}</Label>
          </Pressable>)}
        </View>
        <Field label="Due date (optional)" value={dueDate} onChangeText={setDueDate} placeholder="YYYY-MM-DD" autoCapitalize="none" maxLength={10} editable={!readOnly} />
        <Field label="Notes (optional)" value={notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Add a useful detail" editable={!readOnly} />
        <Button label="Add task" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
      </Panel>
      <Panel>
        <Eyebrow>Tasks · {items.filter((item) => item.item_type === 'task' && item.state === 'active').length} open · {items.filter((item) => item.item_type === 'task' && item.state === 'completed').length} completed</Eyebrow>
        <View style={styles.filterRow} accessibilityRole="tablist" accessibilityLabel="Task view">
          {(['today', 'overdue', 'upcoming', 'postponed', 'completed', 'archived'] as const).map((filter) => <Pressable key={filter} accessibilityRole="tab" accessibilityState={{ selected: taskFilter === filter }} onPress={() => setTaskFilter(filter)} style={[styles.filter, { backgroundColor: taskFilter === filter ? theme.colors.surfaceTinted : theme.colors.surface, borderColor: taskFilter === filter ? accent.deep : theme.colors.border }]}>
            <Label>{filter[0].toUpperCase() + filter.slice(1)}</Label>
          </Pressable>)}
        </View>
        {visibleTasks.length === 0 ? <Body>{taskFilter === 'completed' ? 'Finished tasks will stay here.' : taskFilter === 'archived' ? 'Archived tasks will appear here.' : taskFilter === 'postponed' ? 'No tasks are postponed.' : taskFilter === 'upcoming' ? 'Nothing is scheduled for a later date.' : taskFilter === 'overdue' ? 'You’re caught up on overdue tasks.' : 'Your next priorities will appear here.'}</Body> : visibleTasks.map((item) => <View key={item.id} style={styles.itemRow}>
          <Pressable accessibilityRole="checkbox" accessibilityLabel={`${item.state === 'completed' ? 'Reopen' : 'Complete'} ${item.title}`} accessibilityState={{ checked: item.state === 'completed', disabled: readOnly || saving }} disabled={readOnly || saving} onPress={() => void changeItem(item, { state: item.state === 'completed' ? 'active' : 'completed', progressPercent: item.state === 'completed' ? 0 : 100 }, item.state === 'completed' ? 'Task reopened.' : 'Task completed.')} style={[styles.check, { borderColor: item.state === 'completed' ? accent.deep : theme.colors.borderStrong, backgroundColor: item.state === 'completed' ? accent.surface : theme.colors.surface }]}>
            {item.state === 'completed' && <MaterialIcons name="check" size={17} color={accent.deep} />}
          </Pressable>
          <View style={sharedStyles.grow}>
            <Label>{item.title}</Label>
            <Body>{item.due_date ? `Due ${formatDateOnly(item.due_date)}` : 'No due date'} · {item.priority} priority{item.postponed_until && item.postponed_until >= todayInProfileTimeZone ? ` · postponed until ${formatDateOnly(item.postponed_until)}` : ''}{item.notes ? ` · ${item.notes}` : ''}</Body>
            <View style={styles.priorityRow} accessibilityRole="radiogroup" accessibilityLabel={`${item.title} priority`}>
              {(['low', 'medium', 'high', 'urgent'] as const).map((priority) => <Pressable key={priority} accessibilityRole="radio" accessibilityState={{ selected: item.priority === priority, disabled: readOnly || saving }} disabled={readOnly || saving || item.priority === priority} onPress={() => void changeTaskMetadata(item, priority, item.postponed_until, `${item.title} priority updated.`)} style={[styles.priorityChoice, { borderColor: item.priority === priority ? accent.deep : theme.colors.border, backgroundColor: item.priority === priority ? accent.surface : theme.colors.surface }]}>
                <Body>{priority[0].toUpperCase() + priority.slice(1)}</Body>
              </Pressable>)}
            </View>
            <View style={styles.actionRow}>
              {item.state === 'archived' ? <Button label="Restore" variant="tertiary" disabled={readOnly || saving} onPress={() => void changeItem(item, { state: 'active' }, 'Task restored.')} /> : <>
                {item.state === 'active' && (item.postponed_until && item.postponed_until >= todayInProfileTimeZone
                  ? <Button label="Bring back" variant="tertiary" disabled={readOnly || saving} onPress={() => void changeTaskMetadata(item, item.priority, null, 'Task moved back to your active list.')} />
                  : <Button label="Postpone 1 day" variant="tertiary" disabled={readOnly || saving} onPress={() => {
                    const tomorrow = new Date(`${todayInProfileTimeZone}T00:00:00.000Z`); tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
                    void changeTaskMetadata(item, item.priority, tomorrow.toISOString().slice(0, 10), 'Task postponed until tomorrow.');
                  }} />)}
                <Button label="Archive" variant="tertiary" disabled={readOnly || saving} onPress={() => void changeItem(item, { state: 'archived' }, 'Task archived.')} />
              </>}
            </View>
          </View>
        </View>)}
      </Panel>
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'projects' && <>
      <Panel>
        <Eyebrow>New project</Eyebrow>
        <Field label="Project name" value={projectTitle} onChangeText={setProjectTitle} maxLength={120} placeholder="A larger outcome" editable={!readOnly} />
        <Field label="Notes (optional)" value={projectNotes} onChangeText={setProjectNotes} multiline maxLength={2000} editable={!readOnly} />
        <Button label="Add project" variant="secondary" onPress={() => void addProject()} busy={saving} disabled={readOnly} />
      </Panel>
      <GrowthHierarchyPanel moduleId="tasks" items={items} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'focus' && <>
      <TaskFocusPanel items={items} sessions={taskFocusSessions} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'breakdown' && <>
      <TaskBreakdownPanel key={profileId} profileId={profileId} items={items} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}
  </Screen>;
}

function DashboardSummary({ moduleId, hasSnapshot, activeSession, activeStudyItems, activeReadings, completedReadings, completedStudySessions, openTaskCount, tasksDueToday }:
  { moduleId: GrowthModuleId; hasSnapshot: boolean; activeSession: GrowthSession | null; activeStudyItems: GrowthItem[];
    activeReadings: GrowthItem[]; completedReadings: GrowthItem[]; completedStudySessions: number; openTaskCount: number; tasksDueToday: number }) {
  if (!hasSnapshot) return null;
  return <Panel>
    {moduleId === 'study' && <>
      <Eyebrow>Your learning</Eyebrow>
      <View style={styles.summaryMetrics}>
        <SummaryMetric label="Learning items" value={activeStudyItems.length.toString()} />
        <SummaryMetric label="Sessions done" value={completedStudySessions.toString()} />
      </View>
      {activeSession && <Body>A Study session is in progress. Open Today to finish it.</Body>}
    </>}
    {moduleId === 'read' && <>
      <Eyebrow>Your shelf</Eyebrow>
      <View style={styles.summaryMetrics}>
        <SummaryMetric label="Reading now" value={activeReadings.length.toString()} />
        <SummaryMetric label="Finished" value={completedReadings.length.toString()} />
      </View>
    </>}
    {moduleId === 'tasks' && <>
      <Eyebrow>Your tasks</Eyebrow>
      <View style={styles.summaryMetrics}>
        <SummaryMetric label="Open" value={openTaskCount.toString()} />
        <SummaryMetric label="Due today" value={tasksDueToday.toString()} />
      </View>
    </>}
  </Panel>;
}

function SummaryMetric({ label, value }: { label: string; value: string }) {
  return <View style={styles.summaryMetric}>
    <Eyebrow>{label}</Eyebrow>
    <Label>{value}</Label>
  </View>;
}

function SessionHistory({ sessions, items, moduleId }: { sessions: GrowthSession[]; items: Map<string, GrowthItem>; moduleId: 'study' | 'read' }) {
  const completed = sessions.filter((session) => session.status === 'completed');
  const name = moduleId === 'study' ? 'Study' : 'Reading';
  return <Panel>
    <Eyebrow>Recent {name.toLowerCase()} sessions</Eyebrow>
    {completed.length === 0 ? <Body>Finished sessions will appear here.</Body> : completed.slice(0, 8).map((session) => <View key={session.id} style={styles.itemRow}>
      <View style={sharedStyles.grow}><Label>{items.get(session.item_id)?.title ?? name}</Label><Body>{session.completed_at ? new Date(session.completed_at).toLocaleString() : ''}</Body></View>
      <Label>{formatDuration(session.duration_seconds ?? 0)}</Label>
    </View>)}
  </Panel>;
}

function ReadingItemCard({ item, readOnly, saving, startLabel, onStart, onRead, onFinish, onProgress }: {
  item: GrowthItem; readOnly: boolean; saving: boolean; startLabel: string;
  onStart: () => void; onRead: () => void; onFinish?: () => void; onProgress: (pageCount: number, currentPage: number) => void;
}) {
  const [editingPages, setEditingPages] = useState(false);
  const [pageCountText, setPageCountText] = useState(item.page_count?.toString() ?? '');
  const [currentPageText, setCurrentPageText] = useState(item.current_page?.toString() ?? '0');
  const [pageError, setPageError] = useState<string | null>(null);
  const { theme } = useBloomTheme();
  const percent = Math.max(0, Math.min(100, item.progress_percent));

  function savePages() {
    const pageCount = Number(pageCountText);
    const currentPage = Number(currentPageText);
    if (!Number.isInteger(pageCount) || pageCount < 1 || pageCount > 100000
      || !Number.isInteger(currentPage) || currentPage < 0 || currentPage > pageCount) {
      setPageError('Enter a current page from 0 through the total page count.'); return;
    }
    setPageError(null);
    onProgress(pageCount, currentPage);
    setEditingPages(false);
  }

  return <View style={styles.readingItem}>
    <View style={sharedStyles.row}>
      <View style={sharedStyles.grow}><Label>{item.title}</Label>
        <Body>{[item.author, item.genre, item.notes].filter(Boolean).join(' · ') || 'No author or notes added'}</Body>
        {item.page_count ? <Body>Page {item.current_page ?? 0} of {item.page_count}</Body> : null}
      </View>
      <Label>{Math.round(percent)}%</Label>
    </View>
    <ProgressBar value={percent} label={`${item.title} reading progress`} color={theme.modules.read.deep} />
    <View style={styles.actionRow}>
      <Button label={startLabel} variant="tertiary" disabled={readOnly || saving} onPress={onStart} />
      <Button label="Start session" variant="secondary" disabled={readOnly || saving} onPress={onRead} />
      {onFinish && <Button label="Mark finished" variant="tertiary" disabled={readOnly || saving} onPress={onFinish} />}
      {!editingPages && <Button label="Update pages" variant="tertiary" disabled={readOnly || saving} onPress={() => setEditingPages(true)} />}
    </View>
    {editingPages && <View style={[styles.pageEditor, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
      <Field label="Current page" value={currentPageText} onChangeText={setCurrentPageText} keyboardType="number-pad" maxLength={6} editable={!readOnly && !saving} />
      <Field label="Total pages" value={pageCountText} onChangeText={setPageCountText} keyboardType="number-pad" maxLength={6} editable={!readOnly && !saving} />
      {pageError && <ErrorText>{pageError}</ErrorText>}
      <View style={styles.actionRow}>
        <Button label="Save page progress" onPress={savePages} disabled={readOnly || saving} />
        <Button label="Cancel" variant="tertiary" onPress={() => { setPageError(null); setEditingPages(false); }} disabled={saving} />
      </View>
    </View>}
  </View>;
}

function readingStatusLabel(status: ReadingStatus) {
  if (status === 'currently_reading') return 'Currently reading';
  if (status === 'finished') return 'Finished';
  return 'Want to read';
}

function formatDuration(seconds: number) {
  const minutes = Math.floor(seconds / 60);
  const remainingSeconds = seconds % 60;
  return minutes ? `${minutes} min${remainingSeconds ? ` ${remainingSeconds} sec` : ''}` : `${remainingSeconds} sec`;
}

function isValidDate(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

const styles = StyleSheet.create({
  moduleHero: { borderWidth: 1, borderRadius: 24, padding: 20, gap: 12 },
  moduleTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  moduleIcon: { width: 48, height: 48, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  sectionHeading: { gap: 5, paddingTop: 2 },
  connectionNotice: { borderWidth: 1, borderRadius: 16, paddingHorizontal: 12, paddingVertical: 10, flexDirection: 'row', alignItems: 'center', gap: 8 },
  dashboardSection: { gap: 12 },
  moreTools: { gap: 8 },
  dashboardGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  dashboardTile: { width: '48%', minWidth: 145, flexGrow: 1, flexBasis: 150 },
  summaryMetrics: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  summaryMetric: { width: '46%', flexGrow: 1, flexBasis: '46%', gap: 4 },
  itemRow: { flexDirection: 'row', alignItems: 'center', gap: 12, borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: '#E4E8F3', paddingVertical: 10 },
  readingItem: { gap: 10, paddingVertical: 8 },
  actionRow: { flexDirection: 'row', gap: 8, flexWrap: 'wrap' },
  pageEditor: { gap: 8, padding: 12, borderRadius: 14, borderWidth: 1 },
  filterRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  filter: { minHeight: 44, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderRadius: 999, paddingHorizontal: 14 },
  priorityRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6, paddingVertical: 6 },
  priorityChoice: { borderWidth: 1, borderRadius: 999, paddingHorizontal: 10, paddingVertical: 5 },
  check: { width: 44, height: 44, borderRadius: 14, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
});
