const SENSITIVE_KEY = /pass(word)?|token|secret|authorization|cookie|credential|api[-_]?key|prompt|content|email/i;
const EMAIL_VALUE = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}/gi;
const BEARER_VALUE = /\bBearer\s+[A-Za-z0-9._~+/-]+=*/gi;

function scrub(text: string): string {
  return text.replace(BEARER_VALUE, 'Bearer [REDACTED]').replace(EMAIL_VALUE, '[REDACTED_EMAIL]').slice(0, 500);
}

export async function reportEdgeException(functionName: string, error: unknown, extra?: Record<string, unknown>): Promise<void> {
  const dsn = Deno.env.get('BLOOM_SENTRY_DSN')?.trim();
  if (!dsn) return;
  let endpoint: string;
  let publicKey: string;
  try {
    const url = new URL(dsn);
    const segments = url.pathname.split('/').filter(Boolean);
    const projectId = segments.pop();
    if (!url.username || !projectId) return;
    publicKey = url.username;
    const prefix = segments.length > 0 ? `/${segments.join('/')}` : '';
    endpoint = `${url.origin}${prefix}/api/${projectId}/envelope/`;
  } catch {
    return;
  }

  const cleanedExtra: Record<string, unknown> = {};
  if (extra) {
    for (const [key, value] of Object.entries(extra)) {
      cleanedExtra[key] = SENSITIVE_KEY.test(key)
        ? '[REDACTED]'
        : typeof value === 'string'
        ? scrub(value)
        : value;
    }
  }

  const err = error instanceof Error ? error : new Error(typeof error === 'string' ? error : 'Edge error');
  const eventId = crypto.randomUUID().replaceAll('-', '');
  const payload = {
    event_id: eventId,
    timestamp: Date.now() / 1000,
    level: 'error',
    platform: 'javascript',
    environment: Deno.env.get('BLOOM_BILLING_ENVIRONMENT')?.trim() || 'production',
    tags: { edge_function: functionName },
    extra: cleanedExtra,
    exception: {
      values: [{ type: err.name || 'Error', value: scrub(err.message || 'Edge error') }],
    },
  };
  const body = `${JSON.stringify({ event_id: eventId, sent_at: new Date().toISOString(), dsn })}\n${JSON.stringify({ type: 'event' })}\n${JSON.stringify(payload)}`;

  await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-sentry-envelope',
      'X-Sentry-Auth': `Sentry sentry_version=7, sentry_client=bloom-edge/1.0, sentry_key=${publicKey}`,
    },
    body,
    signal: AbortSignal.timeout(3000),
  }).catch(() => undefined);
}
