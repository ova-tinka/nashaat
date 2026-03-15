import 'package:flutter/foundation.dart';

import '../../../core/repositories/auth-repository.dart';
import '../../../shared/logger.dart';
import '../model/auth-models.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _auth;

  AuthFlowStep _step = AuthFlowStep.idle;
  OtpMethod _otpMethod = OtpMethod.email;
  String? _pendingEmail;
  String? _pendingPhone;
  String? _errorMessage;
  bool _needsOnboarding = false;
  int _otpFailures = 0;
  DateTime? _lockoutUntil;

  AuthViewModel(this._auth);

  AuthFlowStep get step => _step;
  OtpMethod get otpMethod => _otpMethod;
  String? get pendingContact =>
      _otpMethod == OtpMethod.email ? _pendingEmail : _pendingPhone;
  String? get errorMessage => _errorMessage;
  bool get needsOnboarding => _needsOnboarding;
  bool get isLockedOut =>
      _lockoutUntil != null && _lockoutUntil!.isAfter(DateTime.now());

  // ── Email OTP ─────────────────────────────────────────────────────────────

  Future<void> sendEmailOtp(String email) async {
    _setLoading();
    try {
      await _auth.sendEmailOtp(email);
      _pendingEmail = email;
      _otpMethod = OtpMethod.email;
      _otpFailures = 0;
      _step = AuthFlowStep.otpSent;
      Log.auth('step → otpSent (email)');
      notifyListeners();
    } catch (e) {
      Log.error('auth', e);
      _setError(e);
    }
  }

  // ── Phone OTP ─────────────────────────────────────────────────────────────

  Future<void> sendPhoneOtp(String phone) async {
    _setLoading();
    try {
      await _auth.sendPhoneOtp(phone);
      _pendingPhone = phone;
      _otpMethod = OtpMethod.phone;
      _otpFailures = 0;
      _step = AuthFlowStep.otpSent;
      Log.auth('step → otpSent (phone)');
      notifyListeners();
    } catch (e) {
      Log.error('auth', e);
      _setError(e);
    }
  }

  // ── OTP verification ──────────────────────────────────────────────────────

  Future<void> verifyOtp(String token) async {
    if (isLockedOut) {
      Log.auth('OTP verify blocked — account locked out');
      _step = AuthFlowStep.error;
      _errorMessage = 'Too many attempts. Try again in 15 minutes.';
      notifyListeners();
      return;
    }

    _setLoading();
    try {
      if (_otpMethod == OtpMethod.email) {
        await _auth.verifyEmailOtp(_pendingEmail!, token);
      } else {
        await _auth.verifyPhoneOtp(_pendingPhone!, token);
      }
      _needsOnboarding = await _auth.needsOnboarding();
      _step = AuthFlowStep.success;
      Log.auth('step → success (needsOnboarding: $_needsOnboarding)');
      notifyListeners();
    } catch (e) {
      _otpFailures++;
      if (_otpFailures >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(minutes: 15));
        Log.auth('too many OTP failures — locked out for 15 min');
      } else {
        Log.auth('OTP failure $_otpFailures/5');
      }
      Log.error('auth', e);
      _setError(e);
    }
  }

  // ── Social sign-in ────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    _setLoading();
    try {
      await _auth.signInWithGoogle();
      _needsOnboarding = await _auth.needsOnboarding();
      _step = AuthFlowStep.success;
      Log.auth('step → success via Google (needsOnboarding: $_needsOnboarding)');
      notifyListeners();
    } catch (e) {
      Log.error('auth', e);
      _setError(e);
    }
  }

  Future<void> signInWithApple() async {
    _setLoading();
    try {
      await _auth.signInWithApple();
      _needsOnboarding = await _auth.needsOnboarding();
      _step = AuthFlowStep.success;
      Log.auth('step → success via Apple (needsOnboarding: $_needsOnboarding)');
      notifyListeners();
    } catch (e) {
      Log.error('auth', e);
      _setError(e);
    }
  }

  // ── Resend ────────────────────────────────────────────────────────────────

  Future<void> resendOtp() async {
    if (_otpMethod == OtpMethod.email && _pendingEmail != null) {
      await sendEmailOtp(_pendingEmail!);
    } else if (_otpMethod == OtpMethod.phone && _pendingPhone != null) {
      await sendPhoneOtp(_pendingPhone!);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void reset() {
    _step = AuthFlowStep.idle;
    _pendingEmail = null;
    _pendingPhone = null;
    _errorMessage = null;
    _otpFailures = 0;
    _lockoutUntil = null;
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
    if (msg.contains('cancelled') || msg.contains('canceled')) return '';
    if (msg.contains('invalid') || msg.contains('expired')) {
      return 'Invalid or expired code. Please try again.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('rate') || msg.contains('too many')) {
      return 'Too many requests. Please wait and try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
