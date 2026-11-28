function runtimePlatform(): string {
  if (typeof navigator !== 'undefined' && navigator.product === 'ReactNative') {
    const ua = typeof navigator.userAgent === 'string' ? navigator.userAgent : '';
    return /android/i.test(ua) ? 'android' : 'ios';
  }
  if (typeof document !== 'undefined') return 'web';
  return 'node';
}

export type SentryContext = Record<string, string | number | boolean | null | undefined>;

export type ParsedSentryDsn = {
  endpoint: string;
  publicKey: string;
  projectId: string;
};

const SENSITIVE_KEY_PATTERN = /pass(word)?|token|secret|authorization|cookie|credential|api[-_]?key|prompt|content|transcript|document|email/i;
const EMAIL_VALUE_PATTERN = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const BEARER_VALUE_PATTERN = /\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi;

let initialized = false;
let currentProfileId: string | null = null;
let isChildAccount = false;

export function parseSentryDsn(dsn: string | undefined | null): ParsedSentryDsn | null {
  if (!dsn || typeof dsn !== 'string') return null;
  const trimmed = dsn.trim();
  if (!trimmed) return null;
  try {
    const url = new URL(trimmed);
    if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;
    const publicKey = url.username;
    const segments = url.pathname.split('/').filter(Boolean);
    const projectId = segments.pop();
    if (!publicKey || !projectId || !/^\d+$/.test(projectId)) return null;
    const prefix = segments.length > 0 ? `/${segments.join('/')}` : '';
    return {
      endpoint: `${url.origin}${prefix}/api/${projectId}/envelope/`,
      publicKey,
      projectId,
    };
  } catch {
    return null;
  }
}

export function scrubString(value: string): string {
  return value
    .replace(BEARER_VALUE_PATTERN, 'Bearer [REDACTED]')
    .replace(EMAIL_VALUE_PATTERN, '[REDACTED_EMAIL]');
}

export function scrubSensitiveData(input: Record<string, unknown> | undefined | null): Record<string, unknown> {
  if (!input || typeof input !== 'object') return {};
  const cleaned: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(input)) {
    if (SENSITIVE_KEY_PATTERN.test(key)) {
      cleaned[key] = '[REDACTED]';
    } else if (typeof value === 'string') {
      cleaned[key] = scrubString(value).slice(0, 500);
    } else if (typeof value === 'number' || typeof value === 'boolean' || value === null) {
      cleaned[key] = value;
    }
  }
  return cleaned;
}

export function getSentryEnvironment(): string {
  const configured = process.env.EXPO_PUBLIC_APP_ENV?.trim();
  if (configured) return configured;
  return typeof __DEV__ !== 'undefined' && __DEV__ ? 'development' : 'production';
}

export function setSentryUser(profileId: string | null, options?: { childProfile?: boolean }) {
  currentProfileId = profileId;
  isChildAccount = Boolean(options?.childProfile);
}

export function initSentry() {
  if (initialized) return;
  initialized = true;
  if (runtimePlatform() === 'web' && typeof window !== 'undefined' && typeof window.addEventListener === 'function') {
    window.addEventListener('error', (event) => {
      if (event.error) captureException(event.error, { source: 'window.onerror' });
    });
    window.addEventListener('unhandledrejection', (event) => {
      captureException(event.reason ?? new Error('Unhandled promise rejection'), { source: 'unhandledrejection' });
    });
  }
}

async function sendEnvelope(event: Record<string, unknown>): Promise<boolean> {
  const parsed = parseSentryDsn(process.env.EXPO_PUBLIC_SENTRY_DSN);
  if (!parsed || typeof fetch !== 'function') return false;

  const sentAt = new Date().toISOString();
  const envelopeHeader = JSON.stringify({
    event_id: event.event_id,
    sent_at: sentAt,
    dsn: process.env.EXPO_PUBLIC_SENTRY_DSN?.trim(),
  });
  const itemHeader = JSON.stringify({ type: 'event', content_type: 'application/json' });
  const body = `${envelopeHeader}\n${itemHeader}\n${JSON.stringify(event)}`;

  const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
  const timeout = controller ? setTimeout(() => controller.abort(), 4000) : null;
  try {
    const response = await fetch(parsed.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-sentry-envelope',
        'X-Sentry-Auth': `Sentry sentry_version=7, sentry_client=bloom-js/1.0, sentry_key=${parsed.publicKey}`,
      },
      body,
      signal: controller?.signal,
    });
    return response.ok;
  } catch {
    return false;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}

function makeEventId(): string {
  const hex = '0123456789abcdef';
  let id = '';
  for (let i = 0; i < 32; i++) id += hex[Math.floor(Math.random() * 16)];
  return id;
}

export function captureException(error: unknown, context?: SentryContext) {
  const err = error instanceof Error ? error : new Error(typeof error === 'string' ? error : 'Unknown error');
  const payload: Record<string, unknown> = {
    event_id: makeEventId(),
    timestamp: Date.now() / 1000,
    level: 'error',
    platform: 'javascript',
    environment: getSentryEnvironment(),
    release: 'bloom@0.1.1',
    tags: { os: runtimePlatform() },
    extra: scrubSensitiveData(context),
    exception: {
      values: [
        {
          type: err.name || 'Error',
          value: scrubString(err.message || 'Unknown error').slice(0, 500),
        },
      ],
    },
  };
  if (currentProfileId && !isChildAccount) {
    payload.user = { id: currentProfileId };
  }
  void sendEnvelope(payload);
}

export function captureMessage(message: string, level: 'info' | 'warning' | 'error' = 'info', context?: SentryContext) {
  const payload: Record<string, unknown> = {
    event_id: makeEventId(),
    timestamp: Date.now() / 1000,
    level,
    platform: 'javascript',
    environment: getSentryEnvironment(),
    release: 'bloom@0.1.1',
    tags: { os: runtimePlatform() },
    message: { formatted: scrubString(message).slice(0, 500) },
    extra: scrubSensitiveData(context),
  };
  if (currentProfileId && !isChildAccount) {
    payload.user = { id: currentProfileId };
  }
  void sendEnvelope(payload);
}

export async function sendSentryTestEvent(): Promise<boolean> {
  const payload: Record<string, unknown> = {
    event_id: makeEventId(),
    timestamp: Date.now() / 1000,
    level: 'info',
    platform: 'javascript',
    environment: getSentryEnvironment(),
    release: 'bloom@0.1.1',
    tags: { os: runtimePlatform(), synthetic_test: 'true' },
    message: { formatted: 'Bloom Sentry verification check' },
  };
  if (currentProfileId && !isChildAccount) {
    payload.user = { id: currentProfileId };
  }
  return sendEnvelope(payload);
}
