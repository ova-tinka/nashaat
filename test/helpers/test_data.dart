import 'package:nashaat/core/entities/blocking-rule-entity.dart';
import 'package:nashaat/core/entities/enums.dart';
import 'package:nashaat/core/entities/exercise-entity.dart';
import 'package:nashaat/core/entities/leaderboard-entity.dart';
import 'package:nashaat/core/entities/profile-entity.dart';
import 'package:nashaat/core/entities/screen-time-transaction-entity.dart';
import 'package:nashaat/core/entities/workout-log-entity.dart';
import 'package:nashaat/core/entities/workout-plan-entity.dart';

class TestData {
  static final _now = DateTime(2026, 4, 18);

  // ── ProfileEntity ──────────────────────────────────────────────────────────

  static ProfileEntity profile({
    String id = 'u1',
    String email = 'test@example.com',
    String? username,
    String? firstName,
    UserStatus status = UserStatus.active,
    int weeklyExerciseTargetMinutes = 120,
    int screenTimeBalanceMinutes = 60,
    int streakCount = 3,
    SubscriptionTier subscriptionTier = SubscriptionTier.free,
    int dailyPhoneHours = 0,
    int weeklySmallSessions = 0,
    int weeklyBigSessions = 0,
  }) {
    return ProfileEntity(
      id: id,
      email: email,
      username: username,
      firstName: firstName,
      status: status,
      weeklyExerciseTargetMinutes: weeklyExerciseTargetMinutes,
      screenTimeBalanceMinutes: screenTimeBalanceMinutes,
      streakCount: streakCount,
      subscriptionTier: subscriptionTier,
      createdAt: _now,
      updatedAt: _now,
      dailyPhoneHours: dailyPhoneHours,
      weeklySmallSessions: weeklySmallSessions,
      weeklyBigSessions: weeklyBigSessions,
    );
  }

  static ProfileEntity configuredProfile({
    String id = 'u1',
    String email = 'test@example.com',
    int screenTimeBalanceMinutes = 60,
  }) {
    return profile(
      id: id,
      email: email,
      screenTimeBalanceMinutes: screenTimeBalanceMinutes,
      dailyPhoneHours: 8,
      weeklySmallSessions: 2,
      weeklyBigSessions: 3,
    );
  }

  // ── ExerciseEntity ────────────────────────────────────────────────────────

  static ExerciseEntity exercise({
    String id = 'ex1',
    String name = 'Push-up',
    List<String> muscleGroups = const ['chest', 'triceps'],
    DifficultyLevel difficultyLevel = DifficultyLevel.medium,
    ExerciseMeasurement measurementType = ExerciseMeasurement.repsOnly,
  }) {
    return ExerciseEntity(
      id: id,
      name: name,
      muscleGroups: muscleGroups,
      difficultyLevel: difficultyLevel,
      measurementType: measurementType,
      createdAt: _now,
    );
  }

  // ── WorkoutPlanExercise ───────────────────────────────────────────────────

  static WorkoutPlanExercise planExercise({
    String exerciseId = 'ex1',
    String exerciseName = 'Push-up',
    int sets = 3,
    int? reps = 12,
    int? restSeconds = 60,
  }) {
    return WorkoutPlanExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      sets: sets,
      reps: reps,
      restSeconds: restSeconds,
    );
  }

  // ── WorkoutPlanEntity ─────────────────────────────────────────────────────

  static WorkoutPlanEntity workoutPlan({
    String id = 'plan1',
    String userId = 'u1',
    String title = 'Morning Routine',
    List<int> scheduledDays = const [1, 3, 5],
    List<WorkoutPlanExercise>? exercises,
    SessionSize sessionSize = SessionSize.small,
    WorkoutSource source = WorkoutSource.manual,
  }) {
    return WorkoutPlanEntity(
      id: id,
      userId: userId,
      title: title,
      source: source,
      scheduledDays: scheduledDays,
      exercises: exercises ??
          [
            planExercise(exerciseId: 'ex1', exerciseName: 'Push-up'),
          ],
      sessionSize: sessionSize,
      createdAt: _now,
      updatedAt: _now,
    );
  }

  // ── WorkoutLogEntity ──────────────────────────────────────────────────────

  static WorkoutLogEntity workoutLog({
    String id = 'log1',
    String userId = 'u1',
    String? workoutPlanId = 'plan1',
    int durationMinutes = 30,
    int earnedScreenTimeMinutes = 0,
    DateTime? loggedAt,
  }) {
    return WorkoutLogEntity(
      id: id,
      userId: userId,
      workoutPlanId: workoutPlanId,
      durationMinutes: durationMinutes,
      earnedScreenTimeMinutes: earnedScreenTimeMinutes,
      loggedAt: loggedAt ?? _now,
    );
  }

  // ── ScreenTimeTransactionEntity ───────────────────────────────────────────

  static ScreenTimeTransactionEntity transaction({
    String id = 'txn1',
    String userId = 'u1',
    int amountMinutes = 30,
    TransactionType transactionType = TransactionType.earned,
    String? description,
    DateTime? createdAt,
  }) {
    return ScreenTimeTransactionEntity(
      id: id,
      userId: userId,
      amountMinutes: amountMinutes,
      transactionType: transactionType,
      description: description,
      createdAt: createdAt ?? _now,
    );
  }

  // ── LeaderboardEntity ─────────────────────────────────────────────────────

  static LeaderboardEntity leaderboard({
    String id = 'lb1',
    String ownerId = 'u1',
    String name = 'Team Alpha',
    String inviteCode = 'ABC123',
  }) {
    return LeaderboardEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      inviteCode: inviteCode,
      createdAt: _now,
    );
  }

  // ── LeaderboardMemberEntity ───────────────────────────────────────────────

  static LeaderboardMemberEntity leaderboardMember({
    String leaderboardId = 'lb1',
    String userId = 'u1',
    int weeklyScore = 100,
  }) {
    return LeaderboardMemberEntity(
      leaderboardId: leaderboardId,
      userId: userId,
      weeklyScore: weeklyScore,
      joinedAt: _now,
    );
  }

  // ── BlockingRuleEntity ────────────────────────────────────────────────────

  static BlockingRuleEntity blockingRule({
    String id = 'rule1',
    String userId = 'u1',
    String itemIdentifier = 'com.instagram.android',
    ItemType itemType = ItemType.app,
    RuleStatus status = RuleStatus.active,
  }) {
    return BlockingRuleEntity(
      id: id,
      userId: userId,
      itemType: itemType,
      itemIdentifier: itemIdentifier,
      status: status,
      createdAt: _now,
      updatedAt: _now,
    );
  }
}
