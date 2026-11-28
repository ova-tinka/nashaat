package expo.modules.bloomblocking

import android.content.Context
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent
import java.util.Calendar

internal data class CachedAccessibilityPolicy(
  val revision: Long,
  val active: Boolean,
  val personalApps: Set<String>,
  val managedApps: Set<String>,
  val personalWebsites: Set<String>,
  val managedWebsites: Set<String>,
  val websiteChecksEnabled: Boolean,
  val creditAccount: String?,
  val focusRoutineAccount: String?,
  val routines: List<FocusSchedule.Routine>,
  val manual: ManualFocusStore.RawConfig?,
) {
  fun activeRoutines(now: Calendar = Calendar.getInstance()): List<FocusSchedule.Routine> {
    if (routines.isEmpty()) return emptyList()
    return FocusSchedule.active(routines, now)
  }

  fun activeManual(nowElapsedMs: Long, currentBoot: Int): ManualFocusStore.Selection? {
    val current = manual ?: return null
    val timing = ManualFocusTiming.evaluate(
      enabled = current.enabled,
      deadline = current.deadline,
      recordedBoot = current.recordedBoot,
      currentBoot = currentBoot,
      now = nowElapsedMs,
    )
    return if (timing.active) current.selection else null
  }
}

object AccessibilityPolicyHelper {
  fun shouldInspectBrowserAddress(
    eventType: Int?,
    packageName: String,
    websiteChecksEnabled: Boolean,
    hasBlockedWebsites: Boolean,
    hasAddressViewId: Boolean,
    lastCheckedPackage: String?,
    lastCheckedAtMs: Long,
    nowMs: Long,
    minContentDebounceMs: Long = 150L,
  ): Boolean {
    if (!websiteChecksEnabled || !hasBlockedWebsites || !hasAddressViewId) return false
    if (eventType == null || eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || eventType == AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED) {
      return true
    }
    if (eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
      if (lastCheckedPackage != packageName) return true
      return nowMs - lastCheckedAtMs >= minContentDebounceMs
    }
    return false
  }
}

class AccessibilityPolicyCache {
  @Volatile
  private var dirty = true
  @Volatile
  private var revision = 0L
  private var cached: CachedAccessibilityPolicy? = null

  fun invalidate() {
    dirty = true
  }

  fun get(context: Context, preferences: SharedPreferences): CachedAccessibilityPolicy {
    val current = cached
    if (!dirty && current != null) return current

    val nextRevision = ++revision
    val active = preferences.getBoolean(BloomBlockingModule.BLOCKING_ACTIVE, false)
    val personalApps = preferences.getStringSet(BloomBlockingModule.BLOCKED_APPS, emptySet()).orEmpty().toSet()
    val managedApps = preferences.getStringSet(BloomBlockingModule.MANAGED_APPS, emptySet()).orEmpty().toSet()
    val personalWebsites = preferences.getStringSet(BloomBlockingModule.BLOCKED_WEBSITES, emptySet()).orEmpty().toSet()
    val managedWebsites = preferences.getStringSet(BloomBlockingModule.MANAGED_WEBSITES, emptySet()).orEmpty().toSet()
    val websiteChecksEnabled = preferences.getBoolean(BloomBlockingModule.WEBSITE_CONSENT, false)
    val creditAccount = preferences.getString(BloomBlockingModule.CREDIT_ACCOUNT, null)
    val focusRoutineAccount = FocusRoutineStore.account(context)
    val routines = try { FocusRoutineStore.read(context) } catch (_: Exception) { emptyList() }
    val manual = try { ManualFocusStore.readRaw(context) } catch (_: Exception) { null }

    val snapshot = CachedAccessibilityPolicy(
      revision = nextRevision,
      active = active,
      personalApps = personalApps,
      managedApps = managedApps,
      personalWebsites = personalWebsites,
      managedWebsites = managedWebsites,
      websiteChecksEnabled = websiteChecksEnabled,
      creditAccount = creditAccount,
      focusRoutineAccount = focusRoutineAccount,
      routines = routines,
      manual = manual,
    )
    cached = snapshot
    dirty = false
    return snapshot
  }
}
