import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nashaat/features/settings/view-model/settings-view-model.dart';

import '../../../helpers/mock_repositories.dart';
import '../../../helpers/test_data.dart';

void main() {
  late MockProfileRepository mockProfileRepo;
  late MockAuthRepository mockAuthRepo;
  late SettingsViewModel vm;

  setUp(() {
    mockProfileRepo = MockProfileRepository();
    mockAuthRepo = MockAuthRepository();
    vm = SettingsViewModel(
      profileRepo: mockProfileRepo,
      authRepo: mockAuthRepo,
      getUserId: () => 'u1',
    );
  });

  tearDown(() => vm.dispose());

  // ── load ───────────────────────────────────────────────────────────────────

  group('load', () {
    test('success: profile set', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.profile());

      await vm.load();

      expect(vm.profile, isNotNull);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockProfileRepo.getProfile(any()))
          .thenThrow(Exception('server error'));

      await vm.load();

      expect(vm.error, isNotNull);
    });
  });

  // ── updateProfile ──────────────────────────────────────────────────────────

  group('updateProfile', () {
    test('success: profile updated, successMessage set', () async {
      final updatedProfile = TestData.profile(username: 'newuser');
      when(() => mockProfileRepo.updateProfile(any(),
              username: any(named: 'username'),
              firstName: any(named: 'firstName'),
              lastName: any(named: 'lastName'),
              weeklyExerciseTargetMinutes:
                  any(named: 'weeklyExerciseTargetMinutes')))
          .thenAnswer((_) async => updatedProfile);

      await vm.updateProfile(username: 'newuser');

      expect(vm.profile?.username, 'newuser');
      expect(vm.successMessage, isNotNull);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockProfileRepo.updateProfile(any(),
              username: any(named: 'username'),
              firstName: any(named: 'firstName'),
              lastName: any(named: 'lastName'),
              weeklyExerciseTargetMinutes:
                  any(named: 'weeklyExerciseTargetMinutes')))
          .thenThrow(Exception('update failed'));

      await vm.updateProfile(username: 'newuser');

      expect(vm.error, isNotNull);
    });
  });

  // ── updateScreenTimeSetup ──────────────────────────────────────────────────

  group('updateScreenTimeSetup', () {
    test('success: successMessage set', () async {
      when(() => mockProfileRepo.updateScreenTimeSetup(any(),
              dailyPhoneHours: any(named: 'dailyPhoneHours'),
              weeklySmallSessions: any(named: 'weeklySmallSessions'),
              weeklyBigSessions: any(named: 'weeklyBigSessions')))
          .thenAnswer((_) async {});
      when(() => mockProfileRepo.getProfile(any()))
          .thenAnswer((_) async => TestData.configuredProfile());

      await vm.updateScreenTimeSetup(
        dailyPhoneHours: 8,
        weeklySmallSessions: 2,
        weeklyBigSessions: 3,
      );

      expect(vm.successMessage, isNotNull);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockProfileRepo.updateScreenTimeSetup(any(),
              dailyPhoneHours: any(named: 'dailyPhoneHours'),
              weeklySmallSessions: any(named: 'weeklySmallSessions'),
              weeklyBigSessions: any(named: 'weeklyBigSessions')))
          .thenThrow(Exception('failed'));

      await vm.updateScreenTimeSetup(
        dailyPhoneHours: 8,
        weeklySmallSessions: 2,
        weeklyBigSessions: 3,
      );

      expect(vm.error, isNotNull);
    });
  });

  // ── changePassword ─────────────────────────────────────────────────────────

  group('changePassword', () {
    test('success: authRepo.changePassword called, successMessage set',
        () async {
      when(() => mockAuthRepo.changePassword(any())).thenAnswer((_) async {});

      await vm.changePassword('newPass123');

      verify(() => mockAuthRepo.changePassword('newPass123')).called(1);
      expect(vm.successMessage, isNotNull);
      expect(vm.error, isNull);
    });

    test('failure: error set', () async {
      when(() => mockAuthRepo.changePassword(any()))
          .thenThrow(Exception('failed'));

      await vm.changePassword('newPass123');

      expect(vm.error, isNotNull);
    });
  });

  // ── signOut ────────────────────────────────────────────────────────────────

  group('signOut', () {
    test('success: authRepo.signOut called', () async {
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

      await vm.signOut();

      verify(() => mockAuthRepo.signOut()).called(1);
    });

    test('failure: error set', () async {
      when(() => mockAuthRepo.signOut()).thenThrow(Exception('sign out failed'));

      await vm.signOut();

      expect(vm.error, isNotNull);
    });
  });

  // ── deleteAccount ──────────────────────────────────────────────────────────

  group('deleteAccount', () {
    test('success: isDeleted=true, deleteAccount called, signOut called',
        () async {
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async {});
      when(() => mockAuthRepo.signOut()).thenAnswer((_) async {});

      await vm.deleteAccount();

      expect(vm.isDeleted, isTrue);
      verify(() => mockAuthRepo.deleteAccount()).called(1);
      verify(() => mockAuthRepo.signOut()).called(1);
    });

    test('failure: isDeleted=false, error set', () async {
      when(() => mockAuthRepo.deleteAccount())
          .thenThrow(Exception('delete failed'));

      await vm.deleteAccount();

      expect(vm.isDeleted, isFalse);
      expect(vm.error, isNotNull);
    });
  });

  // ── clearMessages ──────────────────────────────────────────────────────────

  group('clearMessages', () {
    test('clears error and successMessage', () async {
      when(() => mockAuthRepo.changePassword(any()))
          .thenThrow(Exception('fail'));
      await vm.changePassword('x');
      expect(vm.error, isNotNull);

      vm.clearMessages();

      expect(vm.error, isNull);
      expect(vm.successMessage, isNull);
    });
  });
}
