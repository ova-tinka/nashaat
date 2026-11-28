import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Href } from 'expo-router';

export type OnboardingGoal =
  | 'screen_time'
  | 'study'
  | 'exercise'
  | 'read'
  | 'tasks'
  | 'routines';

export type OnboardingUsageMode = 'individual' | 'family';

export type OnboardingState = {
  version: 1;
  completed: boolean;
  completedAt: string | null;
  currentStep: number;
  goals: OnboardingGoal[];
  usageMode: OnboardingUsageMode;
  skippedPermissions: boolean;
};

export const ONBOARDING_STEPS = [
  'welcome',
  'goals',
  'usage_mode',
  'earned_screen_time',
  'permissions',
  'subscription',
  'first_action',
] as const;

export const ONBOARDING_GOAL_OPTIONS: { id: OnboardingGoal; label: string; description: string }[] = [
  { id: 'screen_time', label: 'Reduce distracting screen time', description: 'Block distracting apps and sites until you earn access.' },
  { id: 'study', label: 'Study more consistently', description: 'Track focused study sessions and review learning items.' },
  { id: 'exercise', label: 'Exercise regularly', description: 'Follow structured workout plans and log completed sets.' },
  { id: 'read', label: 'Read more', description: 'Build a reading library and log steady reading progress.' },
  { id: 'tasks', label: 'Complete daily tasks', description: 'Organize checklists and turn finished work into progress.' },
  { id: 'routines', label: 'Build calmer daily routines', description: 'Combine focus rules with clear, sustainable habits.' },
];

export function onboardingStorageKey(profileId: string): string {
  return `bloom:onboarding:v1:${profileId}`;
}

export function defaultOnboardingState(): OnboardingState {
  return {
    version: 1,
    completed: false,
    completedAt: null,
    currentStep: 0,
    goals: [],
    usageMode: 'individual',
    skippedPermissions: false,
  };
}

export function parseOnboardingState(raw: string | null): OnboardingState {
  if (!raw) return defaultOnboardingState();
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return defaultOnboardingState();
    const record = parsed as Record<string, unknown>;
    const validGoals = new Set<string>(ONBOARDING_GOAL_OPTIONS.map((item) => item.id));
    const goals = Array.isArray(record.goals)
      ? record.goals.filter((item): item is OnboardingGoal => typeof item === 'string' && validGoals.has(item))
      : [];
    const step = typeof record.currentStep === 'number' && Number.isInteger(record.currentStep)
      ? Math.max(0, Math.min(ONBOARDING_STEPS.length - 1, record.currentStep))
      : 0;
    return {
      version: 1,
      completed: record.completed === true,
      completedAt: typeof record.completedAt === 'string' ? record.completedAt : null,
      currentStep: step,
      goals,
      usageMode: record.usageMode === 'family' ? 'family' : 'individual',
      skippedPermissions: record.skippedPermissions === true,
    };
  } catch {
    return defaultOnboardingState();
  }
}

export function shouldShowOnboarding(
  state: OnboardingState | null,
  options: { childProfile: boolean },
): boolean {
  if (options.childProfile) return false;
  if (!state) return false;
  return !state.completed;
}

export function recommendedFirstAction(goals: OnboardingGoal[]): {
  label: string;
  description: string;
  route: Href;
  pillar?: 'exercise' | 'study' | 'read' | 'tasks';
} {
  if (goals.includes('study')) {
    return {
      label: 'Open Study',
      description: 'Add a study item or start a focused study session.',
      route: '/study' as Href,
      pillar: 'study',
    };
  }
  if (goals.includes('exercise')) {
    return {
      label: 'Open Exercise',
      description: 'Choose a workout plan or log your first activity.',
      route: '/workouts' as Href,
      pillar: 'exercise',
    };
  }
  if (goals.includes('read')) {
    return {
      label: 'Open Reading',
      description: 'Add a book or start your first reading session.',
      route: '/read' as Href,
      pillar: 'read',
    };
  }
  if (goals.includes('tasks')) {
    return {
      label: 'Open Tasks',
      description: 'Create your first task checklist and earn credits on completion.',
      route: '/tasks' as Href,
      pillar: 'tasks',
    };
  }
  return {
    label: 'Configure blocking rules',
    description: 'Select distracting apps or websites to block on this device.',
    route: '/focus' as Href,
  };
}

export async function loadOnboardingState(profileId: string): Promise<OnboardingState> {
  try {
    const raw = await AsyncStorage.getItem(onboardingStorageKey(profileId));
    return parseOnboardingState(raw);
  } catch {
    return defaultOnboardingState();
  }
}

export async function saveOnboardingState(profileId: string, state: OnboardingState): Promise<void> {
  try {
    await AsyncStorage.setItem(onboardingStorageKey(profileId), JSON.stringify(state));
  } catch {
    // Keep onboarding responsive even if local storage is temporarily unavailable.
  }
}
