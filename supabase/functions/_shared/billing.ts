export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error('Billing provider is unavailable');
  return value;
}

export function record(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, unknown> : {};
}

export function str(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

export function secureMatch(left: string, right: string): boolean {
  if (left.length !== right.length || left.length === 0) return false;
  let difference = 0;
  for (let index = 0; index < left.length; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

export function json(body: unknown, status = 200, headers?: HeadersInit): Response {
  const result = new Headers(headers);
  result.set('content-type', 'application/json');
  result.set('cache-control', 'no-store');
  return new Response(JSON.stringify(body), { status, headers: result });
}

export async function providerFetch(url: string, key: string, method = 'GET', data?: unknown) {
  return fetch(url, {
    method,
    headers: { authorization: `Bearer ${key}`, accept: 'application/json', 'content-type': 'application/json' },
    body: data === undefined ? undefined : JSON.stringify(data),
    signal: AbortSignal.timeout(12_000),
    redirect: 'error',
  });
}
