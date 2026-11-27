import { coachAccess } from '../_shared/coach-access.ts';
import { studyTutorHandler, studyTutorInstructions, studyTutorSchema } from '../_shared/study-tutor.ts';
import { admin, authenticateActiveUser, userClient } from '../_shared/supabase.ts';

const model = Deno.env.get('FIREWORKS_MODEL') ?? '';
const apiKey = Deno.env.get('FIREWORKS_API_KEY') ?? '';
const testMode = Deno.env.get('BLOOM_COACH_TEST_MODE') === 'true';
const access = coachAccess({
  enabled: Deno.env.get('BLOOM_COACH_ENABLED') === 'true',
  providerApproved: Deno.env.get('FIREWORKS_DATA_SHARING_APPROVED') === 'true',
  modelVerified: Deno.env.get('FIREWORKS_MODEL_VERIFIED') === 'true',
  model,
  apiKeyPresent: Boolean(apiKey),
  testMode,
  testUserId: Deno.env.get('BLOOM_COACH_TEST_USER_ID') ?? '',
  testExpiresAt: Deno.env.get('BLOOM_COACH_TEST_EXPIRES_AT') ?? '',
});
const minorsApproved = Deno.env.get('BLOOM_MINOR_COACH_APPROVED') === 'true';

async function limitedJson(response: Response): Promise<unknown> {
  if (!response.body) throw new Error('Provider response unavailable');
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const item = await reader.read();
    if (item.done) break;
    size += item.value.length;
    if (size > 32768) {
      await reader.cancel();
      throw new Error('Provider response too large');
    }
    chunks.push(item.value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  return JSON.parse(new TextDecoder().decode(bytes));
}

Deno.serve(studyTutorHandler({
  enabled: access.enabled,
  minorsApproved,
  async authenticate(token) {
    const active = await authenticateActiveUser(token);
    return Boolean(active) && access.permits(active!.user.id);
  },
  async begin(token, requestId, itemId, prompt) {
    const { data, error } = await userClient(token).rpc('bloom_begin_study_tutor_request', {
      p_request_id: requestId,
      p_item_id: itemId,
      p_prompt: prompt,
    });
    return { data, errorMessage: error?.message };
  },
  async loadMemory(token) {
    const { data, error } = await userClient(token).rpc('bloom_growth_ai_memory_context', { p_module_id: 'study' });
    if (error) throw new Error('Could not read shared memory');
    return data;
  },
  async finish(requestId, prompt, answer, uncertainty) {
    const { data, error } = await admin.rpc('bloom_finish_study_tutor_request', {
      p_request_id: requestId,
      p_prompt: prompt,
      p_answer: answer,
      p_uncertainty: uncertainty,
    });
    if (error) throw new Error('Could not save the tutor conversation');
    return (data ?? { status: 'answered' }) as { status?: unknown };
  },
  async fail(requestId) {
    await admin.rpc('bloom_fail_growth_ai_request', { p_request_id: requestId });
  },
  async generate(userData) {
    const response = await fetch('https://api.fireworks.ai/inference/v1/chat/completions', {
      method: 'POST',
      headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
      signal: AbortSignal.timeout(20000),
      body: JSON.stringify({
        model,
        max_tokens: 1200,
        temperature: 0.25,
        ...(model === 'accounts/fireworks/models/nemotron-lightning-3p5-30b-a3b'
          ? { chat_template_kwargs: { enable_thinking: false } }
          : {}),
        response_format: { type: 'json_schema', json_schema: { name: 'bloom_study_tutor', schema: studyTutorSchema } },
        messages: [
          { role: 'system', content: `${studyTutorInstructions}\nSchema: ${JSON.stringify(studyTutorSchema)}` },
          { role: 'user', content: userData },
        ],
      }),
    });
    if (!response.ok) throw new Error('Provider unavailable');
    const payload = await limitedJson(response) as {
      choices?: { finish_reason?: string; message?: { content?: unknown } }[];
    };
    const choice = payload.choices?.[0];
    if (!choice || choice.finish_reason === 'length' || typeof choice.message?.content !== 'string') {
      throw new Error('Invalid provider response');
    }
    return JSON.parse(choice.message.content);
  },
}));
