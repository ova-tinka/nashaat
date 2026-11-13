import { body, preliminary, reply } from './child-pairing.ts';

type Item = Record<string, unknown>;
type Context = { is_child: boolean; [key: string]: unknown };
export type CoachDependencies = {
  enabled: boolean;
  minorsApproved: boolean;
  authenticate: (token: string) => Promise<boolean>;
  begin: (token: string, id: string, kind: string, prompt: string) => Promise<{ status: string; context?: Context }>;
  finish: (id: string, message: string, proposal: Item | null) => Promise<void>;
  fail: (id: string) => Promise<void>;
  generate: (input: { context: Item; prompt: string; kind: string }) => Promise<unknown>;
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const harm = /\b(pain|painful|painkillers?|hurts?|sore(?:ness)?|aches?|aching|injur(?:y|ed|ies)|chest\s+(?:tightness|pressure)|faint(?:ing|ed)?|dizz(?:y|iness)|shortness\s+of\s+breath|suicid\w*|self[ -]?harm|kill\s+myself|overdos\w*|starv\w*|purge|dehydrat\w*|steroids?|exercise\s+through\s+pain|push\s+through\s+pain)\b|(?:^|[^\p{L}\p{M}])(?:ألم|الم|وجع|إصابة|اصابة|دوخة|انتحار)(?=$|[^\p{L}\p{M}])|أؤذي نفسي/iu;
const identifiers = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b|(?:\+?\d[\s().-]*){8,}|\b(?:medical\s+record|patient\s+id|date\s+of\s+birth|home\s+address)\b/i;
const dangerousOutput = /\b(?:ignore|push\s+through|train\s+through)\s+(?:the\s+)?pain\b|\b(?:skip\s+meals|starve\s+yourself|dehydrate\s+yourself|take\s+steroids)\b/i;
function object(value: unknown): Item | null { return value !== null && typeof value === 'object' && !Array.isArray(value) ? value as Item : null; }
function array(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }

// Replace persistent database IDs with request-local aliases before disclosure.
function anonymize(context: Context) {
  const exercises = new Map<string, { alias: string; measurement: string }>();
  const plans = new Map<string, string>();
  const addExercise = (id: unknown, measurement: unknown) => {
    if (typeof id !== 'string' || !uuid.test(id) || typeof measurement !== 'string') throw new Error('Invalid exercise context');
    if (!exercises.has(id)) exercises.set(id, { alias: `exercise_${exercises.size + 1}`, measurement });
    return exercises.get(id)!.alias;
  };
  const catalog = array(context.catalog).map((value) => {
    const item = object(value); if (!item) throw new Error('Invalid catalog');
    return { ref: addExercise(item.id, item.measurement_type), name: item.name, measurement_type: item.measurement_type };
  });
  const cleanPlans = array(context.plans).map((value) => {
    const plan = object(value); if (!plan || typeof plan.id !== 'string' || !uuid.test(plan.id)) throw new Error('Invalid plan');
    const ref = `plan_${plans.size + 1}`; plans.set(plan.id, ref);
    return { ref, title: plan.title, scheduled_days: plan.scheduled_days, exercises: array(plan.exercises).map((value) => {
      const item = object(value); if (!item) throw new Error('Invalid plan exercise');
      return { ref: addExercise(item.exercise_id, item.measurement_type), name: item.name, measurement_type: item.measurement_type,
        sets: item.sets, target: item.target, weight_kg: item.weight_kg, distance_km: item.distance_km };
    }) };
  });
  return { context: { is_child: context.is_child, goals: context.goals, experience: context.experience,
    equipment: context.equipment, plans: cleanPlans, recent_workouts: context.recent_workouts, catalog, conversation: context.conversation }, exercises, plans };
}

function normalizeOutput(output: unknown, maps: ReturnType<typeof anonymize>, child: boolean): { message: string; proposal: Item | null } {
  const value = object(output);
  if (!value || typeof value.reply !== 'string' || !value.reply.trim() || value.reply.length > 4000
    || dangerousOutput.test(value.reply) || harm.test(value.reply) || identifiers.test(value.reply)) throw new Error('Invalid coach reply');
  if (value.proposal === null) return { message: value.reply.trim(), proposal: null };
  const proposal = object(value.proposal);
  if (!proposal || typeof proposal.title !== 'string' || !proposal.title.trim() || proposal.title.trim().length > 100
    || typeof proposal.explanation !== 'string' || !proposal.explanation.trim() || proposal.explanation.length > 1000
    || dangerousOutput.test(JSON.stringify(proposal)) || harm.test(JSON.stringify(proposal)) || identifiers.test(JSON.stringify(proposal))) throw new Error('Invalid proposal');
  const planId = proposal.plan_ref === null ? null : [...maps.plans].find(([, alias]) => alias === proposal.plan_ref)?.[0];
  if (proposal.plan_ref !== null && !planId) throw new Error('Unknown plan');
  const days = array(proposal.scheduled_days);
  if (days.length > 7 || days.some((day) => !Number.isInteger(day) || Number(day) < 1 || Number(day) > 7) || new Set(days).size !== days.length) throw new Error('Invalid schedule');
  const inputs = array(proposal.exercises);
  if (!inputs.length || inputs.length > 20) throw new Error('Invalid exercises');
  const seen = new Set<string>();
  const exercises = inputs.map((value) => {
    const item = object(value); if (!item || !Number.isInteger(item.sets) || Number(item.sets) < 1 || Number(item.sets) > 5
      || !Number.isInteger(item.target) || Number(item.target) < 1) throw new Error('Invalid targets');
    const existing = typeof item.exercise_ref === 'string' ? [...maps.exercises].find(([, info]) => info.alias === item.exercise_ref) : undefined;
    const custom = item.custom === null ? null : object(item.custom);
    if (Boolean(existing) === Boolean(custom)) throw new Error('Invalid exercise choice');
    let measurement: string;
    let customValue: Item | null = null;
    if (existing) {
      if (seen.has(existing[0])) throw new Error('Duplicate exercise');
      seen.add(existing[0]); measurement = existing[1].measurement;
    } else {
      if (!custom || typeof custom.name !== 'string' || !custom.name.trim() || custom.name.length > 100
        || typeof custom.description !== 'string' || custom.description.length > 1000
        || typeof custom.measurement_type !== 'string') throw new Error('Invalid custom exercise');
      measurement = custom.measurement_type;
      customValue = { name: custom.name.trim(), description: custom.description.trim(), measurement_type: measurement };
    }
    if (!['reps_only', 'reps_weight', 'time_only', 'time_distance'].includes(measurement)) throw new Error('Invalid measurement');
    const limit = measurement.startsWith('reps') ? (child ? 50 : 200) : (child ? 1800 : 3600);
    if (Number(item.target) > limit) throw new Error('Target outside coaching limits');
    const weight = item.weight_kg;
    const distance = item.distance_km;
    if (weight !== null && (typeof weight !== 'number' || !Number.isFinite(weight) || weight < 0 || weight > 100
      || measurement !== 'reps_weight' || (child && weight > 0))) throw new Error('Invalid weight');
    if (distance !== null && (typeof distance !== 'number' || !Number.isFinite(distance) || distance <= 0 || distance > (child ? 10 : 100)
      || measurement !== 'time_distance')) throw new Error('Invalid distance');
    return { exercise_id: existing?.[0] ?? null, custom: customValue, sets: item.sets, target: item.target, weight_kg: weight, distance_km: distance };
  });
  return { message: value.reply.trim(), proposal: { title: proposal.title.trim(), explanation: proposal.explanation.trim(),
    plan_id: planId ?? null, scheduled_days: days, exercises } };
}

export function coachHandler(deps: CoachDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request); if (early) return early;
    const token = /^Bearer\s+(\S+)$/i.exec(request.headers.get('authorization') ?? '')?.[1];
    if (!token) return reply(401, { error: 'Sign in required' });
    const input = await body(request, 10000);
    const id = typeof input?.request_id === 'string' ? input.request_id : '';
    const kind = typeof input?.kind === 'string' ? input.kind : '';
    const prompt = typeof input?.prompt === 'string' ? input.prompt.trim() : '';
    if (!uuid.test(id) || !['chat', 'weekly'].includes(kind) || !prompt || prompt.length > 2000) return reply(400, { error: 'Invalid coaching request' });
    if (!deps.enabled) return reply(503, { error: 'Coaching is not available yet.' });
    let started = false;
    try {
      if (!await deps.authenticate(token)) return reply(401, { error: 'Sign in required' });
      const startedRequest = await deps.begin(token, id, kind, prompt);
      if (startedRequest.status === 'completed') return reply(200, { status: 'completed' });
      if (startedRequest.status !== 'pending' || !startedRequest.context) return reply(409, { error: 'This request has already been processed.' });
      started = true;
      if (typeof startedRequest.context.is_child !== 'boolean') throw new Error('Invalid context');
      if (startedRequest.context.is_child && !deps.minorsApproved) {
        await deps.fail(id); started = false;
        return reply(403, { error: 'Coaching for children is not available yet.' });
      }
      const prepared = anonymize(startedRequest.context);
      const text = `${prompt}\n${JSON.stringify(prepared.context)}`;
      if (harm.test(text) || identifiers.test(text)) {
        const safe = harm.test(text)
          ? 'Stop the activity if you have pain, feel faint, or may be injured. Tell a trusted adult if you are a child, and seek help from a qualified health professional. If you are in immediate danger, contact local emergency services.'
          : 'Please remove names, contact details, medical records, and other identifying information before asking the coach.';
        await deps.finish(id, safe, null); started = false;
        return reply(200, { status: 'completed' });
      }
      const result = normalizeOutput(await deps.generate({ context: prepared.context, prompt, kind }), prepared, startedRequest.context.is_child);
      await deps.finish(id, result.message, result.proposal); started = false;
      return reply(200, { status: 'completed' });
    } catch {
      if (started) { try { await deps.fail(id); } catch { /* A pending request expires without retrying the provider. */ } }
      return reply(503, { error: 'Could not complete coaching. Please try again later.' });
    }
  };
}
