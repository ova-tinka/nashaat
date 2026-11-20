import { dateKeyInTimeZone } from './date-utils';
import type { CreditLedgerEntry } from './bloom';
import type { WeeklyPillarActual, WeeklyPillarGoal } from './growth-modules';
import { moduleManifest } from './module-manifest';

export type DailyScreenTimeTotal = { dateKey: string; label: string; minutes: number };
export type PillarGoalProgress = WeeklyPillarGoal & { actualValue: number; complete: boolean };
export type WeeklyGoalSummary = {
  goals: PillarGoalProgress[];
  completedCount: number;
  totalCount: number;
  percent: number;
};

export function summarizeWeeklyGoals(goals: readonly WeeklyPillarGoal[], actuals: readonly WeeklyPillarActual[] = []): WeeklyGoalSummary {
  const orderedGoals = moduleManifest.flatMap((module) => goals
    .filter((goal) => goal.module_id === module.id && goal.target_count > 0)
    .map((goal) => {
      const actualValue = actuals.find((actual) => actual.module_id === goal.module_id)?.actual_value ?? 0;
      return { ...goal, actualValue, complete: actualValue >= goal.target_count };
    }));
  const completedCount = orderedGoals.filter((goal) => goal.complete).length;
  return {
    goals: orderedGoals,
    completedCount,
    totalCount: orderedGoals.length,
    percent: orderedGoals.length === 0 ? 0 : Math.round((completedCount / orderedGoals.length) * 100),
  };
}

export function buildDailyScreenTimeTotals(
  entries: readonly Pick<CreditLedgerEntry, 'amount_minutes' | 'entry_type' | 'created_at'>[],
  now: Date = new Date(),
  timeZone = 'UTC',
  locale?: string,
): DailyScreenTimeTotal[] {
  let resolvedTimeZone = timeZone || 'UTC';
  try {
    new Intl.DateTimeFormat('en', { timeZone: resolvedTimeZone }).format(now);
  } catch {
    resolvedTimeZone = 'UTC';
  }

  const today = dateKeyInTimeZone(now, resolvedTimeZone);
  const [year, month, day] = today.split('-').map(Number);
  const totals = new Map<string, number>();
  const days = Array.from({ length: 7 }, (_, index) => {
    const date = new Date(Date.UTC(year, month - 1, day + index - 6, 12));
    const dateKey = date.toISOString().slice(0, 10);
    totals.set(dateKey, 0);
    return { dateKey, label: new Intl.DateTimeFormat(locale, { weekday: 'short', timeZone: 'UTC' }).format(date), minutes: 0 };
  });

  for (const entry of entries) {
    if (entry.entry_type !== 'spent' || !Number.isFinite(entry.amount_minutes) || entry.amount_minutes >= 0) continue;
    const date = new Date(entry.created_at);
    if (!Number.isFinite(date.getTime())) continue;
    const dateKey = dateKeyInTimeZone(date, resolvedTimeZone);
    const currentTotal = totals.get(dateKey);
    if (currentTotal !== undefined) totals.set(dateKey, currentTotal + Math.abs(entry.amount_minutes));
  }

  return days.map((item) => ({ ...item, minutes: totals.get(item.dateKey) ?? 0 }));
}
