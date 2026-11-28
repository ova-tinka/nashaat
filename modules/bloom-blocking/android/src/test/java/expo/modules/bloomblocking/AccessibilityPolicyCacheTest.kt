package expo.modules.bloomblocking

import android.view.accessibility.AccessibilityEvent
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
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

  @Test
  fun protectsEssentialPackagesAndExpiresTimedManualFocusLive() {
    assertTrue(ProtectedPackages.isProtected("com.android.settings", "com.bloomgrowth.app"))
    assertTrue(ProtectedPackages.isProtected("com.android.dialer", "com.bloomgrowth.app"))
    assertTrue(ProtectedPackages.isProtected("com.bloomgrowth.app", "com.bloomgrowth.app"))
    assertFalse(ProtectedPackages.isProtected("com.example.game", "com.bloomgrowth.app"))

    val policy = CachedAccessibilityPolicy(
      revision = 1L,
      active = false,
      personalApps = emptySet(),
      managedApps = emptySet(),
      personalWebsites = emptySet(),
      managedWebsites = emptySet(),
      websiteChecksEnabled = false,
      creditAccount = null,
      focusRoutineAccount = null,
      routines = emptyList(),
      manual = ManualFocusStore.RawConfig(
        selection = ManualFocusStore.Selection(setOf("com.example.game"), emptySet()),
        enabled = true,
        deadline = 5_000L,
        recordedBoot = 2,
      ),
    )
    assertNotNull(policy.activeManual(nowElapsedMs = 4_000L, currentBoot = 2))
    assertNull(policy.activeManual(nowElapsedMs = 5_000L, currentBoot = 2))
    assertNull(policy.activeManual(nowElapsedMs = 4_000L, currentBoot = 3))
  }
}
