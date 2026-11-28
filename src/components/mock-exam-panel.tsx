import { usageRequestFailed } from '../lib/usage-request';
import { UsageButton } from './usage-action';
import { getAppLocale } from '../lib/locale-context';
import { randomUUID } from 'expo-crypto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useMemo, useRef, useState } from 'react';
import { Switch, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel, sharedStyles } from './bloom-ui';
import { loadGrowthAiPreferences, saveGrowthAiPreferences } from '../lib/growth-ai';
import { deleteGrowthRecord, requestMockExamAssessment, saveGrowthRecord, saveMockExamAttempt, updateGrowthRecord, type GrowthItem, type GrowthRecord } from '../lib/growth-modules';
import { useAuth } from '../lib/auth';

type QuestionType = 'multiple_choice' | 'true_false' | 'short_answer';
type ExamQuestion = { id: string; type: QuestionType; prompt: string; options: string[]; expected_answer: string; rubric: string; explanation: string };
type ExamDefinition = { version: 1; time_limit_minutes: number; questions: ExamQuestion[] };
type AttemptResult = { score: number; results: { question_id: string; answer: string; correct?: boolean; score?: number;
  expected_answer?: string; explanation: string; uncertainty?: string }[]; duration_seconds: number; uncertainty?: string };

function parseExam(record: GrowthRecord): ExamDefinition | null {
  try {
    const value = JSON.parse(record.body) as Partial<ExamDefinition>;
    if (value.version !== 1 || !Array.isArray(value.questions) || value.questions.length < 1 || value.questions.length > 50) return null;
    if (value.questions.some((question) => !question || typeof question.id !== 'string' || typeof question.prompt !== 'string'
      || !['multiple_choice', 'true_false', 'short_answer'].includes(question.type))) return null;
    return { version: 1, time_limit_minutes: Number(value.time_limit_minutes) || 30, questions: value.questions as ExamQuestion[] };
  } catch { return null; }
}

function isExamQuestion(value: unknown): value is ExamQuestion {
  if (!value || typeof value !== 'object') return false;
  const question = value as Partial<ExamQuestion>;
  return typeof question.id === 'string' && question.id.length <= 128
    && (question.type === 'multiple_choice' || question.type === 'true_false' || question.type === 'short_answer')
    && typeof question.prompt === 'string' && question.prompt.length <= 1000
    && Array.isArray(question.options) && question.options.length <= 6
    && question.options.every((option) => typeof option === 'string' && option.length <= 500)
    && typeof question.expected_answer === 'string' && question.expected_answer.length <= 1000
    && typeof question.rubric === 'string' && question.rubric.length <= 2000
    && typeof question.explanation === 'string' && question.explanation.length <= 1500;
}

export function MockExamPanel({ profileId, items, records, readOnly, onSaved }: {
  profileId: string; items: GrowthItem[]; records: GrowthRecord[]; readOnly: boolean; onSaved: () => void;
}) {
  const { childProfile } = useAuth();
  const studyItems = useMemo(() => items.filter((item) => item.module_id === 'study' && item.state !== 'archived'
    && ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)), [items]);
  const [itemId, setItemId] = useState(studyItems[0]?.id ?? '');
  const [title, setTitle] = useState('');
  const [sourceReference, setSourceReference] = useState('');
  const [timeLimit, setTimeLimit] = useState('30');
  const [questionType, setQuestionType] = useState<QuestionType>('multiple_choice');
  const [prompt, setPrompt] = useState('');
  const [optionsText, setOptionsText] = useState('');
  const [expectedAnswer, setExpectedAnswer] = useState('');
  const [rubric, setRubric] = useState('');
  const [explanation, setExplanation] = useState('');
  const [draftQuestions, setDraftQuestions] = useState<ExamQuestion[]>([]);
  const [editingQuestionId, setEditingQuestionId] = useState<string | null>(null);
  const [activeExamId, setActiveExamId] = useState<string | null>(null);
  const [activeQuestion, setActiveQuestion] = useState(0);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [startTime, setStartTime] = useState<number | null>(null);
  const [tick, setTick] = useState(0);
  const [aiConsent, setAiConsent] = useState(false);
  const [adultAttested, setAdultAttested] = useState(false);
  const [parentEnabled, setParentEnabled] = useState(false);
  const [parentEligible, setParentEligible] = useState(false);
  const [parentConsent, setParentConsent] = useState(false);
  const [editingExam, setEditingExam] = useState<GrowthRecord | null>(null);
  const [confirmDeleteExam, setConfirmDeleteExam] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const pendingRequest = useRef<{ signature: string; requestId: string } | null>(null);
  const pendingSave = useRef<{ signature: string; requestId: string } | null>(null);
  const draftKey = profileId ? `bloom.mock-exam-builder-draft.v1:${profileId}` : null;

  const exams = useMemo(() => records.filter((record) => record.kind === 'exam').flatMap((record) => {
    const definition = parseExam(record);
    return definition ? [{ record, definition }] : [];
  }), [records]);
  const attempts = useMemo(() => records.filter((record) => record.kind === 'exam_attempt'), [records]);
  const active = exams.find((exam) => exam.record.id === activeExamId);
  const current = active?.definition.questions[activeQuestion];
  const hasShortAnswer = Boolean(active?.definition.questions.some((question) => question.type === 'short_answer'));
  const examsNeedAi = exams.some(({ definition }) => definition.questions.some((question) => question.type === 'short_answer'));
  const consentReady = Boolean(aiConsent && (childProfile
    ? parentEnabled && parentEligible && parentConsent
    : adultAttested));
  const elapsed = startTime === null ? 0 : Math.max(0, Math.floor((tick - startTime) / 1000));
  const timeLeft = active ? Math.max(0, active.definition.time_limit_minutes * 60 - elapsed) : 0;
  const timeExpired = Boolean(active && timeLeft === 0);
  const examAttempts = attempts.flatMap((record) => record.metadata.exam_id
    ? [{ record, examId: String(record.metadata.exam_id), parsed: parseAttempt(record) }]
    : []);

  useEffect(() => {
    let activeRequest = true;
    if (readOnly || !draftKey) return () => { activeRequest = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!activeRequest) return;
      if (raw && raw.length <= 250_000) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1) {
            const value = saved as Record<string, unknown>;
            if (Array.isArray(value.draftQuestions) && value.draftQuestions.length <= 50 && value.draftQuestions.every(isExamQuestion)) {
              setDraftQuestions(value.draftQuestions);
            }
            if (typeof value.itemId === 'string' && studyItems.some((item) => item.id === value.itemId)) setItemId(value.itemId);
            if (typeof value.title === 'string' && value.title.length <= 120) setTitle(value.title);
            if (typeof value.sourceReference === 'string' && value.sourceReference.length <= 300) setSourceReference(value.sourceReference);
            if (typeof value.timeLimit === 'string' && value.timeLimit.length <= 3) setTimeLimit(value.timeLimit);
            if (value.questionType === 'multiple_choice' || value.questionType === 'true_false' || value.questionType === 'short_answer') setQuestionType(value.questionType);
            if (typeof value.prompt === 'string' && value.prompt.length <= 1000) setPrompt(value.prompt);
            if (typeof value.optionsText === 'string' && value.optionsText.length <= 1000) setOptionsText(value.optionsText);
            if (typeof value.expectedAnswer === 'string' && value.expectedAnswer.length <= 1000) setExpectedAnswer(value.expectedAnswer);
            if (typeof value.rubric === 'string' && value.rubric.length <= 2000) setRubric(value.rubric);
            if (typeof value.explanation === 'string' && value.explanation.length <= 1500) setExplanation(value.explanation);
            if (typeof value.editingQuestionId === 'string' && Array.isArray(value.draftQuestions)
              && value.draftQuestions.some((question) => isExamQuestion(question) && question.id === value.editingQuestionId)) setEditingQuestionId(value.editingQuestionId);
            if (typeof value.editingExamId === 'string') {
              const savedExam = exams.find((exam) => exam.record.id === value.editingExamId);
              if (savedExam) setEditingExam(savedExam.record);
            }
            const activeExam = typeof value.activeExamId === 'string' ? exams.find((exam) => exam.record.id === value.activeExamId) : null;
            if (activeExam && typeof value.startTime === 'number' && Number.isFinite(value.startTime)
              && value.startTime > 0 && value.startTime <= Date.now() + 60_000) {
              setActiveExamId(activeExam.record.id);
              if (typeof value.activeQuestion === 'number' && Number.isInteger(value.activeQuestion)
                && value.activeQuestion >= 0 && value.activeQuestion < activeExam.definition.questions.length) setActiveQuestion(value.activeQuestion);
              if (value.answers && typeof value.answers === 'object' && !Array.isArray(value.answers)) {
                const allowedQuestionIds = new Set(activeExam.definition.questions.map((question) => question.id));
                const nextAnswers: Record<string, string> = {};
                for (const [questionId, answer] of Object.entries(value.answers)) {
                  if (allowedQuestionIds.has(questionId) && typeof answer === 'string' && answer.length <= 3000) nextAnswers[questionId] = answer;
                }
                setAnswers(nextAnswers);
              }
              setStartTime(value.startTime);
            }
          }
        } catch { /* Ignore an unreadable local mock-exam draft. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (activeRequest) setLoadedDraftKey(draftKey); });
    return () => { activeRequest = false; };
  }, [draftKey, exams, readOnly, studyItems]);

  useEffect(() => {
    if (readOnly || !draftKey || loadedDraftKey !== draftKey) return;
    const hasDraft = Boolean(title || sourceReference || prompt || optionsText || expectedAnswer || rubric || explanation
      || draftQuestions.length || editingExam || activeExamId || startTime);
    if (!hasDraft) {
      void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      return;
    }
    const serialized = JSON.stringify({ version: 1, itemId, title, sourceReference, timeLimit, questionType, prompt, optionsText,
      expectedAnswer, rubric, explanation, draftQuestions, editingQuestionId, editingExamId: editingExam?.id ?? null,
      activeExamId, activeQuestion, answers, startTime });
    if (serialized.length <= 250_000) void AsyncStorage.setItem(draftKey, serialized).catch(() => undefined);
  }, [draftKey, draftQuestions, editingExam, editingQuestionId, explanation, expectedAnswer, itemId, loadedDraftKey, optionsText,
    activeExamId, activeQuestion, answers, prompt, questionType, readOnly, rubric, sourceReference, startTime, timeLimit, title]);

  useEffect(() => {
    let currentRequest = true;
    if (!profileId) return () => { currentRequest = false; };
    void loadGrowthAiPreferences(profileId, 'study').then((preferences) => {
      if (!currentRequest) return;
      setAiConsent(preferences?.sharing_consent ?? false);
      setAdultAttested(preferences?.adult_attested ?? false);
      setParentEnabled(preferences?.parent_enabled ?? false);
      setParentEligible(preferences?.minor_eligible_attested ?? false);
      setParentConsent(preferences?.parent_sharing_consent ?? false);
    }).catch(() => { if (currentRequest) setError('Could not load Study AI consent.'); });
    return () => { currentRequest = false; };
  }, [profileId]);

  useEffect(() => {
    if (startTime === null) return;
    const immediate = setTimeout(() => setTick(Date.now()), 0);
    const timer = setInterval(() => setTick(Date.now()), 1000);
    return () => { clearTimeout(immediate); clearInterval(timer); };
  }, [startTime]);

  function addQuestion() {
    const options = optionsText.split('\n').map((value) => value.trim()).filter(Boolean);
    if (!prompt.trim()) { setError('Enter a question first.'); return; }
    if (questionType === 'multiple_choice' && (options.length < 2 || options.length > 6 || !options.includes(expectedAnswer.trim()))) {
      setError('Add 2–6 answer choices and enter the exact correct choice.'); return;
    }
    if (questionType === 'true_false' && !['true', 'false'].includes(expectedAnswer.trim().toLocaleLowerCase())) {
      setError('Choose true or false as the correct answer.'); return;
    }
    if (questionType === 'short_answer' && !rubric.trim()) { setError('Add an expected answer or a short marking rubric.'); return; }
    if (!explanation.trim()) { setError('Add a brief explanation for review.'); return; }
    if (!editingQuestionId && draftQuestions.length >= 50) { setError('An exam can have up to 50 questions.'); return; }
    const nextQuestion = {
      id: editingQuestionId ?? randomUUID(), type: questionType, prompt: prompt.trim(), options: questionType === 'multiple_choice' ? options : [],
      expected_answer: questionType === 'true_false' ? expectedAnswer.trim().toLocaleLowerCase() : expectedAnswer.trim(),
      rubric: rubric.trim(), explanation: explanation.trim(),
    };
    setDraftQuestions((currentQuestions) => editingQuestionId
      ? currentQuestions.map((question) => question.id === editingQuestionId ? nextQuestion : question)
      : [...currentQuestions, nextQuestion]);
    setEditingQuestionId(null); setPrompt(''); setOptionsText(''); setExpectedAnswer(''); setRubric(''); setExplanation(''); setError(null);
  }

  function editQuestion(question: ExamQuestion) {
    setEditingQuestionId(question.id); setQuestionType(question.type); setPrompt(question.prompt);
    setOptionsText(question.options.join('\n')); setExpectedAnswer(question.expected_answer);
    setRubric(question.rubric); setExplanation(question.explanation); setError(null);
  }

  async function saveExam() {
    const minutes = Number(timeLimit);
    if (!title.trim() || !sourceReference.trim() || !itemId || draftQuestions.length === 0
      || !Number.isInteger(minutes) || minutes < 1 || minutes > 240) {
      setError('Add a title, source or rubric reference, Study item, 1–50 questions, and a 1–240 minute time limit.'); return;
    }
    if (JSON.stringify({ version: 1, time_limit_minutes: minutes, questions: draftQuestions }).length > 9500) {
      setError('This exam is too large to save. Shorten the question text or create a second exam.'); return;
    }
    const body = JSON.stringify({ version: 1, time_limit_minutes: minutes, questions: draftQuestions });
    const metadata = { source_reference: sourceReference.trim() };
    const signature = JSON.stringify([itemId, title.trim(), body, metadata]);
    if (!editingExam && pendingSave.current?.signature !== signature) pendingSave.current = { signature, requestId: randomUUID() };
    setBusy(true); setError(null); setNotice(null);
    try {
      if (editingExam) await updateGrowthRecord(editingExam.id, title.trim(), body, metadata);
      else await saveGrowthRecord({ moduleId: 'study', itemId, kind: 'exam', title: title.trim(), body,
        metadata, requestId: pendingSave.current!.requestId });
      if (draftKey) await AsyncStorage.removeItem(draftKey).catch(() => undefined);
      pendingSave.current = null; setEditingExam(null); setTitle(''); setSourceReference(''); setDraftQuestions([]);
      setNotice(editingExam ? 'Mock exam updated.' : 'Mock exam saved. Its source or rubric reference stays with the review history.'); onSaved();
    } catch { setError('Could not save the mock exam. Your draft remains available to retry.'); }
    finally { setBusy(false); }
  }

  function editExam(record: GrowthRecord, definition: ExamDefinition) {
    setEditingExam(record); setItemId(record.item_id ?? ''); setTitle(record.title);
    setSourceReference(String(record.metadata.source_reference ?? '')); setTimeLimit(String(definition.time_limit_minutes));
    setDraftQuestions(definition.questions); setError(null); setNotice(null);
  }

  async function removeExam(record: GrowthRecord) {
    setBusy(true); setError(null); setNotice(null);
    try {
      await deleteGrowthRecord(record.id);
      setConfirmDeleteExam(null);
      if (editingExam?.id === record.id) { setEditingExam(null); setTitle(''); setSourceReference(''); setDraftQuestions([]); }
      setNotice('Mock exam deleted. Completed attempts remain in your Study history.'); onSaved();
    } catch { setError('Could not delete this mock exam.'); }
    finally { setBusy(false); }
  }

  async function saveAiConsent(enabled: boolean) {
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthAiPreferences('study', enabled, childProfile ? false : enabled);
      setAiConsent(enabled); setAdultAttested(childProfile ? false : enabled);
      setNotice(enabled ? 'Study AI consent saved.' : 'Study AI consent turned off.');
    } catch { setError('Study AI consent could not be saved. Check parent settings and eligibility.'); }
    finally { setBusy(false); }
  }

  function start(examId: string) {
    const startedAt = clockNow();
    setActiveExamId(examId); setActiveQuestion(0); setAnswers({}); setStartTime(startedAt); setTick(startedAt); pendingRequest.current = null;
    setError(null); setNotice(null);
  }

  async function submit() {
    if (!active || !startTime) return;
    if (hasShortAnswer && !consentReady) { setError('Short-answer assessment needs Study AI consent. Turn it on below first.'); return; }
    setBusy(true); setError(null); setNotice(null);
    const signature = JSON.stringify([active.record.id, answers]);
    if (pendingRequest.current?.signature !== signature) pendingRequest.current = { signature, requestId: randomUUID() };
    try {
      const result = hasShortAnswer
        ? await requestMockExamAssessment(pendingRequest.current.requestId, active.record.id, answers, elapsed)
        : await saveMockExamAttempt(active.record.id, answers, elapsed, pendingRequest.current.requestId);
      setActiveExamId(null); setStartTime(null); setAnswers({}); setActiveQuestion(0);
      setNotice(`Attempt saved · ${result.score}% suggested result. ${hasShortAnswer ? 'Short-answer results are AI suggestions; review the explanations and uncertainty.' : 'Objective answers were checked against this exam’s saved key.'}`);
      pendingRequest.current = null; onSaved();
    } catch (cause) {
      if (hasShortAnswer && pendingRequest.current && await usageRequestFailed(pendingRequest.current.requestId)) pendingRequest.current = null;
      setError(cause instanceof Error ? cause.message : 'Could not submit this exam. Your answers remain available to retry.');
    } finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>Mock exams and review</Eyebrow>
    <Body>Create a focused, timed practice attempt using your own source-linked answer key or rubric. Objective questions are checked against your key. Short-answer scores are AI suggestions and may be uncertain; use their explanations when reviewing.</Body>
    {studyItems.length > 0 && <View style={styles.choiceRow}>{studyItems.map((item) => <Button key={item.id}
      label={`${itemId === item.id ? '✓ ' : ''}${item.title}`} variant="tertiary" disabled={busy || readOnly}
      onPress={() => setItemId(item.id)} />)}</View>}
    {!active && <View style={sharedStyles.column}>
      <Field label="Exam title" value={readOnly ? '' : title} onChangeText={setTitle} maxLength={120} editable={!busy && !readOnly} />
      <Field label="Source or rubric reference" value={readOnly ? '' : sourceReference} onChangeText={setSourceReference} maxLength={300} editable={!busy && !readOnly}
        placeholder="Chapter 4 notes · page 18" helperText="Link the questions to a source you can revisit." />
      <Field label="Time limit in minutes" value={readOnly ? '' : timeLimit} onChangeText={setTimeLimit} keyboardType="number-pad" editable={!busy && !readOnly} />
      <View style={styles.choiceRow}>{(['multiple_choice', 'true_false', 'short_answer'] as const).map((type) => <Button key={type}
        label={`${questionType === type ? '✓ ' : ''}${type === 'multiple_choice' ? 'Multiple choice' : type === 'true_false' ? 'True or false' : 'Short answer'}`}
        variant="tertiary" disabled={busy || readOnly} onPress={() => { setQuestionType(type); setError(null); }} />)}</View>
      <Field label="Question" value={readOnly ? '' : prompt} onChangeText={setPrompt} maxLength={1000} multiline editable={!busy && !readOnly} />
      {questionType === 'multiple_choice' && <Field label="Answer choices (one per line)" value={readOnly ? '' : optionsText} onChangeText={setOptionsText} maxLength={1000} multiline editable={!busy && !readOnly} />}
      <Field label={questionType === 'short_answer' ? 'Expected answer (optional)' : 'Correct answer'} value={readOnly ? '' : expectedAnswer} onChangeText={setExpectedAnswer} maxLength={1000} editable={!busy && !readOnly} />
      {questionType === 'short_answer' && <Field label="Marking rubric" value={readOnly ? '' : rubric} onChangeText={setRubric} maxLength={2000} multiline editable={!busy && !readOnly} />}
      <Field label="Explanation shown in review" value={readOnly ? '' : explanation} onChangeText={setExplanation} maxLength={1500} multiline editable={!busy && !readOnly} />
      <Button label={editingQuestionId ? 'Save question changes' : 'Add question to draft'} variant="secondary" disabled={busy || readOnly} onPress={addQuestion} />
      {!readOnly && draftQuestions.length > 0 && <View style={sharedStyles.column}>
        <Label>Draft questions · {draftQuestions.length}</Label>
        {draftQuestions.map((question, index) => <View key={question.id} style={styles.row}>
          <View style={sharedStyles.grow}><Label>{index + 1}. {question.prompt}</Label><Body>{question.type.replace('_', ' ')}</Body></View>
          <Button label="Edit" variant="tertiary" disabled={busy || readOnly} onPress={() => editQuestion(question)} />
          <Button label="Remove" variant="tertiary" disabled={busy || readOnly} onPress={() => {
            setDraftQuestions((currentQuestions) => currentQuestions.filter((entry) => entry.id !== question.id));
            if (editingQuestionId === question.id) setEditingQuestionId(null);
          }} />
        </View>)}
      </View>}
      <View style={styles.row}>
        <Button label={editingExam ? 'Save exam changes' : 'Save mock exam'} onPress={() => void saveExam()} busy={busy} disabled={busy || readOnly} />
        {editingExam && <Button label="Cancel editing" variant="secondary" disabled={busy} onPress={() => {
          setEditingExam(null); setTitle(''); setSourceReference(''); setDraftQuestions([]); setError(null);
        }} />}
      </View>
    </View>}

    {active && current && <View style={sharedStyles.column}>
      <Label>{active.record.title} · Question {activeQuestion + 1} of {active.definition.questions.length}</Label>
      <Body>Practice timer · {formatClock(timeLeft)} remaining{timeExpired ? ' · time is up; submit to save this attempt' : ''}</Body>
      <Label>{current.prompt}</Label>
      {current.type === 'multiple_choice' && current.options.map((option) => <Button key={option}
        label={`${!readOnly && answers[current.id] === option ? '✓ ' : ''}${option}`} variant={!readOnly && answers[current.id] === option ? 'secondary' : 'tertiary'}
        disabled={busy || readOnly || timeExpired} onPress={() => setAnswers((currentAnswers) => ({ ...currentAnswers, [current.id]: option }))} />)}
      {current.type === 'true_false' && ['true', 'false'].map((option) => <Button key={option}
        label={`${!readOnly && answers[current.id] === option ? '✓ ' : ''}${option === 'true' ? 'True' : 'False'}`} variant="tertiary"
        disabled={busy || readOnly || timeExpired} onPress={() => setAnswers((currentAnswers) => ({ ...currentAnswers, [current.id]: option }))} />)}
      {current.type === 'short_answer' && <Field label="Your answer" value={readOnly ? '' : answers[current.id] ?? ''} onChangeText={(value) => setAnswers((currentAnswers) => ({ ...currentAnswers, [current.id]: value }))}
        multiline maxLength={3000} editable={!busy && !readOnly && !timeExpired} />}
      {!timeExpired && activeQuestion < active.definition.questions.length - 1 ? <View style={styles.row}>
        <Button label="Previous" variant="secondary" disabled={busy || readOnly || activeQuestion === 0} onPress={() => setActiveQuestion((index) => Math.max(0, index - 1))} />
        <Button label="Next question" onPress={() => setActiveQuestion((index) => index + 1)} disabled={busy || readOnly} />
      </View> : <View style={sharedStyles.column}>
        <Button label="Previous" variant="secondary" disabled={busy || readOnly || activeQuestion === 0} onPress={() => setActiveQuestion((index) => Math.max(0, index - 1))} />
        {hasShortAnswer
          ? <UsageButton feature="mock_exam_assess" replay={Boolean(error)} label="Submit attempt" onPress={submit} busy={busy} disabled={busy || readOnly} />
          : <Button label="Submit attempt" onPress={() => void submit()} busy={busy} disabled={busy || readOnly} />}
      </View>}
      <Button label="Leave this attempt" variant="tertiary" disabled={busy} onPress={() => {
        setActiveExamId(null); setStartTime(null); setActiveQuestion(0); setAnswers({}); pendingRequest.current = null;
        if (draftKey && !title && !sourceReference && draftQuestions.length === 0) void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      }} />
    </View>}

    {examsNeedAi && <View style={sharedStyles.row}>
      <View style={sharedStyles.grow}><Label>{childProfile ? 'Consent to AI assessment of short answers' : 'I am an adult and consent to AI assessment of short answers'}</Label>
        <Body>The exam title, source reference, marking rubric, and short answers go to Bloom’s approved AI provider. Answers stay in your private Study history.</Body></View>
      <Switch accessibilityLabel="Consent to AI mock exam assessment" value={aiConsent} disabled={busy || readOnly}
        onValueChange={(enabled) => void saveAiConsent(enabled)} />
    </View>}
    {childProfile && examsNeedAi && !consentReady && <Body>Short-answer assessment also needs parent eligibility and consent in Family Space. Objective questions remain available.</Body>}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
    <Label>Saved exams</Label>
    {exams.length === 0 ? <Body>Add questions and save a mock exam to begin.</Body> : exams.map(({ record, definition }) => <View key={record.id} style={styles.record}>
      <Label>{record.title} · {definition.questions.length} questions · {definition.time_limit_minutes} min</Label>
      <Body>Source / rubric: {String(record.metadata.source_reference ?? 'Not set')}</Body>
      {examAttempts.filter((attempt) => attempt.examId === record.id).slice(0, 3).map(({ record: attemptRecord, parsed }) => <View key={attemptRecord.id} style={styles.record}>
        <Label>{parsed ? `${parsed.score}% · ${new Date(attemptRecord.created_at).toLocaleString(getAppLocale())}` : 'Attempt saved'}</Label>
        {parsed?.uncertainty && <Body>{parsed.uncertainty}</Body>}
        {parsed?.results.map((result) => <View key={result.question_id}>
          <Body>Your answer: {result.answer || 'Skipped'}</Body>
          <Body>{result.explanation}{result.uncertainty ? ` · Uncertainty: ${result.uncertainty}` : ''}</Body>
        </View>)}
      </View>)}
      <View style={styles.row}>
        <Button label="Start timed attempt" variant="secondary" disabled={busy || readOnly || Boolean(active) || Boolean(editingExam)} onPress={() => start(record.id)} />
        <Button label="Edit" variant="tertiary" disabled={busy || readOnly || Boolean(active)} onPress={() => editExam(record, definition)} />
        <Button label="Delete" variant="tertiary" disabled={busy || readOnly || Boolean(active)} onPress={() => setConfirmDeleteExam(record.id)} />
      </View>
      {confirmDeleteExam === record.id && <View style={sharedStyles.column}>
        <Body>Delete {record.title}? Completed attempts remain in your Study history.</Body>
        <Button label="Confirm delete" variant="destructive" busy={busy} onPress={() => void removeExam(record)} />
        <Button label="Keep exam" variant="secondary" disabled={busy} onPress={() => setConfirmDeleteExam(null)} />
      </View>}
    </View>)}
  </Panel>;
}

function parseAttempt(record: GrowthRecord): AttemptResult | null {
  try {
    const result = JSON.parse(record.body) as Partial<AttemptResult>;
    const score = typeof result.score === 'number' ? result.score : record.score;
    if (typeof score !== 'number' || !Array.isArray(result.results)) return null;
    return { ...result, score, results: result.results } as AttemptResult;
  } catch { return null; }
}

function formatClock(seconds: number) {
  return `${Math.floor(seconds / 60).toString().padStart(2, '0')}:${(seconds % 60).toString().padStart(2, '0')}`;
}

function clockNow() {
  return Date.now();
}

const styles = StyleSheet.create({
  choiceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  row: { ...sharedStyles.row, alignItems: 'center' },
  record: { gap: 8, paddingVertical: 8, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#E4E8F3' },
});
