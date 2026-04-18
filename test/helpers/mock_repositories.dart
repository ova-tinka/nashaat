import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/repositories/auth-repository.dart';
import 'package:nashaat/core/repositories/blocking-repository.dart';
import 'package:nashaat/core/repositories/exercise-repository.dart';
import 'package:nashaat/core/repositories/leaderboard-repository.dart';
import 'package:nashaat/core/repositories/profile-repository.dart';
import 'package:nashaat/core/repositories/screen-time-transaction-repository.dart';
import 'package:nashaat/core/repositories/workout-log-repository.dart';
import 'package:nashaat/core/repositories/workout-plan-repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockWorkoutPlanRepository extends Mock implements WorkoutPlanRepository {}

class MockWorkoutLogRepository extends Mock implements WorkoutLogRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockBlockingRepository extends Mock implements BlockingRepository {}

class MockScreenTimeTransactionRepository extends Mock
    implements ScreenTimeTransactionRepository {}

class MockLeaderboardRepository extends Mock implements LeaderboardRepository {}
