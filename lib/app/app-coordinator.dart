import 'package:flutter/material.dart';

class AppCoordinator {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  NavigatorState? get _navigator => navigatorKey.currentState;

  void showOnboarding() {
    _navigator?.pushReplacementNamed('/onboarding');
  }

  void showLogin() {
    _navigator?.pushNamed('/login');
  }

  void showRegister() {
    _navigator?.pushNamed('/register');
  }

  void showDashboard() {
    _navigator?.pushReplacementNamed('/dashboard');
  }

  void showLogActivity() {
    _navigator?.pushNamed('/log-activity');
  }

  void showBlocking() {
    _navigator?.pushNamed('/blocking');
  }

  void showSubscription() {
    _navigator?.pushNamed('/subscription');
  }

  void pop() {
    _navigator?.pop();
  }
}
