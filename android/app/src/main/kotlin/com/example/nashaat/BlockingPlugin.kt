package com.example.nashaat

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.net.Uri
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class BlockingPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.nashaat/blocking")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkPermissions"  -> checkPermissions(result)
            "requestPermission" -> requestPermission(call.argument("type")!!, result)
            "getInstalledApps"  -> getInstalledApps(result)
            "startBlocking"     -> startBlocking(call.argument<List<String>>("appIds")!!, result)
            "stopBlocking"      -> stopBlocking(result)
            "isBlockingActive"  -> isBlockingActive(result)
            else                -> result.notImplemented()
        }
    }

    // ── Permissions ───────────────────────────────────────────────────────────

    private fun checkPermissions(result: MethodChannel.Result) {
        result.success(
            mapOf(
                "usageStats"    to hasUsageStatsPermission(),
                "overlay"       to Settings.canDrawOverlays(context),
                "accessibility" to isAccessibilityServiceEnabled(),
            )
        )
    }

    private fun requestPermission(type: String, result: MethodChannel.Result) {
        val intent = when (type) {
            "usageStats"    -> Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            "overlay"       -> Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${context.packageName}"),
            )
            "accessibility" -> Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            else            -> { result.success(false); return }
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        result.success(true)
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val enabledVal = Settings.Secure.getInt(
            context.contentResolver,
            Settings.Secure.ACCESSIBILITY_ENABLED,
            0,
        )
        if (enabledVal != 1) return false

        val service =
            "${context.packageName}/${BlockingAccessibilityService::class.java.canonicalName}"
        val enabledServices = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: return false

        return enabledServices.split(':').any { it.equals(service, ignoreCase = true) }
    }

    // ── Installed apps ────────────────────────────────────────────────────────

    private fun getInstalledApps(result: MethodChannel.Result) {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(0)
            .filter { info ->
                // Only user-launchable, non-system apps
                pm.getLaunchIntentForPackage(info.packageName) != null &&
                        (info.flags and ApplicationInfo.FLAG_SYSTEM) == 0
            }
            .map { info ->
                mapOf(
                    "packageId" to info.packageName,
                    "name"      to pm.getApplicationLabel(info).toString(),
                )
            }
            .sortedBy { it["name"] }
        result.success(apps)
    }

    // ── Blocking control ──────────────────────────────────────────────────────

    private fun startBlocking(appIds: List<String>, result: MethodChannel.Result) {
        prefs().edit()
            .putStringSet("blocked_apps", appIds.toSet())
            .putBoolean("is_active", true)
            .apply()

        val intent = Intent(context, AppBlockingService::class.java)
        context.startForegroundService(intent)
        result.success(null)
    }

    private fun stopBlocking(result: MethodChannel.Result) {
        prefs().edit().putBoolean("is_active", false).apply()
        context.stopService(Intent(context, AppBlockingService::class.java))
        result.success(null)
    }

    private fun isBlockingActive(result: MethodChannel.Result) {
        result.success(prefs().getBoolean("is_active", false))
    }

    private fun prefs() =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    companion object {
        const val PREFS_NAME = "nashaat_blocking"
    }
}
