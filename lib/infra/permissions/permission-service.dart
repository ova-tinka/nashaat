import 'dart:io';

import '../blocking/blocking-platform-service.dart';

class PermissionsState {
  // Android-specific
  final bool usageStats;
  final bool overlay;
  final bool accessibility;
  // iOS-specific
  final bool familyControls;

  const PermissionsState({
    this.usageStats = false,
    this.overlay = false,
    this.accessibility = false,
    this.familyControls = false,
  });

  factory PermissionsState.fromMap(Map<String, bool> map) => PermissionsState(
        usageStats: map['usageStats'] ?? false,
        overlay: map['overlay'] ?? false,
        accessibility: map['accessibility'] ?? false,
        familyControls: map['familyControls'] ?? false,
      );

  bool get isFullyGranted {
    if (Platform.isAndroid) return usageStats && overlay && accessibility;
    return familyControls;
  }

  List<MissingPermission> get missing {
    final result = <MissingPermission>[];
    if (Platform.isAndroid) {
      if (!usageStats) result.add(MissingPermission.usageStats);
      if (!overlay) result.add(MissingPermission.overlay);
      if (!accessibility) result.add(MissingPermission.accessibility);
    } else {
      if (!familyControls) result.add(MissingPermission.familyControls);
    }
    return result;
  }
}

enum MissingPermission {
  usageStats,
  overlay,
  accessibility,
  familyControls;

  String get label => switch (this) {
        MissingPermission.usageStats => 'Usage Access',
        MissingPermission.overlay => 'Display Over Other Apps',
        MissingPermission.accessibility => 'Accessibility Service',
        MissingPermission.familyControls => 'Screen Time',
      };

  String get description => switch (this) {
        MissingPermission.usageStats =>
          'Lets Nashaat track which apps you use and deduct screen-time accordingly.',
        MissingPermission.overlay =>
          'Lets Nashaat show a blocking screen over other apps.',
        MissingPermission.accessibility =>
          'Lets Nashaat detect when a blocked app is opened.',
        MissingPermission.familyControls =>
          'Lets Nashaat restrict selected apps via iOS Screen Time.',
      };

  String get platformKey => switch (this) {
        MissingPermission.usageStats => 'usageStats',
        MissingPermission.overlay => 'overlay',
        MissingPermission.accessibility => 'accessibility',
        MissingPermission.familyControls => 'familyControls',
      };
}

class PermissionService {
  final BlockingPlatformService _platform;

  const PermissionService(this._platform);

  Future<PermissionsState> checkAll() async {
    final map = await _platform.checkPermissions();
    return PermissionsState.fromMap(map);
  }

  Future<bool> request(MissingPermission permission) =>
      _platform.requestPermission(permission.platformKey);
}
