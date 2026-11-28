import { useUsageRequest } from '../lib/usage-request';
import { UsageButton } from './usage-action';
import { getAppLocale } from '../lib/locale-context';
import { randomUUID } from 'expo-crypto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { Pressable, StyleSheet, Switch, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Label, LocalizedText as Text, Panel, ProgressBar, sharedStyles, useIsDesktopColumns } from './bloom-ui';
import {
  changeStudyOccurrence, createGrowthChild, createGrowthItem, deleteGrowthRecord, finishTaskFocus, formatElapsed,
  saveGrowthRecord, saveStudyPlan, saveStudyVerification, startTaskFocus, submitStudyReview, updateGrowthItem, updateGrowthReadingDetails, updateGrowthRecord, updateStudyVerification,
  type GrowthDocument, type GrowthItem, type GrowthModuleId, type GrowthRecord, type GrowthRecordAttachment, type StudyPlanChange, type StudyPlanSlot,
  type TaskFocusSession, type GrowthSession,
} from '../lib/growth-modules';
import { approveTaskBreakdown, clearStudyTutorConversation, loadGrowthAiPreferences, loadStudyTutorMessages, requestReadingReflection, requestStudyTutor, requestTaskBreakdown, saveGrowthAiPreferences, type GrowthAiPreferences, type StudyTutorMessage, type TaskBreakdownDraft } from '../lib/growth-ai';
import { useAuth } from '../lib/auth';
import { suggestStudyPracticeDifficulty, type StudyPracticeDifficulty } from '../lib/study-practice';
import { useBloomTheme } from '../lib/theme-context';
import { dateKeyInTimeZone } from '../lib/date-utils';

const studyDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export function StudyPlanPanel({ items, slots, changes, sessions, timeZone, today, todayDayOfWeek, readOnly, onSaved }: {
  items: GrowthItem[]; slots: StudyPlanSlot[]; changes: StudyPlanChange[]; sessions: GrowthSession[]; timeZone: string;
  today: string; todayDayOfWeek: number; readOnly: boolean; onSaved: () => void;
}) {
  const { theme } = useBloomTheme();
  const { profileId } = useAuth();
  const desktopColumns = useIsDesktopColumns();
  const [values, setValues] = useState<Record<string, string[]>>(() => initialPlanValues(items, slots));
  const [selectedDay, setSelectedDay] = useState(todayDayOfWeek);
  const [loadedPlanDraftKey, setLoadedPlanDraftKey] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const active = items.filter((item) => item.state === 'active' && ['subject', 'course'].includes(item.item_type));
  const initialPlanDraft = useRef({ values: initialPlanValues(items, slots), itemIds: active.map((item) => item.id) });
  const weekStart = startOfWeekKey(today);
  const completedMinutes = Math.floor(sessions.filter((session) => session.status === 'completed' && session.completed_at
    && dateKeyInTimeZone(Date.parse(session.completed_at), timeZone) >= weekStart
    && dateKeyInTimeZone(Date.parse(session.completed_at), timeZone) <= today)
    .reduce((sum, session) => sum + (session.duration_seconds ?? 0), 0) / 60);
  const plannedMinutes = active.reduce((sum, item) => sum + (values[item.id] ?? Array(7).fill('0'))
    .reduce((itemSum, minutes) => itemSum + (Number.isInteger(Number(minutes)) ? Number(minutes) : 0), 0), 0);
  const dayTotals = studyDays.map((_, day) => active.reduce((sum, item) => {
    const minutes = Number(values[item.id]?.[day] ?? 0);
    return sum + (Number.isInteger(minutes) && minutes > 0 ? minutes : 0);
  }, 0));
  const upcoming = useMemo(() => getUpcomingStudySessions(items, slots, changes, today), [items, slots, changes, today]);
  const planDraftKey = profileId ? `bloom.study-plan-draft.v1:${profileId}` : null;

  useEffect(() => {
    let active = true;
    if (!planDraftKey) return () => { active = false; };
    void AsyncStorage.getItem(planDraftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1
            && 'selectedDay' in saved && typeof saved.selectedDay === 'number' && Number.isInteger(saved.selectedDay) && saved.selectedDay >= 0 && saved.selectedDay <= 6
            && 'values' in saved && saved.values && typeof saved.values === 'object') {
            const next = { ...initialPlanDraft.current.values };
            for (const itemId of initialPlanDraft.current.itemIds) {
              const candidate = (saved.values as Record<string, unknown>)[itemId];
              if (Array.isArray(candidate) && candidate.length === 7 && candidate.every((value) => typeof value === 'string' && value.length <= 4)) {
                next[itemId] = candidate;
              }
            }
            setValues(next);
            setSelectedDay(saved.selectedDay);
          }
        } catch { /* Ignore an unreadable local plan draft and start from the saved plan. */ }
      }
      setLoadedPlanDraftKey(planDraftKey);
    }).catch(() => {
      if (active) setLoadedPlanDraftKey(planDraftKey);
    });
    return () => { active = false; };
  }, [planDraftKey]);

  useEffect(() => {
    if (!planDraftKey || loadedPlanDraftKey !== planDraftKey) return;
    void AsyncStorage.setItem(planDraftKey, JSON.stringify({ version: 1, selectedDay, values })).catch(() => undefined);
  }, [loadedPlanDraftKey, planDraftKey, selectedDay, values]);

  async function save() {
    setBusy(true); setError(null); setNotice(null);
    try {
      const entries = active.flatMap((item) => {
        const parsed = (values[item.id] ?? Array(7).fill('0')).map((part) => part.trim() ? Number(part.trim()) : 0);
        if (parsed.length !== 7 || parsed.some((minutes) => !Number.isInteger(minutes) || minutes < 0 || minutes > 1440)) {
          throw new Error(`Enter seven daily minute values for ${item.title}.`);
        }
        return parsed.flatMap((minutes, dayOfWeek) => minutes > 0 ? [{ itemId: item.id, dayOfWeek, targetMinutes: minutes }] : []);
      });
      await saveStudyPlan(entries);
      if (planDraftKey) await AsyncStorage.removeItem(planDraftKey).catch(() => undefined);
      setNotice('Weekly plan saved.');
      onSaved();
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not save the weekly plan.'); }
    finally { setBusy(false); }
  }

  async function reschedule(itemId: string, date: string, action: 'skip' | 'move') {
    setBusy(true); setError(null); setNotice(null);
    const moved = action === 'move' ? addDays(date, 1) : undefined;
    try {
      await changeStudyOccurrence(itemId, date, action, moved);
      setNotice(action === 'skip' ? 'Session skipped. It will not count as a missed session.' : `Session moved to ${moved}.`);
      onSaved();
    } catch { setError('Could not update this session. Check that the date is still in the plan window.'); }
    finally { setBusy(false); }
  }

  return <View style={[styles.studyPlanWorkspace, desktopColumns && styles.studyPlanWorkspaceDesktop]}>
    <View style={[styles.studyPlanEditor, desktopColumns && styles.studyPlanEditorDesktop]}><Panel>
      <Eyebrow>Weekly plan</Eyebrow>
      <Text style={[styles.planBigMetric, { color: theme.colors.ink }]}>{formatMinutes(plannedMinutes)}</Text>
      <View style={styles.planSummaryRow}>
        <View style={sharedStyles.grow}><Body>Planned</Body><Label>{formatMinutes(plannedMinutes)}</Label></View>
        <View style={sharedStyles.grow}><Body>Completed</Body><Label>{formatMinutes(completedMinutes)}</Label></View>
        <View style={sharedStyles.grow}><Body>Remaining</Body><Label>{formatMinutes(Math.max(0, plannedMinutes - completedMinutes))}</Label></View>
      </View>
      <View style={[styles.planDaySelector, { borderColor: theme.colors.border }]}>
        {studyDays.map((day, dayOfWeek) => {
          const selected = selectedDay === dayOfWeek;
          const isToday = todayDayOfWeek === dayOfWeek;
          return <Pressable key={day} accessibilityRole="button" accessibilityState={{ selected }} accessibilityLabel={`${day}${isToday ? ', today' : ''}, ${dayTotals[dayOfWeek]} planned minutes`}
            onPress={() => setSelectedDay(dayOfWeek)} style={({ pressed }) => [styles.planDayOption,
              selected && { backgroundColor: theme.modules.study.surface, borderColor: theme.modules.study.deep }, pressed && { opacity: 0.78 }]}>
            <Text style={[styles.planDayName, { color: selected ? theme.modules.study.deep : theme.colors.inkMuted }]}>{day}{isToday ? ' ·' : ''}</Text>
            <Text style={[styles.planDayMinutes, { color: theme.colors.ink }]}>{dayTotals[dayOfWeek] ? `${dayTotals[dayOfWeek]}m` : '—'}</Text>
          </Pressable>;
        })}
      </View>
      {active.length === 0 ? <Body>Add a subject to start planning.</Body> : <>
        <Label>{studyDays[selectedDay]} allocation</Label>
        {active.map((item) => {
          const dailyValues = values[item.id] ?? Array(7).fill('0');
          const total = dailyValues.reduce((sum, value) => sum + (Number.isInteger(Number(value)) ? Number(value) : 0), 0);
          return <View key={item.id} style={styles.planInputRow}>
            <View style={sharedStyles.grow}><Label>{item.title}</Label><Body>{item.item_type === 'subject' ? `${item.target_minutes ?? 0} min target` : `${formatMinutes(total)} this week`}</Body></View>
            <View style={styles.planInput}><Field label="Minutes" value={dailyValues[selectedDay] ?? '0'}
              onChangeText={(value) => setValues((current) => {
                const next = [...(current[item.id] ?? Array(7).fill('0'))]; next[selectedDay] = value;
                return { ...current, [item.id]: next };
              })}
              placeholder="0" keyboardType="number-pad" maxLength={4} editable={!readOnly && !busy} /></View>
          </View>;
        })}
        <Button label="Save weekly plan" onPress={() => void save()} busy={busy} disabled={readOnly} />
      </>}
      {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    </Panel></View>
    <View style={[styles.studyPlanUpcoming, desktopColumns && styles.studyPlanUpcomingDesktop]}><Panel>
      <Eyebrow>Upcoming</Eyebrow>
      {upcoming.length === 0 ? <Body>No planned sessions yet.</Body> : upcoming.slice(0, 5).map((session) => <View key={`${session.itemId}:${session.date}`} style={styles.row}>
        <View style={sharedStyles.grow}><Label>{session.title} · {formatMinutes(session.minutes)}</Label><Body>{formatPlanDate(session.date)}{session.moved ? ' · moved' : ''}</Body></View>
        <Button label="Skip" variant="tertiary" disabled={busy || readOnly} onPress={() => void reschedule(session.itemId, session.originalDate, 'skip')} />
        <Button label="Move +1 day" variant="tertiary" disabled={busy || readOnly} onPress={() => void reschedule(session.itemId, session.originalDate, 'move')} />
      </View>)}
    </Panel></View>
  </View>;
}

export function StudyPracticeReviewPanel({ items, records, initialItemId, readOnly, onSaved }: {
  items: GrowthItem[]; records: GrowthRecord[]; initialItemId?: string; readOnly: boolean; onSaved: () => void;
}) {
  const { profileId } = useAuth();
  const studyItems = useMemo(() => items.filter((item) => item.module_id === 'study' && item.state !== 'archived'), [items]);
  const [itemId, setItemId] = useState(initialItemId ?? studyItems[0]?.id ?? null);
  const [question, setQuestion] = useState('');
  const [answerKey, setAnswerKey] = useState('');
  const [explanation, setExplanation] = useState('');
  const [difficultyOverride, setDifficultyOverride] = useState<StudyPracticeDifficulty | null>(null);
  const [practiceAnswer, setPracticeAnswer] = useState('');
  const [activeQuestionId, setActiveQuestionId] = useState<string | null>(null);
  const [reviewTitle, setReviewTitle] = useState('');
  const [reviewPrompt, setReviewPrompt] = useState('');
  const [reviewInterval, setReviewInterval] = useState('1');
  const [activeReviewId, setActiveReviewId] = useState<string | null>(null);
  const [reviewAnswer, setReviewAnswer] = useState('');
  const [reviewRating, setReviewRating] = useState<'hard' | 'remembered' | 'easy'>('remembered');
  const [nextInterval, setNextInterval] = useState('3');
  const [busy, setBusy] = useState(false);
  const [now, setNow] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const pendingReview = useRef<{ signature: string; requestId: string } | null>(null);
  const draftKey = profileId ? `bloom.study-practice-draft.v1:${profileId}` : null;
  useEffect(() => {
    let active = true;
    if (readOnly || !draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1) {
            const value = saved as Record<string, unknown>;
            if (typeof value.itemId === 'string' && value.itemId.length <= 128) setItemId(value.itemId);
            if (typeof value.question === 'string' && value.question.length <= 500) setQuestion(value.question);
            if (typeof value.answerKey === 'string' && value.answerKey.length <= 2000) setAnswerKey(value.answerKey);
            if (typeof value.explanation === 'string' && value.explanation.length <= 3000) setExplanation(value.explanation);
            if (value.difficultyOverride === null || value.difficultyOverride === 'gentle' || value.difficultyOverride === 'steady' || value.difficultyOverride === 'challenge') setDifficultyOverride(value.difficultyOverride);
            if (typeof value.activeQuestionId === 'string' && value.activeQuestionId.length <= 128) setActiveQuestionId(value.activeQuestionId);
            if (typeof value.practiceAnswer === 'string' && value.practiceAnswer.length <= 3000) setPracticeAnswer(value.practiceAnswer);
            if (typeof value.reviewTitle === 'string' && value.reviewTitle.length <= 120) setReviewTitle(value.reviewTitle);
            if (typeof value.reviewPrompt === 'string' && value.reviewPrompt.length <= 3000) setReviewPrompt(value.reviewPrompt);
            if (typeof value.reviewInterval === 'string' && value.reviewInterval.length <= 2) setReviewInterval(value.reviewInterval);
            if (typeof value.activeReviewId === 'string' && value.activeReviewId.length <= 128) setActiveReviewId(value.activeReviewId);
            if (typeof value.reviewAnswer === 'string' && value.reviewAnswer.length <= 5000) setReviewAnswer(value.reviewAnswer);
            if (value.reviewRating === 'hard' || value.reviewRating === 'remembered' || value.reviewRating === 'easy') setReviewRating(value.reviewRating);
            if (typeof value.nextInterval === 'string' && value.nextInterval.length <= 2) setNextInterval(value.nextInterval);
          }
        } catch { /* Ignore an unreadable local Study practice draft. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [draftKey, readOnly]);

  useEffect(() => {
    if (readOnly || !draftKey || loadedDraftKey !== draftKey) return;
    const hasDraft = Boolean(question || answerKey || explanation || practiceAnswer || reviewTitle || reviewPrompt || reviewAnswer
      || activeQuestionId || activeReviewId || difficultyOverride);
    if (!hasDraft) {
      void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(draftKey, JSON.stringify({ version: 1, itemId, question, answerKey, explanation, difficultyOverride,
      activeQuestionId, practiceAnswer, reviewTitle, reviewPrompt, reviewInterval, activeReviewId, reviewAnswer, reviewRating, nextInterval })).catch(() => undefined);
  }, [activeQuestionId, activeReviewId, answerKey, difficultyOverride, draftKey, explanation, itemId, loadedDraftKey, nextInterval,
    practiceAnswer, question, readOnly, reviewAnswer, reviewInterval, reviewPrompt, reviewRating, reviewTitle]);
  useEffect(() => {
    const immediate = setTimeout(() => setNow(Date.now()), 0);
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => { clearTimeout(immediate); clearInterval(timer); };
  }, []);
  const questions = records.filter((record) => record.kind === 'practice_question');
  const answers = records.filter((record) => record.kind === 'practice_answer');
  const suggestedDifficulty = suggestStudyPracticeDifficulty(answers);
  const difficulty = difficultyOverride ?? suggestedDifficulty;
  const reviewedIds = new Set(answers.map((record) => String(record.metadata.question_id ?? '')));
  const duePrompts = records.filter((record) => record.kind === 'review_prompt' && record.scheduled_at
    && Date.parse(record.scheduled_at) <= now
    && !records.some((answer) => answer.kind === 'review_answer' && answer.metadata.prompt_id === record.id))
    .sort((a, b) => String(a.scheduled_at).localeCompare(String(b.scheduled_at)));
  const activeQuestion = questions.find((record) => record.id === activeQuestionId);
  const activeReview = duePrompts.find((record) => record.id === activeReviewId);

  async function addQuestion() {
    if (!question.trim() || !answerKey.trim() || !explanation.trim() || !itemId) { setError('Add a question, answer, explanation, and Study item.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthRecord({ moduleId: 'study', itemId, kind: 'practice_question', title: question.trim(),
        body: `Expected answer\n${answerKey.trim()}\n\nExplanation\n${explanation.trim()}`,
        metadata: { difficulty }, requestId: randomUUID() });
      setQuestion(''); setAnswerKey(''); setExplanation(''); setNotice('Practice question saved.'); onSaved();
    } catch { setError('Could not save this practice question.'); }
    finally { setBusy(false); }
  }

  async function answerQuestion(correct: boolean) {
    if (!activeQuestion || !practiceAnswer.trim()) return;
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthRecord({ moduleId: 'study', itemId: activeQuestion.item_id, kind: 'practice_answer',
        title: activeQuestion.title, body: practiceAnswer.trim(),
        metadata: { question_id: activeQuestion.id, self_assessed_correct: correct, difficulty: activeQuestion.metadata.difficulty ?? 'steady' },
        requestId: randomUUID() });
      setPracticeAnswer(''); setActiveQuestionId(null); setDifficultyOverride(null);
      setNotice('Your self-rating is saved. Compare your answer with the explanation below.'); onSaved();
    } catch { setError('Could not save your answer.'); }
    finally { setBusy(false); }
  }

  async function addReviewPrompt() {
    const days = Number(reviewInterval);
    if (!reviewTitle.trim() || !reviewPrompt.trim() || !itemId || !Number.isInteger(days) || days < 0 || days > 30) {
      setError('Enter a prompt, select a Study item, and choose 0–30 days.'); return;
    }
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthRecord({ moduleId: 'study', itemId, kind: 'review_prompt', title: reviewTitle.trim(), body: reviewPrompt.trim(),
        metadata: { interval_days: days }, scheduledAt: new Date(Date.now() + days * 86400000).toISOString(), requestId: randomUUID() });
      setReviewTitle(''); setReviewPrompt(''); setNotice(days === 0 ? 'Retrieval prompt added to your due queue.' : `Retrieval prompt scheduled in ${days} day${days === 1 ? '' : 's'}.`); onSaved();
    } catch { setError('Could not save this retrieval prompt.'); }
    finally { setBusy(false); }
  }

  async function submitReview() {
    if (!activeReview || !reviewAnswer.trim()) return;
    const days = Number(nextInterval);
    if (!Number.isInteger(days) || days < 1 || days > 30) { setError('Choose the next review in 1–30 days.'); return; }
    const signature = JSON.stringify([activeReview.id, reviewAnswer.trim(), reviewRating, days]);
    if (pendingReview.current?.signature !== signature) pendingReview.current = { signature, requestId: randomUUID() };
    setBusy(true); setError(null); setNotice(null);
    try {
      await submitStudyReview(activeReview.id, reviewAnswer.trim(), reviewRating, days, pendingReview.current.requestId);
      pendingReview.current = null; setReviewAnswer(''); setActiveReviewId(null);
      setNotice(`Review saved. Next scheduled in ${days} day${days === 1 ? '' : 's'}; Bloom did not assign a mastery score.`); onSaved();
    } catch { setError('Could not save your review. Your answer remains in the form so you can retry.'); }
    finally { setBusy(false); }
  }

  function chooseRating(rating: 'hard' | 'remembered' | 'easy') {
    setReviewRating(rating);
    setNextInterval(rating === 'hard' ? '1' : rating === 'remembered' ? '3' : '7');
  }

  return <Panel>
    <Eyebrow>Study practice and review</Eyebrow>
    <Body>Use your own questions and explanations. Recent self-rated answers set the suggested difficulty for your next question; you can change it before saving. This is not a mastery score.</Body>
    {studyItems.length > 0 && <View style={styles.choiceRow}>{studyItems.filter((item) => ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)).map((item) => <Button key={item.id}
      label={`${itemId === item.id ? '✓ ' : ''}${item.title}`} variant="tertiary" disabled={busy || readOnly} onPress={() => setItemId(item.id)} />)}</View>}
    <Label>Next question difficulty · {difficulty}{difficultyOverride ? ' · changed by you' : ' · suggested'}</Label>
    <View style={styles.choiceRow}>{(['gentle', 'steady', 'challenge'] as const).map((value) => <Button key={value}
      label={`${difficulty === value ? '✓ ' : ''}${value}`} variant="tertiary" disabled={busy || readOnly}
      onPress={() => setDifficultyOverride(value === suggestedDifficulty ? null : value)} />)}</View>
    <Field label="Practice question" value={readOnly ? '' : question} onChangeText={setQuestion} maxLength={500} multiline editable={!busy && !readOnly} />
    <Field label="Expected answer" value={readOnly ? '' : answerKey} onChangeText={setAnswerKey} maxLength={2000} multiline editable={!busy && !readOnly} />
    <Field label="Explanation" value={readOnly ? '' : explanation} onChangeText={setExplanation} maxLength={3000} multiline editable={!busy && !readOnly} />
    <Button label="Save practice question" onPress={() => void addQuestion()} busy={busy} disabled={busy || readOnly} />
    <Label>Practice questions</Label>
    {questions.length === 0 ? <Body>Add a question to begin.</Body> : questions.map((record) => <View key={record.id} style={styles.record}>
      <Label>{record.title} · {String(record.metadata.difficulty ?? 'steady')}{reviewedIds.has(record.id) ? ' · answered' : ''}</Label>
      {!reviewedIds.has(record.id) && <Button label="Try this question" variant="tertiary" disabled={busy || readOnly} onPress={() => { setActiveQuestionId(record.id); setPracticeAnswer(''); }} />}
      {activeQuestionId === record.id && <View style={sharedStyles.column}>
        <Field label="Your answer" value={readOnly ? '' : practiceAnswer} onChangeText={setPracticeAnswer} multiline maxLength={3000} editable={!busy && !readOnly} />
        <View style={styles.row}><Button label="I could answer it" variant="secondary" onPress={() => void answerQuestion(true)} disabled={busy || readOnly || !practiceAnswer.trim()} />
          <Button label="I need to review this" variant="secondary" onPress={() => void answerQuestion(false)} disabled={busy || readOnly || !practiceAnswer.trim()} /></View>
      </View>}
      {reviewedIds.has(record.id) && <Body>{record.body}</Body>}
    </View>)}

    <Label>Spaced retrieval prompts</Label>
    <Body>Choose an initial interval. When a prompt is due, rate how retrieval felt and edit the next interval if needed.</Body>
    <Field label="Prompt title" value={readOnly ? '' : reviewTitle} onChangeText={setReviewTitle} maxLength={120} editable={!busy && !readOnly} />
    <Field label="Question to retrieve" value={readOnly ? '' : reviewPrompt} onChangeText={setReviewPrompt} multiline maxLength={3000} editable={!busy && !readOnly} />
    <Field label="First review in days (0–30)" value={readOnly ? '' : reviewInterval} onChangeText={setReviewInterval} keyboardType="number-pad" editable={!busy && !readOnly} />
    <Button label="Add retrieval prompt" variant="secondary" onPress={() => void addReviewPrompt()} busy={busy} disabled={busy || readOnly} />
    <Label>Due review queue · {duePrompts.length}</Label>
    {duePrompts.length === 0 ? <Body>No reviews due. Your schedule appears here when prompts reach their date.</Body> : duePrompts.map((record) => <View key={record.id} style={styles.record}>
      <Label>{record.title}</Label><Body>{record.body}</Body>
      {activeReviewId !== record.id && <Button label="Review now" variant="tertiary" disabled={busy || readOnly} onPress={() => { setActiveReviewId(record.id); setReviewAnswer(''); setReviewRating('remembered'); setNextInterval('3'); }} />}
      {activeReviewId === record.id && <View style={sharedStyles.column}>
        <Field label="Your recalled answer" value={readOnly ? '' : reviewAnswer} onChangeText={setReviewAnswer} multiline maxLength={5000} editable={!busy && !readOnly} />
        <View style={styles.choiceRow}>{(['hard', 'remembered', 'easy'] as const).map((rating) => <Button key={rating}
          label={`${reviewRating === rating ? '✓ ' : ''}${rating}`} variant="tertiary" disabled={busy || readOnly} onPress={() => chooseRating(rating)} />)}</View>
        <Field label="Next review in days (1–30)" value={readOnly ? '' : nextInterval} onChangeText={setNextInterval} keyboardType="number-pad" editable={!busy && !readOnly} />
        <Button label="Save review and schedule next" onPress={() => void submitReview()} busy={busy} disabled={busy || readOnly || !reviewAnswer.trim()} />
      </View>}
    </View>)}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function StudyTutorPanel({ profileId, items, initialItemId, readOnly }: { profileId: string; items: GrowthItem[]; initialItemId?: string; readOnly: boolean }) {
  const { childProfile } = useAuth();
  const [preferences, setPreferences] = useState<GrowthAiPreferences | null>(null);
  const [messages, setMessages] = useState<StudyTutorMessage[]>([]);
  const [itemId, setItemId] = useState(initialItemId ?? items.find((item) => item.module_id === 'study' && item.state !== 'archived')?.id ?? '');
  const [prompt, setPrompt] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [confirmClear, setConfirmClear] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const draftKey = profileId ? `bloom.study-tutor-draft.v1:${profileId}` : null;
  const activeItems = useMemo(() => items.filter((item) => item.module_id === 'study' && item.state !== 'archived'
    && ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)), [items]);
  const itemNames = useMemo(() => new Map(items.map((item) => [item.id, item.title])), [items]);

  const refresh = useCallback(async () => {
    try {
      const [nextPreferences, nextMessages] = await Promise.all([
        loadGrowthAiPreferences(profileId, 'study'), loadStudyTutorMessages(profileId),
      ]);
      setPreferences(nextPreferences);
      setMessages(nextMessages);
      setError(null);
    } catch {
      setError('Could not load the private tutor conversation.');
    } finally {
      setLoading(false);
    }
  }, [profileId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));

  useEffect(() => {
    let active = true;
    if (readOnly || !draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1) {
            const value = saved as Record<string, unknown>;
            if (typeof value.prompt === 'string' && value.prompt.length <= 2000) setPrompt(value.prompt);
            if (typeof value.itemId === 'string' && activeItems.some((item) => item.id === value.itemId)) setItemId(value.itemId);
          }
        } catch { /* Ignore an unreadable local tutor draft. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [activeItems, draftKey, readOnly]);

  useEffect(() => {
    if (readOnly || !draftKey || loadedDraftKey !== draftKey) return;
    if (!prompt) {
      void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(draftKey, JSON.stringify({ version: 1, prompt, itemId })).catch(() => undefined);
  }, [draftKey, itemId, loadedDraftKey, prompt, readOnly]);

  const consentReady = childProfile
    ? Boolean(preferences?.parent_enabled && preferences.parent_sharing_consent && preferences.minor_eligible_attested)
    : Boolean(preferences?.adult_attested);
  const canAsk = Boolean(preferences?.sharing_consent && consentReady && itemId);

  async function updateConsent(enabled: boolean) {
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthAiPreferences('study', enabled, childProfile ? false : enabled);
      setNotice(enabled ? 'Study tutor consent saved.' : 'Study tutor consent turned off.');
      await refresh();
    } catch {
      setError('Could not save tutor consent. Check the parent settings and try again.');
    } finally { setBusy(false); }
  }

  const { run: runTutor, retrying: retryTutor } = useUsageRequest();

  async function askTutor() {
    if (!canAsk || !prompt.trim()) { setError('Choose a Study item and enter a question.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      const response = await runTutor([itemId, prompt.trim()], (id) => requestStudyTutor(id, itemId, prompt.trim()));
      setPrompt('');
      setNotice(response.status === 'cleared'
        ? 'Your Study tutor conversation was cleared before this response finished.'
        : 'Tutor response saved in your private Study history.');
      await refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not prepare a tutor response. Please try again.');
    } finally { setBusy(false); }
  }

  async function clearConversation() {
    setBusy(true); setError(null); setNotice(null);
    try {
      await clearStudyTutorConversation(); setConfirmClear(false); setMessages([]);
      setNotice('Your Study tutor conversation was cleared.');
    } catch { setError('Could not clear the tutor conversation.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>Study tutor</Eyebrow>
    <Body>Ask for a general explanation tied to a Study item. Bloom labels these as general knowledge, not answers verified against your class materials.</Body>
    <View style={sharedStyles.row}>
      <View style={sharedStyles.grow}><Label>{childProfile ? 'I consent to sending my Study question to Bloom’s approved AI provider' : 'I am an adult and consent to sending Study questions to Bloom’s approved AI provider'}</Label>
        <Body>{childProfile ? preferences?.parent_enabled && preferences.parent_sharing_consent && preferences.minor_eligible_attested
          ? 'A parent has enabled AI tutoring for this profile.' : 'A parent must also enable AI tutoring and confirm eligibility.'
          : 'You can turn this off at any time and clear the saved conversation.'}</Body></View>
      <Switch accessibilityLabel="Study tutor consent" value={Boolean(preferences?.sharing_consent)}
        disabled={busy || loading || readOnly} onValueChange={(enabled) => void updateConsent(enabled)} />
    </View>
    {activeItems.length > 0 && <View style={styles.choiceRow}>{activeItems.map((item) => <Button key={item.id}
      label={`${itemId === item.id ? '✓ ' : ''}${item.title}`} variant="tertiary" disabled={busy || readOnly}
      onPress={() => setItemId(item.id)} />)}</View>}
    {activeItems.length === 0 && <Body>Add a Study item before asking a tutor question.</Body>}
    <Field label="Question" value={readOnly ? '' : prompt} onChangeText={setPrompt} multiline maxLength={2000} editable={!busy && !readOnly && canAsk}
      placeholder="Ask for an explanation or an example" />
    <UsageButton feature="study_tutor" replay={retryTutor} label="Ask the Study tutor" onPress={() => askTutor()} busy={busy} disabled={busy || readOnly || !canAsk || !prompt.trim()} />
    {loading && <Body>Loading private tutor history…</Body>}
    {messages.map((message) => <View key={message.id} style={styles.record}>
      <Label>{message.role === 'assistant' ? 'Bloom tutor · General explanation' : 'You'}{itemNames.has(message.item_id) ? ` · ${itemNames.get(message.item_id)}` : ''}</Label>
      <Body>{message.content}</Body>
      {message.role === 'assistant' && message.uncertainty && <Body>Uncertainty: {message.uncertainty}</Body>}
    </View>)}
    {messages.length > 0 && !confirmClear && <Button label="Clear Study tutor conversation" variant="secondary" disabled={busy || readOnly} onPress={() => setConfirmClear(true)} />}
    {confirmClear && <View style={sharedStyles.column}>
      <Body>Clear all saved Study tutor questions and answers for this profile?</Body>
      <Button label="Confirm clear conversation" variant="destructive" disabled={busy || readOnly} busy={busy} onPress={() => void clearConversation()} />
      <Button label="Keep conversation" variant="secondary" disabled={busy} onPress={() => setConfirmClear(false)} />
    </View>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function GrowthHierarchyPanel({ moduleId, items, readOnly, onOpenTool, onSaved }: {
  moduleId: 'study' | 'tasks'; items: GrowthItem[]; readOnly: boolean; onOpenTool?: (tool: string, itemId: string) => void; onSaved: () => void;
}) {
  const { theme } = useBloomTheme();
  const { profileId } = useAuth();
  const [parentId, setParentId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [notes, setNotes] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const draftKey = profileId ? `bloom.growth-hierarchy-draft.v1:${profileId}:${moduleId}` : null;
  const parent = items.find((item) => item.id === parentId && item.state === 'active');
  const childType = parent ? nextChildType(moduleId, parent.item_type) : null;
  const tree = flattenTree(items.filter((item) => item.state !== 'archived'));

  useEffect(() => {
    let active = true;
    if (readOnly || !draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1
            && 'title' in saved && typeof saved.title === 'string' && saved.title.length <= 120
            && 'notes' in saved && typeof saved.notes === 'string' && saved.notes.length <= 2000
            && 'dueDate' in saved && typeof saved.dueDate === 'string' && saved.dueDate.length <= 10) {
            const parentValue = 'parentId' in saved && typeof saved.parentId === 'string' && saved.parentId.length <= 128 ? saved.parentId : null;
            setParentId(parentValue); setTitle(saved.title); setNotes(saved.notes); setDueDate(saved.dueDate);
          }
        } catch { /* Ignore an unreadable local hierarchy draft. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [draftKey, moduleId, readOnly]);

  useEffect(() => {
    if (readOnly || !draftKey || loadedDraftKey !== draftKey) return;
    if (!parentId && !title && !notes && !dueDate) {
      void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(draftKey, JSON.stringify({ version: 1, parentId, title, notes, dueDate })).catch(() => undefined);
  }, [draftKey, dueDate, loadedDraftKey, notes, parentId, readOnly, title]);

  function discardDraft() {
    setParentId(null); setTitle(''); setNotes(''); setDueDate(''); setError(null);
    if (draftKey) void AsyncStorage.removeItem(draftKey).catch(() => undefined);
  }

  async function add() {
    if (!parent || !childType || !title.trim()) { setError('Choose a parent and add a title.'); return; }
    if (dueDate.trim() && !isValidDateOnly(dueDate.trim())) { setError('Enter a due date as YYYY-MM-DD.'); return; }
    setBusy(true); setError(null);
    try {
      await createGrowthChild({ parentId: parent.id, itemType: childType, title: title.trim(), notes: notes.trim(),
        dueDate: moduleId === 'tasks' && dueDate.trim() ? dueDate.trim() : null, requestId: randomUUID() });
      setParentId(null); setTitle(''); setNotes(''); setDueDate(''); onSaved();
    } catch { setError('Could not add this item. Check the parent, title, and due date.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>{moduleId === 'study' ? 'Subjects, courses and lessons' : 'Projects and task steps'}</Eyebrow>
    <Body>{moduleId === 'study' ? 'Keep courses, lessons, and assignments under the subject they belong to.' : 'Organize projects into milestones, tasks, and checklists. Completing a task never completes its parent.'}</Body>
    {tree.length === 0 ? <Body>Your items will appear here.</Body> : tree.map(({ item, depth }) => {
      const descendants = moduleId === 'tasks' && item.item_type === 'project' ? getDescendants(items.filter((entry) => entry.state !== 'archived'), item.id) : [];
      const completedDescendants = descendants.filter((entry) => entry.state === 'completed').length;
      return <View key={item.id} style={[styles.row, { paddingLeft: Math.min(depth, 4) * 14 }]}>
        <View style={sharedStyles.grow}>
          <Label>{item.title}</Label>
          <Body>{humanType(item.item_type)}{item.due_date ? ` · due ${item.due_date}` : ''}{item.state === 'completed' ? ' · complete' : ''}{moduleId === 'tasks' && ['task', 'checklist'].includes(item.item_type) ? ` · ${item.priority} priority` : ''}</Body>
          {moduleId === 'tasks' && item.item_type === 'project' && <>
            <Body>{completedDescendants} of {descendants.length} project steps complete</Body>
            <ProgressBar value={descendants.length ? completedDescendants / descendants.length * 100 : 0} label={`${item.title}: ${completedDescendants} of ${descendants.length} steps complete`} color={theme.modules.tasks.deep} />
          </>}
        </View>
        {nextChildType(moduleId, item.item_type) && item.state === 'active' && <Button label={`Add ${humanType(nextChildType(moduleId, item.item_type)!)}`} variant="tertiary"
          disabled={readOnly || busy} onPress={() => { setParentId(item.id); setError(null); }} />}
        {moduleId === 'study' && ['lesson', 'assignment'].includes(item.item_type) && item.state === 'active' && onOpenTool && <View style={styles.contextActionRow}>
          <Button label="Practice" variant="tertiary" onPress={() => onOpenTool('practice', item.id)} />
          <Button label="Ask tutor" variant="tertiary" onPress={() => onOpenTool('tutor', item.id)} />
          <Button label="Materials" variant="tertiary" onPress={() => onOpenTool('resources', item.id)} />
        </View>}
      </View>;
    })}
    {parent && childType && <View style={sharedStyles.column}>
      <Label>Add {humanType(childType)} under {parent.title}</Label>
      <Field label="Title" value={readOnly ? '' : title} onChangeText={setTitle} maxLength={120} editable={!readOnly && !busy} />
      {moduleId === 'tasks' && <Field label="Due date (optional)" value={readOnly ? '' : dueDate} onChangeText={setDueDate} placeholder="YYYY-MM-DD" maxLength={10} editable={!readOnly && !busy} />}
      <Field label="Notes (optional)" value={readOnly ? '' : notes} onChangeText={setNotes} multiline maxLength={2000} editable={!readOnly && !busy} />
      <View style={styles.row}><Button label={`Add ${humanType(childType)}`} onPress={() => void add()} busy={busy} disabled={readOnly || !title.trim()} />
        <Button label="Cancel" variant="secondary" onPress={discardDraft} disabled={busy} /></View>
    </View>}
    {error && <ErrorText>{error}</ErrorText>}
  </Panel>;
}

type GrowthRecordDraft = {
  version: 1;
  itemId: string | null;
  kind: 'reading_note' | 'reading_annotation' | 'vocabulary' | 'reflection' | 'verification';
  title: string;
  body: string;
  artifactDocumentId: string;
  section: string;
  comprehensionSignal: 'clear' | 'partial' | 'revisit' | '';
  editId: string | null;
  generatedReflectionPrompt: boolean;
  generatedReflectionPromptText: string | null;
}

function parseGrowthRecordDraft(raw: string | null): GrowthRecordDraft | null {
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (!value || typeof value !== 'object') return null;
    const draft = value as Partial<GrowthRecordDraft>;
    if (draft.version !== 1 || (draft.itemId !== null && (typeof draft.itemId !== 'string' || draft.itemId.length > 128))
      || !['reading_note', 'reading_annotation', 'vocabulary', 'reflection', 'verification'].includes(draft.kind ?? '')
      || typeof draft.title !== 'string' || draft.title.length > 120 || typeof draft.body !== 'string' || draft.body.length > 10000
      || typeof draft.artifactDocumentId !== 'string' || draft.artifactDocumentId.length > 128
      || typeof draft.section !== 'string' || draft.section.length > 120
      || !['', 'clear', 'partial', 'revisit'].includes(draft.comprehensionSignal ?? '')
      || (draft.editId !== null && (typeof draft.editId !== 'string' || draft.editId.length > 128))
      || typeof draft.generatedReflectionPrompt !== 'boolean'
      || (draft.generatedReflectionPromptText !== null && (typeof draft.generatedReflectionPromptText !== 'string' || draft.generatedReflectionPromptText.length > 5000))) return null;
    return draft as GrowthRecordDraft;
  } catch { return null; }
}

export function GrowthRecordPanel({ profileId, moduleId, items, records, documents = [], attachments = [], initialItemId, readOnly, onSaved }: {
  profileId: string | null; moduleId: GrowthModuleId; items: GrowthItem[]; records: GrowthRecord[]; documents?: GrowthDocument[];
  attachments?: GrowthRecordAttachment[]; initialItemId?: string; readOnly: boolean; onSaved: () => void;
}) {
  const { childProfile } = useAuth();
  const isRead = moduleId === 'read';
  const targets = useMemo(() => items.filter((item) => item.state !== 'archived' && (isRead ? item.item_type === 'reading'
    : ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type))), [isRead, items]);
  const [itemId, setItemId] = useState<string | null>(initialItemId ?? targets[0]?.id ?? null);
  const [kind, setKind] = useState<'reading_note' | 'reading_annotation' | 'vocabulary' | 'reflection' | 'verification'>
    (isRead ? 'reading_note' : 'verification');
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [artifactDocumentId, setArtifactDocumentId] = useState('');
  const [section, setSection] = useState('');
  const [comprehensionSignal, setComprehensionSignal] = useState<'clear' | 'partial' | 'revisit' | ''>('');
  const [editId, setEditId] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [reflectionPreferences, setReflectionPreferences] = useState<GrowthAiPreferences | null>(null);
  const [reflectionPreferencesProfileId, setReflectionPreferencesProfileId] = useState<string | null>(null);
  const [reflectionSettingsLoading, setReflectionSettingsLoading] = useState(true);
  const [reflectionSettingsBusy, setReflectionSettingsBusy] = useState(false);
  const [reflectionPromptBusy, setReflectionPromptBusy] = useState(false);
  const [generatedReflectionPrompt, setGeneratedReflectionPrompt] = useState(false);
  const [generatedReflectionPromptText, setGeneratedReflectionPromptText] = useState<string | null>(null);
  const [reflectionAiError, setReflectionAiError] = useState<string | null>(null);
  const [reflectionAiNotice, setReflectionAiNotice] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const pendingSave = useRef<{ signature: string; requestId: string } | null>(null);
  const draftKey = profileId ? `bloom.growth-record-draft.v1:${profileId}:${moduleId}` : null;
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const discardDraftAfterSave = useRef(false);
  const availableRecordIds = useRef(new Set<string>());
  const availableArtifacts = documents.filter((document) => !isRead && document.module_id === 'study' && document.item_id === itemId);
  const documentNames = new Map(documents.map((document) => [document.id, document]));
  useEffect(() => {
    availableRecordIds.current = new Set(records.map((record) => record.id));
  }, [records]);
  useEffect(() => {
    let active = true;
    if (!draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      const draft = parseGrowthRecordDraft(raw);
      if (!draft || (isRead ? draft.kind === 'verification' : draft.kind !== 'verification')) return;
      setItemId(draft.itemId); setKind(draft.kind); setTitle(draft.title); setBody(draft.body);
      setArtifactDocumentId(draft.artifactDocumentId); setSection(draft.section); setComprehensionSignal(draft.comprehensionSignal);
      setEditId(draft.editId && availableRecordIds.current.has(draft.editId) ? draft.editId : null);
      setGeneratedReflectionPrompt(draft.generatedReflectionPrompt); setGeneratedReflectionPromptText(draft.generatedReflectionPromptText);
    }).catch(() => undefined).finally(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [draftKey, isRead]);
  useEffect(() => {
    if (!draftKey || loadedDraftKey !== draftKey || busy) return;
    if (discardDraftAfterSave.current) { discardDraftAfterSave.current = false; return; }
    const draft: GrowthRecordDraft = { version: 1, itemId, kind, title, body, artifactDocumentId, section,
      comprehensionSignal, editId, generatedReflectionPrompt, generatedReflectionPromptText };
    void AsyncStorage.setItem(draftKey, JSON.stringify(draft)).catch(() => undefined);
  }, [artifactDocumentId, body, busy, comprehensionSignal, draftKey, editId, generatedReflectionPrompt,
    generatedReflectionPromptText, itemId, kind, loadedDraftKey, section, title]);
  const relevant = records.filter((record) => isRead
    ? ['reading_note', 'reading_annotation', 'vocabulary', 'reflection'].includes(record.kind)
    : record.kind === 'verification');
  const refreshReflectionPreferences = useCallback(async () => {
    if (!isRead || !profileId) {
      setReflectionPreferences(null); setReflectionPreferencesProfileId(null); setReflectionSettingsLoading(false); return;
    }
    setReflectionSettingsLoading(true);
    try {
      setReflectionPreferences(await loadGrowthAiPreferences(profileId, 'read'));
      setReflectionPreferencesProfileId(profileId); setReflectionAiError(null);
    } catch { setReflectionPreferences(null); setReflectionPreferencesProfileId(profileId); setReflectionAiError('Could not load reading reflection consent.'); }
    finally { setReflectionSettingsLoading(false); }
  }, [isRead, profileId]);
  useFocusEffect(useCallback(() => { void refreshReflectionPreferences(); }, [refreshReflectionPreferences]));
  const currentReflectionPreferences = profileId && reflectionPreferencesProfileId === profileId ? reflectionPreferences : null;
  const parentReady = childProfile
    ? Boolean(currentReflectionPreferences?.parent_enabled && currentReflectionPreferences.parent_sharing_consent && currentReflectionPreferences.minor_eligible_attested)
    : Boolean(currentReflectionPreferences?.adult_attested);
  const canRequestReflection = Boolean(profileId && itemId && targets.some((item) => item.id === itemId)
    && !editId && currentReflectionPreferences?.sharing_consent && parentReady);

  async function updateReflectionConsent(enabled: boolean) {
    setReflectionSettingsBusy(true); setReflectionAiError(null); setReflectionAiNotice(null);
    try {
      await saveGrowthAiPreferences('read', enabled, childProfile ? false : enabled);
      await refreshReflectionPreferences();
      setReflectionAiNotice(enabled ? 'Reading reflection consent saved.' : 'Reading reflection consent turned off.');
    } catch { setReflectionAiError('Could not save reading reflection consent.'); }
    finally { setReflectionSettingsBusy(false); }
  }

  const { run: runReflection, retrying: retryReflection } = useUsageRequest();

  async function generateReflectionPrompt() {
    if (!itemId || !canRequestReflection) return;
    setReflectionPromptBusy(true); setReflectionAiError(null); setReflectionAiNotice(null);
    try {
      const result = await runReflection([itemId], id => requestReadingReflection(id, itemId!));
      setGeneratedReflectionPromptText(result.prompt);
      setReflectionAiNotice(result.uncertainty);
    } catch (cause) {
      setReflectionAiError(cause instanceof Error ? cause.message : 'Could not prepare a reading reflection prompt.');
    } finally { setReflectionPromptBusy(false); }
  }

  async function save() {
    if (!title.trim() || (isRead && !body.trim()) || (!isRead && !itemId) || (!isRead && !body.trim() && !artifactDocumentId)) {
      setError(isRead ? 'Add a title and an entry.' : 'Add an answer or attach a private Study artifact.'); return;
    }
    if (!isRead && itemId && !targets.some((item) => item.id === itemId)) { setError('Choose an active Study item before saving this draft.'); return; }
    if (isRead && kind === 'reflection' && !comprehensionSignal) { setError('Choose the comprehension check that best fits your response.'); return; }
    setBusy(true); setError(null); setNotice(null);
    const metadata = { section_reference: section.trim() || null, optional_learning_signal: !isRead,
      comprehension_signal: isRead && kind === 'reflection' ? comprehensionSignal : null,
      reflection_prompt_source: isRead && kind === 'reflection' && generatedReflectionPrompt ? 'ai' : null };
    try {
      if (isRead && editId) await updateGrowthRecord(editId, title.trim(), body.trim(), metadata);
      else if (isRead) {
        await saveGrowthRecord({ moduleId, itemId, kind, title: title.trim(), body: body.trim(), metadata, requestId: randomUUID() });
      } else if (editId) {
        await updateStudyVerification(editId, title.trim(), body.trim(), artifactDocumentId || null);
      } else {
        const signature = JSON.stringify([moduleId, itemId, kind, title.trim(), body.trim(), metadata]);
        if (pendingSave.current?.signature !== signature) pendingSave.current = { signature, requestId: randomUUID() };
        await saveStudyVerification(itemId!, title.trim(), body.trim(), artifactDocumentId || null, pendingSave.current.requestId);
      }
      pendingSave.current = null;
      discardDraftAfterSave.current = true;
      if (draftKey) void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      setTitle(''); setBody(''); setSection(''); setArtifactDocumentId(''); setEditId(null);
      setGeneratedReflectionPrompt(false); setGeneratedReflectionPromptText(null);
      setNotice(isRead && kind === 'reflection' ? reflectionFeedback(comprehensionSignal)
        : isRead ? 'Your reading entry is saved in history.'
          : artifactDocumentId
            ? 'Your optional Study reflection and private artifact are saved in history. Neither is proof of study time.'
            : 'Your optional Study reflection is saved in history. It is not proof of study time.');
      onSaved();
    } catch { setError('Could not save this entry or attach the file. Your text remains available to retry.'); }
    finally { setBusy(false); }
  }

  async function remove(recordId: string) {
    setBusy(true); setError(null);
    try { await deleteGrowthRecord(recordId); if (editId === recordId) {
      discardDraftAfterSave.current = true;
      if (draftKey) void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      setEditId(null); setTitle(''); setBody(''); setGeneratedReflectionPrompt(false); setGeneratedReflectionPromptText(null);
    } onSaved(); }
    catch { setError('Could not delete this entry.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>{isRead ? 'Reading notes and vocabulary' : 'Study reflection and artifact'}</Eyebrow>
    <Body>{isRead ? 'Add notes, annotations, vocabulary, or a reflection. Section or page references are optional.' : 'After study, answer a short question, attach a private PDF or DOCX, or do both. These entries do not prove study time.'}</Body>
    {loadedDraftKey !== draftKey && draftKey && <Body>Restoring your unsaved entry…</Body>}
    {targets.length > 0 && <View style={styles.choiceRow}>{targets.map((item) => <Button key={item.id} label={`${itemId === item.id ? '✓ ' : ''}${item.title}`} variant="tertiary"
      disabled={busy || readOnly} onPress={() => { setItemId(item.id); setArtifactDocumentId(''); setGeneratedReflectionPrompt(false); setGeneratedReflectionPromptText(null); }} />)}</View>}
    {isRead && <View style={styles.choiceRow}>{(['reading_note', 'reading_annotation', 'vocabulary', 'reflection'] as const).map((choice) => <Button key={choice}
      label={`${kind === choice ? '✓ ' : ''}${humanType(choice)}`} variant="tertiary" disabled={busy} onPress={() => {
        setKind(choice);
        if (choice !== 'reflection') { setGeneratedReflectionPrompt(false); setGeneratedReflectionPromptText(null); }
        if (choice === 'reflection' && !title.trim()) setTitle('What is one idea you can explain now?');
      }} />)}</View>}
    {isRead && kind === 'reflection' && <>
      <Body>Choose a reflection prompt, then check how the idea feels to explain. This is a helpful signal, not proof of understanding or a measure of reading time.</Body>
      <View style={sharedStyles.column}>
        <Label>Optional AI reflection prompt</Label>
        <Body>With consent, Bloom sends this reading’s title and your notes, plus any shared memory you opted into. It asks one question; it does not assess the book or your understanding.</Body>
        {reflectionSettingsLoading ? <Body>Loading privacy settings…</Body> : <View style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{childProfile ? 'My consent' : 'Use AI prompts'}</Label>
            <Body>{childProfile && !parentReady ? 'A parent must first enable this feature and consent.' : 'You can turn this off at any time.'}</Body></View>
          <Switch accessibilityLabel="Consent to AI reading reflection prompts" value={Boolean(currentReflectionPreferences?.sharing_consent)}
            disabled={readOnly || reflectionSettingsBusy || !profileId} onValueChange={(enabled) => void updateReflectionConsent(enabled)} />
        </View>}
        <UsageButton feature="read_reflection" replay={retryReflection} label={reflectionPromptBusy ? 'Preparing prompt…' : 'Generate a reflection prompt'} variant="secondary"
          onPress={() => generateReflectionPrompt()} busy={reflectionPromptBusy}
          disabled={readOnly || reflectionPromptBusy || reflectionSettingsBusy || reflectionSettingsLoading || !canRequestReflection} />
        {generatedReflectionPromptText && <View style={sharedStyles.column}>
          <Label>Suggested question</Label><Body>{generatedReflectionPromptText}</Body>
          <Button label={generatedReflectionPrompt ? 'Question selected' : 'Use this question'} variant="tertiary" disabled={readOnly || busy}
            onPress={() => { setTitle(generatedReflectionPromptText); setGeneratedReflectionPrompt(true); }} />
        </View>}
        {reflectionAiError && <ErrorText>{reflectionAiError}</ErrorText>}{reflectionAiNotice && <Body>{reflectionAiNotice}</Body>}
      </View>
      <View style={styles.choiceRow}>{readingReflectionPrompts.map((prompt) => <Button key={prompt}
        label={title === prompt ? `✓ ${prompt}` : prompt} variant="tertiary" disabled={busy || readOnly}
        onPress={() => { setTitle(prompt); setGeneratedReflectionPrompt(false); setGeneratedReflectionPromptText(null); }} />)}</View>
      <Label>Comprehension check</Label>
      <View style={styles.choiceRow}>{([['clear', 'I can explain it'], ['partial', 'I can explain part'], ['revisit', 'I want to revisit']] as const).map(([value, label]) => <Button key={value}
        label={`${comprehensionSignal === value ? '✓ ' : ''}${label}`} variant="tertiary" disabled={busy || readOnly}
        onPress={() => setComprehensionSignal(value)} />)}</View>
      {comprehensionSignal && <Body>{reflectionFeedback(comprehensionSignal)}</Body>}
    </>}
    <Field label={isRead ? (kind === 'vocabulary' ? 'Word or phrase' : kind === 'reflection' ? 'Prompt' : 'Title') : 'Question or artifact title'} value={title} onChangeText={setTitle} maxLength={120} editable={!readOnly && !busy} />
    <Field label={isRead ? (kind === 'vocabulary' ? 'Meaning and example' : kind === 'reflection' ? 'Your response' : 'Note or response') : 'Your answer (optional if attaching a file)'} value={body} onChangeText={setBody} multiline maxLength={isRead ? 10000 : 3000} editable={!readOnly && !busy} />
    {isRead && <Field label="Page or section (optional)" value={section} onChangeText={setSection} maxLength={120} editable={!readOnly && !busy} />}
    {!isRead && <View style={sharedStyles.column}>
      <Label>Attach a private Study artifact · optional</Label>
      {availableArtifacts.length === 0 ? <Body>Upload a PDF or DOCX for this Study item in Private Study documents, then attach it here.</Body> :
        <View style={styles.choiceRow}>{availableArtifacts.map((document) => <Button key={document.id}
          label={`${artifactDocumentId === document.id ? '✓ ' : ''}${document.title} · ${document.format.toUpperCase()}`}
          variant="tertiary" disabled={readOnly || busy} onPress={() => setArtifactDocumentId(document.id === artifactDocumentId ? '' : document.id)} />)}</View>
      }
      {artifactDocumentId && <Button label="Remove selected file" variant="tertiary" disabled={busy || readOnly} onPress={() => setArtifactDocumentId('')} />}
    </View>}
    <Button label={editId ? 'Save changes' : isRead ? `Save ${humanType(kind)}` : 'Save Study reflection'} onPress={() => void save()} busy={busy}
      disabled={readOnly || !title.trim() || (isRead && !body.trim()) || (!isRead && !body.trim() && !artifactDocumentId)} />
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    <Label>{isRead ? 'Reading history' : 'Saved reflections'}</Label>
    {relevant.length === 0 ? <Body>Saved entries will appear here.</Body> : relevant.map((record) => <View key={record.id} style={styles.record}>
      <Label>{record.title} · {humanType(record.kind)}</Label>
      {record.body && !(record.metadata.artifact_only === true && attachments.some((attachment) => attachment.record_id === record.id)) && <Body>{record.body}</Body>}
      {typeof record.metadata.section_reference === 'string' && <Body>Page or section: {record.metadata.section_reference}</Body>}
      {!isRead && attachments.find((attachment) => attachment.record_id === record.id) && (() => {
        const attachedDocument = documentNames.get(attachments.find((attachment) => attachment.record_id === record.id)!.document_id);
        return attachedDocument ? <Body>Attached learning artifact · {attachedDocument.title} · {attachedDocument.format.toUpperCase()}</Body> : null;
      })()}
      {record.kind === 'reflection' && typeof record.metadata.comprehension_signal === 'string'
        && <Body>Check: {reflectionFeedback(record.metadata.comprehension_signal as 'clear' | 'partial' | 'revisit')}</Body>}
      <View style={styles.row}>
        <Button label="Edit" variant="tertiary" disabled={busy || readOnly} onPress={() => {
          setEditId(record.id); setItemId(record.item_id); setTitle(record.title); setBody(record.body);
          setArtifactDocumentId(attachments.find((attachment) => attachment.record_id === record.id)?.document_id ?? '');
          setSection(typeof record.metadata.section_reference === 'string' ? record.metadata.section_reference : '');
          setComprehensionSignal(record.metadata.comprehension_signal === 'clear' || record.metadata.comprehension_signal === 'partial'
            || record.metadata.comprehension_signal === 'revisit' ? record.metadata.comprehension_signal : '');
          setGeneratedReflectionPrompt(record.metadata.reflection_prompt_source === 'ai');
          setGeneratedReflectionPromptText(null);
          if (isRead && ['reading_note', 'reading_annotation', 'vocabulary', 'reflection'].includes(record.kind)) setKind(record.kind as typeof kind);
        }} />
        <Button label="Delete" variant="tertiary" disabled={busy || readOnly} onPress={() => void remove(record.id)} />
      </View>
    </View>)}
  </Panel>;
}

const readingReflectionPrompts = [
  'What is one idea you can explain now?',
  'How does this connect to something you already know?',
  'What question would you like to revisit?',
];

function reflectionFeedback(signal: string) {
  if (signal === 'clear') return 'Your explanation feels clear. You can save it and move on when ready.';
  if (signal === 'partial') return 'You have part of the idea. Add a note about what still feels unclear or revisit that section later.';
  if (signal === 'revisit') return 'Save the question that remains and return to the page or section when it suits you.';
  return 'This check is a personal cue for what may help next; it is not a score.';
}

const readingCatalog = [
  { title: 'Pride and Prejudice', author: 'Jane Austen', tags: ['classic', 'relationships', 'comedy'] },
  { title: 'Frankenstein', author: 'Mary Shelley', tags: ['classic', 'science', 'gothic'] },
  { title: 'Alice’s Adventures in Wonderland', author: 'Lewis Carroll', tags: ['fantasy', 'adventure', 'classic'] },
  { title: 'The Time Machine', author: 'H. G. Wells', tags: ['science fiction', 'adventure', 'classic'] },
  { title: 'The Adventures of Sherlock Holmes', author: 'Arthur Conan Doyle', tags: ['mystery', 'detective', 'classic'] },
  { title: 'The Secret Garden', author: 'Frances Hodgson Burnett', tags: ['nature', 'family', 'classic'] },
  { title: 'Little Women', author: 'Louisa May Alcott', tags: ['family', 'relationships', 'classic'] },
  { title: 'The Wonderful Wizard of Oz', author: 'L. Frank Baum', tags: ['fantasy', 'adventure', 'classic'] },
];

export function ReadingDiscoveryPanel({ profileId, items, records, readOnly, onSaved }: {
  profileId: string | null; items: GrowthItem[]; records: GrowthRecord[]; readOnly: boolean; onSaved: () => void;
}) {
  const [search, setSearch] = useState('');
  const [interestOverride, setInterestOverride] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const preference = records.find((record) => record.kind === 'reading_note' && record.title === 'Reading interests'
    && record.metadata.catalog_preferences === true);
  const interests = interestOverride ?? preference?.body ?? '';
  const readingItems = items.filter((item) => item.item_type === 'reading');
  const catalog = useMemo(() => {
    const savedTitles = new Set(readingItems.map((item) => item.title.toLocaleLowerCase()));
    const keywords = `${interests} ${readingItems.map((item) => `${item.title} ${item.notes}`).join(' ')}`.toLocaleLowerCase()
      .split(/[^\p{L}\p{N}]+/u).filter((word) => word.length > 2);
    return readingCatalog.map((entry) => ({ ...entry, score: entry.tags.filter((tag) => keywords.includes(tag)).length }))
      .filter((entry) => `${entry.title} ${entry.author} ${entry.tags.join(' ')}`.toLocaleLowerCase().includes(search.toLocaleLowerCase()))
      .filter((entry) => !savedTitles.has(entry.title.toLocaleLowerCase()))
      .sort((a, b) => b.score - a.score || a.title.localeCompare(b.title));
  }, [interests, readingItems, search]);

  async function saveInterests() {
    if (!profileId || !interests.trim()) { setError('Add one or more interests first.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      if (preference) await updateGrowthRecord(preference.id, 'Reading interests', interests.trim(), { catalog_preferences: true });
      else await saveGrowthRecord({ moduleId: 'read', kind: 'reading_note', title: 'Reading interests', body: interests.trim(),
        metadata: { catalog_preferences: true }, requestId: randomUUID() });
      setNotice('Reading interests saved for recommendations.'); onSaved();
    } catch { setError('Could not save your interests.'); }
    finally { setBusy(false); }
  }

  async function add(entry: typeof readingCatalog[number]) {
    setBusy(true); setError(null); setNotice(null);
    try {
      const itemId = await createGrowthItem({ moduleId: 'read', title: entry.title,
        notes: `Author: ${entry.author} · Source: Bloom starter catalog metadata · Availability: metadata only; choose an authorized edition.`,
        requestId: randomUUID() });
      await updateGrowthReadingDetails(itemId, { author: entry.author, genre: entry.tags[0] ?? '', pageCount: null, currentPage: null, status: 'want_to_read' });
      setNotice(`${entry.title} added to your reading list.`); onSaved();
    } catch { setError('Could not add this title to your reading list.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>Discover a book</Eyebrow>
    <Body>Search free catalog metadata. Bloom does not include book text; find an edition you are authorized to read. Availability can vary by region.</Body>
    <Field label="Reading interests" value={interests} onChangeText={setInterestOverride} maxLength={300} placeholder="Mystery, nature, science fiction" editable={!readOnly && !busy} />
    <Button label="Save interests" variant="secondary" onPress={() => void saveInterests()} disabled={readOnly || busy} busy={busy} />
    <Field label="Search title, author, or topic" value={search} onChangeText={setSearch} maxLength={120} editable={!busy} />
    <Label>{search ? 'Search results' : interests ? 'Recommended from your interests and reading list' : 'Starter catalog'}</Label>
    {catalog.length === 0 ? <Body>No matching titles. Try another search.</Body> : catalog.slice(0, 8).map((entry) => <View key={entry.title} style={styles.record}>
      <Label>{entry.title}</Label><Body>{entry.author} · {entry.tags.join(', ')}</Body>
      <Body>Source: free starter-catalog metadata · Text availability: not provided by Bloom.</Body>
      <Button label="Add to reading list" variant="tertiary" onPress={() => void add(entry)} disabled={busy || readOnly} />
    </View>)}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function TaskFocusPanel({ items, sessions, readOnly, onSaved }: {
  items: GrowthItem[]; sessions: TaskFocusSession[]; readOnly: boolean; onSaved: () => void;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const [updatingItem, setUpdatingItem] = useState<string | null>(null);
  const pending = useRef<{ taskId: string; requestId: string } | null>(null);
  const active = sessions.find((session) => session.status === 'in_progress') ?? null;
  const tasks = items.filter((item) => item.item_type === 'task' && item.state === 'active');
  const activeId = active?.id;
  useEffect(() => {
    const timer = setInterval(() => setTick(Date.now()), activeId ? 1000 : 60_000);
    return () => clearInterval(timer);
  }, [activeId]);

  async function start(taskId: string) {
    if (pending.current?.taskId !== taskId) pending.current = { taskId, requestId: randomUUID() };
    setBusy(true); setError(null); setNotice(null);
    try { await startTaskFocus(taskId, pending.current.requestId); pending.current = null; onSaved(); }
    catch { setError('Could not start Focus. Finish or cancel the current session, then retry.'); }
    finally { setBusy(false); }
  }
  async function finish(cancel: boolean) {
    if (!active) return;
    setBusy(true); setError(null); setNotice(null);
    try { const result = await finishTaskFocus(active.id, cancel); onSaved();
      if (!cancel) setNotice(`Focus saved for ${formatDuration(result.durationSeconds ?? 0)}. The task remains open and no second reward was created.`);
    } catch { setError('Could not save Focus. The server session remains available to retry.'); }
    finally { setBusy(false); }
  }
  async function toggleChecklist(item: GrowthItem) {
    setUpdatingItem(item.id); setError(null); setNotice(null);
    try {
      await updateGrowthItem(item, { state: item.state === 'completed' ? 'active' : 'completed', progressPercent: item.state === 'completed' ? 0 : 100 });
      onSaved();
    } catch { setError('Could not update this checklist item. Retry while connected.'); }
    finally { setUpdatingItem(null); }
  }
  async function completeTask(item: GrowthItem) {
    setUpdatingItem(item.id); setError(null); setNotice(null);
    try { await updateGrowthItem(item, { state: 'completed', progressPercent: 100 }); setNotice(`${item.title} marked complete.`); onSaved(); }
    catch { setError('Focus is saved, but the task could not be completed. Retry the task from Today.'); }
    finally { setUpdatingItem(null); }
  }
  const activeTask = active ? items.find((item) => item.id === active.task_id) : null;
  const checklist = activeTask ? items.filter((item) => item.parent_id === activeTask.id && item.item_type === 'checklist') : [];
  const elapsed = active && tick ? Math.max(0, Math.floor((tick - Date.parse(active.started_at)) / 1000)) : 0;

  return <Panel>
    <Eyebrow>Focus linked to a task</Eyebrow>
    <Body>Focus time is recorded against the task. Ending Focus does not complete the task or award its reward.</Body>
    {active && <View style={sharedStyles.column}>
      <Label>{activeTask?.title ?? 'Task'} · {formatElapsed(elapsed)}</Label>
      {checklist.length > 0 && <View style={sharedStyles.column}>
        <Label>Checklist</Label>
        {checklist.map((item) => <Button key={item.id} label={`${item.state === 'completed' ? '✓ ' : ''}${item.title}`} variant={item.state === 'completed' ? 'secondary' : 'tertiary'} disabled={busy || readOnly || updatingItem === item.id}
          onPress={() => void toggleChecklist(item)} />)}
      </View>}
      <Button label="Finish Focus" onPress={() => void finish(false)} disabled={busy || readOnly} busy={busy} />
      <Button label="Cancel Focus" variant="secondary" onPress={() => void finish(true)} disabled={busy || readOnly} />
    </View>}
    {!active && (tasks.length === 0 ? <Body>Add an active task to start linked Focus.</Body> : tasks.map((task) => <View key={task.id} style={styles.row}>
      <View style={sharedStyles.grow}><Label>{task.title}</Label></View>
      <Button label="Start Focus" variant="tertiary" onPress={() => void start(task.id)} disabled={busy || readOnly} />
    </View>))}
    {sessions.filter((session) => session.status === 'completed').slice(0, 5).map((session) => {
      const sessionTask = items.find((item) => item.id === session.task_id);
      return <View key={session.id} style={styles.row}>
        <View style={sharedStyles.grow}><Body>{sessionTask?.title ?? 'Task'} · {formatDuration(session.duration_seconds ?? 0)}</Body></View>
        {sessionTask?.state === 'active' && <Button label="Mark task complete" variant="tertiary" disabled={busy || readOnly || updatingItem === sessionTask.id} onPress={() => void completeTask(sessionTask)} />}
      </View>;
    })}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function TaskBreakdownPanel({ profileId, items, readOnly, onSaved }: {
  profileId: string | null; items: GrowthItem[]; readOnly: boolean; onSaved: () => void;
}) {
  const { childProfile } = useAuth();
  const [preferences, setPreferences] = useState<GrowthAiPreferences | null>(null);
  const [consent, setConsent] = useState(false);
  const [adult, setAdult] = useState(false);
  const [itemId, setItemId] = useState('');
  const [prompt, setPrompt] = useState('Suggest manageable next steps for this task.');
  const [draft, setDraft] = useState<TaskBreakdownDraft | null>(null);
  const [stepsText, setStepsText] = useState('');
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const tasks = items.filter((item) => item.item_type === 'task' && item.state === 'active');
  const taskIds = useRef(tasks.map((task) => task.id));
  const draftKey = profileId ? `bloom.task-breakdown-draft.v1:${profileId}` : null;
  const selected = tasks.find((task) => task.id === itemId);
  const canGenerate = Boolean(preferences?.sharing_consent && (childProfile
    ? preferences.parent_enabled && preferences.parent_sharing_consent && preferences.minor_eligible_attested
    : preferences.adult_attested));

  useEffect(() => {
    let active = true;
    if (!draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      if (raw) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1
            && 'itemId' in saved && typeof saved.itemId === 'string' && taskIds.current.includes(saved.itemId)
            && 'prompt' in saved && typeof saved.prompt === 'string' && saved.prompt.length <= 2000
            && 'stepsText' in saved && typeof saved.stepsText === 'string' && saved.stepsText.length <= 1600) {
            setItemId(saved.itemId);
            setPrompt(saved.prompt);
            setStepsText(saved.stepsText);
            if ('draft' in saved && saved.draft && typeof saved.draft === 'object'
              && 'requestId' in saved.draft && typeof saved.draft.requestId === 'string'
              && 'reply' in saved.draft && typeof saved.draft.reply === 'string' && saved.draft.reply.length <= 5000
              && 'steps' in saved.draft && Array.isArray(saved.draft.steps)
              && saved.draft.steps.length <= 12 && saved.draft.steps.every((step) => typeof step === 'string' && step.length <= 120)) {
              setDraft({ requestId: saved.draft.requestId, reply: saved.draft.reply, steps: saved.draft.steps });
            }
          }
        } catch { /* Ignore a malformed local draft and keep the current task form empty. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [draftKey]);

  useEffect(() => {
    if (!draftKey || loadedDraftKey !== draftKey) return;
    void AsyncStorage.setItem(draftKey, JSON.stringify({ version: 1, itemId, prompt, draft, stepsText })).catch(() => undefined);
  }, [draft, draftKey, itemId, loadedDraftKey, prompt, stepsText]);

  useEffect(() => {
    let active = true;
    if (!profileId) return () => { active = false; };
    void loadGrowthAiPreferences(profileId, 'tasks').then((value) => {
      if (!active) return;
      setPreferences(value); setConsent(value?.sharing_consent ?? false); setAdult(value?.adult_attested ?? false);
    }).catch(() => { if (active) setError('Could not load AI privacy settings.'); });
    return () => { active = false; };
  }, [profileId]);

  async function savePreferences() {
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthAiPreferences('tasks', consent, childProfile ? false : adult);
      if (profileId) setPreferences(await loadGrowthAiPreferences(profileId, 'tasks'));
      setNotice('Task AI privacy settings saved.');
    } catch { setError('Consent and age eligibility must be complete before AI use.'); }
    finally { setBusy(false); }
  }

  const { run: runBreakdown, retrying: retryBreakdown } = useUsageRequest();

  async function generate() {
    if (!selected || !canGenerate || !prompt.trim()) return;
    setBusy(true); setError(null); setNotice(null); setDraft(null);
    try {
      const result = await runBreakdown([selected.id, prompt.trim()], id => requestTaskBreakdown(id, selected.id, prompt.trim()));
      setDraft(result); setStepsText(result.steps.join('\n'));
    } catch { setError('Could not prepare a task breakdown. Check consent, provider availability, and your connection.'); }
    finally { setBusy(false); }
  }

  async function approve() {
    if (!selected || !draft) return;
    const steps = stepsText.split('\n').map((step) => step.trim()).filter(Boolean);
    if (!steps.length || steps.length > 12 || steps.some((step) => step.length > 120)) {
      setError('Keep 1–12 steps, each no longer than 120 characters.'); return;
    }
    setBusy(true); setError(null); setNotice(null);
    try {
      await approveTaskBreakdown(selected.id, steps, draft.requestId);
      setDraft(null); setStepsText(''); setNotice('Approved steps were added as checklist items.'); onSaved();
    } catch { setError('Could not save these steps. Review the task and retry.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>AI task breakdown</Eyebrow>
    <Body>Bloom sends the selected task title, its notes, and your request to the approved AI provider. The draft stays here until you edit and approve it; it never completes the task or controls another app.</Body>
    <View style={sharedStyles.row}><Body>Allow AI to process task details</Body><Switch accessibilityLabel="Allow AI to process task details" value={consent} onValueChange={setConsent} disabled={busy || readOnly} /></View>
    {childProfile ? <Body>A parent must approve sharing and confirm eligibility. Children also need to agree before a request is sent.</Body> : <View style={sharedStyles.row}>
      <Body>I am an adult under my local law</Body><Switch accessibilityLabel="Confirm adult eligibility for task AI" value={adult} onValueChange={setAdult} disabled={busy || readOnly} />
    </View>}
    <Button label="Save AI privacy settings" variant="secondary" onPress={() => void savePreferences()} disabled={busy || readOnly} busy={busy} />
    {childProfile && preferences?.sharing_consent && !preferences.parent_enabled && <Body>Waiting for parent approval. No task details will be sent yet.</Body>}
    {tasks.length === 0 ? <Body>Add an active task before creating a draft.</Body> : <View style={styles.choiceRow}>{tasks.map((task) => <Button key={task.id} label={`${itemId === task.id ? '✓ ' : ''}${task.title}`} variant="tertiary"
      disabled={busy || readOnly || Boolean(draft)} onPress={() => setItemId(task.id)} />)}</View>}
    <Field label="What kind of help would you like?" value={prompt} onChangeText={setPrompt} maxLength={2000} multiline editable={!busy && !readOnly && !draft} />
    <UsageButton feature="task_breakdown" replay={retryBreakdown} label="Generate an editable draft" onPress={() => generate()} busy={busy} disabled={busy || readOnly || !canGenerate || !selected || !prompt.trim() || Boolean(draft)} />
    {draft && <View style={sharedStyles.column}>
      <Label>Draft · not saved</Label><Body>{draft.reply}</Body>
      <Field label="Edit steps · one per line" value={stepsText} onChangeText={setStepsText} multiline maxLength={1600} editable={!busy && !readOnly} />
      <View style={styles.row}><Button label="Approve and save steps" onPress={() => void approve()} busy={busy} disabled={busy || readOnly} />
        <Button label="Discard draft" variant="secondary" disabled={busy} onPress={() => { setDraft(null); setStepsText(''); }} /></View>
    </View>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

function nextChildType(moduleId: 'study' | 'tasks', parentType: string) {
  if (moduleId === 'study') {
    if (parentType === 'subject') return 'course';
    if (parentType === 'course') return 'lesson';
    if (parentType === 'lesson') return 'assignment';
  } else {
    if (parentType === 'project') return 'milestone';
    if (parentType === 'milestone') return 'task';
    if (parentType === 'task') return 'checklist';
  }
  return null;
}

function isValidDateOnly(value: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const date = new Date(`${value}T12:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function flattenTree(items: GrowthItem[]) {
  const roots = items.filter((item) => !item.parent_id);
  const result: { item: GrowthItem; depth: number }[] = [];
  const visit = (parent: GrowthItem, depth: number) => {
    result.push({ item: parent, depth });
    for (const child of items.filter((item) => item.parent_id === parent.id).sort((a, b) => a.title.localeCompare(b.title))) visit(child, depth + 1);
  };
  for (const root of roots.sort((a, b) => a.title.localeCompare(b.title))) visit(root, 0);
  return result;
}

function getDescendants(items: GrowthItem[], parentId: string) {
  const result: GrowthItem[] = [];
  const visit = (id: string) => {
    const children = items.filter((item) => item.parent_id === id);
    result.push(...children);
    children.forEach((child) => visit(child.id));
  };
  visit(parentId);
  return result;
}

function getUpcomingStudySessions(items: GrowthItem[], slots: StudyPlanSlot[], changes: StudyPlanChange[], today: string) {
  const itemById = new Map(items.map((item) => [item.id, item]));
  const result: { itemId: string; title: string; date: string; originalDate: string; minutes: number; moved: boolean }[] = [];
  for (let offset = 0; offset < 15; offset += 1) {
    const dateKey = shiftDateKey(today, offset);
    const dayOfWeek = new Date(`${dateKey}T12:00:00Z`).getUTCDay();
    for (const slot of slots.filter((item) => item.day_of_week === dayOfWeek)) {
      const item = itemById.get(slot.item_id);
      if (!item || item.state !== 'active') continue;
      const change = changes.find((entry) => entry.item_id === item.id && entry.original_date === dateKey);
      if (!change) result.push({ itemId: item.id, title: item.title, date: dateKey, originalDate: dateKey, minutes: slot.target_minutes, moved: false });
      else if (change.action === 'move' && change.moved_to_date) result.push({ itemId: item.id, title: item.title, date: change.moved_to_date, originalDate: dateKey, minutes: slot.target_minutes, moved: true });
    }
  }
  for (const change of changes.filter((item) => item.action === 'move' && item.moved_to_date)) {
    const item = itemById.get(change.item_id); const slot = slots.find((entry) => entry.item_id === change.item_id);
    if (item && slot && change.moved_to_date! >= today && !result.some((entry) => entry.itemId === item.id && entry.originalDate === change.original_date)) {
      result.push({ itemId: item.id, title: item.title, date: change.moved_to_date!, originalDate: change.original_date, minutes: slot.target_minutes, moved: true });
    }
  }
  return result.sort((a, b) => a.date.localeCompare(b.date) || a.title.localeCompare(b.title));
}

function initialPlanValues(items: GrowthItem[], slots: StudyPlanSlot[]) {
  const next: Record<string, number[]> = {};
  for (const slot of slots) {
    next[slot.item_id] ??= Array(7).fill(0);
    next[slot.item_id][slot.day_of_week] = slot.target_minutes;
  }
  const formatted: Record<string, string[]> = {};
  for (const item of items.filter((candidate) => candidate.state === 'active' && ['subject', 'course'].includes(candidate.item_type))) {
    formatted[item.id] = (next[item.id] ?? Array(7).fill(0)).map(String);
  }
  return formatted;
}

function shiftDateKey(value: string, count: number) { const date = new Date(`${value}T12:00:00Z`); date.setUTCDate(date.getUTCDate() + count); return date.toISOString().slice(0, 10); }
function startOfWeekKey(value: string) { const date = new Date(`${value}T12:00:00Z`); date.setUTCDate(date.getUTCDate() - date.getUTCDay()); return date.toISOString().slice(0, 10); }
function addDays(value: string, count: number) { return shiftDateKey(value, count); }
function formatPlanDate(value: string) { return new Date(`${value}T12:00:00Z`).toLocaleDateString(getAppLocale(), { weekday: 'short', month: 'short', day: 'numeric', timeZone: 'UTC' }); }
function formatMinutes(value: number) { const hours = Math.floor(value / 60); const minutes = value % 60; return hours ? `${hours}h${minutes ? ` ${minutes}m` : ''}` : `${value} min`; }
function humanType(value: string) { return value.replaceAll('_', ' '); }
function formatDuration(seconds: number) { if (seconds >= 0 && seconds < 60) return '<1 min'; const mins = Math.floor(seconds / 60); const secs = seconds % 60; return mins ? `${mins} min${secs ? ` ${secs} sec` : ''}` : `${secs} sec`; }

const styles = StyleSheet.create({
  studyPlanWorkspace: { gap: 14 },
  studyPlanWorkspaceDesktop: { flexDirection: 'row', alignItems: 'flex-start' },
  studyPlanEditor: { minWidth: 0 },
  studyPlanEditorDesktop: { flex: 1.1, minWidth: 360 },
  studyPlanUpcoming: { minWidth: 0 },
  studyPlanUpcomingDesktop: { flex: 0.9, minWidth: 300 },
  row: { ...sharedStyles.row, gap: 8, paddingVertical: 8, flexWrap: 'wrap' },
  choiceRow: { ...sharedStyles.row, gap: 6, flexWrap: 'wrap' },
  planItem: { ...sharedStyles.column, borderTopWidth: 1, borderTopColor: '#E4E8F3', paddingTop: 12 },
  planBigMetric: { fontSize: 38, lineHeight: 46, fontWeight: '800', fontVariant: ['tabular-nums'], letterSpacing: -1 },
  planSummaryRow: { flexDirection: 'row', gap: 10 },
  planDaySelector: { borderWidth: 1, borderRadius: 18, flexDirection: 'row', padding: 4, gap: 2 },
  planDayOption: { flex: 1, minHeight: 52, justifyContent: 'center', alignItems: 'center', borderWidth: 1, borderColor: 'transparent', borderRadius: 13, paddingHorizontal: 2 },
  planDayName: { fontSize: 11, fontWeight: '700' },
  planDayMinutes: { fontSize: 10, fontWeight: '700', marginTop: 2 },
  planInputRow: { flexDirection: 'row', alignItems: 'center', gap: 12, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#E4E8F3', paddingVertical: 8 },
  planInput: { width: 100 },
  contextActionRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 0, marginStart: -8 },
  record: { ...sharedStyles.column, paddingVertical: 10, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#E4E8F3' },
});
