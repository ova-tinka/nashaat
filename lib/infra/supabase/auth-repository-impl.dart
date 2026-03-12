import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/repositories/auth-repository.dart';
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
    await _auth.signInWithOtp(
      email: email,
      shouldCreateUser: true,
    );
  }

  @override
  Future<AuthResult> verifyEmailOtp(String email, String token) async {
    final response = await _auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
    final user = response.user;
    if (user == null) throw Exception('Email OTP verification failed.');
    return AuthResult(userId: user.id, email: user.email ?? email);
  }

  // ── Phone / SMS OTP ───────────────────────────────────────────────────────

  @override
  Future<void> sendPhoneOtp(String phone) async {
    await _auth.signInWithOtp(phone: phone);
  }

  @override
  Future<AuthResult> verifyPhoneOtp(String phone, String token) async {
    final response = await _auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    final user = response.user;
    if (user == null) throw Exception('Phone OTP verification failed.');
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Google ────────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> signInWithGoogle() async {
    // TODO: set clientId to your iOS OAuth client ID from Google Cloud Console.
    const webClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId.isEmpty ? null : webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled.');

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
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Apple ─────────────────────────────────────────────────────────────────

  @override
  Future<AuthResult> signInWithApple() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = credential.identityToken;
    if (idToken == null) throw Exception('Failed to retrieve Apple ID token.');

    final response = await _auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );

    final user = response.user;
    if (user == null) throw Exception('Apple authentication failed.');
    return AuthResult(userId: user.id, email: user.email ?? '');
  }

  // ── Session ───────────────────────────────────────────────────────────────

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<bool> needsOnboarding() async {
    final userId = currentUserId;
    if (userId == null) return true;

    final data = await _supabase
        .from('profiles')
        .select('status')
        .eq('id', userId)
        .maybeSingle();

    return data == null || data['status'] != 'onboarded';
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
}
