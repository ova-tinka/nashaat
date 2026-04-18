import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/repositories/auth-repository.dart';
import '../../shared/logger.dart';
import 'supabase-client.dart';

/// Concrete Supabase implementation of [AuthRepository].
///
/// Native setup required before shipping:
/// ─ Google: add google-services.json (Android) & GoogleService-Info.plist (iOS),
///   set the SHA-1 fingerprint in Firebase, and configure the OAuth client ID
///   in the Supabase dashboard under Auth → Providers → Google.
/// ─ Apple: enable "Sign in with Apple" capability in Xcode and configure the
///   Apple OAuth app in the Supabase dashboard under Auth → Providers → Apple.
/// ─ Phone SMS: enable the Phone provider in Supabase dashboard and set up a
///   Twilio / MessageBird account in Auth → Providers → Phone.
class SupabaseAuthRepository implements AuthRepository {
  final _supabase = SupabaseClientProvider.client;
  final _auth = SupabaseClientProvider.auth;

  @override
  String? get currentUserId => _auth.currentUser?.id;

  // ── Email OTP ─────────────────────────────────────────────────────────────

  @override
  Future<void> sendEmailOtp(String email) async {
    Log.auth('sending OTP → ${_mask(email)}');
    await _auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
    Log.auth('OTP sent ✓');
  }

  @override
  Future<AuthResult> verifyEmailOtp(String email, String token) async {
    Log.auth('verifying email OTP for ${_mask(email)}');
    final response = await _auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    final user = response.user;
    if (user == null) throw Exception('Email OTP verification failed.');
    Log.auth('email OTP verified ✓ — uid ${user.id.substring(0, 8)}…');
    return AuthResult(userId: user.id, email: user.email ?? email);
  }

  // ── Phone / SMS OTP ───────────────────────────────────────────────────────

  @override
  Future<void> sendPhoneOtp(String phone) async {
    Log.auth('sending SMS OTP → ${_maskPhone(phone)}');
    await _auth.signInWithOtp(phone: phone);
    Log.auth('SMS OTP sent ✓');
  }

  @override
  Future<AuthResult> verifyPhoneOtp(String phone, String token) async {
    Log.auth('verifying SMS OTP for ${_maskPhone(phone)}');
    final response = await _auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    final user = response.user;
    if (user == null) throw Exception('Phone OTP verification failed.');
    Log.auth('SMS OTP verified ✓ — uid ${user.id.substring(0, 8)}…');
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Google ────────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> signInWithGoogle() async {
    // TODO: set clientId to your iOS OAuth client ID from Google Cloud Console.
    Log.auth('Google sign-in started');
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isEmpty ? null : webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled.');
    Log.auth('Google account selected: ${googleUser.email}');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to retrieve Google ID token.');

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );

    final user = response.user;
    if (user == null) throw Exception('Google authentication failed.');
    Log.auth('Google sign-in ✓ — uid ${user.id.substring(0, 8)}…');
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> signInWithApple() async {
    Log.auth('Apple sign-in started');
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );
    Log.auth('Apple credential received');

    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Failed to retrieve Apple ID token.');

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final user = response.user;
    if (user == null) throw Exception('Apple authentication failed.');
    Log.auth('Apple sign-in ✓ — uid ${user.id.substring(0, 8)}…');
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Session ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() {
    Log.auth('signing out');
    return _auth.signOut();
  }

  @override
  Future<void> changePassword(String newPassword) async {
    Log.auth('changing password');
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> deleteAccount() async {
    Log.auth('deleting account');
    await _auth.updateUser(UserAttributes(
      data: {'deleted_at': DateTime.now().toIso8601String()},
    ));
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
    Log.auth('needsOnboarding → $needs (status: ${data?['status'] ?? 'no profile'})');
    return needs;
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Shows first 3 chars + *** + @domain, e.g. "ayh***@gmail.com"
  String _mask(String email) {
    final at = email.indexOf('@');
    if (at <= 3) return '***${email.substring(at)}';
    return '${email.substring(0, 3)}***${email.substring(at)}';
  }

  /// Shows last 4 digits only, e.g. "•••• 4321"
  String _maskPhone(String phone) {
    if (phone.length <= 4) return phone;
    return '•••• ${phone.substring(phone.length - 4)}';
  }
}
