import { coachHandler, CoachProviderError } from '../_shared/coach.ts';
import { fireworksRequest } from '../_shared/fireworks-request.ts';
import { coachAccess } from '../_shared/coach-access.ts';
import { admin, userClient } from '../_shared/supabase.ts';

const model = Deno.env.get('FIREWORKS_MODEL') ?? '';
const apiKey = Deno.env.get('FIREWORKS_API_KEY') ?? '';
const testMode = Deno.env.get('BLOOM_COACH_TEST_MODE') === 'true';
const access = coachAccess({ enabled: Deno.env.get('BLOOM_COACH_ENABLED') === 'true',
  providerApproved: Deno.env.get('FIREWORKS_DATA_SHARING_APPROVED') === 'true',
  modelVerified: Deno.env.get('FIREWORKS_MODEL_VERIFIED') === 'true', model, apiKeyPresent: Boolean(apiKey),
  testMode, testUserId: Deno.env.get('BLOOM_COACH_TEST_USER_ID') ?? '',
  testExpiresAt: Deno.env.get('BLOOM_COACH_TEST_EXPIRES_AT') ?? '' });
const minorsApproved = !testMode && Deno.env.get('BLOOM_MINOR_COACH_APPROVED') === 'true';

async function limitedJson(response: Response): Promise<unknown> {
  if (!response.body) throw new Error('Provider response unavailable');
  const reader = response.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
  while (true) {
    const item = await reader.read(); if (item.done) break;
    size += item.value.length;
    if (size > 65536) { await reader.cancel(); throw new Error('Provider response too large'); }
    chunks.push(item.value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return JSON.parse(new TextDecoder().decode(bytes));
}

Deno.serve(coachHandler({
  enabled: access.enabled, minorsApproved, testDiagnostics: testMode,
  async authenticate(token) {
    const { data, error } = await userClient().auth.getUser(token);
    return !error && Boolean(data.user && access.permits(data.user.id));
  },
  async begin(token, id, kind, prompt) {
    const { data, error } = await userClient(token).rpc('bloom_begin_coach_request', { p_request_id: id, p_kind: kind, p_prompt: prompt });
    if (error || !data || typeof data.status !== 'string') throw new Error('Coaching request unavailable');
    return data;
  },
  async finish(id, message, proposal) {
    const { error } = await admin.rpc('bloom_finish_coach_request', { p_request_id: id, p_reply: message, p_proposal: proposal });
    if (error) throw new Error('Could not save coaching response');
  },
  async fail(id) { await admin.rpc('bloom_fail_coach_request', { p_request_id: id }); },
  async generate({ context, prompt, kind }) {
    let response: Response;
    try {
      response = await fetch('https://api.fireworks.ai/inference/v1/chat/completions', {
        method: 'POST', headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
        signal: AbortSignal.timeout(20000),
        body: JSON.stringify(fireworksRequest(model, kind, context, prompt)),
      });
    } catch (error) {
      throw new CoachProviderError(error instanceof Error && ['TimeoutError', 'AbortError'].includes(error.name) ? 'timeout' : 'network');
    }
    if (!response.ok) throw new CoachProviderError('http', response.status);
    let data: { choices?: { finish_reason?: string; message?: { content?: unknown } }[] };
    try { data = await limitedJson(response) as typeof data; }
    catch { throw new CoachProviderError('response_body'); }
    const choice = data.choices?.[0];
    if (choice?.finish_reason === 'length') throw new CoachProviderError('truncated');
    if (!choice || typeof choice.message?.content !== 'string' || choice.message.content.length > 20000) throw new CoachProviderError('invalid_content');
    try { return JSON.parse(choice.message.content); }
    catch { throw new CoachProviderError('response_json'); }
  },
}));
