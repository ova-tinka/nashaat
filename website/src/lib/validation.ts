export const CONSENT_POLICY_VERSION = "2026-11-28-v1";
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/u;

export function normalizeEmail(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 254) return null;
  const normalized = value.trim().normalize("NFKC").toLowerCase();
  if (normalized.length < 3 || !emailPattern.test(normalized) || /[\r\n\u0000-\u001f]/u.test(normalized)) return null;
  return normalized;
}

export function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function boundedText(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.trim();
  if (normalized.length === 0 || normalized.length > max || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/u.test(normalized)) return null;
  return normalized;
}
