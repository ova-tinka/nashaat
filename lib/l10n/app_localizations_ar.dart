// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'نشاط';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get workouts => 'التمارين';

  @override
  String get settings => 'الإعدادات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get leaderboard => 'المتصدرون';

  @override
  String get friends => 'الأصدقاء';

  @override
  String get subscription => 'الاشتراك';

  @override
  String get logWorkout => 'تسجيل تمرين';

  @override
  String get startWorkout => 'بدء التمرين';

  @override
  String get completeWorkout => 'إنهاء التمرين';

  @override
  String get screenTimeBalance => 'رصيد وقت الشاشة';

  @override
  String get earnedToday => 'مكتسب اليوم';

  @override
  String get currentStreak => 'السلسلة الحالية';

  @override
  String get register => 'إنشاء حساب';

  @override
  String get login => 'تسجيل الدخول';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get confirmPassword => 'تأكيد كلمة المرور';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirm => 'تأكيد';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get back => 'رجوع';

  @override
  String get next => 'التالي';

  @override
  String get done => 'تم';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get networkError => 'خطأ في الاتصال بالشبكة';

  @override
  String get authError => 'خطأ في المصادقة';

  @override
  String get genericError => 'حدث خطأ ما';

  @override
  String get appBlocking => 'حظر التطبيقات';

  @override
  String get webBlocking => 'حظر المواقع';

  @override
  String get manageRules => 'إدارة القواعد';

  @override
  String get welcome => 'مرحباً بك';

  @override
  String get setGoals => 'تحديد الأهداف';

  @override
  String get setupBlocking => 'إعداد الحظر';

  @override
  String get onboardingWelcomeTitle => 'مرحباً بك في نشاط';

  @override
  String get onboardingLetsGo => 'لنبدأ';

  @override
  String onboardingStep(int current, int total) {
    return 'الخطوة $current من $total';
  }

  @override
  String get onboardingWelcomeBodyScreenTime =>
      'اكسب وقت الشاشة من خلال التمرين.\nابنِ انضباطك واستمراريتك.';

  @override
  String get onboardingWelcomeBodyWorkout => 'تتبّع تمارينك وابنِ استمراريتك.';

  @override
  String get onboardingNamePrompt => 'كيف نناديك؟';

  @override
  String get onboardingUsernameOptional => 'اسم المستخدم (اختياري)';

  @override
  String get onboardingUsernameHint => 'مثال: fitnessathlete';

  @override
  String get onboardingDaysTitle => 'كم يوماً ستتمرن كل أسبوع؟';

  @override
  String onboardingDaysPerWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم في الأسبوع',
      many: '$count يوماً في الأسبوع',
      few: '$count أيام في الأسبوع',
      two: 'يومان في الأسبوع',
      one: 'يوم واحد في الأسبوع',
      zero: 'لا أيام هذا الأسبوع',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDurationTitle => 'كم ستستغرق كل جلسة؟';

  @override
  String onboardingDurationOption(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String get onboardingPhoneTitle => 'ما معدل استخدامك للهاتف يومياً؟';

  @override
  String get onboardingPhoneBody =>
      'نستخدم هذا الرقم لمعايرة اقتصاد وقت الشاشة.';

  @override
  String onboardingPhoneHours(int hours) {
    return '$hoursس';
  }

  @override
  String get onboardingPhoneMinimum => 'ساعة';

  @override
  String get onboardingPhoneMaximum => '16 ساعة';

  @override
  String get onboardingRewardTitle => 'معاينة مكافآتك';

  @override
  String get onboardingWeeklyTarget => 'الهدف الأسبوعي';

  @override
  String get onboardingFreeTime => 'المتاح كل أسبوع (20٪)';

  @override
  String get onboardingSmallSessionReward => 'كل تمرين صغير';

  @override
  String get onboardingBigSessionReward => 'كل تمرين كبير';

  @override
  String get onboardingWeeklySessionSplit => 'توزيع الجلسات الأسبوعية';

  @override
  String get onboardingSmallSessions => 'جلسات صغيرة (1×)';

  @override
  String get onboardingBigSessions => 'جلسات كبيرة (2×)';

  @override
  String get onboardingSmallSessionShort => 'صغيرة (1×)';

  @override
  String get onboardingBigSessionShort => 'كبيرة (2×)';

  @override
  String get onboardingBlockingBody =>
      'اختر التطبيقات التي تريد حظرها عند انتهاء وقت الشاشة.\nيمكنك تغيير ذلك لاحقاً.';

  @override
  String get onboardingBlockingKicker => 'حظر التطبيقات';

  @override
  String get onboardingBlockingTitle =>
      'اختر التطبيقات التي تُقفل عند انتهاء وقتك';

  @override
  String get onboardingBlockingHint =>
      'تحافظ Apple على قائمتك بشكل خاص؛ لا يستطيع نشاط رؤية ما بداخل تطبيقاتك.';

  @override
  String get onboardingSelectApps => 'اختيار التطبيقات عبر وقت الشاشة';

  @override
  String get onboardingChooseViaScreenTime => 'اختيار عبر وقت الشاشة';

  @override
  String get onboardingAppsSelected => 'تم اختيار التطبيقات عبر وقت الشاشة';

  @override
  String get onboardingNoApps => 'لم يتم العثور على تطبيقات.';

  @override
  String get onboardingFinishSetup => 'إنهاء الإعداد';

  @override
  String get onboardingSkipForNow => 'تخطي الآن';

  @override
  String get workoutMyPlans => 'خططي';

  @override
  String get workoutLibrary => 'المكتبة';

  @override
  String get workoutAi => 'الذكاء الاصطناعي';

  @override
  String get workoutNewPlan => 'خطة جديدة';

  @override
  String get workoutStart => 'ابدأ';

  @override
  String get workoutNextWorkout => 'التمرين التالي';

  @override
  String get workoutRecommended => 'مقترح';

  @override
  String get workoutToday => 'اليوم';

  @override
  String get workoutYourPlans => 'خططك';

  @override
  String get workoutNoPlansTitle => 'ما عندك خطط للحين';

  @override
  String get workoutNoPlansScreenTime => 'سوّ أول خطة وابدأ تكسب وقت جوال.';

  @override
  String get workoutNoPlansTraining => 'سوّ أول خطة وابدأ تمارينك.';

  @override
  String get workoutCouldNotLoad => 'ما قدرنا نحمّل خططك.';

  @override
  String workoutExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمريناً',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'ولا تمرين',
    );
    return '$_temp0';
  }

  @override
  String workoutPlanSummary(int count, String duration) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمريناً',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
    );
    return '$_temp0 · $duration';
  }

  @override
  String get workoutPlanMenu => 'قائمة الخطة';

  @override
  String workoutDeleteConfirmation(String plan) {
    return 'تحذف $plan؟ ما تقدر ترجعها.';
  }

  @override
  String get workoutAiTitle => 'تمارين بالذكاء الاصطناعي';

  @override
  String get workoutAiBody => 'خطط مصمّمة لك من تاريخك وأهدافك.';

  @override
  String get workoutAiPlans => 'خطط تمارين بالذكاء الاصطناعي';

  @override
  String get workoutAiAnalytics => 'تحليلات تقدّم أعمق';

  @override
  String get workoutAiLibrary => 'مكتبة تمارين أكبر';

  @override
  String get workoutAiSupport => 'دعم بأولوية';

  @override
  String get workoutUpgradeVip => 'الترقية إلى VIP';

  @override
  String get workoutComingSoon => 'قريباً';

  @override
  String get workoutAiTrainingBody => 'ندرّب النموذج على تاريخ تمارينك.';

  @override
  String get workoutTryBeta => 'جرّب المولّد التجريبي';

  @override
  String get builderNewPlan => 'خطة جديدة';

  @override
  String get builderEditPlan => 'تعديل الخطة';

  @override
  String get builderPlanTitle => 'اسم الخطة *';

  @override
  String get builderPlanTitleHint => 'مثال: تمرين الصدر، تمارين الجسم كامل';

  @override
  String get builderDescriptionOptional => 'الوصف (اختياري)';

  @override
  String get builderSessionSize => 'حجم التمرين';

  @override
  String get builderSessionSizeBody =>
      'يحدد مقدار وقت الشاشة الذي يكسبه هذا التمرين.';

  @override
  String get builderSmall => 'صغير';

  @override
  String get builderBig => 'كبير ×2';

  @override
  String get builderSchedule => 'الأيام';

  @override
  String get builderExercises => 'التمارين';

  @override
  String get builderAddExercise => 'أضف تمريناً';

  @override
  String get builderNoExercises => 'ما أضفت تمارين للحين';

  @override
  String get builderSwapExercise => 'تبديل التمرين';

  @override
  String get builderRemoveExercise => 'حذف التمرين';

  @override
  String get builderSets => 'المجموعات';

  @override
  String get builderReps => 'العدّات';

  @override
  String get builderWeight => 'الوزن (كغ)';

  @override
  String get builderDuration => 'المدة (ث)';

  @override
  String get builderDistance => 'المسافة (كم)';

  @override
  String get builderRest => 'الراحة (ث)';

  @override
  String get builderSavePlan => 'حفظ الخطة';

  @override
  String get builderPlanCreated => 'انحفظت الخطة بنجاح';

  @override
  String get builderPlanUpdated => 'تحدّثت الخطة بنجاح';

  @override
  String builderExerciseCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تمرين',
      many: '$count تمريناً',
      few: '$count تمارين',
      two: 'تمرينان',
      one: 'تمرين واحد',
      zero: 'ولا تمرين',
    );
    return '$_temp0';
  }

  @override
  String get builderInvalidValue => 'تحقق من القيمة';

  @override
  String get activePause => 'إيقاف مؤقت';

  @override
  String get activeResume => 'استئناف';

  @override
  String get activePaused => 'متوقف';

  @override
  String get activeRunning => 'مستمر';

  @override
  String get activeDone => 'تم';

  @override
  String get activeFinish => 'إنهاء';

  @override
  String get activeQuitTitle => 'تطلع من التمرين؟';

  @override
  String get activeQuitBody => 'بتفقد تقدمك. متأكد؟';

  @override
  String get activeKeepGoing => 'كمل التمرين';

  @override
  String get activeQuit => 'خروج';

  @override
  String get activeCompleteSet => 'إنهاء المجموعة';

  @override
  String get activeSkip => 'تخطي';

  @override
  String get activeElapsed => 'الوقت المنقضي';

  @override
  String get activeRest => 'راحة';

  @override
  String get activeSkipRest => 'تخطي الراحة';

  @override
  String get activeUpNext => 'التالي';

  @override
  String get activeFinishSession => 'إنهاء الجلسة';

  @override
  String activeSetProgress(int current, int total) {
    return 'المجموعة $current من $total';
  }

  @override
  String get activeWorkoutComplete => 'خلص التمرين';

  @override
  String get activeSaving => 'جارٍ حفظ الجلسة...';

  @override
  String get activeStarting => 'جارٍ بدء الجلسة...';

  @override
  String get activeRetrySave => 'إعادة الحفظ';

  @override
  String get activeDuration => 'المدة';

  @override
  String get activeRewardPoints => 'نقاط المكافأة';

  @override
  String get activeNoRewardPoints => 'ما حصلت نقاط مكافأة لهذا التمرين';

  @override
  String get activePointBalance => 'رصيد النقاط';

  @override
  String activeTotalPoints(int points) {
    return 'إجمالي النقاط: $points';
  }

  @override
  String get activeWorkoutStreak => 'سلسلة التمارين';

  @override
  String activeStreakValue(int current, int longest) {
    return '$current أيام · الأطول: $longest';
  }

  @override
  String get activeEarned => 'المكتسب';

  @override
  String activeEarnedScreenTime(String minutes) {
    return '+$minutes وقت شاشة';
  }

  @override
  String get activeConfigureSettings => 'اضبطها من الإعدادات';

  @override
  String get activeWorkoutLogged => 'تم تسجيل التمرين';

  @override
  String get activeNewAchievements => 'إنجازات جديدة';

  @override
  String get activeBackToWorkouts => 'العودة إلى التمارين';

  @override
  String get activeThanks => 'شكراً!';
}
