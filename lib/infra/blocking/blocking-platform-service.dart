import 'dart:io';

import 'package:flutter/services.dart';

/// Represents an installed app on the device (Android only).
/// On iOS, app selection is handled by the native FamilyActivityPicker.
class InstalledApp {
  final String packageId;
  final String name;

  const InstalledApp({required this.packageId, required this.name});

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        packageId: map['packageId'] as String,
        name: map['name'] as String,
      );
}

class IosSummary {
  final int appCount;
  final int categoryCount;
  final int domainCount;

  const IosSummary({
    required this.appCount,
    required this.categoryCount,
    required this.domainCount,
  });

  int get total => appCount + categoryCount + domainCount;
  bool get isEmpty => total == 0;

  String get displayText {
    final parts = <String>[];
    if (appCount > 0) parts.add('$appCount app${appCount == 1 ? '' : 's'}');
    if (categoryCount > 0) parts.add('$categoryCount categor${categoryCount == 1 ? 'y' : 'ies'}');
    if (domainCount > 0) parts.add('$domainCount site${domainCount == 1 ? '' : 's'}');
    return parts.isEmpty ? 'Nothing selected' : parts.join(', ');
  }
}

/// Bridge to native iOS/Android blocking functionality.
///
/// iOS  → FamilyControls (Screen Time API), requires entitlement.
/// Android → AccessibilityService + foreground monitoring service.
class BlockingPlatformService {
  static const _channel = MethodChannel('com.nashaat/blocking');

  /// Returns a map of permission keys → granted status.
  ///
  /// Android keys: usageStats, overlay, accessibility
  /// iOS keys:     familyControls
  Future<Map<String, bool>> checkPermissions() async {
    final result =
        await _channel.invokeMapMethod<String, bool>('checkPermissions');
    return result ?? {};
  }

  /// Opens the OS settings page for the given permission type.
  /// Returns true if the request was dispatched (not necessarily granted).
  Future<bool> requestPermission(String type) async {
    return await _channel.invokeMethod<bool>(
          'requestPermission',
          {'type': type},
        ) ??
        false;
  }

  /// Android only — returns empty list on iOS.
  /// Fetches all user-launchable installed apps, excluding system apps.
  Future<List<InstalledApp>> getInstalledApps() async {
    if (!Platform.isAndroid) return [];
    final result = await _channel
        .invokeListMethod<Map<dynamic, dynamic>>('getInstalledApps');
    return (result ?? []).map(InstalledApp.fromMap).toList();
  }

  /// iOS only — presents the native FamilyActivityPicker sheet.
  /// Returns the total number of selected items (apps + categories + domains).
  /// 0 means the user dismissed without selecting anything.
  Future<int> presentIosPicker() async {
    if (!Platform.isIOS) return 0;
    final result =
        await _channel.invokeMapMethod<String, dynamic>('presentAppPicker');
    return (result?['appCount'] as int?) ?? 0;
  }

  /// Activates blocking for the given package/bundle IDs.
  /// On iOS this applies the stored FamilyActivitySelection.
  Future<void> startBlocking(List<String> appIds) async {
    await _channel.invokeMethod<void>('startBlocking', {'appIds': appIds});
  }

  /// Deactivates all active blocking.
  Future<void> stopBlocking() async {
    await _channel.invokeMethod<void>('stopBlocking');
  }

  /// Returns whether the blocking service is currently running.
  Future<bool> isBlockingActive() async {
    return await _channel.invokeMethod<bool>('isBlockingActive') ?? false;
  }

  /// Returns the package/bundle ID of the app currently in the foreground,
  /// or null if it cannot be determined or is a system app.
  ///
  /// Android: UsageStatsManager (requires usageStats permission).
  /// iOS:     Returns null — iOS does not expose the foreground app to the
  ///          calling process outside of a DeviceActivityMonitor extension.
  ///          Screen-time drain on iOS falls back to continuous mode.
  Future<String?> getForegroundAppId() async {
    try {
      return await _channel.invokeMethod<String?>('getForegroundApp');
    } catch (_) {
      return null;
    }
  }

  /// iOS only — returns a summary of what is currently selected in the
  /// FamilyActivitySelection stored on-device.
  Future<IosSummary> getSelectionSummary() async {
    if (!Platform.isIOS) return const IosSummary(appCount: 0, categoryCount: 0, domainCount: 0);
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getSelectionSummary');
      return IosSummary(
        appCount: (result?['appCount'] as int?) ?? 0,
        categoryCount: (result?['categoryCount'] as int?) ?? 0,
        domainCount: (result?['domainCount'] as int?) ?? 0,
      );
    } catch (_) {
      return const IosSummary(appCount: 0, categoryCount: 0, domainCount: 0);
    }
  }
}
