import 'package:flutter/material.dart';

import '../shared/logger.dart';

class AppCoordinator {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState? get _navigator => navigatorKey.currentState;

  // ── Auth ──────────────────────────────────────────────────────────────────

  void showLogin() {
    Log.nav('showLogin (stack cleared)');
    _navigator?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void showRegister() {
    Log.nav('showRegister');
    _navigator?.pushNamed('/register');
  }

  // ── Post-auth destinations (clear entire stack) ───────────────────────────

  void showOnboarding() {
    Log.nav('showOnboarding (stack cleared)');
    _navigator?.pushNamedAndRemoveUntil('/onboarding', (_) => false);
  }

  void showDashboard() {
    Log.nav('showDashboard (stack cleared)');
    _navigator?.pushNamedAndRemoveUntil('/dashboard', (_) => false);
  }

  // ── Feature navigation ────────────────────────────────────────────────────

  void showLogActivity() {
    Log.nav('showLogActivity');
    _navigator?.pushNamed('/log-activity');
  }

  void showBlocking({required String userId}) {
    Log.nav('showBlocking');
    _navigator?.pushNamed('/blocking', arguments: {'userId': userId});
  }

  void showSubscription() {
    Log.nav('showSubscription');
    _navigator?.pushNamed('/subscription');
  }

  void pop() {
    Log.nav('pop');
    _navigator?.pop();
  }
}
