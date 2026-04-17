import 'package:flutter/material.dart';

import '../core/entities/workout-plan-entity.dart';
import '../features/auth/view/auth-gate.dart';
import '../features/auth/view/login-screen.dart';
import '../features/auth/view/register-screen.dart';
import '../features/onboarding/view/onboarding-screen.dart';
import '../features/settings/view/settings-screen.dart';
import '../features/shell/view/app-shell-screen.dart';
import '../features/workout/view/active-session-screen.dart';
import '../features/workout/view/ai-generation-screen.dart';
import '../features/workout/view/exercise-detail-screen.dart';
import '../features/workout/view/exercise-library-screen.dart';
import '../features/workout/view/workout-builder-screen.dart';
import '../shared/logger.dart';

class AppRouter {
  // ── Auth ──────────────────────────────────────────────────────────────────
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String onboarding = '/onboarding';

  // ── Authenticated shell ───────────────────────────────────────────────────
  static const String dashboard = '/dashboard';

  // ── Workout feature ───────────────────────────────────────────────────────
  static const String workoutBuilder = '/workout-builder';
  static const String exerciseLibrary = '/exercise-library';
  static const String exerciseDetail = '/exercise-detail';
  static const String activeSession = '/active-session';
  static const String aiGeneration = '/ai-generation';

  // ── Settings ──────────────────────────────────────────────────────────────
  static const String settings = '/settings';

  // ── Legacy routes kept for compat ─────────────────────────────────────────
  static const String logActivity = '/log-activity';
  static const String blocking = '/blocking';
  static const String subscription = '/subscription';

  static Route<dynamic> generateRoute(RouteSettings routeSettings) {
    final route = routeSettings.name ?? '?';
    Log.nav('→ $route');

    switch (routeSettings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const AuthGate());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());

      case dashboard:
        return MaterialPageRoute(builder: (_) => const AppShellScreen());

      // ── Workout ──────────────────────────────────────────────────────────

      case workoutBuilder:
        final args = routeSettings.arguments as Map<String, dynamic>?;
        final planId = args?['planId'] as String?;
        return MaterialPageRoute(
          builder: (_) => WorkoutBuilderScreen(editPlanId: planId),
          fullscreenDialog: planId == null,
        );

      case exerciseLibrary:
        return MaterialPageRoute(
          builder: (_) => const ExerciseLibraryScreen(),
        );

      case exerciseDetail:
        final exercise = routeSettings.arguments as dynamic;
        return MaterialPageRoute(
          builder: (_) => ExerciseDetailScreen(exercise: exercise),
        );

      case activeSession:
        final plan = routeSettings.arguments as WorkoutPlanEntity;
        return MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(plan: plan),
          fullscreenDialog: true,
        );

      case aiGeneration:
        return MaterialPageRoute(
          builder: (_) => const AiGenerationScreen(),
          fullscreenDialog: true,
        );

      // ── Settings ─────────────────────────────────────────────────────────

      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());

      // ── Placeholder / legacy routes ──────────────────────────────────────

      case logActivity:
        Log.nav('$route — redirected to dashboard');
        return MaterialPageRoute(builder: (_) => const AppShellScreen());

      case subscription:
        Log.nav('$route — subscription screen (placeholder)');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Subscription')),
            body: const Center(child: Text('Subscription management coming soon.')),
          ),
        );

      default:
        Log.nav('$route — no route found');
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}
