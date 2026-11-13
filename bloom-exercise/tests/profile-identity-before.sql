-- Representative pre-migration data, created before the identity migration.
insert into auth.users(id) values
 ('00000000-0000-0000-0000-000000000111'),
 ('00000000-0000-0000-0000-000000000112');
insert into public.bloom_settings(user_id) values ('00000000-0000-0000-0000-000000000112');
insert into public.bloom_workout_plans(id, user_id, title) values
 ('11000000-0000-0000-0000-000000000111', '00000000-0000-0000-0000-000000000112', 'Existing plan');
insert into public.bloom_workout_sessions(id, user_id, plan_id, plan_snapshot, status, completed_at, credits_enabled_at_completion)
values ('11000000-0000-0000-0000-000000000112', '00000000-0000-0000-0000-000000000112',
  '11000000-0000-0000-0000-000000000111', '[]', 'completed', now(), false);
insert into public.bloom_credit_ledger(user_id, amount_minutes, entry_type, idempotency_key)
values ('00000000-0000-0000-0000-000000000112', 10, 'adjustment', 'identity-fixture');
insert into public.bloom_households(id, owner_user_id, name)
values ('11000000-0000-0000-0000-000000000113', '00000000-0000-0000-0000-000000000111', 'Existing family');
insert into public.bloom_household_members(household_id, user_id, role) values
 ('11000000-0000-0000-0000-000000000113', '00000000-0000-0000-0000-000000000111', 'parent'),
 ('11000000-0000-0000-0000-000000000113', '00000000-0000-0000-0000-000000000112', 'child');
