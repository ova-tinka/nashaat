export function formatDiagnosticFailure(error: unknown) {
  const record = error && typeof error === 'object' ? error as { code?: unknown; message?: unknown } : null;
  const rawCode = typeof record?.code === 'string' ? record.code : null;
  const code = rawCode && /^[A-Z0-9_]+$/.test(rawCode) ? rawCode : null;
  const rawMessage = typeof record?.message === 'string' ? record.message : 'The request failed without an error message.';
  const message = rawMessage
    .replace(/\bBearer\s+\S+/gi, 'Bearer [redacted]')
    .replace(/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/g, '[redacted token]')
    .replace(/\bsb_(?:publishable|secret)_[A-Za-z0-9_-]+\b/gi, '[redacted key]')
    .replace(/\b(?:api[_-]?key|access[_-]?token|refresh[_-]?token|device[_-]?key)\s*[:=]\s*\S+/gi, '[redacted credential]')
    .replace(/https?:\/\/\S+/gi, '[redacted URL]')
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[redacted email]')
    .replace(/\s+/g, ' ')
    .trim()
    .slice(0, 220);
  return { code, message: message || 'The request failed without an error message.' };
}
