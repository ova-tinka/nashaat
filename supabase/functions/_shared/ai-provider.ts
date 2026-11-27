export type AiJsonCompletionRequest = {
  schemaName: string;
  schema: Record<string, unknown>;
  systemPrompt: string;
  userPrompt: string;
  maxTokens: number;
  temperature: number;
  timeoutMs?: number;
};

export interface AiJsonProvider {
  completeJson(request: AiJsonCompletionRequest): Promise<unknown>;
}

export async function readLimitedJson(response: Response, maxBytes = 32768): Promise<unknown> {
  if (!response.body) throw new Error('Provider response unavailable');
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const item = await reader.read();
    if (item.done) break;
    size += item.value.length;
    if (size > maxBytes) {
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

export function createFireworksJsonProvider(options: {
  apiKey: string;
  model: string;
  fetchImpl?: typeof fetch;
}): AiJsonProvider {
  const fetchImpl = options.fetchImpl ?? fetch;
  return {
    async completeJson(request) {
      const response = await fetchImpl('https://api.fireworks.ai/inference/v1/chat/completions', {
        method: 'POST',
        headers: {
          authorization: `Bearer ${options.apiKey}`,
          'content-type': 'application/json',
        },
        signal: AbortSignal.timeout(request.timeoutMs ?? 20_000),
        body: JSON.stringify({
          model: options.model,
          max_tokens: request.maxTokens,
          temperature: request.temperature,
          ...(options.model === 'accounts/fireworks/models/nemotron-lightning-3p5-30b-a3b'
            ? { chat_template_kwargs: { enable_thinking: false } }
            : {}),
          response_format: {
            type: 'json_schema',
            json_schema: { name: request.schemaName, schema: request.schema },
          },
          messages: [
            { role: 'system', content: request.systemPrompt },
            { role: 'user', content: request.userPrompt },
          ],
        }),
      });
      if (!response.ok) throw new Error('Provider unavailable');
      const payload = (await readLimitedJson(response)) as {
        choices?: { finish_reason?: string; message?: { content?: unknown } }[];
      };
      const choice = payload.choices?.[0];
      if (!choice || choice.finish_reason === 'length' || typeof choice.message?.content !== 'string') {
        throw new Error('Invalid provider response');
      }
      return JSON.parse(choice.message.content);
    },
  };
}
