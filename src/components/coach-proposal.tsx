import { Body, Button, Label, Panel } from './bloom-ui';
import { formatScheduledDays, type Exercise } from '../lib/bloom';
import type { CoachProposal } from '../lib/coach';

export function CoachProposalCard({ proposal, catalog, canApprove, busy, onDecision }: {
  proposal: CoachProposal; catalog: Exercise[]; canApprove: boolean; busy: boolean; onDecision: (approve: boolean) => void;
}) {
  const plan = proposal.proposal;
  return <Panel>
    <Label>{plan.title} · {proposal.status}</Label>
    <Body>{plan.explanation}</Body>
    <Body>{plan.plan_id ? 'Changes an existing plan' : 'Creates a new plan'} · {formatScheduledDays(plan.scheduled_days)}</Body>
    {plan.exercises.map((exercise, index) => {
      const existing = catalog.find((item) => item.id === exercise.exercise_id);
      const name = exercise.custom?.name ?? existing?.name ?? 'Exercise';
      const measurement = exercise.custom?.measurement_type ?? existing?.measurement_type;
      const timed = measurement === 'time_only' || measurement === 'time_distance';
      return <Body key={`${proposal.id}-${index}`}>{name}: {exercise.sets} × {exercise.target} {timed ? 'seconds' : 'repetitions'}
        {exercise.weight_kg != null ? ` · ${exercise.weight_kg} kg` : ''}{exercise.distance_km != null ? ` · ${exercise.distance_km} km` : ''}</Body>;
    })}
    {proposal.status === 'pending' && <>
      {!canApprove && <Body>A parent must approve this change.</Body>}
      {canApprove && <Button label="Approve and apply" onPress={() => onDecision(true)} busy={busy} />}
      <Button label="Reject proposal" secondary onPress={() => onDecision(false)} disabled={busy} />
    </>}
  </Panel>;
}
