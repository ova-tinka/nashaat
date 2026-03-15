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
  /// The user selects apps through the native UI; selection is stored natively
  /// and immediately applied to ManagedSettingsStore.
  Future<void> presentIosPicker() async {
    if (!Platform.isIOS) return;
    await _channel.invokeMethod<void>('presentAppPicker');
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
}
