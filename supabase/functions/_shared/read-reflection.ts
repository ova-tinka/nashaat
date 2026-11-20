import { body, preliminary, reply } from './child-pairing.ts';

type Item = Record<string, unknown>;
type Result = { prompt: string; uncertainty: string };
type Context = { is_child: boolean; reading: { title: string; notes: string } };
type BeginResult = { status: string; response?: unknown; is_child?: unknown; reading?: unknown };

export type ReadReflectionDependencies = {
  enabled: boolean;
  minorsApproved: boolean;
  authenticate: (token: string) => Promise<boolean>;
  begin: (token: string, requestId: string, itemId: string) => Promise<BeginResult>;
  loadMemory: (token: string) => Promise<unknown>;
  finish: (requestId: string, prompt: string, uncertainty: string) => Promise<unknown>;
  fail: (requestId: string) => Promise<void>;
  generate: (context: { reading: Context['reading']; shared_memory: Item[] }) => Promise<unknown>;
};

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const identifiers = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|(?:\+?\d[\s().-]*){8,}/i;
const unsafe = /\b(?:suicid\w*|self[ -]?harm|kill myself|overdos\w*)\b/i;
const domains = new Set(['exercise', 'study', 'read', 'tasks']);
export const reflectionUncertainty = 'This prompt uses your reading title and notes; it is not a reading assessment.';

function object(value: unknown): Item | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Item : null;
}

function validResult(value: unknown): Result | null {
  const parsed = object(value);
  if (!parsed || typeof parsed.prompt !== 'string' || parsed.prompt.trim().length < 1
    || parsed.prompt.length > 120 || identifiers.test(parsed.prompt) || unsafe.test(parsed.prompt)) return null;
  return { prompt: parsed.prompt.trim(), uncertainty: reflectionUncertainty };
}

function validContext(value: BeginResult): Context | null {
  if (typeof value.is_child !== 'boolean') return null;
  const reading = object(value.reading);
  if (!reading || typeof reading.title !== 'string' || typeof reading.notes !== 'string'
    || reading.title.length > 120 || reading.notes.length > 1000) return null;
  return { is_child: value.is_child, reading: { title: reading.title, notes: reading.notes } };
}

function cleanMemory(value: unknown): Item[] | null {
  if (!Array.isArray(value) || value.length > 4) return null;
  const result: Item[] = [];
  for (const entry of value) {
    const item = object(entry);
    if (!item || typeof item.domain !== 'string' || !domains.has(item.domain)
      || typeof item.summary !== 'string' || item.summary.length > 1200) return null;
    result.push({ domain: item.domain, summary: item.summary });
  }
  return result;
}

export function readReflectionHandler(deps: ReadReflectionDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    const input = await body(request, 1024);
    const requestId = typeof input?.request_id === 'string' ? input.request_id : '';
    const itemId = typeof input?.item_id === 'string' ? input.item_id : '';
    if (!uuid.test(requestId) || !uuid.test(itemId)) return reply(400, { error: 'Choose a reading item and retry.' });
    if (!deps.enabled) return reply(503, { error: 'Reading reflection prompts are not available yet.' });

    let started = false;
    try {
      if (!await deps.authenticate(token)) return reply(401, { error: 'Sign in required' });
      const begin = await deps.begin(token, requestId, itemId);
      if (begin.status === 'completed') {
        const cached = validResult(begin.response);
        return cached ? reply(200, { status: 'generated', ...cached })
          : reply(409, { error: 'This reflection request is unavailable. Start a new one.' });
      }
      if (begin.status !== 'pending') return reply(409, { error: 'This reflection request has already been processed.' });
      started = true;
      const context = validContext(begin);
      if (!context) throw new Error('Invalid reading context');
      if (context.is_child && !deps.minorsApproved) {
        await deps.fail(requestId); started = false;
        return reply(403, { error: 'AI reading reflections are not available for child profiles yet.' });
      }

      const memory = cleanMemory(await deps.loadMemory(token));
      if (!memory) throw new Error('Invalid shared memory context');
      const userData = JSON.stringify({ reading: context.reading, shared_memory: memory });
      if (identifiers.test(userData) || unsafe.test(userData)) {
        await deps.fail(requestId); started = false;
        return reply(400, { error: 'Remove contact details or sensitive information from reading notes before generating a prompt.' });
      }
      const generated = object(await deps.generate({ reading: context.reading, shared_memory: memory }));
      const result = generated && typeof generated.question === 'string'
        ? validResult({ prompt: generated.question, uncertainty: reflectionUncertainty }) : null;
      if (!result) throw new Error('Invalid reflection prompt');
      const saved = validResult(await deps.finish(requestId, result.prompt, result.uncertainty));
      if (!saved) throw new Error('Could not save reflection prompt');
      started = false;
      return reply(200, { status: 'generated', ...saved });
    } catch {
      if (started) { try { await deps.fail(requestId); } catch { /* Keep prompt content out of logs. */ } }
      return reply(503, { error: 'Could not prepare a reading reflection prompt. Please try again.' });
    }
  };
}
