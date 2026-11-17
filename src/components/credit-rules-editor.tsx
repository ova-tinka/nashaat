import { useState } from 'react';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel } from './bloom-ui';
import type { CreditSettings } from '../lib/bloom';

export function CreditRulesEditor({ settings, onSave }: { settings: CreditSettings; onSave: (rules: Omit<CreditSettings, 'credits_enabled'>) => Promise<void> }) {
  const [mode, setMode] = useState(settings.credit_mode);
  const [timezone, setTimezone] = useState(settings.credit_timezone);
  const [earningStrategy, setEarningStrategy] = useState(settings.earning_strategy);
  const [reps, setReps] = useState(settings.reps_per_award?.toString() ?? '');
  const [repMinutes, setRepMinutes] = useState(settings.rep_award_minutes?.toString() ?? '');
  const [exerciseMinutes, setExerciseMinutes] = useState(settings.exercise_minutes_per_award?.toString() ?? '');
  const [timeMinutes, setTimeMinutes] = useState(settings.time_award_minutes?.toString() ?? '');
  const [dailyCap, setDailyCap] = useState(settings.super_daily_cap_minutes?.toString() ?? '');
  const [weeklyWorkouts, setWeeklyWorkouts] = useState(settings.weekly_workout_target?.toString() ?? '');
  const [weeklyCreditMinutes, setWeeklyCreditMinutes] = useState(settings.weekly_credit_target_minutes?.toString() ?? '');
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);

  async function save() {
    setError(null); setSaved(false);
    const parse = (value: string, integer: boolean, max: number) => {
      if (!value.trim()) return null;
      if (!(integer ? /^\d+$/ : /^\d+(\.\d{1,2})?$/).test(value.trim())) throw new Error('Enter positive numbers with at most two decimal places.');
      const number = Number(value);
      if (!Number.isFinite(number) || number <= 0 || number > max) throw new Error('Check the values you entered.');
      return number;
    };
    try {
      const repsValue = earningStrategy === 'rates' ? parse(reps, true, 1000000) : settings.reps_per_award;
      const repReward = earningStrategy === 'rates' ? parse(repMinutes, false, 10080) : settings.rep_award_minutes;
      const timeValue = earningStrategy === 'rates' ? parse(exerciseMinutes, false, 10080) : settings.exercise_minutes_per_award;
      const timeReward = earningStrategy === 'rates' ? parse(timeMinutes, false, 10080) : settings.time_award_minutes;
      const cap = mode === 'super_hard' ? parse(dailyCap, false, 1440) : null;
      const workoutTarget = earningStrategy === 'goal_analytics' ? parse(weeklyWorkouts, true, 7) : settings.weekly_workout_target;
      const creditTarget = earningStrategy === 'goal_analytics' ? parse(weeklyCreditMinutes, false, 10080) : settings.weekly_credit_target_minutes;
      if (earningStrategy === 'rates' && ((repsValue === null) !== (repReward === null) || (timeValue === null) !== (timeReward === null))) throw new Error('Enter both numbers for each earning rate, or leave both blank.');
      if (earningStrategy === 'goal_analytics' && (workoutTarget === null || creditTarget === null)) throw new Error('Set both a weekly workout target and a weekly credit goal.');
      if (mode === 'super_hard' && cap === null) throw new Error('Set a daily cap for super hard mode.');
      if (!timezone.trim()) throw new Error('Enter a time zone.');
      setSaving(true);
      await onSave({ credit_mode: mode, credit_timezone: timezone.trim(), earning_strategy: earningStrategy, reps_per_award: repsValue,
        rep_award_minutes: repReward, exercise_minutes_per_award: timeValue,
        time_award_minutes: timeReward, super_daily_cap_minutes: cap,
        weekly_workout_target: workoutTarget, weekly_credit_target_minutes: creditTarget });
      setSaved(true);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not save earning rules. Check the time zone and try again.');
    } finally { setSaving(false); }
  }

  return <Panel>
    <Eyebrow>Earning rules</Eyebrow>
    <Label>How screen time is earned</Label>
    {(['rates', 'goal_analytics'] as const).map((choice) => <Button key={choice} label={`${earningStrategy === choice ? '✓ ' : ''}${choice === 'rates' ? 'Per exercise rate' : 'Weekly target + analytics'}`} secondary onPress={() => setEarningStrategy(choice)} disabled={saving} />)}
    {earningStrategy === 'rates' ? <>
      <Body>Set a rate for repetitions, exercise time, or both. Leave a pair blank if that exercise type should not earn credits.</Body>
      <Field label="Repetitions required" value={reps} onChangeText={setReps} keyboardType="number-pad" placeholder="e.g. 20" />
      <Field label="Screen-time minutes earned for those repetitions" value={repMinutes} onChangeText={setRepMinutes} keyboardType="decimal-pad" placeholder="e.g. 5" />
      <Field label="Exercise minutes required" value={exerciseMinutes} onChangeText={setExerciseMinutes} keyboardType="decimal-pad" placeholder="e.g. 10" />
      <Field label="Screen-time minutes earned for that exercise time" value={timeMinutes} onChangeText={setTimeMinutes} keyboardType="decimal-pad" placeholder="e.g. 5" />
    </> : <>
      <Body>Choose a weekly workout target and credit pool. Each completed workout earns its share, adjusted by planned exercise coverage, completed sets, and reps or time completed. Extra work does not earn extra credit, and awards stop at your weekly goal.</Body>
      <Field label="Workout target per week" value={weeklyWorkouts} onChangeText={setWeeklyWorkouts} keyboardType="number-pad" placeholder="e.g. 3" />
      <Field label="Screen-time credit goal per week in minutes" value={weeklyCreditMinutes} onChangeText={setWeeklyCreditMinutes} keyboardType="decimal-pad" placeholder="e.g. 45" />
    </>}
    <Label>Difficulty</Label>
    <Body>Easy meters a server-timed access window, including idle time. Hard uses a countdown and divides the weekly balance across seven days. Super hard also caps daily use.</Body>
    {(['easy', 'hard', 'super_hard'] as const).map((choice) => <Button key={choice} label={`${mode === choice ? '✓ ' : ''}${choice === 'super_hard' ? 'Super hard' : choice === 'hard' ? 'Hard' : 'Easy'}`} secondary onPress={() => setMode(choice)} disabled={saving} />)}
    {mode === 'super_hard' && <Field label="Maximum screen-time minutes per day" value={dailyCap} onChangeText={setDailyCap} keyboardType="decimal-pad" />}
    <Field label="Week time zone" value={timezone} onChangeText={setTimezone} autoCapitalize="none" autoCorrect={false} placeholder="Asia/Qatar" />
    <Button label="Use this device’s time zone" secondary onPress={() => setTimezone(Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC')} disabled={saving} />
    <Body>Credits expire at Sunday midnight in this time zone. Easy time runs from reservation until you finish or the access window expires; Hard modes use countdown sessions.</Body>
    {error && <ErrorText>{error}</ErrorText>}{saved && <Body>Earning rules saved.</Body>}
    <Button label="Save earning rules" onPress={() => void save()} busy={saving} />
  </Panel>;
}
