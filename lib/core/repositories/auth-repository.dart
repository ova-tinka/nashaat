/// Returned by every successful authentication method.
class AuthResult {
  final String userId;
  final String email;

  const AuthResult({required this.userId, required this.email});
}

abstract class AuthRepository {
  /// The currently signed-in user's ID, or null when not authenticated.
  String? get currentUserId;

  // ── Email-only demo authentication ───────────────────────────────────────

  /// Signs in with an email address using the demo authentication flow.
  Future<AuthResult> signInWithEmail(String email);

  /// Creates an account with an email address using the demo authentication flow.
  Future<AuthResult> signUpWithEmail(String email);

  // ── Session ───────────────────────────────────────────────────────────────

  Future<void> signOut();

  /// Returns true when the current user has not yet completed onboarding
  /// (i.e. profiles.status != 'onboarded').
  Future<bool> needsOnboarding();

  Future<void> deleteAccount();
}
