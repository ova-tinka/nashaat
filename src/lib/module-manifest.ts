import type { ComponentProps } from 'react';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { palette, type ModuleKey } from '../theme';

export type BloomPlatform = 'ios' | 'android' | 'macos' | 'web';
export type BloomModule = {
  id: ModuleKey;
  name: string;
  description: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
  accent: string;
  route: string | null;
  navigation: string[];
  permissions: string[];
  dashboardWidgets: string[];
  capabilities: string[];
  supportedPlatforms: BloomPlatform[];
  readerFormats?: Partial<Record<BloomPlatform, readonly ('PDF' | 'EPUB')[]>>;
  available: boolean;
};

/** One source for module availability, launch routes and shell presentation. */
export const moduleManifest: readonly BloomModule[] = [
  {
    id: 'exercise',
    name: 'Exercise',
    description: 'Build strength and movement into a routine that fits your week.',
    icon: 'fitness-center',
    accent: palette.exerciseDeep,
    route: '/exercise',
    navigation: ['Workouts', 'Exercise library', 'Workout session'],
    permissions: [],
    dashboardWidgets: ['Active workout', 'Weekly exercise progress'],
    capabilities: ['Workout plans', 'Timed and rep-based sessions', 'Workout history'],
    supportedPlatforms: ['ios', 'android', 'macos', 'web'],
    available: true,
  },
  {
    id: 'study',
    name: 'Study',
    description: 'Build a steady study rhythm with subjects, focused sessions and weekly targets.',
    icon: 'school',
    accent: palette.studyDeep,
    route: '/study',
    navigation: ['Today', 'Weekly plan', 'Courses and lessons', 'Practice and review', 'Mock exams', 'Study tutor', 'Documents', 'Document help', 'Learning check'],
    permissions: [],
    dashboardWidgets: ['Study subjects', 'Weekly study plan', 'Active focus session'],
    capabilities: ['Subject, course and lesson hierarchy', 'Weekly targets and flexible study plans', 'Server-timed focus sessions', 'Practice and spaced retrieval', 'Mock exams', 'Study tutor', 'Private learning documents'],
    supportedPlatforms: ['ios', 'android', 'macos', 'web'],
    available: true,
  },
  {
    id: 'read',
    name: 'Read',
    description: 'Keep a personal reading list, track your progress and log focused reading sessions.',
    icon: 'menu-book',
    accent: palette.readDeep,
    route: '/read',
    navigation: ['Reading list', 'Discover', 'Notes and reflection', 'Reader files'],
    permissions: [],
    dashboardWidgets: ['Continue reading', 'Reading progress'],
    capabilities: ['Personal reading list and progress tracking', 'Server-timed reading sessions', 'Curated public-domain discovery', 'Notes, annotations and vocabulary', 'Authorized PDF and EPUB reader on web'],
    supportedPlatforms: ['ios', 'android', 'macos', 'web'],
    readerFormats: { web: ['PDF', 'EPUB'] },
    available: true,
  },
  {
    id: 'tasks',
    name: 'Tasks',
    description: 'Capture priorities, set due dates and keep finished tasks in view.',
    icon: 'check-box',
    accent: palette.tasksDeep,
    route: '/tasks',
    navigation: ['Today', 'Projects', 'Task focus', 'Break down a task'],
    permissions: [],
    dashboardWidgets: ['Today’s priorities', 'Projects and milestones', 'Upcoming tasks'],
    capabilities: ['Task capture and due dates', 'Projects, milestones and checklists', 'Task-linked Focus sessions', 'Editable task breakdown drafts', 'Completion history'],
    supportedPlatforms: ['ios', 'android', 'macos', 'web'],
    available: true,
  },
];

export const availableModules = moduleManifest.filter((module) => module.available);
