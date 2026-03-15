import 'package:flutter/material.dart';

import '../features/auth/view/auth-gate.dart';
import '../features/auth/view/login-screen.dart';
import '../features/auth/view/register-screen.dart';
import '../features/blocking/view/blocking-screen.dart';
import '../shared/logger.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String logActivity = '/log-activity';
  static const String blocking = '/blocking';
  static const String subscription = '/subscription';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final route = settings.name ?? '?';
    Log.nav('→ $route');

    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const AuthGate());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());

      case blocking:
        final args = settings.arguments as Map<String, dynamic>?;
        final userId = args?['userId'] as String? ?? '';
        Log.nav('blocking screen for user ${userId.substring(0, 8)}…');
        return MaterialPageRoute(
          builder: (_) => BlockingScreen(userId: userId),
        );

      // TODO: wire up remaining feature screens as they are implemented.
      case onboarding:
      case dashboard:
      case logActivity:
      case subscription:
        Log.nav('$route — placeholder screen');
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(settings.name ?? '')),
            body: Center(child: Text('${settings.name} — coming soon')),
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
