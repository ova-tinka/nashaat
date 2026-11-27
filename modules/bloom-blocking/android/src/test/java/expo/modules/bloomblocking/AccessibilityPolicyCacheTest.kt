package expo.modules.bloomblocking

import android.view.accessibility.AccessibilityEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessibilityPolicyCacheTest {
  @Test
  fun skipsBrowserAddressInspectionForNonBrowsersOrEmptyRules() {
    assertFalse(
      AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
        packageName = "com.example.game",
        websiteChecksEnabled = true,
        hasBlockedWebsites = true,
        hasAddressViewId = false,
        lastCheckedPackage = null,
        lastCheckedAtMs = 0L,
        nowMs = 1000L,
      ),
    )
    assertFalse(
      AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
        packageName = "com.android.chrome",
        websiteChecksEnabled = true,
        hasBlockedWebsites = false,
        hasAddressViewId = true,
        lastCheckedPackage = null,
        lastCheckedAtMs = 0L,
        nowMs = 1000L,
      ),
    )
  }

  @Test
  fun inspectsStateChangesImmediatelyAndDebouncesRapidContentChanges() {
    assertTrue(
      AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
        packageName = "com.android.chrome",
        websiteChecksEnabled = true,
        hasBlockedWebsites = true,
        hasAddressViewId = true,
        lastCheckedPackage = "com.android.chrome",
        lastCheckedAtMs = 990L,
        nowMs = 1000L,
      ),
    )
    assertFalse(
      AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
        packageName = "com.android.chrome",
        websiteChecksEnabled = true,
        hasBlockedWebsites = true,
        hasAddressViewId = true,
        lastCheckedPackage = "com.android.chrome",
        lastCheckedAtMs = 950L,
        nowMs = 1000L,
      ),
    )
    assertTrue(
      AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
        packageName = "com.android.chrome",
        websiteChecksEnabled = true,
        hasBlockedWebsites = true,
        hasAddressViewId = true,
        lastCheckedPackage = "com.android.chrome",
        lastCheckedAtMs = 800L,
        nowMs = 1000L,
      ),
    )
  }
}
