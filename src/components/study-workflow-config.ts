import type MaterialIcons from '@expo/vector-icons/MaterialIcons';
import type { Href } from 'expo-router';
import type { ComponentProps } from 'react';
import type { GrowthModuleId } from '../lib/growth-modules';

export const moduleContent: Record<GrowthModuleId, { title: string; description: string; icon: 'school' | 'menu-book' | 'check-box' }> = {
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

export type GrowthSection = {
  id: string;
  label: string;
  title: string;
  description: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
};

export function sectionHref(moduleId: GrowthModuleId, sectionId: string): Href {
  if (moduleId === 'study' && sectionId === 'today') return '/study';
  const params = { section: sectionId };
  switch (moduleId) {
    case 'study': return { pathname: '/apps/study/[section]', params };
    case 'read': return { pathname: '/apps/read/[section]', params };
    case 'tasks': return { pathname: '/apps/tasks/[section]', params };
  }
}

export const moduleSections: Record<GrowthModuleId, GrowthSection[]> = {
  study: [
    { id: 'today', label: 'Today', title: 'Today', description: 'Focus. Learn. Grow.', icon: 'today' },
    { id: 'plan', label: 'Plan', title: 'Weekly plan', description: 'Set a flexible weekly target.', icon: 'calendar-month' },
    { id: 'courses', label: 'Courses', title: 'Courses and lessons', description: 'Organize subjects, courses, and lessons.', icon: 'account-tree' },
    { id: 'more', label: 'More', title: 'Study tools', description: 'Practice, exams, tutor, and materials.', icon: 'apps' },
    { id: 'progress', label: 'Progress', title: 'Your study progress', description: 'Review sessions and learning activity.', icon: 'insights' },
    { id: 'practice', label: 'Practice & review', title: 'Practice and review', description: 'Questions, flashcards, and due review.', icon: 'quiz' },
    { id: 'exams', label: 'Mock exams', title: 'Mock exams', description: 'Take an exam and review results.', icon: 'assignment' },
    { id: 'tutor', label: 'Study tutor', title: 'Study tutor', description: 'Get explanations and guided hints.', icon: 'forum' },
    { id: 'resources', label: 'Documents', title: 'Study documents', description: 'Your private course materials.', icon: 'folder-open' },
    { id: 'document-help', label: 'Document help', title: 'Document help', description: 'Ask about a source with citations.', icon: 'manage-search' },
    { id: 'learning-check', label: 'Learning check', title: 'Learning check', description: 'Save a short reflection after a session.', icon: 'fact-check' },
    { id: 'active-session', label: 'Focus session', title: 'Focus session', description: 'A focused study session.', icon: 'timer' },
    { id: 'session-complete', label: 'Session complete', title: 'Session complete', description: 'Review your saved session.', icon: 'check-circle' },
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
    { id: 'focus', label: 'Task focus', title: 'Focus on one step', description: 'Count focused time toward a task.', icon: 'timer' },
    { id: 'breakdown', label: 'Break down a task', title: 'Make a task easier to start', description: 'Edit and approve AI drafted steps.', icon: 'format-list-bulleted' },
  ],
};
