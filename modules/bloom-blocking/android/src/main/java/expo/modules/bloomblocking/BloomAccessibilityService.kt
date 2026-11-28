package expo.modules.bloomblocking

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.content.Context
import android.content.SharedPreferences
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.widget.Toast

class BloomAccessibilityService : AccessibilityService() {
  private var lastBlockedTarget: String? = null
  private var lastBlockedPackage: String? = null
  private var blockedOverlay: BloomBlockedOverlay? = null
  private var receiverRegistered = false
  private var heartbeatRunning = false
  private val policyCache = AccessibilityPolicyCache()
  private var lastAddressCheckPackage: String? = null
  private var lastAddressCheckAtMs: Long = 0L
  private var lastAddressValue: String? = null
  private val handler = Handler(Looper.getMainLooper())
  private val checkDeadline = Runnable { checkActiveWindow() }
  private val heartbeat = object : Runnable {
    override fun run() {
      writeHeartbeat()
      checkActiveWindow()
      handler.postDelayed(this, SERVICE_HEARTBEAT_INTERVAL)
    }
  }
  private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
    if (key == BloomBlockingModule.CREDIT_DEADLINE || key == BloomBlockingModule.CREDIT_BOOT || key == BloomBlockingModule.CREDIT_ACCOUNT || key == BloomBlockingModule.BLOCKING_ACTIVE
      || key == BloomBlockingModule.BLOCKED_APPS || key == BloomBlockingModule.BLOCKED_WEBSITES
      || key == BloomBlockingModule.MANAGED_APPS || key == BloomBlockingModule.MANAGED_WEBSITES
      || key == BloomBlockingModule.WEBSITE_CONSENT
      || key == "focus_routine_account" || key?.startsWith("focus_routines:") == true
      || key?.startsWith("manual_focus_") == true) {
      policyCache.invalidate()
      handler.post(checkDeadline)
    }
  }
  private val usagePreferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ ->
    handler.post(checkDeadline)
  }
  private val screenReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      if (intent.action == Intent.ACTION_SCREEN_OFF) {
        UsageTracker.setTracking(context, false)
        dismissBlockedOverlay()
        lastBlockedTarget = null
      }
      else handler.post(checkDeadline)
    }
  }

  override fun onServiceConnected() {
    super.onServiceConnected()
    policyCache.invalidate()
    UsageTracker.recoverAfterInterruption(this)
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    preferences.registerOnSharedPreferenceChangeListener(preferenceListener)
    getSharedPreferences("bloom_actual_usage", Context.MODE_PRIVATE)
      .registerOnSharedPreferenceChangeListener(usagePreferenceListener)
    startHeartbeat()
    val filter = IntentFilter().apply { addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_SCREEN_ON); addAction(Intent.ACTION_USER_PRESENT) }
    if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    else @Suppress("DEPRECATION") registerReceiver(screenReceiver, filter)
    receiverRegistered = true
    handler.post(checkDeadline)
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (!heartbeatRunning) startHeartbeat()
    checkActiveWindow(event)
  }

  private fun checkActiveWindow(event: AccessibilityEvent? = null) {
    // During an app transition Android can send the window-state event before
    // rootInActiveWindow is ready. Use that event's package as the immediate
    // fallback, while continuing to prefer the active root whenever available.
    val packageName = ActivePackageResolver.resolve(
      rootInActiveWindow?.packageName?.toString(),
      event?.packageName?.toString(),
      event?.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
    )
    if (packageName == null) {
      UsageTracker.setTracking(this, false)
      if (blockedOverlay == null) lastBlockedTarget = null
      return
    }
    checkWindow(packageName, event?.eventType)
  }

  private fun checkWindow(packageName: String, eventType: Int? = null) {
    val effectivePackage = if (packageName == this.packageName && blockedOverlay != null) {
      lastBlockedPackage ?: return
    } else {
      packageName
    }
    if (ProtectedPackages.isProtected(this, effectivePackage)) {
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      lastBlockedPackage = null
      dismissBlockedOverlay()
      return
    }

    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    val policy = policyCache.get(this, preferences)
    val active = policy.active
    val personalApps = policy.personalApps
    val managedApps = policy.managedApps
    val routines = policy.activeRoutines()
    val currentBoot = Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1)
    val nowMs = SystemClock.elapsedRealtime()
    val manual = policy.activeManual(nowMs, currentBoot)
    if (!active && routines.isEmpty() && manual == null) {
      handler.removeCallbacks(checkDeadline)
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      lastBlockedPackage = null
      dismissBlockedOverlay()
      return
    }
    val remaining = if (CreditDeadline.accountMatches(policy.creditAccount, policy.focusRoutineAccount)) CreditDeadline.remainingMillis(
      preferences.getLong(BloomBlockingModule.CREDIT_DEADLINE, 0),
      preferences.getInt(BloomBlockingModule.CREDIT_BOOT, -1),
      currentBoot,
      nowMs,
    ) else 0L
    handler.removeCallbacks(checkDeadline)
    val personalWebsites = policy.personalWebsites
    val managedWebsites = policy.managedWebsites
    val scheduledWebsites = routines.flatMap { it.websites }.toSet()
    val blockedWebsites = (if (active) personalWebsites + managedWebsites else emptySet()) + scheduledWebsites + (manual?.websites ?: emptySet())
    val websiteChecksEnabled = policy.websiteChecksEnabled
    val addressViewId = BrowserAddressIds.viewId(effectivePackage)
    val address = if (packageName != this.packageName && AccessibilityPolicyHelper.shouldInspectBrowserAddress(
        eventType = eventType,
        packageName = effectivePackage,
        websiteChecksEnabled = websiteChecksEnabled,
        hasBlockedWebsites = blockedWebsites.isNotEmpty(),
        hasAddressViewId = addressViewId != null,
        lastCheckedPackage = lastAddressCheckPackage,
        lastCheckedAtMs = lastAddressCheckAtMs,
        nowMs = nowMs,
      )
    ) {
      val root = rootInActiveWindow?.takeIf { it.packageName?.toString() == effectivePackage }
      val resolved = root?.findAccessibilityNodeInfosByViewId(addressViewId!!)?.asSequence()
        ?.mapNotNull { it.text?.toString() }
        ?.firstOrNull()
      lastAddressCheckPackage = effectivePackage
      lastAddressCheckAtMs = nowMs
      lastAddressValue = resolved
      resolved
    } else if (websiteChecksEnabled && addressViewId != null && lastAddressCheckPackage == effectivePackage) {
      lastAddressValue
    } else null
    fun target(apps: Set<String>, websites: Set<String>): String? {
      val decision = if (websiteChecksEnabled) BrowserAddressIds.decide(effectivePackage, address, websites)
        else BrowserAddressIds.Decision(BrowserAddressIds.DecisionKind.NONE)
      return when {
        ProtectedPackages.isProtected(this, effectivePackage) -> null
        effectivePackage in apps -> "app:$effectivePackage"
        decision.kind == BrowserAddressIds.DecisionKind.BLOCK_WEBSITE -> "website:$effectivePackage:${decision.host}"
        decision.kind == BrowserAddressIds.DecisionKind.BLOCK_UNREADABLE_BROWSER -> "browser-unreadable:$effectivePackage"
        else -> null
      }
    }
    // Parent restrictions are hard blocks; access grants apply only to personal targets.
    val managedTarget = if (active) target(managedApps, managedWebsites) else null
    val personalTarget = if (active) target(personalApps, personalWebsites) else null
    val scheduled = routines.mapNotNull { routine ->
      target(routine.apps, routine.websites)?.let { EffectiveAccess.Restriction(it, routine.name) }
    }
    val manualTarget = manual?.let { target(it.apps, it.websites) }
    val hard = EffectiveAccess.evaluate(managedTarget, manualTarget, scheduled, null, true)
    if (remaining > 0 && !hard.blocked) {
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      lastBlockedPackage = null
      dismissBlockedOverlay()
      handler.postDelayed(checkDeadline, remaining)
      return
    }
    val interactive = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
    val storedUsage = UsageTracker.state(this)
    val usage = if (storedUsage != null && storedUsage.user == FocusRoutineStore.account(this))
      UsageTracker.setTracking(this, !hard.blocked && personalTarget != null && interactive)
    else {
      if (storedUsage != null) UsageTracker.setTracking(this, false)
      null
    }
    if (usage != null && !usage.closed && !hard.blocked) {
      val untilCheck = if (usage.tracking) minOf(usage.remaining, usage.expiryRemaining, 1000L)
        else minOf(usage.remaining, usage.expiryRemaining)
      if (untilCheck > 0) handler.postDelayed(checkDeadline, untilCheck)
    }
    val decision = EffectiveAccess.evaluate(managedTarget, manualTarget, scheduled, personalTarget,
      remaining > 0 || (usage != null && !usage.closed && interactive))
    val target = decision.target
    if (target == null) {
      lastBlockedTarget = null
      lastBlockedPackage = null
      dismissBlockedOverlay()
      return
    }
    val blockedKey = "$target|${decision.reasons.joinToString("|")}"
    if (blockedKey == lastBlockedTarget && blockedOverlay != null) return

    lastBlockedTarget = blockedKey
    lastBlockedPackage = effectivePackage
    UsageTracker.setTracking(this, false)
    try {
      val notice = BloomBlockedOverlay(this)
      notice.show(
        targetLabel = blockedTargetLabel(effectivePackage, target),
        reasons = decision.reasons,
        onOpenBloom = ::openBloomFromNotice,
        onGoHome = ::goHomeFromNotice,
      )
      blockedOverlay?.dismiss()
      blockedOverlay = notice
    } catch (_: RuntimeException) {
      dismissBlockedOverlay()
      Toast.makeText(
        this,
        BlockedNotice.message(blockedTargetLabel(packageName, target), decision.reasons),
        Toast.LENGTH_LONG,
      ).show()
      performGlobalAction(GLOBAL_ACTION_HOME)
    }
  }

  private fun blockedTargetLabel(packageName: String, target: String): String {
    val websitePrefix = "website:$packageName:"
    if (target.startsWith(websitePrefix)) return target.removePrefix(websitePrefix)
    if (target.startsWith("browser-unreadable:")) return "${applicationLabel(packageName)} website access"
    return applicationLabel(packageName)
  }

  private fun applicationLabel(packageName: String): String = try {
    @Suppress("DEPRECATION")
    packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
  } catch (_: Exception) {
    packageName.substringAfterLast('.')
  }

  private fun openBloomFromNotice() {
    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
    if (launchIntent == null) {
      Toast.makeText(this, "Open Bloom from your app launcher to review blocking rules.", Toast.LENGTH_LONG).show()
      return
    }
    launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    try {
      // Keep the visible accessibility window until Android accepts this
      // user-tapped launch, then uncover Bloom after its launch transition.
      startActivity(launchIntent)
      handler.postDelayed({ dismissBlockedOverlay() }, 300)
    } catch (_: SecurityException) {
      Toast.makeText(this, "Bloom could not open. Use Go to home screen to leave this app.", Toast.LENGTH_LONG).show()
    }
  }

  private fun goHomeFromNotice() {
    dismissBlockedOverlay()
    lastBlockedTarget = null
    performGlobalAction(GLOBAL_ACTION_HOME)
  }

  private fun dismissBlockedOverlay() {
    blockedOverlay?.dismiss()
    blockedOverlay = null
  }

  override fun onInterrupt() {
    UsageTracker.setTracking(this, false)
    dismissBlockedOverlay()
    lastBlockedTarget = null
    heartbeatRunning = false
    getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).edit()
      .putLong(BloomBlockingModule.SERVICE_HEARTBEAT, 0).apply()
    handler.removeCallbacks(heartbeat)
    handler.removeCallbacks(checkDeadline)
  }

  override fun onDestroy() {
    policyCache.invalidate()
    UsageTracker.setTracking(this, false)
    dismissBlockedOverlay()
    if (receiverRegistered) unregisterReceiver(screenReceiver)
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    preferences.edit().putLong(BloomBlockingModule.SERVICE_HEARTBEAT, 0).apply()
    preferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
    getSharedPreferences("bloom_actual_usage", Context.MODE_PRIVATE)
      .unregisterOnSharedPreferenceChangeListener(usagePreferenceListener)
    heartbeatRunning = false
    handler.removeCallbacks(heartbeat)
    handler.removeCallbacks(checkDeadline)
    super.onDestroy()
  }

  companion object {
    private const val SERVICE_HEARTBEAT_INTERVAL = 5_000L
  }

  private fun startHeartbeat() {
    writeHeartbeat()
    if (heartbeatRunning) return
    heartbeatRunning = true
    handler.removeCallbacks(heartbeat)
    handler.postDelayed(heartbeat, SERVICE_HEARTBEAT_INTERVAL)
  }

  private fun writeHeartbeat() {
    getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).edit()
      .putLong(BloomBlockingModule.SERVICE_HEARTBEAT, SystemClock.elapsedRealtime()).apply()
  }

}
