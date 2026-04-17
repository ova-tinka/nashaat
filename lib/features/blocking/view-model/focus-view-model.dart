import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/entities/enums.dart';
import '../../../core/entities/profile-entity.dart';
import '../../../core/entities/screen-time-transaction-entity.dart';
import '../../../core/repositories/profile-repository.dart';
import '../../../core/repositories/screen-time-transaction-repository.dart';
import '../../../core/repositories/blocking-repository.dart';
import '../../../core/repositories/emergency-break-repository.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../shared/logger.dart';
import '../../../shared/utils/screen-time-economy.dart';
import '../view-model/blocking-view-model.dart';

class FocusViewModel extends ChangeNotifier {
  final ProfileRepository _profileRepo;
  final ScreenTimeTransactionRepository _txnRepo;
  final BlockingPlatformService _platform;
  final BlockingViewModel blockingVm;

  FocusViewModel({
    required ProfileRepository profileRepo,
    required ScreenTimeTransactionRepository txnRepo,
    required BlockingPlatformService platform,
    required BlockingRepository blockingRepo,
    required EmergencyBreakRepository emergencyBreakRepo,
    required String userId,
  })  : _profileRepo = profileRepo,
        _txnRepo = txnRepo,
        _platform = platform,
        blockingVm = BlockingViewModel(
          userId: userId,
          blockingRepo: blockingRepo,
          platform: platform,
          permissionService: PermissionService(platform),
          emergencyBreakRepo: emergencyBreakRepo,
        );

  // ── State ─────────────────────────────────────────────────────────────────

  ProfileEntity? _profile;
  ScreenTimeRewards _rewards = ScreenTimeRewards.zero;
  bool _isLoading = false;
  String? _error;

  /// True when apps are currently unblocked because the user has balance.
  bool _appsUnblocked = false;

  Timer? _drainTimer;

  // ── Getters ───────────────────────────────────────────────────────────────

  ProfileEntity? get profile => _profile;
  ScreenTimeRewards get rewards => _rewards;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get appsUnblocked => _appsUnblocked;
  int get balanceMinutes => _profile?.screenTimeBalanceMinutes ?? 0;
  bool get isConfigured => _profile?.isScreenTimeConfigured ?? false;
  bool get hasBlockedApps => blockingVm.rules.isNotEmpty;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Future.wait([
        _loadProfile(userId),
        blockingVm.initialize(),
      ]);
      await _creditWeeklyFreeIfNeeded();
      await _syncBlockingState();
      _startDrainTimer();
    } catch (e) {
      Log.error('FocusViewModel', e);
      _error = 'Could not load screen time data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadProfile(String userId) async {
    _profile = await _profileRepo.getProfile(userId);
    if (_profile != null) {
      _rewards = ScreenTimeEconomy.calculate(_profile!);
    }
  }

  // ── Weekly free minutes ───────────────────────────────────────────────────

  Future<void> _creditWeeklyFreeIfNeeded() async {
    final profile = _profile;
    if (profile == null || !profile.isScreenTimeConfigured) return;
    if (!ScreenTimeEconomy.isNewWeek(DateTime.now(), profile.lastWeeklyResetAt)) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final freeMinutes = _rewards.freeMinutes;

    await _profileRepo.updateLastWeeklyReset(userId, DateTime.now());
    await _profileRepo.updateScreenTimeBalance(userId, freeMinutes);

    if (freeMinutes > 0) {
      await _txnRepo.recordTransaction(ScreenTimeTransactionEntity(
        id: '',
        userId: userId,
        amountMinutes: freeMinutes,
        transactionType: TransactionType.earned,
        description: 'Weekly free screen time (20% baseline)',
        createdAt: DateTime.now(),
      ));
    }

    _profile = await _profileRepo.getProfile(userId);
    _rewards = ScreenTimeEconomy.calculate(_profile!);
    Log.db('weekly reset ✓ credited $freeMinutes free min');
  }

  // ── Automatic blocking state management ──────────────────────────────────

  /// Ensures the blocking layer matches the current balance:
  /// balance > 0 → apps unblocked; balance == 0 → apps blocked.
  Future<void> _syncBlockingState() async {
    final hasBalance = balanceMinutes > 0;
    final hasRules = blockingVm.rules.isNotEmpty;

    if (hasBalance && hasRules && !_appsUnblocked) {
      await blockingVm.deactivateBlocking();
      _appsUnblocked = true;
      Log.blocking('auto-unblocked: balance=$balanceMinutes min');
    } else if (!hasBalance && _appsUnblocked) {
      await _reblock();
    }
  }

  Future<void> _reblock() async {
    if (blockingVm.rules.isNotEmpty) {
      await blockingVm.activateBlocking();
    }
    _appsUnblocked = false;
    Log.blocking('auto-reblocked: balance depleted');
    notifyListeners();
  }

  // ── Drain timer ───────────────────────────────────────────────────────────

  void _startDrainTimer() {
    _drainTimer?.cancel();
    // Check every 60 seconds.
    _drainTimer = Timer.periodic(const Duration(minutes: 1), (_) => _onTick());
  }

  Future<void> _onTick() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    if (!_appsUnblocked) {
      // Refresh balance from DB to pick up screen time earned by recent workouts.
      await _loadProfile(userId);
      await _syncBlockingState();
      return;
    }

    // Determine whether to drain this tick.
    // Android: only drain if a blocked-app is currently in the foreground.
    // iOS:     always drain while unblocked (iOS blocks at OS level via
    //          FamilyControls; Flutter cannot inspect the foreground app).
    final shouldDrain = await _shouldDrainThisTick();
    if (!shouldDrain) return;

    final current = _profile?.screenTimeBalanceMinutes ?? 0;
    if (current <= 0) {
      await _reblock();
      return;
    }

    final newBalance = current - 1;

    await _txnRepo.recordTransaction(ScreenTimeTransactionEntity(
      id: '',
      userId: userId,
      amountMinutes: -1,
      transactionType: TransactionType.spent,
      description: 'Screen time used',
      createdAt: DateTime.now(),
    ));
    await _profileRepo.updateScreenTimeBalance(userId, newBalance);
    _profile = _profile?.copyWith(screenTimeBalanceMinutes: newBalance);

    Log.blocking('drained 1 min — remaining: $newBalance min');

    if (newBalance <= 0) {
      await _reblock();
    } else {
      notifyListeners();
    }
  }

  /// Returns true if screen time should be deducted this tick.
  ///
  /// On Android we check whether any blocked app is in the foreground via the
  /// native UsageStats API.  On iOS we always return true because the
  /// foreground app is not accessible from Flutter code.
  Future<bool> _shouldDrainThisTick() async {
    if (Platform.isIOS) return true;

    final foreground = await _platform.getForegroundAppId();
    if (foreground == null) return false;

    final blockedIds =
        blockingVm.activeRules.map((r) => r.itemIdentifier).toSet();
    return blockedIds.contains(foreground);
  }

  // ── Manual refresh (pull-to-refresh) ─────────────────────────────────────

  Future<void> refresh() async {
    _error = null;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _loadProfile(userId);
      await _syncBlockingState();
    } catch (e) {
      Log.error('FocusViewModel.refresh', e);
      _error = 'Could not refresh.';
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _drainTimer?.cancel();
    blockingVm.dispose();
    super.dispose();
  }
}
