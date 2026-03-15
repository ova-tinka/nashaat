import 'package:flutter/material.dart';

class AppCoordinator {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState? get _navigator => navigatorKey.currentState;

  // ── Auth ──────────────────────────────────────────────────────────────────

  void showLogin() {
    _navigator?.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void showRegister() {
    _navigator?.pushNamed('/register');
  }

  // ── Post-auth destinations (clear entire stack) ───────────────────────────

  void showOnboarding() {
    _navigator?.pushNamedAndRemoveUntil('/onboarding', (_) => false);
  }

  void showDashboard() {
    _navigator?.pushNamedAndRemoveUntil('/dashboard', (_) => false);
  }

  // ── Feature navigation ────────────────────────────────────────────────────

  void showLogActivity() {
    _navigator?.pushNamed('/log-activity');
  }

  void showBlocking({required String userId}) {
    _navigator?.pushNamed('/blocking', arguments: {'userId': userId});
  }

  void showSubscription() {
    _navigator?.pushNamed('/subscription');
  }

  void pop() {
    _navigator?.pop();
  }
}
