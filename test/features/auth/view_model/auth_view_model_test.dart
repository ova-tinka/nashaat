import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/repositories/auth-repository.dart';
import 'package:nashaat/features/auth/model/auth-models.dart';
import 'package:nashaat/features/auth/view-model/auth-view-model.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockAuthRepository mockAuth;
  late AuthViewModel vm;

  setUpAll(() {
    registerFallbackValue(const AuthResult(userId: '', email: ''));
  });

  setUp(() {
    mockAuth = MockAuthRepository();
    vm = AuthViewModel(mockAuth);
  });

  tearDown(() => vm.dispose());

  // ── Initial state ──────────────────────────────────────────────────────────

  group('initial state', () {
    test('step is idle', () {
      expect(vm.step, AuthFlowStep.idle);
    });

    test('no error', () {
      expect(vm.errorMessage, isNull);
    });

    test('isLockedOut is false', () {
      expect(vm.isLockedOut, isFalse);
    });

    test('needsOnboarding is false', () {
      expect(vm.needsOnboarding, isFalse);
    });
  });

  // ── sendEmailOtp ───────────────────────────────────────────────────────────

  group('sendEmailOtp', () {
    test('success: calls repo, step → otpSent, sets pendingContact and method',
        () async {
      when(() => mockAuth.sendEmailOtp(any())).thenAnswer((_) async {});

      await vm.sendEmailOtp('user@example.com');

      verify(() => mockAuth.sendEmailOtp('user@example.com')).called(1);
      expect(vm.step, AuthFlowStep.otpSent);
      expect(vm.pendingContact, 'user@example.com');
      expect(vm.otpMethod, OtpMethod.email);
    });

    test('failure: step → error, errorMessage is non-empty for non-cancel',
        () async {
      when(() => mockAuth.sendEmailOtp(any()))
          .thenThrow(Exception('network error'));

      await vm.sendEmailOtp('user@example.com');

      expect(vm.step, AuthFlowStep.error);
      expect(vm.errorMessage, isNotEmpty);
    });
  });

  // ── sendPhoneOtp ───────────────────────────────────────────────────────────

  group('sendPhoneOtp', () {
    test('success: calls repo, step → otpSent, sets pendingContact and method',
        () async {
      when(() => mockAuth.sendPhoneOtp(any())).thenAnswer((_) async {});

      await vm.sendPhoneOtp('+966501234567');

      verify(() => mockAuth.sendPhoneOtp('+966501234567')).called(1);
      expect(vm.step, AuthFlowStep.otpSent);
      expect(vm.pendingContact, '+966501234567');
      expect(vm.otpMethod, OtpMethod.phone);
    });
  });

  // ── verifyOtp ──────────────────────────────────────────────────────────────

  group('verifyOtp', () {
    setUp(() {
      when(() => mockAuth.sendEmailOtp(any())).thenAnswer((_) async {});
    });

    test('email success: calls verifyEmailOtp, needsOnboarding set, step → success',
        () async {
      when(() => mockAuth.verifyEmailOtp(any(), any())).thenAnswer(
          (_) async => const AuthResult(userId: 'u1', email: 'user@example.com'));
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => true);

      await vm.sendEmailOtp('user@example.com');
      await vm.verifyOtp('123456');

      verify(() => mockAuth.verifyEmailOtp('user@example.com', '123456'))
          .called(1);
      expect(vm.step, AuthFlowStep.success);
      expect(vm.needsOnboarding, isTrue);
    });

    test('phone success: calls verifyPhoneOtp', () async {
      when(() => mockAuth.sendPhoneOtp(any())).thenAnswer((_) async {});
      when(() => mockAuth.verifyPhoneOtp(any(), any())).thenAnswer(
          (_) async => const AuthResult(userId: 'u1', email: ''));
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => false);

      await vm.sendPhoneOtp('+966501234567');
      await vm.verifyOtp('123456');

      verify(() => mockAuth.verifyPhoneOtp('+966501234567', '123456')).called(1);
      expect(vm.step, AuthFlowStep.success);
    });

    test('failure increments failure counter, step → error', () async {
      when(() => mockAuth.verifyEmailOtp(any(), any()))
          .thenThrow(Exception('invalid otp'));

      await vm.sendEmailOtp('user@example.com');
      await vm.verifyOtp('wrong');

      expect(vm.step, AuthFlowStep.error);
      // errorMessage contains "Invalid or expired"
      expect(vm.errorMessage, contains('Invalid'));
    });

    test('5 failures trigger lockout: isLockedOut=true', () async {
      when(() => mockAuth.verifyEmailOtp(any(), any()))
          .thenThrow(Exception('invalid otp'));

      await vm.sendEmailOtp('user@example.com');
      for (int i = 0; i < 5; i++) {
        await vm.verifyOtp('wrong');
      }

      expect(vm.isLockedOut, isTrue);
      expect(vm.step, AuthFlowStep.error);
    });

    test('verifyOtp when locked out returns immediately, does NOT call repo',
        () async {
      when(() => mockAuth.verifyEmailOtp(any(), any()))
          .thenThrow(Exception('invalid otp'));

      await vm.sendEmailOtp('user@example.com');
      // Trigger lockout
      for (int i = 0; i < 5; i++) {
        await vm.verifyOtp('wrong');
      }

      clearInteractions(mockAuth);

      // Now try again — should be blocked
      await vm.verifyOtp('123456');

      verifyNever(() => mockAuth.verifyEmailOtp(any(), any()));
      expect(vm.errorMessage, contains('Too many attempts'));
    });
  });

  // ── signInWithGoogle ───────────────────────────────────────────────────────

  group('signInWithGoogle', () {
    test('success: step → success, needsOnboarding set', () async {
      when(() => mockAuth.signInWithGoogle()).thenAnswer(
          (_) async => const AuthResult(userId: 'u1', email: 'g@gmail.com'));
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => false);

      await vm.signInWithGoogle();

      expect(vm.step, AuthFlowStep.success);
      expect(vm.needsOnboarding, isFalse);
    });

    test('failure: step → error', () async {
      when(() => mockAuth.signInWithGoogle())
          .thenThrow(Exception('Google sign-in cancelled.'));

      await vm.signInWithGoogle();

      expect(vm.step, AuthFlowStep.error);
    });
  });

  // ── signInWithApple ────────────────────────────────────────────────────────

  group('signInWithApple', () {
    test('success: step → success', () async {
      when(() => mockAuth.signInWithApple()).thenAnswer(
          (_) async => const AuthResult(userId: 'u1', email: 'a@apple.com'));
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => true);

      await vm.signInWithApple();

      expect(vm.step, AuthFlowStep.success);
      expect(vm.needsOnboarding, isTrue);
    });
  });

  // ── resendOtp ──────────────────────────────────────────────────────────────

  group('resendOtp', () {
    test('resends to email when otpMethod is email', () async {
      when(() => mockAuth.sendEmailOtp(any())).thenAnswer((_) async {});

      await vm.sendEmailOtp('user@example.com');
      clearInteractions(mockAuth);
      when(() => mockAuth.sendEmailOtp(any())).thenAnswer((_) async {});

      await vm.resendOtp();

      verify(() => mockAuth.sendEmailOtp('user@example.com')).called(1);
    });

    test('resends to phone when otpMethod is phone', () async {
      when(() => mockAuth.sendPhoneOtp(any())).thenAnswer((_) async {});

      await vm.sendPhoneOtp('+966501234567');
      clearInteractions(mockAuth);
      when(() => mockAuth.sendPhoneOtp(any())).thenAnswer((_) async {});

      await vm.resendOtp();

      verify(() => mockAuth.sendPhoneOtp('+966501234567')).called(1);
    });
  });

  // ── reset ──────────────────────────────────────────────────────────────────

  group('reset', () {
    test('step → idle, no error, failures reset', () async {
      when(() => mockAuth.sendEmailOtp(any())).thenAnswer((_) async {});
      when(() => mockAuth.verifyEmailOtp(any(), any()))
          .thenThrow(Exception('invalid'));

      await vm.sendEmailOtp('user@example.com');
      await vm.verifyOtp('wrong');

      vm.reset();

      expect(vm.step, AuthFlowStep.idle);
      expect(vm.errorMessage, isNull);
      expect(vm.isLockedOut, isFalse);
    });
  });

  // ── friendly error messages ────────────────────────────────────────────────

  group('friendly error messages', () {
    test("'invalid' in error → specific invalid/expired message", () async {
      when(() => mockAuth.sendEmailOtp(any()))
          .thenThrow(Exception('invalid token'));

      await vm.sendEmailOtp('user@example.com');

      expect(vm.errorMessage, contains('Invalid or expired'));
    });

    test("'network' in error → network message", () async {
      when(() => mockAuth.sendEmailOtp(any()))
          .thenThrow(Exception('network failure'));

      await vm.sendEmailOtp('user@example.com');

      expect(vm.errorMessage, contains('internet'));
    });

    test("'cancelled' in error → empty string", () async {
      when(() => mockAuth.signInWithGoogle())
          .thenThrow(Exception('cancelled by user'));

      await vm.signInWithGoogle();

      expect(vm.errorMessage, isEmpty);
    });
  });
}
