-- Nashaat Supabase MVP Schema
-- This schema translates the 15 Use Case Specifications into PostgreSQL tables suitable for Supabase.

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ENUMS
-- ============================================================================

CREATE TYPE item_type_enum AS ENUM ('app', 'website');
CREATE TYPE friendship_status_enum AS ENUM ('pending', 'accepted', 'rejected');
CREATE TYPE subscription_tier_enum AS ENUM ('free', 'vip');
CREATE TYPE user_status_enum AS ENUM ('active', 'verified', 'onboarded', 'inactive', 'deleted', 'suspended');
CREATE TYPE workout_source_enum AS ENUM ('manual', 'ai_generated');
CREATE TYPE rule_status_enum AS ENUM ('active', 'inactive', 'archived');
CREATE TYPE notification_status_enum AS ENUM ('unread', 'read', 'archived');
CREATE TYPE media_type_enum AS ENUM ('image', 'video', 'document');
CREATE TYPE exercise_measurement_enum AS ENUM ('reps_weight', 'time_distance', 'time_only', 'reps_only');
CREATE TYPE transaction_type_enum AS ENUM ('earned', 'spent', 'penalty', 'manual_adjustment');

-- ============================================================================
-- 1. PROFILES (Extends Supabase auth.users)
-- Covers: UC1 (Register/Onboarding), UC3 (Settings), UC6 (Dashboard state), 
--         UC11 (Subscriptions), UC15 (Streaks)
-- ============================================================================
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    username TEXT UNIQUE,
    first_name TEXT,
    last_name TEXT,
    -- Onboarding / Configuration (UC1)
    status user_status_enum DEFAULT 'active',
    weekly_exercise_target_minutes INT DEFAULT 0,
    
    -- Dashboard / State (UC6, UC15)
    screen_time_balance_minutes INT DEFAULT 0,
    streak_count INT DEFAULT 0,
    last_workout_date DATE,
    
    -- Subscriptions (UC11)
    subscription_tier subscription_tier_enum DEFAULT 'free',
    
    -- Push Notifications (MVP Approach)
    fcm_token TEXT, -- Overwritten on new logins, fine for single-device usage
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to automatically create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- ============================================================================
-- 1.5 MEDIA
-- Covers: Centralized media management (Avatars, future workout photos, etc.)
-- ============================================================================
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    storage_path TEXT NOT NULL, -- Path in Supabase Storage bucket (e.g., 'avatars/user123.jpg')
    file_name TEXT,             -- Original uploaded filename
    mime_type TEXT,             -- e.g., 'image/jpeg'
    size_bytes BIGINT,
    type media_type_enum DEFAULT 'image',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Add avatar reference back to profiles
ALTER TABLE profiles 
ADD COLUMN avatar_media_id UUID REFERENCES media(id) ON DELETE SET NULL;

-- ============================================================================
-- 1.7 EXERCISES (Master Catalog)
-- Covers: The global list of exercises used in workout plans
-- ============================================================================
CREATE TABLE exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT UNIQUE NOT NULL,
    description TEXT,
    muscle_group TEXT,
    measurement_type exercise_measurement_enum NOT NULL DEFAULT 'reps_weight', -- Defines the UI inputs needed for this exercise
    media_id UUID REFERENCES media(id) ON DELETE SET NULL, -- Link to a demonstration image/video
    is_system BOOLEAN DEFAULT true, -- True for global exercises, False if users can create custom ones
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 2. WORKOUT PLANS
-- Covers: UC4 (Manage Workout Plan)
-- ============================================================================
CREATE TABLE workout_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    source workout_source_enum DEFAULT 'manual', -- 'manual' or 'ai_generated' for VIP AI workouts
    
    -- Schedule and Structure
    scheduled_days INT[] DEFAULT '{}', -- Array of days (e.g., {1, 3, 5} for Mon/Wed/Fri)
    exercises JSONB NOT NULL DEFAULT '[]'::jsonb, -- Document hybrid: stores the plan's exercises, sets, and reps
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 3. WORKOUT LOGS
-- Covers: UC5 (Log Workout & Earn Screen-Time)
-- ============================================================================
CREATE TABLE workout_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    workout_plan_id UUID REFERENCES workout_plans(id) ON DELETE SET NULL,
    
    -- Overarching metrics for screen time calculations
    duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
    earned_screen_time_minutes INT NOT NULL,
    
    -- Progress Tracking: What the user actually completed
    completed_exercises JSONB NOT NULL DEFAULT '[]'::jsonb,
    notes TEXT, -- Optional user notes about the session
    
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 4. BLOCKING CONFIGURATION
-- Covers: UC8 (Mobile App Blocking), UC9 (Web Blocking), UC10 (Manage Config)
-- ============================================================================
CREATE TABLE blocking_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    item_type item_type_enum NOT NULL, -- 'app' or 'website'
    item_identifier TEXT NOT NULL,     -- e.g., 'com.instagram.android' or 'youtube.com'
    status rule_status_enum DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_type, item_identifier)
);

-- ============================================================================
-- 5. EMERGENCY BREAKS
-- Covers: UC7 (Screen Lock & Emergency Break Handling)
-- ============================================================================
CREATE TABLE emergency_breaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    duration_minutes INT NOT NULL,
    reason TEXT,
    granted_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 6. FRIENDSHIPS
-- Covers: UC13 (Private Leaderboards), UC14 (Manage Friends)
-- ============================================================================
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    requester_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    status friendship_status_enum DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(requester_id, addressee_id),
    CHECK (requester_id != addressee_id)
);

-- ============================================================================
-- 7. REWARDS
-- Covers: UC15 (Streaks & Rewards System)
-- ============================================================================
CREATE TABLE user_rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    reward_title TEXT NOT NULL,
    reward_description TEXT,
    unlocked_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 8. NOTIFICATIONS
-- Covers: UC12 (Receive Notifications)
-- ============================================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT, -- e.g., 'workout_reminder', 'goal_deadline', 'friend_request'
    status notification_status_enum DEFAULT 'unread',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 9. SCREEN TIME TRANSACTIONS (The Ledger)
-- Covers: Historical tracking of all screen-time earned and spent
-- ============================================================================
CREATE TABLE screen_time_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount_minutes INT NOT NULL, -- Positive for earned, Negative for spent/penalty
    transaction_type transaction_type_enum NOT NULL,
    description TEXT, -- e.g., 'Completed Chest Day' or 'Requested Emergency Break'
    reference_id UUID, -- Optional foreign key to workout_logs.id or emergency_breaks.id
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- 10. LEADERBOARDS & MEMBERS (Simplified)
-- Covers: UC13 (Private Leaderboards)
-- ============================================================================
CREATE TABLE leaderboards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    invite_code TEXT UNIQUE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE leaderboard_members (
    leaderboard_id UUID NOT NULL REFERENCES leaderboards(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    weekly_score INT DEFAULT 0, -- Dynamically updated or reset weekly
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (leaderboard_id, user_id)
);

-- ============================================================================
-- 11. APP USAGE INSIGHTS
-- Covers: Historical tracking of blocked/allowed app usage for the user
-- ============================================================================
CREATE TABLE app_usage_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    usage_date DATE NOT NULL,
    total_screen_time_minutes INT DEFAULT 0,
    app_breakdown JSONB DEFAULT '{}'::jsonb, -- e.g., {"com.instagram": 45, "com.tiktok": 30}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, usage_date)
);

-- ============================================================================
-- 12. INDEXING & GIN INDEXES
-- Covers: Performance optimizations for frequent queries and JSONB columns
-- ============================================================================

-- B-Tree Indexes for Foreign Keys and frequently filtered/sorted columns
CREATE INDEX idx_media_user_id ON media(user_id);
CREATE INDEX idx_exercises_name ON exercises(name);
CREATE INDEX idx_workout_plans_user_id ON workout_plans(user_id);
CREATE INDEX idx_workout_logs_user_id ON workout_logs(user_id);
CREATE INDEX idx_workout_logs_plan_id ON workout_logs(workout_plan_id);
CREATE INDEX idx_workout_logs_logged_at ON workout_logs(logged_at DESC);
CREATE INDEX idx_blocking_rules_user_id_status ON blocking_rules(user_id, status);
CREATE INDEX idx_emergency_breaks_user_id ON emergency_breaks(user_id);
CREATE INDEX idx_friendships_requester_id ON friendships(requester_id);
CREATE INDEX idx_friendships_addressee_id ON friendships(addressee_id);
CREATE INDEX idx_user_rewards_user_id ON user_rewards(user_id);
CREATE INDEX idx_notifications_user_id_status ON notifications(user_id, status);
CREATE INDEX idx_screen_transactions_user_id ON screen_time_transactions(user_id, created_at DESC);
CREATE INDEX idx_leaderboards_owner_id ON leaderboards(owner_id);
CREATE INDEX idx_leaderboard_members_user_id ON leaderboard_members(user_id);
CREATE INDEX idx_app_usage_insights_user_date ON app_usage_insights(user_id, usage_date DESC);

-- GIN Indexes for deep JSONB searching and arrays
CREATE INDEX idx_workout_plans_exercises_gin ON workout_plans USING GIN (exercises);
CREATE INDEX idx_workout_logs_completed_exercises_gin ON workout_logs USING GIN (completed_exercises);
CREATE INDEX idx_app_usage_insights_breakdown_gin ON app_usage_insights USING GIN (app_breakdown);

-- ============================================================================
-- 13. POSTGRESQL COMMENTS (Data Dictionary)
-- Covers: Documentation directly embedded in the database schema
-- ============================================================================

-- Profiles
COMMENT ON TABLE profiles IS 'Core user profile data extending Supabase auth.users';
COMMENT ON COLUMN profiles.status IS 'Lifecycle: active -> verified -> onboarded -> inactive -> deleted -> suspended';
COMMENT ON COLUMN profiles.fcm_token IS 'Push notification token for the user''s primary device.';
COMMENT ON COLUMN profiles.screen_time_balance_minutes IS 'Current available screen time in minutes. Updated via transactions.';

-- Media
COMMENT ON TABLE media IS 'Central registry for user-uploaded media like avatars or workout videos.';

-- Exercises
COMMENT ON TABLE exercises IS 'Master catalog of exercises available in the app.';
COMMENT ON COLUMN exercises.measurement_type IS 'Determines which UI inputs are shown (e.g., reps vs time).';

-- Workout Plans
COMMENT ON TABLE workout_plans IS 'Container for a workout routine (manual or AI generated).';
COMMENT ON COLUMN workout_plans.exercises IS 'Document hybrid: JSON array of exercise objects containing sets, reps, duration.';
COMMENT ON COLUMN workout_plans.scheduled_days IS 'Array of integers representing intended days of the week (e.g., {1,3,5}).';

-- Workout Logs
COMMENT ON TABLE workout_logs IS 'Historical record of completed workouts and earned screen time.';
COMMENT ON COLUMN workout_logs.completed_exercises IS 'Document hybrid: exactly what the user actually completed during the session (can differ from the plan).';

-- Blocking Rules
COMMENT ON TABLE blocking_rules IS 'User configurations for which apps or websites are restricted.';

-- Screen Time Transactions
COMMENT ON TABLE screen_time_transactions IS 'Immutable ledger tracking all screen time earned and spent.';
COMMENT ON COLUMN screen_time_transactions.amount_minutes IS 'Positive for earned time, negative for spent or penalized time.';

-- App Usage Insights
COMMENT ON TABLE app_usage_insights IS 'Daily aggregated breakdown of time spent on specific apps.';
COMMENT ON COLUMN app_usage_insights.app_breakdown IS 'JSON mapping of app identifiers to minutes used (e.g., {"com.instagram": 45, "com.tiktok": 30}).';
