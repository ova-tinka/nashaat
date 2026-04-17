import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../core/repositories/blocking-repository.dart';
import '../../../core/repositories/emergency-break-repository.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';
import '../../../shared/logger.dart';

class BlockingViewModel extends ChangeNotifier {
  final BlockingRepository _blockingRepo;
  final BlockingPlatformService _platform;
  final PermissionService _permissionService;
  final EmergencyBreakRepository _emergencyBreakRepo;
  final String userId;

  bool _isLoading = false;
  String? _error;
  List<BlockingRuleEntity> _rules = [];
  List<InstalledApp> _installedApps = [];
  PermissionsState _permissions = const PermissionsState();
  bool _isBlockingActive = false;
  IosSummary? _iosSummary;

  int _todayBreakMinutesUsed = 0;
  bool _emergencyBreakActive = false;
  int _emergencyBreakSecondsRemaining = 0;
  Timer? _emergencyBreakTimer;

  BlockingViewModel({
    required this.userId,
    required BlockingRepository blockingRepo,
    required BlockingPlatformService platform,
    required PermissionService permissionService,
    required EmergencyBreakRepository emergencyBreakRepo,
  })  : _blockingRepo = blockingRepo,
        _platform = platform,
        _permissionService = permissionService,
        _emergencyBreakRepo = emergencyBreakRepo;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BlockingRuleEntity> get rules => List.unmodifiable(_rules);
  List<InstalledApp> get installedApps => List.unmodifiable(_installedApps);
  PermissionsState get permissions => _permissions;
  bool get isBlockingActive => _isBlockingActive;
  bool get isIos => Platform.isIOS;
  IosSummary? get iosSummary => _iosSummary;
  static const int dailyBreakBudgetMinutes = 15;
  int get todayBreakMinutesUsed => _todayBreakMinutesUsed;
  int get remainingBreakMinutes =>
      (dailyBreakBudgetMinutes - _todayBreakMinutesUsed).clamp(0, dailyBreakBudgetMinutes);
  bool get emergencyBreakActive => _emergencyBreakActive;
  int get emergencyBreakSecondsRemaining => _emergencyBreakSecondsRemaining;
  bool get canRequestBreak =>
      remainingBreakMinutes > 0 && !_emergencyBreakActive;

  List<BlockingRuleEntity> get activeRules =>
      _rules.where((r) => r.status == RuleStatus.active).toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    Log.blocking('initializing for user ${userId.substring(0, 8)}…');
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([
        _refreshPermissions(),
        _loadRules(),
        _loadTodayBreaks(),
      ]);
      _isBlockingActive = await _platform.isBlockingActive();
      if (Platform.isIOS) {
        try {
          _iosSummary = await _platform.getSelectionSummary();
        } catch (_) {
          // Summary is cosmetic — never block the initialize flow.
        }
      }
      Log.blocking(
        'ready — ${_rules.length} rule(s), '
        '${activeRules.length} active, '
        'blocking ${_isBlockingActive ? "ON" : "OFF"}',
      );
    } catch (e) {
      Log.error('blocking', e);
      _error = _friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<void> refreshPermissions() async {
    await _refreshPermissions();
    notifyListeners();
  }

  Future<void> requestPermission(MissingPermission permission) async {
    await _permissionService.request(permission);
    await _refreshPermissions();
    notifyListeners();
  }

  // ── App list (Android only) ───────────────────────────────────────────────

  Future<void> loadInstalledApps() async {
    if (Platform.isIOS) {
      _installedApps = [];
      notifyListeners();
      return;
    }
    final raw = await _platform.getInstalledApps();
    final blockedIds = _rules.map((r) => r.itemIdentifier).toSet();
    _installedApps = raw
        .where(
          (a) =>
              !_exemptPackages.contains(a.packageId) &&
              !blockedIds.contains(a.packageId),
        )
        .toList();
    Log.blocking('${_installedApps.length} blockable app(s) loaded (${raw.length} total, ${blockedIds.length} already blocked)');
    notifyListeners();
  }

  // ── iOS native picker ─────────────────────────────────────────────────────

  Future<void> openIosPicker() async {
    Log.blocking('opening iOS native picker');
    final count = await _platform.presentIosPicker();
    if (count == 0) {
      Log.blocking('iOS picker closed — no apps selected');
      return;
    }
    // Remove any existing synthetic iOS rule before writing the new one
    final existing = _rules
        .where((r) => r.itemIdentifier.startsWith('ios_selection:'))
        .toList();
    for (final rule in existing) {
      await _blockingRepo.deleteRule(rule.id);
      _rules.remove(rule);
    }
    final rule = BlockingRuleEntity(
      id: '',
      userId: userId,
      itemType: ItemType.app,
      itemIdentifier: 'ios_selection:$count',
      status: RuleStatus.active,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final created = await _blockingRepo.createRule(rule);
    _rules.add(created);
    _iosSummary = await _platform.getSelectionSummary();
    _isBlockingActive = true;
    Log.blocking('iOS picker done — $count item(s) selected, blocking active');
    notifyListeners();
  }

  // ── Rule CRUD ─────────────────────────────────────────────────────────────

  Future<void> addRules(List<InstalledApp> apps) async {
    Log.blocking('adding ${apps.length} app(s) to block list');
    for (final app in apps) {
      await _addRule(app);
    }
    if (_isBlockingActive) await _syncToNative();
    Log.blocking('block list now has ${_rules.length} rule(s) (${activeRules.length} active)');
    notifyListeners();
  }

  Future<void> removeRule(String id) async {
    try {
      final rule = _rules.firstWhere((r) => r.id == id);
      await _blockingRepo.deleteRule(id);
      _rules.removeWhere((r) => r.id == id);
      if (Platform.isIOS && rule.itemIdentifier.startsWith('ios_selection:')) {
        _iosSummary = null;
      }
      if (_isBlockingActive) {
        if (Platform.isIOS &&
            rule.itemIdentifier.startsWith('ios_selection:')) {
          // Clear native ManagedSettingsStore shields
          await _platform.stopBlocking();
          _isBlockingActive = false;
        } else {
          await _syncToNative();
        }
      }
      Log.blocking('rule removed — ${_rules.length} rule(s) remaining');
      notifyListeners();
    } catch (e) {
      Log.error('blocking', e);
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> toggleRule(String id) async {
    final rule = _rules.firstWhere((r) => r.id == id);
    final newStatus = rule.status == RuleStatus.active
        ? RuleStatus.inactive
        : RuleStatus.active;
    Log.blocking('toggle ${rule.itemIdentifier} → ${newStatus.name}');
    try {
      final updated = await _blockingRepo.updateRuleStatus(id, newStatus);
      final idx = _rules.indexWhere((r) => r.id == id);
      if (idx != -1) _rules[idx] = updated;
      if (_isBlockingActive) await _syncToNative();
      notifyListeners();
    } catch (e) {
      Log.error('blocking', e);
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  // ── Blocking toggle ───────────────────────────────────────────────────────

  Future<void> activateBlocking() async {
    Log.blocking('activating — syncing ${activeRules.length} active rule(s) to native');
    try {
      await _syncToNative();
      _isBlockingActive = true;
      Log.blocking('blocking ON ✓');
      notifyListeners();
    } catch (e) {
      Log.error('blocking', e);
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> deactivateBlocking() async {
    Log.blocking('deactivating');
    try {
      await _platform.stopBlocking();
      _isBlockingActive = false;
      Log.blocking('blocking OFF ✓');
      notifyListeners();
    } catch (e) {
      Log.error('blocking', e);
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  // ── Emergency break ───────────────────────────────────────────────────────

  Future<void> requestEmergencyBreak(int minutes) async {
    if (!canRequestBreak) return;
    final clamped = minutes.clamp(1, remainingBreakMinutes);
    try {
      await _emergencyBreakRepo.requestBreak(userId, clamped);
      _todayBreakMinutesUsed += clamped;
      _emergencyBreakActive = true;
      _emergencyBreakSecondsRemaining = clamped * 60;
      notifyListeners();
      _emergencyBreakTimer?.cancel();
      _emergencyBreakTimer =
          Timer.periodic(const Duration(seconds: 1), (_) {
        if (_emergencyBreakSecondsRemaining > 0) {
          _emergencyBreakSecondsRemaining--;
          notifyListeners();
        } else {
          _emergencyBreakActive = false;
          _emergencyBreakTimer?.cancel();
          _emergencyBreakTimer = null;
          notifyListeners();
        }
      });
    } catch (e) {
      Log.error('blocking.emergencyBreak', e);
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _refreshPermissions() async {
    _permissions = await _permissionService.checkAll();
  }

  Future<void> _loadRules() async {
    _rules = await _blockingRepo.getUserRules(userId);
    _rules = _rules.where((r) => r.status != RuleStatus.archived).toList();
  }

  Future<void> _loadTodayBreaks() async {
    try {
      final breaks = await _emergencyBreakRepo.getUserBreaks(userId);
      final today = DateTime.now();
      _todayBreakMinutesUsed = breaks
          .where((b) =>
              b.grantedAt.year == today.year &&
              b.grantedAt.month == today.month &&
              b.grantedAt.day == today.day)
          .fold(0, (sum, b) => sum + b.durationMinutes);
    } catch (e) {
      Log.error('blocking._loadTodayBreaks', e);
    }
  }

  Future<void> _addRule(InstalledApp app) async {
    try {
      final rule = BlockingRuleEntity(
        id: '',
        userId: userId,
        itemType: ItemType.app,
        itemIdentifier: app.packageId,
        status: RuleStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final created = await _blockingRepo.createRule(rule);
      _rules.add(created);
    } catch (e) {
      // Skip duplicates silently; surface other errors
      final msg = e.toString().toLowerCase();
      if (!msg.contains('duplicate') && !msg.contains('unique')) {
        Log.error('blocking', e);
        _error = _friendlyError(e);
      } else {
        Log.blocking('skipped duplicate: ${app.packageId}');
      }
    }
  }

  Future<void> _syncToNative() async {
    final ids = activeRules.map((r) => r.itemIdentifier).toList();
    Log.blocking('syncing ${ids.length} app id(s) to native layer');
    await _platform.startBlocking(ids);
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('connection')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('duplicate') || msg.contains('unique')) {
      return 'That app is already in your block list.';
    }
    return 'Something went wrong. Please try again.';
  }

  static const _exemptPackages = {
    'com.example.nashaat',
    'com.android.phone',
    'com.android.dialer',
    'com.google.android.dialer',
    'com.android.mms',
    'com.android.messaging',
    'com.google.android.apps.messaging',
    'com.android.settings',
  };

  @override
  void dispose() {
    _emergencyBreakTimer?.cancel();
    super.dispose();
  }
}
