export type RecordMeasurement = 'reps_weight' | 'reps_only' | 'time_only' | 'time_distance';
export type ExercisePersonalBest = {
  exerciseId: string; exerciseName: string; measurement: RecordMeasurement; metric: string; value: number; unit: string; achievedAt: string;
};
export type ExerciseAchievement = { id: string; title: string; explanation: string; achievedAt: string };
export type CompletedExerciseSession = { completed_at: string | null; plan_snapshot: unknown; exercise_results: unknown };
export type ExerciseStreak = { currentDays: number; longestDays: number };

export function calculateExerciseRecords(completed: CompletedExerciseSession[], timeZone = 'UTC', now = new Date()) {
  const bestByMetric = new Map<string, ExercisePersonalBest>();
  const achievements: ExerciseAchievement[] = [];
  const milestones = new Set([1, 5, 10, 25, 50, 100]);
  const streak = calculateExerciseStreak(completed, timeZone, now);
  completed.forEach((session, index) => {
    const completedAt = String(session.completed_at ?? '');
    const count = index + 1;
    if (milestones.has(count)) achievements.push({
      id: `workouts:${count}`, title: count === 1 ? 'First completed workout' : `${count} completed workouts`,
      explanation: 'Based on saved, completed workout records.', achievedAt: completedAt,
    });
    const plans = Array.isArray(session.plan_snapshot) ? session.plan_snapshot as Record<string, unknown>[] : [];
    const results = Array.isArray(session.exercise_results) ? session.exercise_results as Record<string, unknown>[] : [];
    for (const result of results) {
      if (typeof result.exercise_id !== 'string') continue;
      const exercise = plans.find((plan) => plan.exercise_id === result.exercise_id);
      if (!exercise || typeof exercise.name !== 'string' || !isMeasurement(exercise.measurement_type)) continue;
      if (!positiveNumber(result.sets_completed)) continue;
      const measurement = exercise.measurement_type;
      const values: { metric: string; value: number; unit: string }[] = [];
      if (measurement === 'reps_only' || measurement === 'reps_weight') {
        const reps = positiveNumber(result.reps_completed);
        if (reps) values.push({ metric: 'Repetitions per set', value: reps, unit: 'reps' });
        if (measurement === 'reps_weight') {
          const weight = nonNegativeNumber(result.weight_kg);
          if (weight !== null) values.push({ metric: 'Weight', value: weight, unit: 'kg' });
        }
      } else {
        const seconds = positiveNumber(result.duration_seconds);
        if (seconds) values.push({ metric: 'Duration per set', value: seconds, unit: 'sec' });
        if (measurement === 'time_distance') {
          const distance = positiveNumber(result.distance_km);
          if (distance) values.push({ metric: 'Distance per set', value: distance, unit: 'km' });
        }
      }
      for (const item of values) {
        const key = `${result.exercise_id}:${item.metric}`;
        const previous = bestByMetric.get(key);
        if (!previous || item.value > previous.value) {
          bestByMetric.set(key, { exerciseId: result.exercise_id, exerciseName: exercise.name, measurement, ...item, achievedAt: completedAt });
          if (previous) achievements.push({
            id: `best:${key}:${completedAt}`, title: `New ${item.metric.toLowerCase()} best · ${exercise.name}`,
            explanation: `${formatPersonalBest(item.value, item.unit)} in a completed workout.`, achievedAt: completedAt,
          });
        }
      }
    }
  });
  return { bests: [...bestByMetric.values()].sort((a, b) => a.exerciseName.localeCompare(b.exerciseName) || a.metric.localeCompare(b.metric)),
    streak, achievements: achievements.sort((a, b) => Date.parse(b.achievedAt) - Date.parse(a.achievedAt)).slice(0, 30) };
}

export function calculateExerciseStreak(completed: Pick<CompletedExerciseSession, 'completed_at'>[], timeZone = 'UTC', now = new Date()): ExerciseStreak {
  const days = new Set(completed.flatMap((session) => {
    const timestamp = Date.parse(String(session.completed_at ?? ''));
    return Number.isFinite(timestamp) ? [dateKeyInTimeZone(timestamp, timeZone)] : [];
  }));
  if (!days.size) return { currentDays: 0, longestDays: 0 };

  const today = dateKeyInTimeZone(now, timeZone);
  const previousDay = shiftDate(today, -1);
  const firstDay = days.has(today) ? today : days.has(previousDay) ? previousDay : null;
  let currentDays = 0;
  if (firstDay) {
    let cursor = firstDay;
    while (days.has(cursor)) { currentDays += 1; cursor = shiftDate(cursor, -1); }
  }

  let longestDays = 0;
  let run = 0;
  let previous = '';
  for (const day of [...days].sort()) {
    run = previous && shiftDate(previous, 1) === day ? run + 1 : 1;
    longestDays = Math.max(longestDays, run);
    previous = day;
  }
  return { currentDays, longestDays };
}

function dateKeyInTimeZone(value: Date | number, timeZone: string) {
  const date = value instanceof Date ? value : new Date(value);
  let parts: Intl.DateTimeFormatPart[];
  try {
    parts = new Intl.DateTimeFormat('en-CA', { timeZone: timeZone || 'UTC', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  } catch {
    parts = new Intl.DateTimeFormat('en-CA', { timeZone: 'UTC', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(date);
  }
  const fields = Object.fromEntries(parts.map(({ type, value: part }) => [type, part]));
  return `${fields.year}-${fields.month}-${fields.day}`;
}

function shiftDate(value: string, offset: number) {
  const date = new Date(`${value}T12:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + offset);
  return date.toISOString().slice(0, 10);
}

function isMeasurement(value: unknown): value is RecordMeasurement { return ['reps_only', 'reps_weight', 'time_only', 'time_distance'].includes(String(value)); }
function positiveNumber(value: unknown) { const number = Number(value); return Number.isFinite(number) && number > 0 ? number : null; }
function nonNegativeNumber(value: unknown) { const number = Number(value); return Number.isFinite(number) && number >= 0 ? number : null; }
function formatPersonalBest(value: number, unit: string) { return `${value.toLocaleString(undefined, { maximumFractionDigits: 2 })} ${unit}`; }
