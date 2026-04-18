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
