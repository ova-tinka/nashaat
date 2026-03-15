package com.example.nashaat

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

/// Accessibility service that detects when a blocked app is brought to the
/// foreground and immediately navigates the user back to Nashaat.
class BlockingAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        val packageName = event.packageName?.toString() ?: return

        val prefs = getSharedPreferences(BlockingPlugin.PREFS_NAME, Context.MODE_PRIVATE)
        val isActive = prefs.getBoolean("is_active", false)
        if (!isActive) return

        val blockedApps = prefs.getStringSet("blocked_apps", emptySet()) ?: return
        if (packageName !in blockedApps) return

        // Send user home
        performGlobalAction(GLOBAL_ACTION_HOME)

        // Bring Nashaat to front so user sees the blocking state
        val nashaat = packageManager.getLaunchIntentForPackage(packageName = this.packageName)
        nashaat?.apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra("blocked_app", packageName)
        }?.let { startActivity(it) }
    }

    override fun onInterrupt() {}
}
