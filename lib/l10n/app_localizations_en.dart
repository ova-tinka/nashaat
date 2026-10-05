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
}
