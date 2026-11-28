import { getAppLocale } from '../lib/locale-context';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { randomUUID } from 'expo-crypto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, ImageBackground, Modal, Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { router, useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { Body, Button, ErrorText, Eyebrow, FeatureTile, Field, Heading, Label, LocalizedText as Text, Panel, ProgressBar, Screen, sharedStyles, useIsDesktopColumns, useIsDesktopLayout, useReduceMotionPreference } from './bloom-ui';
import { OfflinePendingBanner } from './offline-pending-banner';
import { moduleContent, moduleSections, sectionHref } from './study-workflow-config';
import { cancelGrowthSession, createGrowthItem, createGrowthProject, finishGrowthSession, formatElapsed, getReadingStatus, GrowthDataQueryError, loadGrowthDocuments, loadGrowthModule, loadStudyPlanModule, loadGrowthRewards, startGrowthSession, updateGrowthItem, updateGrowthReadingDetails, updateGrowthTaskMetadata, type GrowthDocument, type GrowthItem, type GrowthModuleId, type GrowthSession, type GrowthRecord, type GrowthRecordAttachment, type StudyPlanChange, type StudyPlanSlot, type TaskFocusSession, type TaskPriority, type ReadingStatus, type GrowthRewardEvent } from '../lib/growth-modules';
import { GrowthHierarchyPanel, GrowthRecordPanel, ReadingDiscoveryPanel, StudyPlanPanel, StudyPracticeReviewPanel, StudyTutorPanel, TaskBreakdownPanel, TaskFocusPanel } from './growth-feature-panels';
import { MockExamPanel } from './mock-exam-panel';
import { GrowthDocumentLibraryPanel, StudyDocumentHelpPanel } from './growth-document-panels';
import { growthModuleSnapshotKey } from '../lib/growth-module-state';
import { useAuth } from '../lib/auth';
import { useBloomTheme } from '../lib/theme-context';
import { loadStudySubjectArtworkPreferences, saveStudySubjectArtworkPreference } from '../lib/study-subject-artwork';
import { studySubjectArtworks } from '../lib/study-subject-artworks';
import { useBloom } from '../lib/bloom-context';
import { dateKeyInTimeZone, formatDateOnly } from '../lib/date-utils';
import { getCurrentDeviceIdentity } from '../lib/devices';
import { flushOfflineActivitiesForProfile, getPendingOfflineCount, queueOfflineActivityForProfile } from '../lib/offline-sync-service';
import { bloomPillarCollectionImages } from '../assets/bloom-images';
import { SubjectArtwork, suggestStudySubjectArtwork } from './study-subject-artwork';

function currentEpochMs() {
  return Date.now();
}

export function GrowthModuleScreen({ moduleId, sectionId }: { moduleId: GrowthModuleId; sectionId?: string }) {
  const content = moduleContent[moduleId];
  const routeParams = useLocalSearchParams<{ itemId?: string | string[]; documentId?: string | string[]; durationSeconds?: string | string[]; rewardStatus?: string | string[]; rewardMinutes?: string | string[] }>();
  const contextItemId = typeof routeParams.itemId === 'string' ? routeParams.itemId : undefined;
  const contextDocumentId = typeof routeParams.documentId === 'string' ? routeParams.documentId : undefined;
  const durationSecondsParam = typeof routeParams.durationSeconds === 'string' ? routeParams.durationSeconds : undefined;
  const rewardStatusParam = typeof routeParams.rewardStatus === 'string' ? routeParams.rewardStatus : undefined;
  const rewardMinutesParam = typeof routeParams.rewardMinutes === 'string' ? routeParams.rewardMinutes : undefined;
  const { profileId } = useAuth();
  const { creditSettings } = useBloom();
  const { theme } = useBloomTheme();
  const reduceMotion = useReduceMotionPreference();
  const desktop = useIsDesktopLayout();
  const desktopColumns = useIsDesktopColumns();
  const accent = theme.modules[moduleId];
  const [items, setItems] = useState<GrowthItem[]>([]);
  const [sessions, setSessions] = useState<GrowthSession[]>([]);
  const [records, setRecords] = useState<GrowthRecord[]>([]);
  const [recordAttachments, setRecordAttachments] = useState<GrowthRecordAttachment[]>([]);
  const [documents, setDocuments] = useState<GrowthDocument[]>([]);
  const [studyRewardEvents, setStudyRewardEvents] = useState<GrowthRewardEvent[] | null>(null);
  const [studyPlan, setStudyPlan] = useState<StudyPlanSlot[]>([]);
  const [studyPlanChanges, setStudyPlanChanges] = useState<StudyPlanChange[]>([]);
  const [taskFocusSessions, setTaskFocusSessions] = useState<TaskFocusSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [snapshotTargetKey, setSnapshotTargetKey] = useState<string | null>(null);
  const [hasStaleSnapshot, setHasStaleSnapshot] = useState(false);
  const [saving, setSaving] = useState(false);
  const [pendingOfflineCount, setPendingOfflineCount] = useState(0);
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
  const [loadedGrowthDraftKey, setLoadedGrowthDraftKey] = useState<string | null>(null);
  const [loadedProjectDraftKey, setLoadedProjectDraftKey] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const [lastSyncCheckedAt, setLastSyncCheckedAt] = useState<number | null>(null);
  const [taskFilter, setTaskFilter] = useState<'today' | 'overdue' | 'upcoming' | 'postponed' | 'completed' | 'archived'>('today');
  const [taskPriority, setTaskPriority] = useState<TaskPriority>('medium');
  const [loadedTaskDraftKey, setLoadedTaskDraftKey] = useState<string | null>(null);
  const [selectedTaskId, setSelectedTaskId] = useState<string | null>(null);
  const [focusedTaskId, setFocusedTaskId] = useState<string | null>(null);
  const [showStudyStartSetup, setShowStudyStartSetup] = useState(false);
  const [showAddSubject, setShowAddSubject] = useState(false);
  const [selectedSubjectArtwork, setSelectedSubjectArtwork] = useState('literature');
  const [subjectArtworkChosen, setSubjectArtworkChosen] = useState(false);
  const [subjectArtworkById, setSubjectArtworkById] = useState<Record<string, string>>({});
  const [imageEditingSubject, setImageEditingSubject] = useState<GrowthItem | null>(null);
  const [imageEditingDraft, setImageEditingDraft] = useState('literature');
  const [subjectArtworkSaveError, setSubjectArtworkSaveError] = useState<string | null>(null);
  const [savingSubjectArtwork, setSavingSubjectArtwork] = useState(false);
  const snapshotTargetRef = useRef<string | null>(null);
  const viewedTargetRef = useRef<string | null>(null);
  const refreshRequest = useRef(0);
  const activeTargetKey = growthModuleSnapshotKey(profileId, moduleId);
  const hasSnapshot = Boolean(activeTargetKey && snapshotTargetKey === activeTargetKey);
  const readOnly = !hasSnapshot || hasStaleSnapshot;
  const sections = moduleSections[moduleId];
  const effectiveSectionId = moduleId === 'study' ? sectionId ?? 'today' : sectionId;
  const primarySections = moduleId === 'study'
    ? sections.filter((section) => ['today', 'plan', 'courses', 'more'].includes(section.id))
    : sections;
  const moreStudySections = moduleId === 'study'
    ? sections.filter((section) => ['progress', 'practice', 'exams', 'tutor', 'resources', 'document-help', 'learning-check'].includes(section.id))
    : [];
  const activeSection = sections.find((section) => section.id === effectiveSectionId);
  const pendingCreate = useRef<{ signature: string; requestId: string } | null>(null);
  const pendingStart = useRef<{ itemId: string; requestId: string } | null>(null);
  const taskDraftKey = moduleId === 'tasks' && profileId ? `bloom.task-capture-draft.v1:${profileId}` : null;
  const growthCreateDraftKey = moduleId !== 'tasks' && profileId ? `bloom.growth-create-draft.v1:${profileId}:${moduleId}` : null;
  const projectDraftKey = moduleId === 'tasks' && profileId ? `bloom.task-project-draft.v1:${profileId}` : null;

  useEffect(() => {
    let active = true;
    if (readOnly || !growthCreateDraftKey) return () => { active = false; };
    void AsyncStorage.getItem(growthCreateDraftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1) {
            const value = saved as Record<string, unknown>;
            if (typeof value.title === 'string' && value.title.length <= 120) setTitle(value.title);
            if (typeof value.notes === 'string' && value.notes.length <= 2000) setNotes(value.notes);
            if (typeof value.targetMinutes === 'string' && value.targetMinutes.length <= 5) setTargetMinutes(value.targetMinutes);
            if (typeof value.author === 'string' && value.author.length <= 160) setAuthor(value.author);
            if (typeof value.genre === 'string' && value.genre.length <= 80) setGenre(value.genre);
            if (typeof value.pageCount === 'string' && value.pageCount.length <= 6) setPageCount(value.pageCount);
            if (value.readingStatus === 'want_to_read' || value.readingStatus === 'currently_reading' || value.readingStatus === 'finished') setReadingStatus(value.readingStatus);
            if (typeof value.selectedSubjectArtwork === 'string' && studySubjectArtworks.some((artwork) => artwork.id === value.selectedSubjectArtwork)) setSelectedSubjectArtwork(value.selectedSubjectArtwork);
            if (typeof value.subjectArtworkChosen === 'boolean') setSubjectArtworkChosen(value.subjectArtworkChosen);
          }
        } catch { /* Ignore an unreadable local item draft. */ }
      }
      setLoadedGrowthDraftKey(growthCreateDraftKey);
    }).catch(() => { if (active) setLoadedGrowthDraftKey(growthCreateDraftKey); });
    return () => { active = false; };
  }, [growthCreateDraftKey, readOnly]);

  useEffect(() => {
    if (readOnly || !growthCreateDraftKey || loadedGrowthDraftKey !== growthCreateDraftKey) return;
    const hasDraft = Boolean(title || notes || targetMinutes || author || genre || pageCount || readingStatus !== 'want_to_read' || subjectArtworkChosen);
    if (!hasDraft) {
      void AsyncStorage.removeItem(growthCreateDraftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(growthCreateDraftKey, JSON.stringify({ version: 1, title, notes, targetMinutes, author, genre, pageCount,
      readingStatus, selectedSubjectArtwork, subjectArtworkChosen })).catch(() => undefined);
  }, [author, genre, growthCreateDraftKey, loadedGrowthDraftKey, notes, pageCount, readOnly, readingStatus, selectedSubjectArtwork,
    subjectArtworkChosen, targetMinutes, title]);

  useEffect(() => {
    let active = true;
    if (readOnly || !projectDraftKey) return () => { active = false; };
    void AsyncStorage.getItem(projectDraftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1
            && 'title' in saved && typeof saved.title === 'string' && saved.title.length <= 120
            && 'notes' in saved && typeof saved.notes === 'string' && saved.notes.length <= 2000) {
            setProjectTitle(saved.title); setProjectNotes(saved.notes);
          }
        } catch { /* Ignore an unreadable local project draft. */ }
      }
      setLoadedProjectDraftKey(projectDraftKey);
    }).catch(() => { if (active) setLoadedProjectDraftKey(projectDraftKey); });
    return () => { active = false; };
  }, [projectDraftKey, readOnly]);

  useEffect(() => {
    if (readOnly || !projectDraftKey || loadedProjectDraftKey !== projectDraftKey) return;
    if (!projectTitle && !projectNotes) {
      void AsyncStorage.removeItem(projectDraftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(projectDraftKey, JSON.stringify({ version: 1, title: projectTitle, notes: projectNotes })).catch(() => undefined);
  }, [loadedProjectDraftKey, projectDraftKey, projectNotes, projectTitle, readOnly]);

  useEffect(() => {
    let active = true;
    if (readOnly || !taskDraftKey) return () => { active = false; };
    void AsyncStorage.getItem(taskDraftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1
            && 'title' in saved && typeof saved.title === 'string' && saved.title.length <= 120
            && 'notes' in saved && typeof saved.notes === 'string' && saved.notes.length <= 2000
            && 'dueDate' in saved && typeof saved.dueDate === 'string' && saved.dueDate.length <= 10
            && 'priority' in saved && (saved.priority === 'low' || saved.priority === 'medium' || saved.priority === 'high' || saved.priority === 'urgent')) {
            setTitle(saved.title); setNotes(saved.notes); setDueDate(saved.dueDate); setTaskPriority(saved.priority);
          }
        } catch { /* Ignore an unreadable local task capture draft. */ }
      }
      setLoadedTaskDraftKey(taskDraftKey);
    }).catch(() => { if (active) setLoadedTaskDraftKey(taskDraftKey); });
    return () => { active = false; };
  }, [readOnly, taskDraftKey]);

  useEffect(() => {
    if (readOnly || !taskDraftKey || loadedTaskDraftKey !== taskDraftKey) return;
    if (!title && !notes && !dueDate) {
      void AsyncStorage.removeItem(taskDraftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(taskDraftKey, JSON.stringify({ version: 1, title, notes, dueDate, priority: taskPriority })).catch(() => undefined);
  }, [dueDate, loadedTaskDraftKey, notes, readOnly, taskDraftKey, taskPriority, title]);

  const refresh = useCallback(async () => {
    const request = ++refreshRequest.current;
    const targetKey = growthModuleSnapshotKey(profileId, moduleId);
    if (!profileId || !targetKey) {
      viewedTargetRef.current = null;
      snapshotTargetRef.current = null;
      setSubjectArtworkById({});
      setItems([]); setSessions([]); setRecords([]); setRecordAttachments([]); setDocuments([]); setStudyPlan([]); setStudyPlanChanges([]); setTaskFocusSessions([]); setStudyRewardEvents(null); setSnapshotTargetKey(null); setLastSyncCheckedAt(null);
      setLoading(false); setHasStaleSnapshot(false); setError('Your Bloom profile is unavailable. Refresh your profile and try again.');
      return;
    }
    if (viewedTargetRef.current !== targetKey) {
      viewedTargetRef.current = targetKey;
      snapshotTargetRef.current = null;
      setSubjectArtworkById({});
      pendingCreate.current = null; pendingStart.current = null;
      setItems([]); setSessions([]); setRecords([]); setRecordAttachments([]); setDocuments([]); setStudyPlan([]); setStudyPlanChanges([]); setTaskFocusSessions([]); setStudyRewardEvents(null); setSnapshotTargetKey(null); setLastSyncCheckedAt(null);
      setTitle(''); setNotes(''); setDueDate(''); setTargetMinutes(''); setAuthor(''); setGenre(''); setPageCount(''); setReadingStatus('want_to_read'); setProjectTitle(''); setProjectNotes(''); setTaskFilter('today'); setTaskPriority('medium');
    }
    setLoading(true); setError(null); setHasStaleSnapshot(false);
    try {
      await flushOfflineActivitiesForProfile(profileId).catch(() => undefined);
      setPendingOfflineCount(await getPendingOfflineCount(profileId).catch(() => 0));
      const planOnly = moduleId === 'study' && effectiveSectionId === 'plan';
      const [result, nextDocuments] = await Promise.all([
        planOnly ? loadStudyPlanModule(profileId) : loadGrowthModule(profileId, moduleId),
        moduleId === 'tasks' || planOnly ? Promise.resolve([]) : loadGrowthDocuments(moduleId),
      ]);
      if (request !== refreshRequest.current) return;
      const nextSubjectArtwork = moduleId === 'study' && !planOnly
        ? await loadStudySubjectArtworkPreferences(profileId, result.items)
        : null;
      if (request !== refreshRequest.current) return;
      setItems(result.items);
      if (nextSubjectArtwork) setSubjectArtworkById(nextSubjectArtwork);
      setSessions(result.sessions);
      setRecords(result.records);
      setRecordAttachments(result.recordAttachments);
      setDocuments(nextDocuments);
      setStudyPlan(result.studyPlan);
      setStudyPlanChanges(result.studyPlanChanges);
      setTaskFocusSessions(result.taskFocusSessions);
      setStudyRewardEvents(null);
      if (moduleId === 'study') {
        void loadGrowthRewards(profileId).then((rewardData) => {
          if (request === refreshRequest.current) setStudyRewardEvents(rewardData.events);
        }).catch(() => { /* Reward status is supplementary; it does not block study records. */ });
      }
      setSnapshotTargetKey(targetKey);
      snapshotTargetRef.current = targetKey;
      setHasStaleSnapshot(false);
      const now = Date.now();
      setTick(now);
      setLastSyncCheckedAt(now);
    } catch (cause) {
      if (request !== refreshRequest.current) return;
      setHasStaleSnapshot(snapshotTargetRef.current === targetKey);
      const diagnostic = __DEV__ && cause instanceof GrowthDataQueryError
        ? ` [${cause.resource}${cause.code ? ` · ${cause.code}` : ''}]` : '';
      setError(`${content.title} data isn’t available right now. Retry in a moment.${diagnostic}`);
    } finally { if (request === refreshRequest.current) setLoading(false); }
  }, [content.title, effectiveSectionId, moduleId, profileId]);

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
      let subjectArtworkSaved = true;
      if (moduleId === 'study' && profileId) {
        try {
          await saveStudySubjectArtworkPreference(createdId, selectedSubjectArtwork);
          setSubjectArtworkById((current) => ({ ...current, [createdId]: selectedSubjectArtwork }));
        }
        catch { subjectArtworkSaved = false; }
      }
      if (moduleId === 'tasks') await updateGrowthTaskMetadata(createdId, taskPriority, null);
      if (moduleId === 'read') await updateGrowthReadingDetails(createdId, { author: author.trim(), genre: genre.trim(), pageCount: parsedPageCount,
        currentPage: parsedPageCount ? (readingStatus === 'finished' ? parsedPageCount : 0) : null, status: readingStatus });
      pendingCreate.current = null;
      setTitle(''); setNotes(''); setDueDate(''); setTargetMinutes(''); setTaskPriority('medium'); setAuthor(''); setGenre(''); setPageCount(''); setReadingStatus('want_to_read');
      if (growthCreateDraftKey) await AsyncStorage.removeItem(growthCreateDraftKey).catch(() => undefined);
      setSelectedSubjectArtwork('literature'); setSubjectArtworkChosen(false);
      if (moduleId === 'study') { setShowAddSubject(false); setShowStudyStartSetup(false); }
      setNotice(moduleId === 'study' ? subjectArtworkSaved ? 'Subject added. Its artwork is saved across your devices.' : 'Subject added, but its artwork could not sync. You can retry by changing the image.' : moduleId === 'read' ? 'Added to your reading list.' : 'Task added.');
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
      setProjectTitle(''); setProjectNotes('');
      if (projectDraftKey) await AsyncStorage.removeItem(projectDraftKey).catch(() => undefined);
      setNotice('Project added. Add milestones and tasks underneath it.'); await refresh();
    } catch { setError('Could not save this project. Your entry is still in the form; check your connection and try again.'); }
    finally { setSaving(false); }
  }

  function openSubjectArtworkPicker(item: GrowthItem) {
    setSubjectArtworkSaveError(null);
    setImageEditingSubject(item);
    setImageEditingDraft(subjectArtworkById[item.id] ?? suggestStudySubjectArtwork(item.title));
  }

  async function saveSubjectArtwork() {
    if (!profileId || !imageEditingSubject) return;
    const nextPreferences = { ...subjectArtworkById, [imageEditingSubject.id]: imageEditingDraft };
    setSavingSubjectArtwork(true);
    try {
      await saveStudySubjectArtworkPreference(imageEditingSubject.id, imageEditingDraft);
      setSubjectArtworkById(nextPreferences);
      setNotice(`${imageEditingSubject.title} artwork updated across your devices.`);
      setImageEditingSubject(null);
      setSubjectArtworkSaveError(null);
    } catch {
      setSubjectArtworkSaveError('Could not sync this artwork choice. Check your connection and try again.');
    } finally { setSavingSubjectArtwork(false); }
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
      if (moduleId === 'study') router.replace(sectionHref('study', 'active-session'));
      else setNotice('Session started. Bloom is timing your activity.');
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
        if (moduleId === 'study' && profileId) {
          let rewardStatus = 'unavailable';
          let rewardMinutes = 0;
          try {
            const rewards = await loadGrowthRewards(profileId);
            const event = rewards.events.find((entry) => entry.source_type === 'session' && entry.source_id === session.id);
            if (event) { rewardStatus = event.status; rewardMinutes = event.awarded_minutes; }
          } catch { /* Session completion is authoritative even if the separate wallet read is unavailable. */ }
          await refresh();
          router.replace({ pathname: '/apps/study/[section]', params: { section: 'session-complete', itemId: session.item_id,
            durationSeconds: String(result.durationSeconds), rewardStatus, rewardMinutes: String(rewardMinutes) } });
          return;
        }
        setNotice(`Session saved · ${formatDuration(result.durationSeconds)}.`);
      }
      await refresh();
      if (cancel && moduleId === 'study') router.replace(sectionHref('study', 'today'));
    } catch (cause) {
      if (!cancel && profileId) {
        try {
          const sourceDevice = await getCurrentDeviceIdentity(profileId);
          const durationSeconds = Math.max(1, Math.min(43200, Math.floor((currentEpochMs() - Date.parse(session.started_at)) / 1000)));
          await queueOfflineActivityForProfile(profileId, {
            kind: moduleId === 'read' ? 'read_session' : 'study_session',
            moduleId: moduleId === 'read' ? 'read' : 'study',
            itemId: session.item_id,
            itemTitle: sessionItem?.title ?? 'Session',
            sourceDeviceId: sourceDevice.deviceId,
            sourceDeviceName: sourceDevice.displayName,
            startedAt: session.started_at,
            completedAt: new Date().toISOString(),
            durationSeconds,
          }, session.id);
          setPendingOfflineCount(await getPendingOfflineCount(profileId));
          setNotice('Session saved offline as Pending. It will sync as self-reported history when connected without automatic time-based credit.');
          if (moduleId === 'study') router.replace(sectionHref('study', 'today'));
          return;
        } catch { /* Fall through to standard retry error. */ }
      }
      setError(cause instanceof Error && cause.message.toLowerCase().includes('session has expired')
        ? 'This session expired after 12 hours. Cancel it, then start a new one.'
        : 'Could not save the session. Reconnect and try again.');
    } finally { setSaving(false); }
  }

  async function changeItem(item: GrowthItem, update: Parameters<typeof updateGrowthItem>[1], success: string) {
    setSaving(true); setError(null); setNotice(null);
    try { await updateGrowthItem(item, update); setNotice(success); await refresh(); }
    catch {
      if (moduleId === 'tasks' && update.state === 'completed' && profileId) {
        try {
          await queueOfflineActivityForProfile(profileId, {
            kind: 'task_completion',
            itemId: item.id,
            itemTitle: item.title,
            completedAt: new Date().toISOString(),
          });
          setPendingOfflineCount(await getPendingOfflineCount(profileId));
          setNotice('Task saved offline as Pending. Normal rewards apply only after the server accepts it.');
          return;
        } catch { /* Fall through to standard retry error. */ }
      }
      setError('Could not update this item. Check your connection and retry.');
    }
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
  const selectedTask = visibleTasks.find((item) => item.id === selectedTaskId) ?? visibleTasks[0] ?? null;
  const activeStudyItems = openItems.filter((item) => ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type));
  const activeReadings = openItems.filter((item) => item.item_type === 'reading');
  const completedReadings = completedItems.filter((item) => item.item_type === 'reading');
  const wantToRead = activeReadings.filter((item) => getReadingStatus(item) === 'want_to_read');
  const currentlyReading = activeReadings.filter((item) => getReadingStatus(item) === 'currently_reading');
  const completedStudySessions = sessions.filter((session) => session.status === 'completed');
  const studySubjects = activeStudyItems.filter((item) => item.item_type === 'subject');
  const studyTodaySessions = sessions.filter((session) => session.status === 'completed' && session.completed_at
    && dateKeyInTimeZone(Date.parse(session.completed_at), taskTimeZone) === todayInProfileTimeZone);
  const studyTodaySeconds = studyTodaySessions.reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0);
  const studyTodayMinutes = Math.floor(studyTodaySeconds / 60);
  const studyTodayPlan = getTodaysStudyPlan(items, studyPlan, studyPlanChanges, todayInProfileTimeZone);
  const studyTodayPlannedMinutes = studyTodayPlan.reduce((sum, slot) => sum + slot.minutes, 0);
  const studyTodayProgress = studyTodayPlannedMinutes > 0 ? Math.min(100, Math.round(studyTodayMinutes / studyTodayPlannedMinutes * 100)) : null;
  const studyTodaySubjectCount = new Set(studyTodaySessions.map((session) => findRootSubject(items, session.item_id)?.id ?? session.item_id)).size;
  const weekStart = startOfWeekKey(todayInProfileTimeZone);
  const studyWeekSessions = completedStudySessions.filter((session) => session.completed_at
    && dateKeyInTimeZone(Date.parse(session.completed_at), taskTimeZone) >= weekStart
    && dateKeyInTimeZone(Date.parse(session.completed_at), taskTimeZone) <= todayInProfileTimeZone);
  const studyWeekMinutes = Math.floor(studyWeekSessions.reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0) / 60);
  const studyWeekRewards = (studyRewardEvents ?? []).filter((event) => event.module_id === 'study'
    && dateKeyInTimeZone(Date.parse(event.created_at), taskTimeZone) >= weekStart
    && dateKeyInTimeZone(Date.parse(event.created_at), taskTimeZone) <= todayInProfileTimeZone);
  const studyWeekRewardedMinutes = studyWeekRewards.filter((event) => event.status === 'awarded').reduce((sum, event) => sum + event.awarded_minutes, 0);
  const studyWeekPendingRewards = studyWeekRewards.filter((event) => event.status === 'pending').length;
  const openTaskCount = openItems.filter((item) => ['task', 'checklist'].includes(item.item_type)).length;
  const isStudyImmersive = moduleId === 'study' && ['active-session', 'session-complete', 'learning-check'].includes(effectiveSectionId ?? '');
  const selectedStudyTab = moduleId === 'study' && !primarySections.some((section) => section.id === effectiveSectionId) ? 'more' : effectiveSectionId;

  return <Screen safeAreaTop={isStudyImmersive}>
    {moduleId === 'study' ? (!isStudyImmersive && <>
      {!desktop && <View style={styles.studyHeader}>
        <View style={[styles.moduleIcon, { backgroundColor: theme.colors.surface }]}><MaterialIcons name="school" size={24} color={accent.deep} /></View>
        <View style={sharedStyles.grow}><Eyebrow>Bloom Study</Eyebrow><Heading>Study</Heading><Body>Focus. Learn. Grow.</Body></View>
      </View>}
      {!desktop && <StudyLocalNavigation selected={selectedStudyTab ?? 'today'} accent={accent.deep} surface={accent.surface}
        onSelect={(id) => router.replace(sectionHref('study', id))} />
      }
    {effectiveSectionId === 'today' && <ImageBackground source={bloomPillarCollectionImages.study} resizeMode="cover" imageStyle={styles.studyHeroImage} style={styles.studyHero}>
        <View style={styles.studyHeroShade} />
        <View style={styles.studyHeroCopy}><Text style={styles.studyHeroEyebrow}>TODAY</Text><Text style={styles.studyHeroTitle}>Deep focus, real progress.</Text></View>
      </ImageBackground>}
    </>) : moduleId === 'tasks' && (!sectionId || sectionId === 'today') ? <ImageBackground source={bloomPillarCollectionImages.tasks} resizeMode="cover" imageStyle={styles.tasksHeroImage} style={[styles.tasksHero, desktop && styles.tasksHeroDesktop]}>
      <View pointerEvents="none" style={styles.tasksHeroShade} />
      <View style={styles.tasksHeroContent}>
        <View style={styles.tasksHeroTopRow}>
          <Text style={styles.tasksHeroEyebrow}>PLAN. ACT. GROW.</Text>
          <Pressable accessibilityRole="button" accessibilityLabel="All apps" accessibilityHint="Returns to the Bloom apps list."
            onPress={() => router.replace('/apps' as Href)} style={({ pressed }) => [styles.tasksHeroAllApps, pressed && styles.tasksHeroAllAppsPressed]}>
            <Text style={[styles.tasksHeroAllAppsText, { color: accent.deep }]}>All apps</Text>
          </Pressable>
        </View>
        <Text style={[styles.tasksHeroTitle, desktop && styles.tasksHeroTitleDesktop]}>Make room for what matters.</Text>
        <Text style={styles.tasksHeroSubtitle}>{content.description}</Text>
      </View>
    </ImageBackground> : <View style={[styles.moduleHero, { backgroundColor: accent.surface, borderColor: theme.colors.border }]}>
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
    </View>}

    {moduleId !== 'study' && sectionId && activeSection && <View style={styles.sectionHeading}>
      <Eyebrow>{activeSection.label}</Eyebrow><Heading>{activeSection.title}</Heading><Body>{activeSection.description}</Body>
    </View>}

    {loading && <View style={styles.loadingNotice}>
      <ActivityIndicator color={accent.deep} />
      <Body>{moduleId === 'study' && effectiveSectionId === 'plan' ? 'Loading your weekly plan…' : `Loading ${content.title.toLowerCase()}…`}</Body>
    </View>}
    {error && <View style={[styles.connectionNotice, { backgroundColor: theme.colors.surfaceSoft, borderColor: theme.colors.border }]}>
      <MaterialIcons name="cloud-off" size={19} color={theme.colors.dangerText} />
      <View style={sharedStyles.grow}>
      <ErrorText>{error}</ErrorText>
        <Body>{hasStaleSnapshot ? 'Showing the last saved version. Reconnect to edit.' : 'Read-only until connected. Changes are not saved offline.'}</Body>
      </View>
      <Button label="Retry" variant="tertiary" onPress={() => void refresh()} />
    </View>}
    {notice && <Panel><Body>{notice}</Body></Panel>}
    <OfflinePendingBanner profileId={profileId} pendingCount={pendingOfflineCount} onCountUpdated={setPendingOfflineCount} onSynced={refresh} />

    {moduleId !== 'study' && !sectionId && !loading && <>
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
      </View>
    </>}

    {effectiveSectionId && !activeSection && <Panel><Eyebrow>{content.title}</Eyebrow><Label>Section not found</Label><Body>This page isn’t part of this pillar.</Body></Panel>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'today' && <>
      {activeSession && <Panel>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Eyebrow>Focus in progress</Eyebrow><Heading>{formatElapsed(elapsed)}</Heading></View>
          <View style={[styles.liveIndicator, { backgroundColor: accent.surface }]}><View style={[styles.liveDot, { backgroundColor: accent.deep }]} /><Text style={[styles.liveText, { color: accent.deep }]}>LIVE</Text></View>
        </View>
        <Label>{sessionItem?.title ?? 'Study session'}</Label>
        <Button label="Continue session" onPress={() => router.push(sectionHref('study', 'active-session'))} />
      </Panel>}

      <Panel>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Eyebrow>Today’s focus</Eyebrow><Label>{studyTodaySessions.length ? `${studyTodaySessions.length} completed session${studyTodaySessions.length === 1 ? '' : 's'}` : 'Ready when you are'}</Label></View>
          {studyTodayProgress !== null && <Text style={[styles.todayPercent, { color: accent.deep }]}>{studyTodayProgress}%</Text>}
        </View>
        <View style={styles.todayMetrics}>
          <StudyMetric value={studyTodaySessions.length ? formatTrackedMinutes(studyTodaySeconds) : '0 min'} label="studied" />
          <StudyMetric value={studyTodaySubjectCount.toString()} label="subjects" />
          <StudyMetric value={studyTodayPlannedMinutes ? formatMinutes(studyTodayPlannedMinutes) : '—'} label="planned" />
        </View>
        {studyTodayProgress !== null && <ProgressBar value={studyTodayProgress} label="Today's planned study time completed" color={accent.deep} />}
        {!studyTodayPlannedMinutes && <Body>No study time planned today.</Body>}
        {studyRewardEvents === null ? <Body>Screen-time rewards are unavailable.</Body> :
          <Body>{formatMinutes(studyWeekRewardedMinutes)} screen time earned this week{studyWeekPendingRewards ? ` · ${studyWeekPendingRewards} pending` : ''}</Body>}
        {!activeSession && <Button label="Start study session" onPress={() => setShowStudyStartSetup((current) => !current)} disabled={readOnly || !studySubjects.length} />}
        {activeSession && <Body>Continue your active session above.</Body>}
        {!studySubjects.length && <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Add a subject to start.</Body></View>
          <Button label="Add subject" variant="tertiary" onPress={() => setShowAddSubject(true)} disabled={readOnly} />
        </View>}
        {showStudyStartSetup && studySubjects.length > 0 && <View style={styles.studyPicker}>
          <Label>Choose a subject</Label>
          {studySubjects.map((item) => <View key={item.id} style={styles.itemRow}><Label>{item.title}</Label>
            <Button label="Start" variant="tertiary" disabled={readOnly || saving || Boolean(activeSession)} onPress={() => void beginSession(item)} />
          </View>)}
        </View>}
      </Panel>

      {showAddSubject && <Panel>
        <View style={sharedStyles.row}><Label>Add a subject</Label><Button label="Close" variant="tertiary" onPress={() => setShowAddSubject(false)} /></View>
        <Field label="Subject" value={readOnly ? '' : title} onChangeText={(value) => {
          setTitle(value);
          if (!subjectArtworkChosen) setSelectedSubjectArtwork(suggestStudySubjectArtwork(value));
        }} placeholder="e.g. Biology" maxLength={120} editable={!readOnly} />
        <View style={styles.subjectArtworkChooser}>
          <View style={sharedStyles.column}><Label>Choose a subject image</Label><Body>Pick the visual identity that fits this subject.</Body></View>
          <SubjectArtworkPicker selectedArtwork={selectedSubjectArtwork} onSelect={(id) => { setSelectedSubjectArtwork(id); setSubjectArtworkChosen(true); }} disabled={readOnly} />
          <Body>Your image choice is saved on this device.</Body>
        </View>
        <Field label="Weekly study target in minutes" value={readOnly ? '' : targetMinutes} onChangeText={setTargetMinutes} keyboardType="number-pad" placeholder="e.g. 240" editable={!readOnly} />
        <Field label="Notes (optional)" value={readOnly ? '' : notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Topics or a short plan" editable={!readOnly} />
        <Button label="Add subject" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
      </Panel>}

      <View style={styles.studySection}>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Heading>Your subjects</Heading></View><Button label="Courses" variant="tertiary" onPress={() => router.push(sectionHref('study', 'courses'))} /></View>
        {studySubjects.length ? <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.subjectCards}>
          {studySubjects.map((item) => {
            const children = items.filter((entry) => entry.parent_id === item.id && entry.state === 'active');
            const nextLesson = children.find((entry) => entry.item_type === 'course') ?? children[0];
            const dueAssignments = items.filter((entry) => entry.item_type === 'assignment' && entry.state === 'active' && entry.due_date
              && findRootSubject(items, entry.id)?.id === item.id).length;
            return <View key={item.id} style={[styles.subjectCard, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
              <View style={styles.subjectCardTop}>
                <SubjectArtwork artworkId={subjectArtworkById[item.id] ?? suggestStudySubjectArtwork(item.title)} size={72} />
                <View style={sharedStyles.grow}>
                  <Text style={[styles.subjectEyebrow, { color: accent.deep }]}>SUBJECT</Text>
                  <Text numberOfLines={2} style={[styles.subjectTitle, { color: theme.colors.ink }]}>{item.title}</Text>
                  <Text numberOfLines={2} style={[styles.subjectDetail, { color: theme.colors.inkMuted }]}>{nextLesson ? `Next · ${nextLesson.title}` : item.target_minutes ? `${formatMinutes(item.target_minutes)} weekly target` : 'No weekly target'}</Text>
                  {dueAssignments > 0 && <Text style={[styles.subjectDetail, { color: theme.colors.inkMuted }]}>{dueAssignments} assignment{dueAssignments === 1 ? '' : 's'} due</Text>}
                </View>
              </View>
              <View style={styles.subjectCardActions}>
                <Pressable accessibilityRole="button" accessibilityLabel={`Open ${item.title} courses`} onPress={() => router.push(sectionHref('study', 'courses'))}
                  style={({ pressed }) => [styles.subjectOpenAction, { backgroundColor: accent.surface }, pressed && { opacity: 0.82 }]}>
                  <Text style={[styles.subjectOpenText, { color: accent.deep }]}>Open courses</Text>
                </Pressable>
                <Pressable accessibilityRole="button" accessibilityLabel={`Change image for ${item.title}`} onPress={() => openSubjectArtworkPicker(item)}
                  style={({ pressed }) => [styles.subjectImageAction, { borderColor: theme.colors.border }, pressed && { opacity: 0.82 }]}>
                  <MaterialIcons name="palette" size={18} color={accent.deep} />
                </Pressable>
              </View>
            </View>;
          })}
        </ScrollView> : <Panel><Body>Your subjects will appear here.</Body><Button label="Add subject" variant="secondary" onPress={() => setShowAddSubject(true)} disabled={readOnly} /></Panel>}
      </View>

      <Panel>
        <View style={sharedStyles.row}><View style={sharedStyles.grow}><Eyebrow>Today’s plan</Eyebrow><Label>{studyTodayPlan.length ? `${studyTodayPlan.length} planned block${studyTodayPlan.length === 1 ? '' : 's'}` : 'A flexible day'}</Label></View>
          <Button label="Edit" variant="tertiary" onPress={() => router.push(sectionHref('study', 'plan'))} />
        </View>
        {studyTodayPlan.length ? studyTodayPlan.map((slot) => <View key={`${slot.itemId}:${slot.minutes}`} style={styles.itemRow}>
          <View style={sharedStyles.grow}><Label>{slot.title}</Label><Body>{formatMinutes(slot.minutes)} planned</Body></View>
          {(() => {
            const completedMinutes = Math.floor(studyTodaySessions.filter((session) => isItemWithin(items, session.item_id, slot.itemId))
              .reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0) / 60);
            return completedMinutes >= slot.minutes
              ? <Text style={[styles.planDone, { color: accent.deep }]}>Done</Text>
              : completedMinutes > 0 ? <Text style={[styles.planDone, { color: accent.deep }]}>{formatMinutes(completedMinutes)}</Text> : null;
          })()}
        </View>) : <Body>No sessions planned.</Body>}
      </Panel>

      <StudySessionHistory sessions={sessions} items={sessionsByItem} timeZone={taskTimeZone}
        onLearningCheck={(itemId) => router.push({ pathname: '/apps/study/[section]', params: { section: 'learning-check', itemId } })} />
    </>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'plan' && <StudyPlanPanel key={profileId} items={items} slots={studyPlan} changes={studyPlanChanges}
      sessions={sessions} timeZone={taskTimeZone} today={todayInProfileTimeZone} todayDayOfWeek={new Date(`${todayInProfileTimeZone}T12:00:00Z`).getUTCDay()}
      readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'courses' && <GrowthHierarchyPanel key={`${profileId}:study-hierarchy`} moduleId="study" items={items} readOnly={readOnly}
      onOpenTool={(tool, itemId) => router.push({ pathname: '/apps/study/[section]', params: { section: tool, itemId } })}
      onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'more' && <View style={styles.studySection}>
      <View><Eyebrow>More</Eyebrow><Heading>Study tools</Heading></View>
      <View style={styles.dashboardGrid}>{moreStudySections.map((section) => <View key={section.id} style={styles.dashboardTile}>
        <FeatureTile title={section.label} subtitle={section.id === 'practice' ? 'Questions and reviews' : section.id === 'exams' ? 'Timed assessments' : section.id === 'tutor' ? 'Guided explanations' : section.id === 'resources' ? 'Course materials' : section.id === 'document-help' ? 'Ask with sources' : section.id === 'progress' ? 'Sessions and learning' : 'Session reflection'}
          icon={section.icon} accentColor={accent.deep} backgroundColor={accent.surface} onPress={() => router.push(sectionHref('study', section.id))} />
      </View>)}</View>
    </View>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'progress' && <>
      <Panel><Eyebrow>This week</Eyebrow><Heading>{formatMinutes(studyWeekMinutes)}</Heading>
        <View style={styles.todayMetrics}>
          <StudyMetric value={studyWeekSessions.length.toString()} label="sessions" />
          <StudyMetric value={studySubjects.length.toString()} label="subjects" />
          <StudyMetric value={studyRewardEvents === null ? '—' : formatMinutes(studyWeekRewardedMinutes)} label="screen time earned" />
        </View>
        {studyRewardEvents === null ? <Body>Reward status is unavailable.</Body> : studyWeekPendingRewards > 0 ? <Body>{studyWeekPendingRewards} reward{studyWeekPendingRewards === 1 ? '' : 's'} pending review.</Body> : null}
      </Panel>
      <StudySessionHistory sessions={sessions} items={sessionsByItem} timeZone={taskTimeZone}
        onLearningCheck={(itemId) => router.push({ pathname: '/apps/study/[section]', params: { section: 'learning-check', itemId } })} />
    </>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'practice' && <StudyPracticeReviewPanel key={`${profileId}:${contextItemId ?? ''}`} items={items} records={records} initialItemId={contextItemId} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'exams' && <MockExamPanel key={profileId} profileId={profileId ?? ''} items={items} records={records} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'learning-check' && <>
      {isStudyImmersive && <View style={[sharedStyles.row, styles.immersiveTitle]}>
        <View style={sharedStyles.grow}><Eyebrow>Study · Learning check</Eyebrow><Heading>What did you learn?</Heading></View>
        <Button label="Study" variant="tertiary" onPress={() => router.replace(sectionHref('study', 'today'))} />
      </View>}
      <GrowthRecordPanel key={`${profileId}:${contextItemId ?? ''}`} profileId={profileId} moduleId="study" items={items} records={records} documents={documents} attachments={recordAttachments}
        initialItemId={contextItemId} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'tutor' && <StudyTutorPanel key={`${profileId}:${contextItemId ?? ''}`} profileId={profileId ?? ''} items={items} initialItemId={contextItemId} readOnly={readOnly} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'resources' && <GrowthDocumentLibraryPanel key={`${profileId}:${contextItemId ?? ''}`} moduleId="study" items={items} records={records}
      documents={documents} initialItemId={contextItemId} onDocumentHelp={(documentId) => router.push({ pathname: '/apps/study/[section]', params: { section: 'document-help', documentId } })}
      readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'document-help' && <StudyDocumentHelpPanel key={`study-document-help:${profileId}:${contextDocumentId ?? ''}`} profileId={profileId}
      documents={documents} initialDocumentId={contextDocumentId} readOnly={readOnly} onSaved={() => void refresh()} />}

    {!loading && moduleId === 'study' && effectiveSectionId === 'active-session' && <Panel>
      <View style={styles.immersiveTitle}><Eyebrow>Study session</Eyebrow><Heading>Stay with one thing.</Heading></View>
      {activeSession ? <>
        <Text accessibilityRole="timer" style={[styles.sessionTimer, { color: accent.deep }]}>{formatElapsed(elapsed)}</Text>
        <Label>{sessionItem?.title ?? 'Study session'}</Label>
        <Body>Started {new Date(activeSession.started_at).toLocaleTimeString(getAppLocale(), { timeZone: taskTimeZone, hour: 'numeric', minute: '2-digit' })} · {activeSession.source_device_name}</Body>
        <Button label="Finish session" onPress={() => void endSession(activeSession, false)} busy={saving} disabled={readOnly} />
        <Button label="Cancel session" variant="secondary" onPress={() => void endSession(activeSession, true)} disabled={saving || readOnly} />
      </> : <><Body>No study session is active.</Body><Button label="Back to Today" variant="secondary" onPress={() => router.replace(sectionHref('study', 'today'))} /></>}
    </Panel>}

    {!loading && moduleId === 'study' && effectiveSectionId === 'session-complete' && <Panel>
      <View style={styles.immersiveTitle}><Eyebrow>Session saved</Eyebrow><Heading>Good work.</Heading></View>
      <Text style={[styles.sessionTimer, { color: accent.deep }]}>{formatDuration(Number(durationSecondsParam ?? 0))}</Text>
      <Label>{items.find((item) => item.id === contextItemId)?.title ?? 'Study session'}</Label>
      <Body>{studyRewardMessage(rewardStatusParam, Number(rewardMinutesParam ?? 0))}</Body>
      <Button label="Complete learning check" onPress={() => router.replace({ pathname: '/apps/study/[section]', params: { section: 'learning-check', itemId: contextItemId ?? '' } })} />
      <Button label="Back to Study" variant="secondary" onPress={() => router.replace(sectionHref('study', 'today'))} />
    </Panel>}

    {!loading && moduleId === 'read' && sectionId === 'library' && <>
      {activeSession && <Panel>
        <Eyebrow>Reading session · in progress</Eyebrow>
        <Heading>{formatElapsed(elapsed)}</Heading>
        <Label>{sessionItem?.title ?? 'Reading item'}</Label>
        <Body>Started on {activeSession.source_device_name} · {new Date(activeSession.started_at).toLocaleString(getAppLocale())}{lastSyncCheckedAt ? ` · last checked ${new Date(lastSyncCheckedAt).toLocaleString(getAppLocale())}` : ''}. Finish to save your reading time.</Body>
        <Button label="Finish reading session" onPress={() => void endSession(activeSession, false)} busy={saving} disabled={readOnly} />
        <Button label="Cancel session" variant="secondary" onPress={() => void endSession(activeSession, true)} disabled={saving || readOnly} />
      </Panel>}
      <Panel>
        <Eyebrow>Reading list</Eyebrow>
        <Label>Add a book or article</Label>
        <Field label="Title" value={readOnly ? '' : title} onChangeText={setTitle} placeholder="What would you like to read?" maxLength={120} editable={!readOnly} />
        <Field label="Author (optional)" value={readOnly ? '' : author} onChangeText={setAuthor} maxLength={160} placeholder="Author" editable={!readOnly} />
        <Field label="Genre (optional)" value={readOnly ? '' : genre} onChangeText={setGenre} maxLength={80} placeholder="Fiction, history, science…" editable={!readOnly} />
        <Field label="Total pages (optional)" value={readOnly ? '' : pageCount} onChangeText={setPageCount} keyboardType="number-pad" maxLength={6} placeholder="e.g. 320" editable={!readOnly} />
        <Body>Reading status</Body>
        <View style={styles.filterRow} accessibilityRole="radiogroup" accessibilityLabel="New reading status">
          {(['want_to_read', 'currently_reading', 'finished'] as const).map((status) => <Pressable key={status} accessibilityRole="radio"
            accessibilityState={{ selected: readingStatus === status }} disabled={readOnly || saving} onPress={() => setReadingStatus(status)}
            style={[styles.filter, { backgroundColor: readingStatus === status ? accent.surface : theme.colors.surface, borderColor: readingStatus === status ? accent.deep : theme.colors.border }]}>
            <Label>{readingStatusLabel(status)}</Label>
          </Pressable>)}
        </View>
        <Field label="Source or notes (optional)" value={readOnly ? '' : notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Publication or a reminder" editable={!readOnly} />
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
      {!desktopColumns && <>
      <Panel>
        <Eyebrow>Quick add</Eyebrow>
        <Label>What needs doing?</Label>
        <Field label="Task" value={readOnly ? '' : title} onChangeText={setTitle} placeholder="A small next step" maxLength={120} editable={!readOnly} />
        <Button label="Add task" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
        <Body>Priority</Body>
        <View style={styles.filterRow} accessibilityRole="radiogroup" accessibilityLabel="New task priority">
          {(['low', 'medium', 'high', 'urgent'] as const).map((value) => <Pressable key={value} accessibilityRole="radio" accessibilityState={{ selected: taskPriority === value }} onPress={() => setTaskPriority(value)} style={[styles.filter, { backgroundColor: taskPriority === value ? accent.surface : theme.colors.surface, borderColor: taskPriority === value ? accent.deep : theme.colors.border }]}>
            <Label>{value[0].toUpperCase() + value.slice(1)}</Label>
          </Pressable>)}
        </View>
        <Field label="Due date (optional)" value={readOnly ? '' : dueDate} onChangeText={setDueDate} placeholder="YYYY-MM-DD" autoCapitalize="none" maxLength={10} editable={!readOnly} />
        <Field label="Notes (optional)" value={readOnly ? '' : notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Add a useful detail" editable={!readOnly} />
      </Panel>
      <Panel>
        <Eyebrow>Tasks · {items.filter((item) => item.item_type === 'task' && item.state === 'active').length} open · {items.filter((item) => item.item_type === 'task' && item.state === 'completed').length} completed</Eyebrow>
        <View style={styles.filterRow} accessibilityRole="tablist" accessibilityLabel="Task view">
          {(['today', 'overdue', 'upcoming', 'postponed', 'completed', 'archived'] as const).map((filter) => <Pressable key={filter} accessibilityRole="tab" accessibilityState={{ selected: taskFilter === filter }} onPress={() => setTaskFilter(filter)} style={[styles.filter, { backgroundColor: taskFilter === filter ? accent.surface : theme.colors.surface, borderColor: taskFilter === filter ? accent.deep : theme.colors.border }]}>
            <Label>{filter[0].toUpperCase() + filter.slice(1)}</Label>
          </Pressable>)}
        </View>
        {visibleTasks.length === 0 ? <Body>{taskFilter === 'completed' ? 'Finished tasks will stay here.' : taskFilter === 'archived' ? 'Archived tasks will appear here.' : taskFilter === 'postponed' ? 'No tasks are postponed.' : taskFilter === 'upcoming' ? 'Nothing is scheduled for a later date.' : taskFilter === 'overdue' ? 'You’re caught up on overdue tasks.' : 'Your next priorities will appear here.'}</Body> : visibleTasks.map((item) => <View key={item.id} style={styles.itemRow}>
          <Pressable accessibilityRole="checkbox" accessibilityLabel={`${item.state === 'completed' ? 'Reopen' : 'Complete'} ${item.title}`} accessibilityState={{ checked: item.state === 'completed', disabled: readOnly || saving }} disabled={readOnly || saving} onPress={() => void changeItem(item, { state: item.state === 'completed' ? 'active' : 'completed', progressPercent: item.state === 'completed' ? 0 : 100 }, item.state === 'completed' ? 'Task reopened.' : 'Task completed.')} style={[styles.check, { borderColor: item.state === 'completed' ? accent.deep : theme.colors.borderStrong, backgroundColor: item.state === 'completed' ? accent.surface : theme.colors.surface }]}>
            {item.state === 'completed' && <MaterialIcons name="check" size={17} color={accent.deep} />}
          </Pressable>
          <View style={sharedStyles.grow}>
            <Label>{item.title}</Label>
            <Body>{item.due_date ? `Due ${formatDateOnly(item.due_date, getAppLocale())}` : 'No due date'} · {item.priority} priority{item.postponed_until && item.postponed_until >= todayInProfileTimeZone ? ` · postponed until ${formatDateOnly(item.postponed_until, getAppLocale())}` : ''}{item.notes ? ` · ${item.notes}` : ''}</Body>
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

      {desktopColumns && <View style={styles.taskWorkspace}>
        <View style={styles.taskListColumn}>
          <Panel>
            <Eyebrow>Quick add</Eyebrow>
            <Label>What needs doing?</Label>
            <Field label="Task" value={readOnly ? '' : title} onChangeText={setTitle} placeholder="A small next step" maxLength={120} editable={!readOnly} />
            <Button label="Add task" onPress={() => void addItem()} busy={saving} disabled={readOnly} />
            <Body>Priority</Body>
            <View style={styles.filterRow} accessibilityRole="radiogroup" accessibilityLabel="New task priority">
              {(['low', 'medium', 'high', 'urgent'] as const).map((value) => <Pressable key={value} accessibilityRole="radio" accessibilityState={{ selected: taskPriority === value }} onPress={() => setTaskPriority(value)} style={[styles.filter, { backgroundColor: taskPriority === value ? accent.surface : theme.colors.surface, borderColor: taskPriority === value ? accent.deep : theme.colors.border }]}>
                <Label>{value[0].toUpperCase() + value.slice(1)}</Label>
              </Pressable>)}
            </View>
            <Field label="Due date (optional)" value={readOnly ? '' : dueDate} onChangeText={setDueDate} placeholder="YYYY-MM-DD" autoCapitalize="none" maxLength={10} editable={!readOnly} />
            <Field label="Notes (optional)" value={readOnly ? '' : notes} onChangeText={setNotes} multiline maxLength={2000} placeholder="Add a useful detail" editable={!readOnly} />
          </Panel>
          <Panel>
            <Eyebrow>Tasks · {items.filter((item) => item.item_type === 'task' && item.state === 'active').length} open · {items.filter((item) => item.item_type === 'task' && item.state === 'completed').length} completed</Eyebrow>
            <View style={styles.filterRow} accessibilityRole="tablist" accessibilityLabel="Task view">
              {(['today', 'overdue', 'upcoming', 'postponed', 'completed', 'archived'] as const).map((filter) => <Pressable key={filter} accessibilityRole="tab" accessibilityState={{ selected: taskFilter === filter }} onPress={() => setTaskFilter(filter)} style={[styles.filter, { backgroundColor: taskFilter === filter ? accent.surface : theme.colors.surface, borderColor: taskFilter === filter ? accent.deep : theme.colors.border }]}>
                <Label>{filter[0].toUpperCase() + filter.slice(1)}</Label>
              </Pressable>)}
            </View>
            {visibleTasks.length === 0 ? <Body>{taskFilter === 'completed' ? 'Finished tasks will stay here.' : taskFilter === 'archived' ? 'Archived tasks will appear here.' : taskFilter === 'postponed' ? 'No tasks are postponed.' : taskFilter === 'upcoming' ? 'Nothing is scheduled for a later date.' : taskFilter === 'overdue' ? 'You’re caught up on overdue tasks.' : 'Your next priorities will appear here.'}</Body> : visibleTasks.map((item) => <Pressable key={item.id} accessibilityRole="button" accessibilityLabel={`${item.title}, ${item.state}, ${item.priority} priority`} accessibilityState={{ selected: selectedTask?.id === item.id }} onFocus={() => setFocusedTaskId(item.id)} onBlur={() => setFocusedTaskId((current) => current === item.id ? null : current)} onPress={() => setSelectedTaskId(item.id)} style={[styles.taskChoice, { borderColor: focusedTaskId === item.id ? theme.colors.focusRing : selectedTask?.id === item.id ? accent.deep : theme.colors.border, backgroundColor: selectedTask?.id === item.id ? accent.surface : theme.colors.surface }]}>
              <View style={[styles.check, { borderColor: item.state === 'completed' ? accent.deep : theme.colors.borderStrong, backgroundColor: item.state === 'completed' ? accent.surface : theme.colors.surface }]}>
                {item.state === 'completed' && <MaterialIcons name="check" size={17} color={accent.deep} />}
              </View>
              <View style={sharedStyles.grow}>
                <Label>{item.title}</Label>
                <Body>{item.due_date ? `Due ${formatDateOnly(item.due_date, getAppLocale())}` : 'No due date'} · {item.priority} priority{item.postponed_until && item.postponed_until >= todayInProfileTimeZone ? ` · postponed until ${formatDateOnly(item.postponed_until, getAppLocale())}` : ''}</Body>
              </View>
              <MaterialIcons name="chevron-right" size={20} color={theme.colors.inkMuted} />
            </Pressable>)}
          </Panel>
        </View>
        <View style={styles.taskDetailColumn}>
          {selectedTask ? <Panel>
            <Eyebrow>Selected task · {selectedTask.state}</Eyebrow>
            <Heading>{selectedTask.title}</Heading>
            <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Due date</Body></View><Label>{selectedTask.due_date ? formatDateOnly(selectedTask.due_date, getAppLocale()) : 'Not set'}</Label></View>
            <View style={sharedStyles.row}><View style={sharedStyles.grow}><Body>Priority</Body></View><Label>{selectedTask.priority}</Label></View>
            {selectedTask.postponed_until && selectedTask.postponed_until >= todayInProfileTimeZone && <Body>Postponed until {formatDateOnly(selectedTask.postponed_until, getAppLocale())}</Body>}
            <View style={[styles.taskNotes, { borderTopColor: theme.colors.border }]}>
              <Eyebrow>Notes</Eyebrow><Body>{selectedTask.notes || 'No notes added.'}</Body>
            </View>
            <View style={styles.taskPriorityGroup} accessibilityRole="radiogroup" accessibilityLabel={`${selectedTask.title} priority`}>
              <Body>Change priority</Body>
              <View style={styles.priorityRow}>{(['low', 'medium', 'high', 'urgent'] as const).map((priority) => <Pressable key={priority} accessibilityRole="radio" accessibilityState={{ selected: selectedTask.priority === priority, disabled: readOnly || saving }} disabled={readOnly || saving || selectedTask.priority === priority} onPress={() => void changeTaskMetadata(selectedTask, priority, selectedTask.postponed_until, `${selectedTask.title} priority updated.`)} style={[styles.priorityChoice, { borderColor: selectedTask.priority === priority ? accent.deep : theme.colors.border, backgroundColor: selectedTask.priority === priority ? accent.surface : theme.colors.surface }]}>
                <Body>{priority[0].toUpperCase() + priority.slice(1)}</Body>
              </Pressable>)}</View>
            </View>
            <View style={styles.actionRow}>
              {selectedTask.state === 'archived' ? <Button label="Restore task" variant="secondary" disabled={readOnly || saving} onPress={() => void changeItem(selectedTask, { state: 'active' }, 'Task restored.')} /> : <>
                <Button label={selectedTask.state === 'completed' ? 'Reopen task' : 'Complete task'} variant={selectedTask.state === 'completed' ? 'secondary' : 'primary'} disabled={readOnly || saving} onPress={() => void changeItem(selectedTask, { state: selectedTask.state === 'completed' ? 'active' : 'completed', progressPercent: selectedTask.state === 'completed' ? 0 : 100 }, selectedTask.state === 'completed' ? 'Task reopened.' : 'Task completed.')} />
                {selectedTask.state === 'active' && (selectedTask.postponed_until && selectedTask.postponed_until >= todayInProfileTimeZone
                  ? <Button label="Bring back" variant="tertiary" disabled={readOnly || saving} onPress={() => void changeTaskMetadata(selectedTask, selectedTask.priority, null, 'Task moved back to your active list.')} />
                  : <Button label="Postpone 1 day" variant="tertiary" disabled={readOnly || saving} onPress={() => {
                    const tomorrow = new Date(`${todayInProfileTimeZone}T00:00:00.000Z`); tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
                    void changeTaskMetadata(selectedTask, selectedTask.priority, tomorrow.toISOString().slice(0, 10), 'Task postponed until tomorrow.');
                  }} />)}
                {selectedTask.state === 'active' && <Button label="Archive" variant="tertiary" disabled={readOnly || saving} onPress={() => void changeItem(selectedTask, { state: 'archived' }, 'Task archived.')} />}
              </>}
            </View>
          </Panel> : <Panel><Eyebrow>Task details</Eyebrow><Label>Choose a task</Label><Body>Select an item from the list to review its due date, priority, notes, and actions.</Body></Panel>}
        </View>
      </View>}
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'projects' && <>
      <Panel>
        <Eyebrow>New project</Eyebrow>
        <Field label="Project name" value={readOnly ? '' : projectTitle} onChangeText={setProjectTitle} maxLength={120} placeholder="A larger outcome" editable={!readOnly} />
        <Field label="Notes (optional)" value={readOnly ? '' : projectNotes} onChangeText={setProjectNotes} multiline maxLength={2000} editable={!readOnly} />
        <Button label="Add project" variant="secondary" onPress={() => void addProject()} busy={saving} disabled={readOnly} />
      </Panel>
      <GrowthHierarchyPanel key={`${profileId}:tasks-hierarchy`} moduleId="tasks" items={items} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'focus' && <>
      <TaskFocusPanel items={items} sessions={taskFocusSessions} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    {!loading && moduleId === 'tasks' && sectionId === 'breakdown' && <>
      <TaskBreakdownPanel key={profileId} profileId={profileId} items={items} readOnly={readOnly} onSaved={() => void refresh()} />
    </>}

    <Modal visible={imageEditingSubject !== null} transparent animationType={reduceMotion ? 'none' : 'slide'} onRequestClose={() => setImageEditingSubject(null)} statusBarTranslucent>
      <View style={[styles.subjectArtworkModal, desktop && styles.subjectArtworkModalDesktop]}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close subject image picker" style={StyleSheet.absoluteFill}
          onPress={() => { if (!savingSubjectArtwork) setImageEditingSubject(null); }} />
        <View style={[styles.subjectArtworkSheet, desktop && styles.subjectArtworkSheetDesktop, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={sharedStyles.column}>
            <Eyebrow>Subject image</Eyebrow>
            <Heading>{imageEditingSubject ? imageEditingSubject.title : 'Choose artwork'}</Heading>
            <Body>Choose from 25 built-in study images. This choice is saved on this device.</Body>
          </View>
          <ScrollView contentContainerStyle={styles.subjectArtworkSheetContent}>
            <SubjectArtworkPicker selectedArtwork={imageEditingDraft} onSelect={setImageEditingDraft} disabled={savingSubjectArtwork} />
          </ScrollView>
          {subjectArtworkSaveError && <ErrorText>{subjectArtworkSaveError}</ErrorText>}
          <View style={styles.subjectArtworkActions}>
            <Button label="Cancel" variant="secondary" onPress={() => setImageEditingSubject(null)} disabled={savingSubjectArtwork} />
            <Button label="Save image" onPress={() => void saveSubjectArtwork()} busy={savingSubjectArtwork} />
          </View>
        </View>
      </View>
    </Modal>
  </Screen>;
}

function SubjectArtworkPicker({ selectedArtwork, onSelect, disabled = false }: {
  selectedArtwork: string; onSelect: (id: string) => void; disabled?: boolean;
}) {
  const { theme } = useBloomTheme();
  const accent = theme.modules.study;
  return <View style={styles.subjectArtworkGrid}>
    {studySubjectArtworks.map((artwork) => {
      const selected = selectedArtwork === artwork.id;
      return <Pressable key={artwork.id} accessibilityRole="radio" accessibilityLabel={`Use ${artwork.label} image`}
        accessibilityState={{ checked: selected, disabled }} disabled={disabled} onPress={() => onSelect(artwork.id)}
        style={[styles.subjectArtworkChoice, { borderColor: selected ? accent.deep : theme.colors.border, backgroundColor: selected ? accent.surface : theme.colors.surface }]}>
        <SubjectArtwork artworkId={artwork.id} size={54} />
        <Text numberOfLines={2} style={[styles.subjectArtworkLabel, { color: selected ? accent.deep : theme.colors.inkMuted }]}>{artwork.label}</Text>
      </Pressable>;
    })}
  </View>;
}

function StudyLocalNavigation({ selected, accent, surface, onSelect }: {
  selected: string; accent: string; surface: string; onSelect: (id: string) => void;
}) {
  const { theme } = useBloomTheme();
  const tabs = [
    { id: 'today', label: 'Today', icon: 'today' as const },
    { id: 'plan', label: 'Plan', icon: 'calendar-month' as const },
    { id: 'courses', label: 'Courses', icon: 'account-tree' as const },
    { id: 'more', label: 'More', icon: 'apps' as const },
  ];
  return <View style={[styles.studyNav, { borderColor: theme.colors.border, backgroundColor: theme.colors.surface }]}>
    {tabs.map((tab) => {
      const active = selected === tab.id;
      return <Pressable key={tab.id} accessibilityRole="button" accessibilityState={{ selected: active }}
        accessibilityLabel={`${tab.label}${active ? ', selected' : ''}`} onPress={() => onSelect(tab.id)}
        style={({ pressed }) => [styles.studyNavItem, active && { backgroundColor: surface }, pressed && { opacity: 0.78 }]}>
        <MaterialIcons name={tab.icon} size={20} color={active ? accent : theme.colors.inkMuted} />
        <Text numberOfLines={1} style={[styles.studyNavLabel, { color: active ? accent : theme.colors.inkMuted }]}>{tab.label}</Text>
      </Pressable>;
    })}
  </View>;
}

function StudyMetric({ value, label }: { value: string; label: string }) {
  const { theme } = useBloomTheme();
  return <View style={styles.studyMetric}>
    <Text style={[styles.studyMetricValue, { color: theme.colors.ink }]}>{value}</Text>
    <Text style={[styles.studyMetricLabel, { color: theme.colors.inkMuted }]}>{label}</Text>
  </View>;
}

function StudySessionHistory({ sessions, items, timeZone, onLearningCheck }: {
  sessions: GrowthSession[]; items: Map<string, GrowthItem>; timeZone: string; onLearningCheck: (itemId: string) => void;
}) {
  const { theme } = useBloomTheme();
  const recent = [...sessions].sort((a, b) => Date.parse(b.started_at) - Date.parse(a.started_at)).slice(0, 3);
  return <Panel>
    <View style={sharedStyles.row}><View style={sharedStyles.grow}><Eyebrow>Recent sessions</Eyebrow></View>
      <Text style={[styles.historyCount, { color: theme.colors.inkMuted }]}>{sessions.length}</Text>
    </View>
    {recent.length ? recent.map((session) => <View key={session.id} style={styles.itemRow}>
      <View style={sharedStyles.grow}><Label>{items.get(session.item_id)?.title ?? 'Study session'}</Label>
        <Body>{session.completed_at ? new Date(session.completed_at).toLocaleDateString(getAppLocale(), { timeZone, weekday: 'short', month: 'short', day: 'numeric' }) : 'In progress'} · {session.status === 'completed' ? formatDuration(session.duration_seconds ?? 0) : session.status === 'cancelled' ? 'Cancelled' : 'In progress'}</Body>
      </View>
      {session.status === 'completed' && <Button label="Learning check" variant="tertiary" onPress={() => onLearningCheck(session.item_id)} />}
    </View>) : <Body>Completed sessions will appear here.</Body>}
  </Panel>;
}

function studyRewardMessage(status: string | undefined, minutes: number) {
  if (status === 'awarded') return `${minutes} min of screen time added.`;
  if (status === 'pending') return 'The screen-time reward is pending review.';
  if (status === 'capped') return 'No screen time was added because a reward cap was reached.';
  if (status === 'rejected') return 'This session was not eligible for a screen-time reward.';
  return 'The screen-time reward status is not available yet.';
}

function formatMinutes(minutes: number) {
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return hours ? `${hours}h${remainder ? ` ${remainder}m` : ''}` : `${minutes} min`;
}

function formatTrackedMinutes(seconds: number) {
  if (seconds >= 0 && seconds < 60) return '<1 min';
  return formatMinutes(Math.floor(seconds / 60));
}

function getTodaysStudyPlan(items: GrowthItem[], slots: StudyPlanSlot[], changes: StudyPlanChange[], date: string) {
  if (!date) return [];
  const dayOfWeek = new Date(`${date}T12:00:00Z`).getUTCDay();
  const itemById = new Map(items.map((item) => [item.id, item]));
  const planned = new Map<string, { itemId: string; title: string; minutes: number }>();
  for (const slot of slots.filter((entry) => entry.day_of_week === dayOfWeek)) {
    const item = itemById.get(slot.item_id);
    if (!item || item.state !== 'active') continue;
    const change = changes.find((entry) => entry.item_id === item.id && entry.original_date === date);
    if (!change) planned.set(`${item.id}:${date}`, { itemId: item.id, title: item.title, minutes: slot.target_minutes });
  }
  for (const change of changes.filter((entry) => entry.action === 'move' && entry.moved_to_date === date)) {
    const item = itemById.get(change.item_id);
    const slot = slots.find((entry) => entry.item_id === change.item_id);
    if (item?.state === 'active' && slot) planned.set(`${item.id}:${change.original_date}`, { itemId: item.id, title: item.title, minutes: slot.target_minutes });
  }
  return [...planned.values()].sort((a, b) => a.title.localeCompare(b.title));
}

function findRootSubject(items: GrowthItem[], itemId: string) {
  const byId = new Map(items.map((item) => [item.id, item]));
  let item = byId.get(itemId);
  const visited = new Set<string>();
  while (item && item.item_type !== 'subject' && item.parent_id && !visited.has(item.id)) {
    visited.add(item.id);
    item = byId.get(item.parent_id);
  }
  return item?.item_type === 'subject' ? item : null;
}

function isItemWithin(items: GrowthItem[], itemId: string, ancestorId: string) {
  const byId = new Map(items.map((item) => [item.id, item]));
  let item = byId.get(itemId);
  const visited = new Set<string>();
  while (item && !visited.has(item.id)) {
    if (item.id === ancestorId) return true;
    visited.add(item.id);
    item = item.parent_id ? byId.get(item.parent_id) : undefined;
  }
  return false;
}

function startOfWeekKey(dateKey: string) {
  if (!dateKey) return '';
  const date = new Date(`${dateKey}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - date.getUTCDay());
  return date.toISOString().slice(0, 10);
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
      <View style={sharedStyles.grow}><Label>{items.get(session.item_id)?.title ?? name}</Label><Body>{session.completed_at ? new Date(session.completed_at).toLocaleString(getAppLocale()) : ''}</Body></View>
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
  if (seconds >= 0 && seconds < 60) return '<1 min';
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
  moduleHeroImage: { borderRadius: 24 },
  moduleHeroImageWash: { ...StyleSheet.absoluteFill, borderRadius: 24, backgroundColor: 'rgba(255,255,255,0.66)' },
  tasksHero: { minHeight: 198, borderRadius: 26, overflow: 'hidden', justifyContent: 'center', padding: 20 },
  tasksHeroDesktop: { minHeight: 218, padding: 26 },
  tasksHeroImage: { borderRadius: 26 },
  tasksHeroShade: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(31, 27, 22, 0.57)' },
  tasksHeroContent: { gap: 8 },
  tasksHeroTopRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 12 },
  tasksHeroEyebrow: { color: 'rgba(255,255,255,0.94)', fontSize: 11, lineHeight: 16, fontWeight: '800', letterSpacing: 1.3 },
  tasksHeroTitle: { color: '#FFFFFF', fontSize: 29, lineHeight: 35, fontWeight: '800', maxWidth: 390 },
  tasksHeroTitleDesktop: { fontSize: 34, lineHeight: 40, maxWidth: 560 },
  tasksHeroSubtitle: { color: 'rgba(255,255,255,0.94)', fontSize: 14, lineHeight: 20, fontWeight: '600', maxWidth: 520 },
  tasksHeroAllApps: { minHeight: 44, paddingHorizontal: 13, borderRadius: 14, alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(255,255,255,0.94)' },
  tasksHeroAllAppsPressed: { opacity: 0.84 },
  tasksHeroAllAppsText: { fontSize: 13, lineHeight: 18, fontWeight: '800' },
  moduleTitleRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  moduleIcon: { width: 48, height: 48, borderRadius: 16, justifyContent: 'center', alignItems: 'center' },
  sectionHeading: { gap: 5, paddingTop: 2 },
  studyHeader: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingTop: 2 },
  studyNav: { flexDirection: 'row', gap: 3, padding: 4, borderWidth: 1, borderRadius: 20 },
  studyNavItem: { flex: 1, minHeight: 46, borderRadius: 15, alignItems: 'center', justifyContent: 'center', flexDirection: 'row', gap: 5, paddingHorizontal: 4 },
  studyNavLabel: { fontSize: 12, fontWeight: '700' },
  studyHero: { height: 168, borderRadius: 26, overflow: 'hidden', justifyContent: 'flex-end' },
  studyHeroImage: { borderRadius: 26 },
  studyHeroShade: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(15, 28, 58, 0.34)' },
  studyHeroCopy: { padding: 20, gap: 5 },
  studyHeroEyebrow: { color: '#FFFFFF', fontSize: 12, fontWeight: '800', letterSpacing: 1.2 },
  studyHeroTitle: { color: '#FFFFFF', fontSize: 25, lineHeight: 31, fontWeight: '800', maxWidth: 280 },
  studySection: { gap: 12 },
  subjectArtworkChooser: { gap: 10 },
  todayMetrics: { flexDirection: 'row', gap: 10 },
  studyMetric: { flex: 1, gap: 2 },
  studyMetricValue: { fontSize: 23, lineHeight: 28, fontWeight: '800', fontVariant: ['tabular-nums'] },
  studyMetricLabel: { fontSize: 12, lineHeight: 17, fontWeight: '600' },
  todayPercent: { fontSize: 28, lineHeight: 34, fontWeight: '800', fontVariant: ['tabular-nums'] },
  studyPicker: { borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#E4E8F3', paddingTop: 12, gap: 4 },
  subjectCards: { gap: 12, paddingEnd: 3 },
  subjectCard: { width: 286, minHeight: 154, borderWidth: 1, borderRadius: 21, padding: 13, gap: 11 },
  subjectCardTop: { flexDirection: 'row', alignItems: 'flex-start', gap: 11 },
  subjectEyebrow: { fontSize: 10, fontWeight: '800', letterSpacing: 1.1 },
  subjectTitle: { fontSize: 18, lineHeight: 23, fontWeight: '800' },
  subjectDetail: { fontSize: 12, lineHeight: 17, fontWeight: '600' },
  subjectCardActions: { flexDirection: 'row', alignItems: 'center', gap: 8 },
  subjectOpenAction: { minHeight: 40, flex: 1, paddingHorizontal: 14, justifyContent: 'center', alignItems: 'center', borderRadius: 13 },
  subjectOpenText: { fontSize: 13, fontWeight: '800' },
  subjectImageAction: { width: 42, height: 42, borderWidth: 1, justifyContent: 'center', alignItems: 'center', borderRadius: 14 },
  subjectArtworkGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  subjectArtworkChoice: { width: '22%', minWidth: 60, minHeight: 78, borderWidth: 1, borderRadius: 14, padding: 6, alignItems: 'center', gap: 4 },
  subjectArtworkLabel: { minHeight: 26, fontSize: 9, lineHeight: 12, fontWeight: '700', textAlign: 'center' },
  subjectArtworkModal: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(9, 17, 32, 0.48)' },
  subjectArtworkModalDesktop: { justifyContent: 'center', alignItems: 'center', padding: 24 },
  subjectArtworkSheet: { maxHeight: '92%', borderTopLeftRadius: 28, borderTopRightRadius: 28, borderWidth: 1, padding: 20, paddingBottom: 26, gap: 14 },
  subjectArtworkSheetDesktop: { width: '100%', maxWidth: 720, borderRadius: 28 },
  subjectArtworkSheetContent: { paddingBottom: 5 },
  subjectArtworkActions: { gap: 8 },
  liveIndicator: { borderRadius: 999, paddingHorizontal: 10, paddingVertical: 6, alignItems: 'center', flexDirection: 'row', gap: 6 },
  liveDot: { width: 7, height: 7, borderRadius: 4 },
  liveText: { fontSize: 10, fontWeight: '800', letterSpacing: 0.8 },
  planDone: { fontSize: 13, fontWeight: '800' },
  historyCount: { fontSize: 13, fontWeight: '700' },
  immersiveTitle: { gap: 4, marginBottom: 8 },
  sessionTimer: { fontSize: 50, lineHeight: 60, fontWeight: '800', letterSpacing: -1.5, fontVariant: ['tabular-nums'] },
  connectionNotice: { borderWidth: 1, borderRadius: 16, paddingHorizontal: 12, paddingVertical: 10, flexDirection: 'row', alignItems: 'center', gap: 8 },
  loadingNotice: { minHeight: 76, alignItems: 'center', justifyContent: 'center', gap: 8 },
  dashboardSection: { gap: 12 },
  moreTools: { gap: 8 },
  dashboardGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  dashboardTile: { width: '48%', minWidth: 145, flexGrow: 1, flexBasis: 150 },
  taskWorkspace: { flexDirection: 'row', alignItems: 'flex-start', gap: 16 },
  taskListColumn: { flex: 0.95, minWidth: 300, gap: 16 },
  taskDetailColumn: { flex: 1.05, minWidth: 340 },
  taskChoice: { minHeight: 68, flexDirection: 'row', alignItems: 'center', gap: 10, borderWidth: 1, borderRadius: 14, padding: 11, marginTop: 8 },
  taskNotes: { borderTopWidth: StyleSheet.hairlineWidth, paddingTop: 12, gap: 5 },
  taskPriorityGroup: { gap: 8, paddingTop: 4 },
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
