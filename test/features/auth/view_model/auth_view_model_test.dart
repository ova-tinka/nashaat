import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/core/repositories/auth-repository.dart';
import 'package:nashaat/features/auth/model/auth-models.dart';
import 'package:nashaat/features/auth/view-model/auth-view-model.dart';

import '../../../helpers/mock_repositories.dart';

void main() {
  late MockAuthRepository mockAuth;
  late AuthViewModel vm;

  setUp(() {
    mockAuth = MockAuthRepository();
    vm = AuthViewModel(mockAuth);
  });

  tearDown(() => vm.dispose());

  group('initial state', () {
    test('step is idle', () {
      expect(vm.step, AuthFlowStep.idle);
    });

    test('has no error', () {
      expect(vm.errorMessage, isNull);
    });

    test('needsOnboarding is false', () {
      expect(vm.needsOnboarding, isFalse);
    });
  });

  group('signInWithEmail', () {
    test('success authenticates and routes using onboarding state', () async {
      when(() => mockAuth.signInWithEmail('user@example.com')).thenAnswer(
        (_) async => const AuthResult(userId: 'u1', email: 'user@example.com'),
      );
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => true);

      await vm.signInWithEmail('user@example.com');

      verify(() => mockAuth.signInWithEmail('user@example.com')).called(1);
      expect(vm.step, AuthFlowStep.success);
      expect(vm.needsOnboarding, isTrue);
      expect(vm.errorMessage, isNull);
    });

    test('failure moves to error state', () async {
      when(
        () => mockAuth.signInWithEmail('user@example.com'),
      ).thenThrow(Exception('network error'));

      await vm.signInWithEmail('user@example.com');

      expect(vm.step, AuthFlowStep.error);
      expect(vm.errorMessage, isNotEmpty);
    });

    test(
      'legacy credentials explain how to recreate the demo account',
      () async {
        when(
          () => mockAuth.signInWithEmail('user@example.com'),
        ).thenThrow(Exception('invalid_credentials'));

        await vm.signInWithEmail('user@example.com');

        expect(vm.errorMessage, contains('current demo auth'));
        expect(vm.errorMessage, contains('new email'));
      },
    );
  });

  group('signUpWithEmail', () {
    test('success authenticates and routes using onboarding state', () async {
      when(() => mockAuth.signUpWithEmail('new@example.com')).thenAnswer(
        (_) async => const AuthResult(userId: 'u2', email: 'new@example.com'),
      );
      when(() => mockAuth.needsOnboarding()).thenAnswer((_) async => false);

      await vm.signUpWithEmail('new@example.com');

      verify(() => mockAuth.signUpWithEmail('new@example.com')).called(1);
      expect(vm.step, AuthFlowStep.success);
      expect(vm.needsOnboarding, isFalse);
    });

    test('failure moves to error state', () async {
      when(
        () => mockAuth.signUpWithEmail('new@example.com'),
      ).thenThrow(Exception('email confirmation is enabled'));

      await vm.signUpWithEmail('new@example.com');

      expect(vm.step, AuthFlowStep.error);
      expect(vm.errorMessage, contains('Disable email confirmation'));
    });
  });

  group('reset', () {
    test('returns the view model to idle state', () async {
      when(
        () => mockAuth.signInWithEmail('user@example.com'),
      ).thenThrow(Exception('network error'));

      await vm.signInWithEmail('user@example.com');
      vm.reset();

      expect(vm.step, AuthFlowStep.idle);
      expect(vm.errorMessage, isNull);
      expect(vm.needsOnboarding, isFalse);
    });
  });
}
