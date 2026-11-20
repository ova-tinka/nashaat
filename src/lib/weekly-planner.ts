import type { ModuleKey } from '../theme';

export type WeeklyScheduleGoal = {
  module_id: ModuleKey;
  target_count: number;
  unit: 'workouts' | 'minutes' | 'sessions' | 'tasks';
  active_days: number[];
};

export type WeeklyScheduleProposal = {
  goals: WeeklyScheduleGoal[];
  recovery_day: number;
  reduced_exercise_goal: boolean;
};

export type WeeklyCheckIn = 'steady' | 'hard_to_fit' | 'too_much';
export type WeeklyCoachedScheduleProposal = WeeklyScheduleProposal & {
  check_in: WeeklyCheckIn;
  reduced_goal_modules: ModuleKey[];
};

/** Balance each saved goal across up to six days and leave one shared recovery day open. */
export function suggestBalancedWeeklySchedule(goals: WeeklyScheduleGoal[], options: { preserveTargets?: boolean } = {}): WeeklyScheduleProposal {
  const normalized = goals.map((goal) => ({
    ...goal,
    active_days: [...new Set(goal.active_days.filter((day) => Number.isInteger(day) && day >= 0 && day <= 6))],
  })).filter((goal) => goal.active_days.length > 0);

  const initialLoad = Array.from({ length: 7 }, (_, day) => normalized.reduce(
    (total, goal) => total + Number(goal.active_days.includes(day)), 0,
  ));
  const recoveryDay = initialLoad.reduce((best, load, day) =>
    load < initialLoad[best] ? day : best, 0);
  const load = [...initialLoad];
  const nextGoals = normalized.map((goal) => {
    const dayCount = Math.min(6, goal.active_days.length);
    const days = Array.from({ length: 7 }, (_, day) => day).filter((day) => day !== recoveryDay)
      .sort((left, right) => load[left] - load[right]
        || Number(!goal.active_days.includes(left)) - Number(!goal.active_days.includes(right))
        || left - right)
      .slice(0, dayCount)
      .sort((left, right) => left - right);
    for (const day of days) load[day] += 1;
    return {
      ...goal,
      target_count: goal.unit === 'workouts' && !options.preserveTargets ? Math.min(goal.target_count, 6) : goal.target_count,
      active_days: days,
    };
  });

  return {
    goals: nextGoals,
    recovery_day: recoveryDay,
    reduced_exercise_goal: nextGoals.some((goal, index) => goal.target_count < normalized[index].target_count),
  };
}

/** Turn the user's weekly check-in into a reviewable, local-only schedule proposal. */
export function suggestWeeklyCheckInSchedule(goals: WeeklyScheduleGoal[], checkIn: WeeklyCheckIn): WeeklyCoachedScheduleProposal {
  const adjusted = goals.map((goal) => ({
    ...goal,
    target_count: checkIn === 'too_much' ? Math.max(1, Math.round(goal.target_count * 0.8)) : goal.target_count,
  }));
  const proposal = suggestBalancedWeeklySchedule(adjusted, { preserveTargets: true });
  return {
    ...proposal,
    check_in: checkIn,
    reduced_goal_modules: adjusted.flatMap((goal, index) => goal.target_count < goals[index].target_count ? [goal.module_id] : []),
  };
}
