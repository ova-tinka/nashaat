import type { ModuleKey } from '../theme';

const guardianOnlyRoutes = ['/family', '/family-child', '/child-coaching', '/child-competitions'] as const;

export function isFamilySpaceRoute(pathname: string) {
  return guardianOnlyRoutes.some((route) => pathname === route || pathname.startsWith(`${route}/`));
}

export function moduleForPath(pathname: string): ModuleKey | null {
  const appModule = pathname.match(/^\/(?:apps\/)?(exercise|study|read|tasks)(?:\/|$)/)?.[1];
  if (appModule) return appModule as ModuleKey;
  if (['/workouts', '/library', '/new-plan', '/coach', '/competitions'].some((route) => pathname === route || pathname.startsWith(`${route}/`))) return 'exercise';
  if (pathname.startsWith('/exercise/')) return 'exercise';
  return null;
}

export function isChildRestrictedRoute(pathname: string, childProfile: boolean, assignedModules: readonly ModuleKey[] = []) {
  if (!childProfile) return false;
  if (guardianOnlyRoutes.some((route) => pathname === route || pathname.startsWith(`${route}/`))) return true;
  // Existing sessions remain reachable so a child can safely finish work
  // started before a guardian changed assignments. Starting new work is gated
  // by the server-side assignment check.
  if (pathname === '/session' || pathname.startsWith('/session/')) return false;
  const requiredModule = moduleForPath(pathname);
  return requiredModule !== null && !assignedModules.includes(requiredModule);
}
