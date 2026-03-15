import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/entities/blocking-rule-entity.dart';
import '../../../core/entities/enums.dart';
import '../../../core/repositories/blocking-repository.dart';
import '../../../infra/blocking/blocking-platform-service.dart';
import '../../../infra/permissions/permission-service.dart';

class BlockingViewModel extends ChangeNotifier {
  final BlockingRepository _blockingRepo;
  final BlockingPlatformService _platform;
  final PermissionService _permissionService;
  final String userId;

  bool _isLoading = false;
  String? _error;
  List<BlockingRuleEntity> _rules = [];
  List<InstalledApp> _installedApps = [];
  PermissionsState _permissions = const PermissionsState();
  bool _isBlockingActive = false;

  BlockingViewModel({
    required this.userId,
    required BlockingRepository blockingRepo,
    required BlockingPlatformService platform,
    required PermissionService permissionService,
  })  : _blockingRepo = blockingRepo,
        _platform = platform,
        _permissionService = permissionService;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BlockingRuleEntity> get rules => List.unmodifiable(_rules);
  List<InstalledApp> get installedApps => List.unmodifiable(_installedApps);
  PermissionsState get permissions => _permissions;
  bool get isBlockingActive => _isBlockingActive;
  bool get isIos => Platform.isIOS;

  List<BlockingRuleEntity> get activeRules =>
      _rules.where((r) => r.status == RuleStatus.active).toList();

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await Future.wait([_refreshPermissions(), _loadRules()]);
      _isBlockingActive = await _platform.isBlockingActive();
    } catch (e) {
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
    notifyListeners();
  }

  // ── iOS native picker ─────────────────────────────────────────────────────

  Future<void> openIosPicker() async {
    await _platform.presentIosPicker();
    // Reload rules after the picker closes (native side may have updated them)
    await _loadRules();
    notifyListeners();
  }

  // ── Rule CRUD ─────────────────────────────────────────────────────────────

  Future<void> addRules(List<InstalledApp> apps) async {
    for (final app in apps) {
      await _addRule(app);
    }
    if (_isBlockingActive) await _syncToNative();
    notifyListeners();
  }

  Future<void> removeRule(String id) async {
    try {
      await _blockingRepo.deleteRule(id);
      _rules.removeWhere((r) => r.id == id);
      if (_isBlockingActive) await _syncToNative();
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> toggleRule(String id) async {
    final rule = _rules.firstWhere((r) => r.id == id);
    final newStatus = rule.status == RuleStatus.active
        ? RuleStatus.inactive
        : RuleStatus.active;
    try {
      final updated = await _blockingRepo.updateRuleStatus(id, newStatus);
      final idx = _rules.indexWhere((r) => r.id == id);
      if (idx != -1) _rules[idx] = updated;
      if (_isBlockingActive) await _syncToNative();
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  // ── Blocking toggle ───────────────────────────────────────────────────────

  Future<void> activateBlocking() async {
    try {
      await _syncToNative();
      _isBlockingActive = true;
      notifyListeners();
    } catch (e) {
      _error = _friendlyError(e);
      notifyListeners();
    }
  }

  Future<void> deactivateBlocking() async {
    try {
      await _platform.stopBlocking();
      _isBlockingActive = false;
      notifyListeners();
    } catch (e) {
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
        _error = _friendlyError(e);
      }
    }
  }

  Future<void> _syncToNative() async {
    final ids = activeRules.map((r) => r.itemIdentifier).toList();
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
}
