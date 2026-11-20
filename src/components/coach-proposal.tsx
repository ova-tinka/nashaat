import { useState } from 'react';
import { Body, Button, Label, Panel } from './bloom-ui';
import { formatScheduledDays, SCHEDULE_DAYS, type Exercise } from '../lib/bloom';
import type { CoachProposal } from '../lib/coach';

export function CoachProposalCard({ proposal, catalog, canApprove, busy, onDecision, requireConfirmation = false, subjectLabel = 'this profile' }: {
  proposal: CoachProposal; catalog: Exercise[]; canApprove: boolean; busy: boolean; onDecision: (approve: boolean) => void; requireConfirmation?: boolean; subjectLabel?: string;
}) {
  const [pendingDecision, setPendingDecision] = useState<boolean | null>(null);
  const plan = proposal.proposal;
  const restDays = SCHEDULE_DAYS.filter((day) => !plan.scheduled_days.includes(day.iso)).map((day) => day.label);
  return <Panel>
    <Label>{plan.title} · {proposal.status}</Label>
    <Body>{plan.explanation}</Body>
    <Body>{plan.plan_id ? 'Changes an existing plan' : 'Creates a new plan'} · {formatScheduledDays(plan.scheduled_days)}</Body>
    <Body>Planned recovery: {restDays.length ? restDays.join(' · ') : 'No full rest day in this proposal. Edit the schedule to leave room for recovery.'}</Body>
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
      {requireConfirmation && canApprove ? pendingDecision === null ? <>
        <Button label="Review approval" onPress={() => setPendingDecision(true)} disabled={busy} />
        <Button label="Review rejection" variant="secondary" onPress={() => setPendingDecision(false)} disabled={busy} />
      </> : <>
        <Body>Confirm {pendingDecision ? 'applying' : 'rejecting'} “{plan.title}” for {subjectLabel}? The server records this proposal decision.</Body>
        <Button label={pendingDecision ? 'Confirm and apply plan' : 'Confirm rejection'} variant={pendingDecision ? 'primary' : 'destructive'} onPress={() => { const decision = pendingDecision; setPendingDecision(null); onDecision(decision); }} busy={busy} />
        <Button label="Cancel" variant="secondary" onPress={() => setPendingDecision(null)} disabled={busy} />
      </> : <>
        {canApprove && <Button label="Approve and apply" onPress={() => onDecision(true)} busy={busy} />}
        <Button label="Reject proposal" secondary onPress={() => onDecision(false)} disabled={busy} />
      </>}
    </>}
  </Panel>;
}
