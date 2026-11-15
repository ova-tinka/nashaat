import { fireworksRequest } from './fireworks-request.ts';

Deno.test('Fireworks request uses the documented schema format and supplies it to the model', () => {
  const payload = fireworksRequest('accounts/fireworks/models/example', 'weekly', { plans: [] }, 'Review my week');
  const format = payload.response_format;
  if (format.type !== 'json_schema' || format.json_schema.name !== 'bloom_coach_response') {
    throw new Error('Structured output format is invalid');
  }
  const schema = format.json_schema.schema;
  if (!schema.required.includes('reply') || !schema.required.includes('proposal')
    || !payload.messages[0].content.includes(JSON.stringify(schema))) {
    throw new Error('Response schema is missing from the request or model instructions');
  }
  const request = JSON.parse(payload.messages[1].content);
  if (request.kind !== 'weekly' || request.request !== 'Review my week' || !Array.isArray(request.context.plans)) {
    throw new Error('Coach request context was not preserved');
  }
});

Deno.test('Nemotron requests disable thinking without changing other model requests', () => {
  const nemotron = fireworksRequest('accounts/fireworks/models/nemotron-lightning-3p5-30b-a3b', 'chat', {}, 'Hello');
  const other = fireworksRequest('accounts/fireworks/models/example', 'chat', {}, 'Hello');
  if (nemotron.chat_template_kwargs?.enable_thinking !== false || other.chat_template_kwargs !== undefined) {
    throw new Error('Model-specific reasoning configuration is incorrect');
  }
});
