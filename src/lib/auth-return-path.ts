export function validateInternalReturnPath(raw: string | null | undefined): string | null {
  if (typeof raw !== 'string') return null;
  const trimmed = raw.trim();
  if (!trimmed.startsWith('/') || trimmed.startsWith('//') || trimmed.length > 512) return null;
  if (/[\x00-\x1f\x7f\\@]/.test(trimmed)) return null;
  if (trimmed === '/sign-in' || trimmed.startsWith('/sign-in?')) return null;
  if (/(?:^|\/)\.\.(?:\/|$)/.test(trimmed)) return null;
  return trimmed;
}

export function buildSignInHref(pathname: string | null | undefined): string {
  const valid = validateInternalReturnPath(pathname);
  if (!valid || valid === '/') return '/sign-in';
  return `/sign-in?next=${encodeURIComponent(valid)}`;
}
