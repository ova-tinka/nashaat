import 'package:flutter/material.dart';

import '../core/entities/workout-plan-entity.dart';
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

  // ── Workout feature ───────────────────────────────────────────────────────

  void showWorkoutBuilder({String? editPlanId}) {
    Log.nav('showWorkoutBuilder${editPlanId != null ? ' (edit)' : ''}');
    _navigator?.pushNamed(
      '/workout-builder',
      arguments: editPlanId != null ? {'planId': editPlanId} : null,
    );
  }

  void showExerciseLibrary() {
    Log.nav('showExerciseLibrary');
    _navigator?.pushNamed('/exercise-library');
  }

  void showActiveSession(WorkoutPlanEntity plan) {
    Log.nav('showActiveSession: ${plan.title}');
    _navigator?.pushNamed('/active-session', arguments: plan);
  }

  void showAiGeneration() {
    Log.nav('showAiGeneration');
    _navigator?.pushNamed('/ai-generation');
  }

  // ── Settings ─────────────────────────────────────────────────────────────

  void showSettings() {
    Log.nav('showSettings');
    _navigator?.pushNamed('/settings');
  }

  // ── Legacy / other features ───────────────────────────────────────────────

  void showLogActivity() {
    Log.nav('showLogActivity → dashboard');
    showDashboard();
  }

  void showBlocking({required String userId}) {
    Log.nav('showBlocking — available via shell Focus tab');
    showDashboard();
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
