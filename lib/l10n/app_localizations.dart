import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Nashaat'**
  String get appName;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Workouts'**
  String get workouts;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Leaderboard'**
  String get leaderboard;

  /// Bottom nav / screen title
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// Subscription screen title
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get subscription;

  /// Action to log a completed workout
  ///
  /// In en, this message translates to:
  /// **'Log Workout'**
  String get logWorkout;

  /// Action to begin a workout session
  ///
  /// In en, this message translates to:
  /// **'Start Workout'**
  String get startWorkout;

  /// Action to mark workout as done
  ///
  /// In en, this message translates to:
  /// **'Complete Workout'**
  String get completeWorkout;

  /// Label for the user's screen time balance
  ///
  /// In en, this message translates to:
  /// **'Screen Time Balance'**
  String get screenTimeBalance;

  /// Label showing screen time earned today
  ///
  /// In en, this message translates to:
  /// **'Earned Today'**
  String get earnedToday;

  /// Label for the user's workout streak
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// Register action label
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get register;

  /// Login action label
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get login;

  /// Logout action label
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// Save action
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Cancel action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm action
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Delete action
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit action
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Back navigation action
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next step action
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Done / finish action
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Generic loading state label
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error shown when network is unavailable
  ///
  /// In en, this message translates to:
  /// **'Network connection error'**
  String get networkError;

  /// Error shown for auth failures
  ///
  /// In en, this message translates to:
  /// **'Authentication error'**
  String get authError;

  /// Fallback error message
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get genericError;

  /// App blocking feature label
  ///
  /// In en, this message translates to:
  /// **'App Blocking'**
  String get appBlocking;

  /// Web blocking feature label
  ///
  /// In en, this message translates to:
  /// **'Web Blocking'**
  String get webBlocking;

  /// Action to manage blocking rules
  ///
  /// In en, this message translates to:
  /// **'Manage Rules'**
  String get manageRules;

  /// Onboarding welcome screen title
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// Onboarding goals screen title
  ///
  /// In en, this message translates to:
  /// **'Set Your Goals'**
  String get setGoals;

  /// Onboarding blocking setup screen title
  ///
  /// In en, this message translates to:
  /// **'Set Up Blocking'**
  String get setupBlocking;

  /// Onboarding welcome heading
  ///
  /// In en, this message translates to:
  /// **'Welcome to Nashaat'**
  String get onboardingWelcomeTitle;

  /// Onboarding first step action
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get onboardingLetsGo;

  /// Onboarding progress label
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onboardingStep(int current, int total);

  /// Onboarding welcome copy when screen time is supported
  ///
  /// In en, this message translates to:
  /// **'Earn screen time by working out.\nBuild discipline. Build consistency.'**
  String get onboardingWelcomeBodyScreenTime;

  /// Onboarding welcome copy when screen time is unavailable
  ///
  /// In en, this message translates to:
  /// **'Track your workouts and build consistency.'**
  String get onboardingWelcomeBodyWorkout;

  /// Onboarding username prompt
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get onboardingNamePrompt;

  /// Optional username field label
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get onboardingUsernameOptional;

  /// Optional username field hint
  ///
  /// In en, this message translates to:
  /// **'e.g. fitnessathlete'**
  String get onboardingUsernameHint;

  /// Onboarding weekly training days heading
  ///
  /// In en, this message translates to:
  /// **'How many days will you train each week?'**
  String get onboardingDaysTitle;

  /// Onboarding weekly training days summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 day per week} other {{count} days per week}}'**
  String onboardingDaysPerWeek(int count);

  /// Onboarding workout duration heading
  ///
  /// In en, this message translates to:
  /// **'How long will each workout take?'**
  String get onboardingDurationTitle;

  /// Onboarding workout duration option
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String onboardingDurationOption(int minutes);

  /// Onboarding daily phone usage heading
  ///
  /// In en, this message translates to:
  /// **'What is your daily phone usage?'**
  String get onboardingPhoneTitle;

  /// Onboarding daily phone usage explanation
  ///
  /// In en, this message translates to:
  /// **'We use this to calibrate your screen-time economy.'**
  String get onboardingPhoneBody;

  /// Onboarding daily phone usage value
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String onboardingPhoneHours(int hours);

  /// Minimum daily phone usage label
  ///
  /// In en, this message translates to:
  /// **'1h'**
  String get onboardingPhoneMinimum;

  /// Maximum daily phone usage label
  ///
  /// In en, this message translates to:
  /// **'16h'**
  String get onboardingPhoneMaximum;

  /// Onboarding reward preview heading
  ///
  /// In en, this message translates to:
  /// **'Your reward preview'**
  String get onboardingRewardTitle;

  /// Onboarding reward preview weekly target label
  ///
  /// In en, this message translates to:
  /// **'Weekly target'**
  String get onboardingWeeklyTarget;

  /// Onboarding reward preview free time label
  ///
  /// In en, this message translates to:
  /// **'Free time per week'**
  String get onboardingFreeTime;

  /// Onboarding reward preview small session label
  ///
  /// In en, this message translates to:
  /// **'Per small session'**
  String get onboardingSmallSessionReward;

  /// Onboarding reward preview big session label
  ///
  /// In en, this message translates to:
  /// **'Per big session'**
  String get onboardingBigSessionReward;

  /// Onboarding reward preview session split heading
  ///
  /// In en, this message translates to:
  /// **'Weekly session split'**
  String get onboardingWeeklySessionSplit;

  /// Onboarding small sessions counter label
  ///
  /// In en, this message translates to:
  /// **'Small sessions (1x)'**
  String get onboardingSmallSessions;

  /// Onboarding big sessions counter label
  ///
  /// In en, this message translates to:
  /// **'Big sessions (2x)'**
  String get onboardingBigSessions;

  /// Onboarding app blocking explanation
  ///
  /// In en, this message translates to:
  /// **'Choose apps to block when your screen time runs out.\nYou can change this later.'**
  String get onboardingBlockingBody;

  /// Onboarding iOS app picker action
  ///
  /// In en, this message translates to:
  /// **'Select apps via Screen Time'**
  String get onboardingSelectApps;

  /// Onboarding iOS app picker completion state
  ///
  /// In en, this message translates to:
  /// **'Apps selected via Screen Time'**
  String get onboardingAppsSelected;

  /// Onboarding Android empty app list state
  ///
  /// In en, this message translates to:
  /// **'No apps found.'**
  String get onboardingNoApps;

  /// Onboarding finish action
  ///
  /// In en, this message translates to:
  /// **'Finish setup'**
  String get onboardingFinishSetup;

  /// Onboarding skip action
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkipForNow;

  /// Workouts hub plans tab
  ///
  /// In en, this message translates to:
  /// **'My plans'**
  String get workoutMyPlans;

  /// Workouts hub exercise library tab
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get workoutLibrary;

  /// Workouts hub AI tab
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get workoutAi;

  /// Workouts hub create plan action
  ///
  /// In en, this message translates to:
  /// **'New plan'**
  String get workoutNewPlan;

  /// Workouts hub recommended workout heading
  ///
  /// In en, this message translates to:
  /// **'Next workout'**
  String get workoutNextWorkout;

  /// Workouts hub recommended workout status
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get workoutRecommended;

  /// Workouts hub workout scheduled today status
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get workoutToday;

  /// Workouts hub plans section heading
  ///
  /// In en, this message translates to:
  /// **'Your plans'**
  String get workoutYourPlans;

  /// Workouts hub empty state heading
  ///
  /// In en, this message translates to:
  /// **'No plans yet'**
  String get workoutNoPlansTitle;

  /// Workouts hub iOS empty state body
  ///
  /// In en, this message translates to:
  /// **'Create your first plan to start earning screen time.'**
  String get workoutNoPlansScreenTime;

  /// Workouts hub Android empty state body
  ///
  /// In en, this message translates to:
  /// **'Create your first plan to start training.'**
  String get workoutNoPlansTraining;

  /// Workouts hub error state body
  ///
  /// In en, this message translates to:
  /// **'Could not load your plans.'**
  String get workoutCouldNotLoad;

  /// Workouts hub plan exercise count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 exercise} other {{count} exercises}}'**
  String workoutExerciseCount(int count);

  /// Workouts hub plan summary
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1 {1 exercise} other {{count} exercises}} · {duration}'**
  String workoutPlanSummary(int count, String duration);

  /// Workouts hub plan menu accessibility label
  ///
  /// In en, this message translates to:
  /// **'Plan menu'**
  String get workoutPlanMenu;

  /// Workouts hub delete plan confirmation
  ///
  /// In en, this message translates to:
  /// **'Delete {plan}? This cannot be undone.'**
  String workoutDeleteConfirmation(String plan);

  /// Workouts hub AI feature title
  ///
  /// In en, this message translates to:
  /// **'AI workouts'**
  String get workoutAiTitle;

  /// Workouts hub AI feature description
  ///
  /// In en, this message translates to:
  /// **'Plans built for you from your history and goals.'**
  String get workoutAiBody;

  /// Workouts hub AI feature list item
  ///
  /// In en, this message translates to:
  /// **'AI-generated workout plans'**
  String get workoutAiPlans;

  /// Workouts hub AI feature list item
  ///
  /// In en, this message translates to:
  /// **'Advanced progress analytics'**
  String get workoutAiAnalytics;

  /// Workouts hub AI feature list item
  ///
  /// In en, this message translates to:
  /// **'Expanded exercise library'**
  String get workoutAiLibrary;

  /// Workouts hub AI feature list item
  ///
  /// In en, this message translates to:
  /// **'Priority support'**
  String get workoutAiSupport;

  /// Workouts hub subscription action
  ///
  /// In en, this message translates to:
  /// **'Upgrade to VIP'**
  String get workoutUpgradeVip;

  /// Workouts hub VIP AI state heading
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get workoutComingSoon;

  /// Workouts hub VIP AI state description
  ///
  /// In en, this message translates to:
  /// **'We are training the model on your workout history.'**
  String get workoutAiTrainingBody;

  /// Workouts hub VIP AI state action
  ///
  /// In en, this message translates to:
  /// **'Try the beta generator'**
  String get workoutTryBeta;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
