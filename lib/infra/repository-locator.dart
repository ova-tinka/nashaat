import '../core/repositories/auth-repository.dart';
import '../core/repositories/blocking-repository.dart';
import '../core/repositories/emergency-break-repository.dart';
import '../core/repositories/exercise-repository.dart';
import '../core/repositories/friendship-repository.dart';
import '../core/repositories/leaderboard-repository.dart';
import '../core/repositories/media-repository.dart';
import '../core/repositories/notification-repository.dart';
import '../core/repositories/profile-repository.dart';
import '../core/repositories/screen-time-transaction-repository.dart';
import '../core/repositories/user-reward-repository.dart';
import '../core/repositories/workout-log-repository.dart';
import '../core/repositories/workout-plan-repository.dart';
import 'supabase/auth-repository-impl.dart';
import 'supabase/blocking-repository-impl.dart';
import 'supabase/emergency-break-repository-impl.dart';
import 'supabase/exercise-repository-impl.dart';
import 'supabase/friendship-repository-impl.dart';
import 'supabase/leaderboard-repository-impl.dart';
import 'supabase/media-repository-impl.dart';
import 'supabase/notification-repository-impl.dart';
import 'supabase/profile-repository-impl.dart';
import 'supabase/screen-time-transaction-repository-impl.dart';
import 'supabase/user-reward-repository-impl.dart';
import 'supabase/workout-log-repository-impl.dart';
import 'supabase/workout-plan-repository-impl.dart';
import 'translation/groq-translation-service.dart';

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
  final EmergencyBreakRepository emergencyBreak =
      SupabaseEmergencyBreakRepository();
  final FriendshipRepository friendship = SupabaseFriendshipRepository();
  final NotificationRepository notification =
      SupabaseNotificationRepository();
  final UserRewardRepository userReward = SupabaseUserRewardRepository();
  final MediaRepository media = SupabaseMediaRepository();
  final GroqTranslationService translation = GroqTranslationService();
}
