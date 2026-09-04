import 'package:flutter/foundation.dart';

import '../../../core/repositories/auth-repository.dart';
import '../../../shared/logger.dart';
import '../model/auth-models.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _auth;

  AuthFlowStep _step = AuthFlowStep.idle;
  String? _errorMessage;
  bool _needsOnboarding = false;

  AuthViewModel(this._auth);

  AuthFlowStep get step => _step;
  String? get errorMessage => _errorMessage;
  bool get needsOnboarding => _needsOnboarding;

  Future<void> signInWithEmail(String email) async {
    await _authenticate(() => _auth.signInWithEmail(email), 'sign-in');
  }

  Future<void> signUpWithEmail(String email) async {
    await _authenticate(() => _auth.signUpWithEmail(email), 'sign-up');
  }

  Future<void> _authenticate(
    Future<AuthResult> Function() action,
    String operation,
  ) async {
    _setLoading();
    try {
      await action();
      _needsOnboarding = await _auth.needsOnboarding();
      _step = AuthFlowStep.success;
      Log.auth(
        'step → success via email $operation '
        '(needsOnboarding: $_needsOnboarding)',
      );
      notifyListeners();
    } catch (e) {
      Log.error('auth', e);
      _setError(e);
    }
  }

  void reset() {
    _step = AuthFlowStep.idle;
    _errorMessage = null;
    _needsOnboarding = false;
    notifyListeners();
  }

  void _setLoading() {
    _step = AuthFlowStep.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(Object e) {
    _step = AuthFlowStep.error;
    _errorMessage = _friendlyError(e);
    notifyListeners();
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('email confirmation')) {
      return 'Disable email confirmation in Supabase for demo email-only sign-in.';
    }
    if (msg.contains('invalid_credentials') ||
        msg.contains('invalid login credentials')) {
      return 'This email is not set up for the current demo auth. Use a new email, or delete this test user in Supabase and register again.';
    }
    if (msg.contains('invalid') ||
        msg.contains('credentials') ||
        msg.contains('not found')) {
      return 'Could not authenticate with this email. Please try again.';
    }
    if (msg.contains('network') ||
        msg.contains('socket') ||
        msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many requests. Please wait and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
