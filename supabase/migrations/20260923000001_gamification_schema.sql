DO $do$
BEGIN
    IF to_regtype('public.point_reason_enum') IS NULL THEN
        CREATE TYPE public.point_reason_enum AS ENUM (
            'workout_completion',
            'streak_bonus',
            'achievement_bonus',
            'manual_adjustment'
        );
    END IF;

    IF to_regtype('public.achievement_category_enum') IS NULL THEN
        CREATE TYPE public.achievement_category_enum AS ENUM (
            'workout',
            'streak',
            'social',
            'milestone'
        );
    END IF;

    IF to_regtype('public.achievement_criteria_enum') IS NULL THEN
        CREATE TYPE public.achievement_criteria_enum AS ENUM (
            'qualifying_workout_count',
            'current_streak',
            'leaderboard_join',
            'weekly_leaderboard_win'
        );
    END IF;

    IF to_regtype('public.reward_type_enum') IS NULL THEN
        CREATE TYPE public.reward_type_enum AS ENUM (
            'recognition',
            'points',
            'screen_time'
        );
    END IF;
END;
$do$;

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS points_total INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS longest_streak INTEGER NOT NULL DEFAULT 0,
ADD COLUMN IF NOT EXISTS timezone TEXT NOT NULL DEFAULT 'UTC';



CREATE TABLE IF NOT EXISTS public.point_awards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    user_id UUID NOT NULL
        REFERENCES public.profiles(id)
        ON DELETE CASCADE,

    points INTEGER NOT NULL
        CHECK (points > 0),

    reason_type public.point_reason_enum NOT NULL,

    description TEXT NOT NULL,

    source_type TEXT NOT NULL,
    source_event_id UUID NOT NULL,

    workout_log_id UUID
        REFERENCES public.workout_logs(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT point_awards_unique_source
        UNIQUE (
            user_id,
            source_type,
            source_event_id,
            reason_type
        )
);

CREATE TABLE IF NOT EXISTS public.achievement_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    code TEXT UNIQUE NOT NULL,

    name TEXT NOT NULL,
    description TEXT NOT NULL,

    category public.achievement_category_enum NOT NULL,
    criteria_type public.achievement_criteria_enum NOT NULL,

    target_value INTEGER NOT NULL
        CHECK (target_value > 0),

    reward_type public.reward_type_enum NOT NULL
        DEFAULT 'recognition',

    reward_amount INTEGER NOT NULL DEFAULT 0
        CHECK (reward_amount >= 0),

    icon_reference TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS public.user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    user_id UUID NOT NULL
        REFERENCES public.profiles(id)
        ON DELETE CASCADE,

    achievement_id UUID NOT NULL
        REFERENCES public.achievement_definitions(id)
        ON DELETE RESTRICT,

    progress INTEGER NOT NULL DEFAULT 0
        CHECK (progress >= 0),

    unlocked_at TIMESTAMPTZ,

    reward_granted_at TIMESTAMPTZ,

    reward_transaction_id UUID
        REFERENCES public.screen_time_transactions(id)
        ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT user_achievements_unique
        UNIQUE (user_id, achievement_id)
);




INSERT INTO public.achievement_definitions (
    code,
    name,
    description,
    category,
    criteria_type,
    target_value,
    reward_type,
    reward_amount
)
VALUES
(
    'first_workout',
    'First Step',
    'Complete your first qualifying workout.',
    'workout',
    'qualifying_workout_count',
    1,
    'points',
    50
),
(
    'three_day_streak',
    'Consistent Three',
    'Reach a three-day workout streak.',
    'streak',
    'current_streak',
    3,
    'screen_time',
    15
),
(
    'ten_workouts',
    'Workout Ten',
    'Complete ten qualifying workouts.',
    'milestone',
    'qualifying_workout_count',
    10,
    'points',
    150
),
(
    'join_private_board',
    'Friendly Start',
    'Join a private leaderboard.',
    'social',
    'leaderboard_join',
    1,
    'recognition',
    0
)
ON CONFLICT (code) DO NOTHING;



CREATE TABLE IF NOT EXISTS public.leaderboard_period_scores (
    leaderboard_id UUID NOT NULL,
    user_id UUID NOT NULL,

    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    score INTEGER NOT NULL DEFAULT 0
        CHECK (score >= 0),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- One user can have only one score entry
    -- for the same leaderboard and weekly period.
    CONSTRAINT leaderboard_period_scores_pkey
        PRIMARY KEY (
            leaderboard_id,
            user_id,
            period_start
        ),

    -- The user must actually be a member of this leaderboard.
    CONSTRAINT leaderboard_period_scores_member_fk
        FOREIGN KEY (
            leaderboard_id,
            user_id
        )
        REFERENCES public.leaderboard_members (
            leaderboard_id,
            user_id
        )
        ON DELETE CASCADE,

    -- Prevent invalid periods such as Sep 20 -> Sep 15.
    CONSTRAINT leaderboard_period_scores_valid_period
        CHECK (period_end >= period_start)
);
