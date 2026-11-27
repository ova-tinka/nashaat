import type { Href } from 'expo-router';
import type { GrowthItem, ReadingKind, ReadingStatus } from '../lib/growth-modules';
import { getAppLocale } from '../lib/locale-context';

export type ReadSection = 'today' | 'library' | 'discover' | 'progress' | 'item' | 'add' | 'edit' | 'session' | 'session-complete';
export type LibraryFilter = 'want_to_read' | 'currently_reading' | 'finished';
export type ProgressPeriod = 'day' | 'week' | 'month';
export type ItemTab = 'overview' | 'sessions' | 'notes' | 'files';
export type AddReturnSection = 'today' | 'library';

export const localReadTabs: { id: ReadSection; label: string }[] = [
  { id: 'today', label: 'Today' },
  { id: 'library', label: 'Library' },
  { id: 'discover', label: 'Discover' },
  { id: 'progress', label: 'Progress' },
];

export function readRouteFor(section: ReadSection, itemId?: string, editPages = false): Href {
  if (section === 'today') return '/read';
  return { pathname: '/apps/read/[section]', params: { section, ...(itemId ? { itemId } : {}), ...(editPages ? { editPages: '1' } : {}) } };
}

export function readAddRouteFor(returnTo: AddReturnSection): Href {
  return { pathname: '/apps/read/[section]', params: { section: 'add', returnTo } };
}

export function readStatusLabel(status: ReadingStatus) {
  if (status === 'currently_reading') return 'Currently reading';
  if (status === 'finished') return 'Finished';
  return 'Want to read';
}

export function searchReadItems(items: GrowthItem[], query: string) {
  const value = query.trim().toLocaleLowerCase();
  if (!value) return items;
  return items.filter((item) => [item.title, item.author, item.genre, item.notes].some((part) => part.toLocaleLowerCase().includes(value)));
}

export function readPeriodLabel(period: ProgressPeriod) {
  if (period === 'day') return 'Today';
  if (period === 'month') return 'This month';
  return 'This week';
}

export function readKindLabel(kind: ReadingKind | null) {
  return kind === 'article' ? 'Article' : 'Book';
}

export function formatReadMinutes(seconds: number) {
  if (seconds > 0 && seconds < 60) return `${Math.floor(seconds)}s`;
  const minutes = Math.floor(Math.max(0, seconds) / 60);
  const hours = Math.floor(minutes / 60);
  return hours ? `${hours}h ${minutes % 60 ? `${minutes % 60}m` : ''}` : `${minutes}m`;
}

export function startOfReadWeekKey(dateKey: string) {
  const date = new Date(`${dateKey}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() - date.getUTCDay());
  return date.toISOString().slice(0, 10);
}

export function addReadDateDays(dateKey: string, amount: number) {
  const date = new Date(`${dateKey}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + amount);
  return date.toISOString().slice(0, 10);
}

export function formatReadClock(value: string) {
  return new Date(value).toLocaleTimeString(getAppLocale(), { hour: 'numeric', minute: '2-digit' });
}
