// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Nashaat';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get workouts => 'Workouts';

  @override
  String get settings => 'Settings';

  @override
  String get profile => 'Profile';

  @override
  String get leaderboard => 'Leaderboard';

  @override
  String get friends => 'Friends';

  @override
  String get subscription => 'Subscription';

  @override
  String get logWorkout => 'Log Workout';

  @override
  String get startWorkout => 'Start Workout';

  @override
  String get completeWorkout => 'Complete Workout';

  @override
  String get screenTimeBalance => 'Screen Time Balance';

  @override
  String get earnedToday => 'Earned Today';

  @override
  String get currentStreak => 'Current Streak';

  @override
  String get register => 'Create Account';

  @override
  String get login => 'Log In';

  @override
  String get logout => 'Log Out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get done => 'Done';

  @override
  String get loading => 'Loading...';

  @override
  String get networkError => 'Network connection error';

  @override
  String get authError => 'Authentication error';

  @override
  String get genericError => 'Something went wrong';

  @override
  String get appBlocking => 'App Blocking';

  @override
  String get webBlocking => 'Web Blocking';

  @override
  String get manageRules => 'Manage Rules';

  @override
  String get welcome => 'Welcome';

  @override
  String get setGoals => 'Set Your Goals';

  @override
  String get setupBlocking => 'Set Up Blocking';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Nashaat';

  @override
  String get onboardingLetsGo => 'Let\'s go';

  @override
  String onboardingStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingWelcomeBodyScreenTime =>
      'Earn screen time by working out.\nBuild discipline. Build consistency.';

  @override
  String get onboardingWelcomeBodyWorkout =>
      'Track your workouts and build consistency.';

  @override
  String get onboardingNamePrompt => 'What should we call you?';

  @override
  String get onboardingUsernameOptional => 'Username (optional)';

  @override
  String get onboardingUsernameHint => 'e.g. fitnessathlete';

  @override
  String get onboardingDaysTitle => 'How many days will you train each week?';

  @override
  String onboardingDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days per week',
      one: '1 day per week',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDurationTitle => 'How long will each workout take?';

  @override
  String onboardingDurationOption(int minutes) {
    return '$minutes min';
  }

  @override
  String get onboardingPhoneTitle => 'What is your daily phone usage?';

  @override
  String get onboardingPhoneBody =>
      'We use this to calibrate your screen-time economy.';

  @override
  String onboardingPhoneHours(int hours) {
    return '${hours}h';
  }

  @override
  String get onboardingPhoneMinimum => '1h';

  @override
  String get onboardingPhoneMaximum => '16h';

  @override
  String get onboardingRewardTitle => 'Your reward preview';

  @override
  String get onboardingWeeklyTarget => 'Weekly target';

  @override
  String get onboardingFreeTime => 'Free time per week';

  @override
  String get onboardingSmallSessionReward => 'Per small session';

  @override
  String get onboardingBigSessionReward => 'Per big session';

  @override
  String get onboardingWeeklySessionSplit => 'Weekly session split';

  @override
  String get onboardingSmallSessions => 'Small sessions (1x)';

  @override
  String get onboardingBigSessions => 'Big sessions (2x)';

  @override
  String get onboardingBlockingBody =>
      'Choose apps to block when your screen time runs out.\nYou can change this later.';

  @override
  String get onboardingSelectApps => 'Select apps via Screen Time';

  @override
  String get onboardingAppsSelected => 'Apps selected via Screen Time';

  @override
  String get onboardingNoApps => 'No apps found.';

  @override
  String get onboardingFinishSetup => 'Finish setup';

  @override
  String get onboardingSkipForNow => 'Skip for now';

  @override
  String get workoutMyPlans => 'My plans';

  @override
  String get workoutLibrary => 'Library';

  @override
  String get workoutAi => 'AI';

  @override
  String get workoutNewPlan => 'New plan';

  @override
  String get workoutNextWorkout => 'Next workout';

  @override
  String get workoutRecommended => 'Recommended';

  @override
  String get workoutToday => 'Today';

  @override
  String get workoutYourPlans => 'Your plans';

  @override
  String get workoutNoPlansTitle => 'No plans yet';

  @override
  String get workoutNoPlansScreenTime =>
      'Create your first plan to start earning screen time.';

  @override
  String get workoutNoPlansTraining =>
      'Create your first plan to start training.';

  @override
  String get workoutCouldNotLoad => 'Could not load your plans.';

  @override
  String workoutExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0';
  }

  @override
  String workoutPlanSummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
    );
    return '$_temp0 · $duration';
  }

  @override
  String get workoutPlanMenu => 'Plan menu';

  @override
  String workoutDeleteConfirmation(String plan) {
    return 'Delete $plan? This cannot be undone.';
  }

  @override
  String get workoutAiTitle => 'AI workouts';

  @override
  String get workoutAiBody =>
      'Plans built for you from your history and goals.';

  @override
  String get workoutAiPlans => 'AI-generated workout plans';

  @override
  String get workoutAiAnalytics => 'Advanced progress analytics';

  @override
  String get workoutAiLibrary => 'Expanded exercise library';

  @override
  String get workoutAiSupport => 'Priority support';

  @override
  String get workoutUpgradeVip => 'Upgrade to VIP';

  @override
  String get workoutComingSoon => 'Coming soon';

  @override
  String get workoutAiTrainingBody =>
      'We are training the model on your workout history.';

  @override
  String get workoutTryBeta => 'Try the beta generator';

  @override
  String get builderNewPlan => 'New plan';

  @override
  String get builderEditPlan => 'Edit plan';

  @override
  String get builderPlanTitle => 'Plan title *';

  @override
  String get builderPlanTitleHint => 'e.g. Push Day, Full Body HIIT';

  @override
  String get builderDescriptionOptional => 'Description (optional)';

  @override
  String get builderSessionSize => 'Session size';

  @override
  String get builderSessionSizeBody =>
      'Determines how much screen time this workout earns.';

  @override
  String get builderSmall => 'Small';

  @override
  String get builderBig => 'Big ×2';

  @override
  String get builderSchedule => 'Schedule';

  @override
  String get builderExercises => 'Exercises';

  @override
  String get builderAddExercise => 'Add exercise';

  @override
  String get builderNoExercises => 'No exercises added yet';

  @override
  String get builderSwapExercise => 'Swap exercise';

  @override
  String get builderRemoveExercise => 'Remove exercise';

  @override
  String get builderSets => 'Sets';

  @override
  String get builderReps => 'Reps';

  @override
  String get builderWeight => 'Weight (kg)';

  @override
  String get builderDuration => 'Duration (s)';

  @override
  String get builderDistance => 'Distance (km)';

  @override
  String get builderRest => 'Rest (s)';

  @override
  String get builderSavePlan => 'Save plan';

  @override
  String get builderPlanCreated => 'Plan created successfully';

  @override
  String get builderPlanUpdated => 'Plan updated successfully';

  @override
  String builderExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count exercises',
      one: '1 exercise',
      zero: 'No exercises',
    );
    return '$_temp0';
  }

  @override
  String get builderInvalidValue => 'Check this value';

  @override
  String get activePause => 'Pause';

  @override
  String get activeResume => 'Resume';

  @override
  String get activePaused => 'Paused';

  @override
  String get activeRunning => 'Live';

  @override
  String get activeDone => 'Done';

  @override
  String get activeQuitTitle => 'Quit workout?';

  @override
  String get activeQuitBody => 'Your progress will be lost. Are you sure?';

  @override
  String get activeKeepGoing => 'Keep going';

  @override
  String get activeQuit => 'Quit';

  @override
  String get activeCompleteSet => 'Complete set';

  @override
  String get activeSkip => 'Skip';

  @override
  String get activeElapsed => 'Elapsed';

  @override
  String get activeRest => 'Rest';

  @override
  String get activeSkipRest => 'Skip rest';

  @override
  String get activeUpNext => 'Up next';

  @override
  String get activeFinishSession => 'Finish session';

  @override
  String activeSetProgress(int current, int total) {
    return 'Set $current of $total';
  }

  @override
  String get activeWorkoutComplete => 'Workout complete';

  @override
  String get activeSaving => 'Saving session...';

  @override
  String get activeStarting => 'Starting session...';

  @override
  String get activeRetrySave => 'Retry save';

  @override
  String get activeDuration => 'Duration';

  @override
  String get activeRewardPoints => 'Reward points';

  @override
  String get activeNoRewardPoints => 'No reward points earned for this workout';

  @override
  String get activePointBalance => 'Point balance';

  @override
  String activeTotalPoints(int points) {
    return 'Total points: $points';
  }

  @override
  String get activeWorkoutStreak => 'Workout streak';

  @override
  String activeStreakValue(int current, int longest) {
    return '$current days · Longest: $longest';
  }

  @override
  String get activeEarned => 'Earned';

  @override
  String activeEarnedScreenTime(String minutes) {
    return '+$minutes screen time';
  }

  @override
  String get activeConfigureSettings => 'Configure in Settings';

  @override
  String get activeWorkoutLogged => 'Workout logged';

  @override
  String get activeNewAchievements => 'New achievements';

  @override
  String get activeBackToWorkouts => 'Back to Workouts';
}
