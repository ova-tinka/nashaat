import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../infra/repository-locator.dart';
import '../../../main.dart';
import '../../../shared/design/tokens/app-colors.dart';

/// Entry point of the app. Checks for an active Supabase session and routes
/// to Login, Onboarding, or Dashboard accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Defer to allow the navigator to be ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      appCoordinator.showLogin();
      return;
    }

    try {
      final repo = RepositoryLocator.instance.auth;
      final needsOnboarding = await repo.needsOnboarding();
      if (!mounted) return;
      if (needsOnboarding) {
        appCoordinator.showOnboarding();
      } else {
        appCoordinator.showDashboard();
      }
    } catch (_) {
      if (mounted) appCoordinator.showLogin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.paper,
      body: Center(child: CircularProgressIndicator(color: AppColors.ink)),
    );
  }
}
