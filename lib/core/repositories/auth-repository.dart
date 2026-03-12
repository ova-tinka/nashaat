/// Returned by every successful authentication method.
class AuthResult {
  final String userId;
  final String email;

  const AuthResult({required this.userId, required this.email});
}

abstract class AuthRepository {
  /// The currently signed-in user's ID, or null when not authenticated.
  String? get currentUserId;

  // ── Email OTP (passwordless) ──────────────────────────────────────────────

  /// Sends a 6-digit OTP to [email]. Creates the account if it does not exist.
  Future<void> sendEmailOtp(String email);

  /// Confirms the OTP [token] sent to [email].
  Future<AuthResult> verifyEmailOtp(String email, String token);

  // ── Phone / SMS OTP ───────────────────────────────────────────────────────

  /// Sends an SMS OTP to [phone] (E.164 format, e.g. +966501234567).
  Future<void> sendPhoneOtp(String phone);

  /// Confirms the SMS [token] sent to [phone].
  Future<AuthResult> verifyPhoneOtp(String phone, String token);

  // ── Social ────────────────────────────────────────────────────────────────

  /// Native Google sign-in via ID-token exchange with Supabase.
  Future<AuthResult> signInWithGoogle();

  /// Native Apple sign-in via ID-token + nonce exchange (iOS 13+).
  Future<AuthResult> signInWithApple();

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> signOut();

  /// Returns true when the current user has not yet completed onboarding
  /// (i.e. profiles.status != 'onboarded').
  Future<bool> needsOnboarding();
}
