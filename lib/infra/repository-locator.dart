import '../core/repositories/auth-repository.dart';
import '../core/repositories/blocking-repository.dart';
import '../core/repositories/exercise-repository.dart';
import '../core/repositories/leaderboard-repository.dart';
import '../core/repositories/profile-repository.dart';
import '../core/repositories/screen-time-transaction-repository.dart';
import '../core/repositories/workout-log-repository.dart';
import '../core/repositories/workout-plan-repository.dart';
import 'supabase/auth-repository-impl.dart';
import 'supabase/blocking-repository-impl.dart';
import 'supabase/exercise-repository-impl.dart';
import 'supabase/leaderboard-repository-impl.dart';
import 'supabase/profile-repository-impl.dart';
import 'supabase/screen-time-transaction-repository-impl.dart';
import 'supabase/workout-log-repository-impl.dart';
import 'supabase/workout-plan-repository-impl.dart';

class RepositoryLocator {
  static final RepositoryLocator _instance = RepositoryLocator._();
  static RepositoryLocator get instance => _instance;
  RepositoryLocator._();

  final AuthRepository auth = SupabaseAuthRepository();
  final ProfileRepository profile = SupabaseProfileRepository();
  final WorkoutPlanRepository workoutPlan = SupabaseWorkoutPlanRepository();
  final ExerciseRepository exercise = SupabaseExerciseRepository();
  final WorkoutLogRepository workoutLog = SupabaseWorkoutLogRepository();
  final ScreenTimeTransactionRepository screenTimeTransaction =
      SupabaseScreenTimeTransactionRepository();
  final BlockingRepository blocking = SupabaseBlockingRepository();
  final LeaderboardRepository leaderboard = SupabaseLeaderboardRepository();
}
