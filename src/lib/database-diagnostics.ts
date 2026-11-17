import { supabase } from './supabase';
import { formatDiagnosticFailure } from './diagnostic-error';
export { formatDiagnosticFailure } from './diagnostic-error';

export type DiagnosticRead<T> =
  | { status: 'ok'; value: T | null }
  | { status: 'error'; code: string | null; message: string };

export type DatabaseDiagnostics = {
  capturedAt: string;
  settings: DiagnosticRead<{
    credits_enabled: boolean;
    credit_mode: string;
    credit_timezone: string;
    earning_strategy: string;
    reps_per_award: number | null;
    rep_award_minutes: number | null;
    exercise_minutes_per_award: number | null;
    time_award_minutes: number | null;
    super_daily_cap_minutes: number | null;
    weekly_workout_target: number | null;
    weekly_credit_target_minutes: number | null;
    updated_at: string;
  }>;
  balance: DiagnosticRead<number>;
  ledger: DiagnosticRead<{
    amount_minutes: number;
    entry_type: string;
    expires_at: string | null;
    created_at: string;
  }[]>;
  creditSessions: DiagnosticRead<{
    mode: string;
    started_at: string;
    ends_at: string;
    expires_at: string;
    settled_at: string | null;
  }[]>;
  usageReservations: DiagnosticRead<{
    id: string;
    requested_ms: number;
    reserved_ms: number;
    used_ms: number | null;
    started_at: string;
    expires_at: string;
    settled_at: string | null;
    abandoned_at: string | null;
  }[]>;
  blockingRules: DiagnosticRead<{
    platform: string;
    target_type: string;
    target_identifier: string;
    enabled: boolean;
    created_at: string;
  }[]>;
};

type QueryResponse = { data: unknown; error: unknown };

async function readQuery<T>(query: PromiseLike<QueryResponse>): Promise<DiagnosticRead<T>> {
  try {
    const { data, error } = await query;
    if (error) return { status: 'error', ...formatDiagnosticFailure(error) };
    return { status: 'ok', value: data as T | null };
  } catch (error) {
    return { status: 'error', ...formatDiagnosticFailure(error) };
  }
}

/** Read only the signed-in user's rows. RLS remains the access boundary; no writes or admin key are used. */
export async function loadDatabaseDiagnostics(userId: string): Promise<DatabaseDiagnostics> {
  if (!supabase) throw new Error('Supabase is not configured in this build.');

  const [settings, balance, ledger, creditSessions, usageReservations, blockingRules] = await Promise.all([
    readQuery<DatabaseDiagnostics['settings'] extends DiagnosticRead<infer T> ? T : never>(
      supabase.from('bloom_settings')
        .select('credits_enabled,credit_mode,credit_timezone,earning_strategy,reps_per_award,rep_award_minutes,exercise_minutes_per_award,time_award_minutes,super_daily_cap_minutes,weekly_workout_target,weekly_credit_target_minutes,updated_at')
        .eq('user_id', userId).maybeSingle(),
    ),
    readQuery<number>(supabase.rpc('bloom_credit_balance')),
    readQuery<NonNullable<DatabaseDiagnostics['ledger'] extends DiagnosticRead<infer T> ? T : never>>(
      supabase.from('bloom_credit_ledger')
        .select('amount_minutes,entry_type,expires_at,created_at')
        .eq('user_id', userId).order('created_at', { ascending: false }).limit(20),
    ),
    readQuery<NonNullable<DatabaseDiagnostics['creditSessions'] extends DiagnosticRead<infer T> ? T : never>>(
      supabase.from('bloom_credit_sessions')
        .select('mode,started_at,ends_at,expires_at,settled_at')
        .eq('user_id', userId).order('started_at', { ascending: false }).limit(10),
    ),
    readQuery<NonNullable<DatabaseDiagnostics['usageReservations'] extends DiagnosticRead<infer T> ? T : never>>(
      supabase.from('bloom_usage_sessions')
        .select('id,requested_ms,reserved_ms,used_ms,started_at,expires_at,settled_at,abandoned_at')
        .eq('user_id', userId).order('started_at', { ascending: false }).limit(10),
    ),
    readQuery<NonNullable<DatabaseDiagnostics['blockingRules'] extends DiagnosticRead<infer T> ? T : never>>(
      supabase.from('bloom_blocking_rules')
        .select('platform,target_type,target_identifier,enabled,created_at')
        .eq('user_id', userId).order('created_at', { ascending: false }).limit(100),
    ),
  ]);

  return { capturedAt: new Date().toISOString(), settings, balance, ledger, creditSessions, usageReservations, blockingRules };
}
