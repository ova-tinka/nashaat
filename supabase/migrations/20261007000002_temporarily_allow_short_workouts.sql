-- Temporary test-mode relaxation: allow completion immediately after a workout
-- starts. This removes only the five-minute rejection in the authoritative
-- completion RPC; all server-side plan, ownership, idempotency, and reward
-- checks remain in place. Add a follow-up migration to restore the gate.

BEGIN;

DO $migration$
DECLARE
  v_definition TEXT;
  v_gate TEXT := E'    IF v_duration_minutes < 5 THEN\n'
      || E'        RAISE EXCEPTION ''A workout must last at least 5 minutes.'';\n'
      || E'    END IF;\n';
BEGIN
  SELECT pg_get_functiondef(
    'public.complete_workout_session(uuid,jsonb,text)'::regprocedure
  )
  INTO v_definition;

  IF position(v_gate IN v_definition) = 0 THEN
    RAISE EXCEPTION 'Expected five-minute workout gate was not found';
  END IF;

  EXECUTE replace(v_definition, v_gate, '');
END;
$migration$;

COMMIT;
