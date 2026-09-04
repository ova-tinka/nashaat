import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/repositories/auth-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

/// Concrete Supabase implementation of [AuthRepository].
///
/// This repository currently uses a demo-only email flow. Supabase's
/// password provider still requires a password internally, so a public
/// internal value is used and never shown in the UI. Do not ship this mode to
/// real users.
class SupabaseAuthRepository implements AuthRepository {
  final _supabase = SupabaseClientProvider.client;
  final _auth = SupabaseClientProvider.auth;

  static const _demoAuthPassword = 'nashaat-demo-email-only-2026';

  @override
  String? get currentUserId => _auth.currentUser?.id;

  // ── Email-only demo authentication ───────────────────────────────────────

  @override
  Future<AuthResult> signInWithEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    Log.auth('signing in with email → ${_mask(normalizedEmail)}');
    final response = await _auth.signInWithPassword(
      email: normalizedEmail,
      password: _demoAuthPassword,
    );
    return _toAuthResult(response, normalizedEmail);
  }

  @override
  Future<AuthResult> signUpWithEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    Log.auth('signing up with email → ${_mask(normalizedEmail)}');
    final response = await _auth.signUp(
      email: normalizedEmail,
      password: _demoAuthPassword,
    );
    if (response.session == null) {
      throw StateError(
        'Email confirmation is enabled. Disable it for demo email-only auth.',
      );
    }
    return _toAuthResult(response, normalizedEmail);
  }

  AuthResult _toAuthResult(AuthResponse response, String fallbackEmail) {
    final user = response.user;
    if (user == null) throw Exception('Email authentication failed.');
    Log.auth('email authentication ✓ — uid ${user.id.substring(0, 8)}…');
    return AuthResult(userId: user.id, email: user.email ?? fallbackEmail);
  }

  // ── Session ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() {
    Log.auth('signing out');
    return _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    Log.auth('deleting account');
    await _auth.updateUser(
      UserAttributes(data: {'deleted_at': DateTime.now().toIso8601String()}),
    );
  }

  @override
  Future<bool> needsOnboarding() async {
    final userId = currentUserId;
    if (userId == null) {
      Log.auth('needsOnboarding — no current user → true');
      return true;
    }

    final data = await _supabase
        .from('profiles')
        .select('status')
        .eq('id', userId)
        .maybeSingle();

    final needs = data == null || data['status'] != 'onboarded';
    Log.auth(
      'needsOnboarding → $needs '
      '(status: ${data?['status'] ?? 'no profile'})',
    );
    return needs;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  /// Shows first 3 chars + *** + @domain, e.g. "ayh***@gmail.com"
  String _mask(String email) {
    final at = email.indexOf('@');
    if (at <= 3) return '***${email.substring(at)}';
    return '${email.substring(0, 3)}***${email.substring(at)}';
  }
}
