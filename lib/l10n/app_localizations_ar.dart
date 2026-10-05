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
  String get onboardingFreeTime => 'وقت الفراغ أسبوعياً';

  @override
  String get onboardingSmallSessionReward => 'لكل جلسة صغيرة';

  @override
  String get onboardingBigSessionReward => 'لكل جلسة كبيرة';

  @override
  String get onboardingWeeklySessionSplit => 'توزيع الجلسات الأسبوعية';

  @override
  String get onboardingSmallSessions => 'جلسات صغيرة (1×)';

  @override
  String get onboardingBigSessions => 'جلسات كبيرة (2×)';

  @override
  String get onboardingBlockingBody =>
      'اختر التطبيقات التي تريد حظرها عند انتهاء وقت الشاشة.\nيمكنك تغيير ذلك لاحقاً.';

  @override
  String get onboardingSelectApps => 'اختيار التطبيقات عبر وقت الشاشة';

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
}
