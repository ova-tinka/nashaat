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

class BloomAccessibilityService : AccessibilityService() {
  private var lastBlockedTarget: String? = null
  private var receiverRegistered = false
  private var heartbeatRunning = false
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
      || key == BloomBlockingModule.MANAGED_APPS || key == BloomBlockingModule.MANAGED_WEBSITES
      || key == "focus_routine_account" || key?.startsWith("focus_routines:") == true
      || key?.startsWith("manual_focus_") == true) {
      handler.post(checkDeadline)
    }
  }
  private val screenReceiver = object : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
      if (intent.action == Intent.ACTION_SCREEN_OFF) UsageTracker.setTracking(context, false)
      else handler.post(checkDeadline)
    }
  }

  override fun onServiceConnected() {
    super.onServiceConnected()
    UsageTracker.recoverAfterInterruption(this)
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    preferences.registerOnSharedPreferenceChangeListener(preferenceListener)
    startHeartbeat()
    val filter = IntentFilter().apply { addAction(Intent.ACTION_SCREEN_OFF); addAction(Intent.ACTION_SCREEN_ON); addAction(Intent.ACTION_USER_PRESENT) }
    if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
    else @Suppress("DEPRECATION") registerReceiver(screenReceiver, filter)
    receiverRegistered = true
    handler.post(checkDeadline)
  }

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (!heartbeatRunning) startHeartbeat()
    // An event may originate from a background window; only the active root
    // is reliable enough to report a selected app as currently visible.
    checkActiveWindow()
  }

  private fun checkActiveWindow() {
    val packageName = rootInActiveWindow?.packageName?.toString()
    if (packageName == null) { UsageTracker.setTracking(this, false); lastBlockedTarget = null; return }
    checkWindow(packageName)
  }

  private fun checkWindow(packageName: String) {
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    val active = preferences.getBoolean(BloomBlockingModule.BLOCKING_ACTIVE, false)
    val personalApps = preferences.getStringSet(BloomBlockingModule.BLOCKED_APPS, emptySet()).orEmpty()
    val managedApps = preferences.getStringSet(BloomBlockingModule.MANAGED_APPS, emptySet()).orEmpty()
    val routines = try { FocusSchedule.active(FocusRoutineStore.read(this)) } catch (_: Exception) { emptyList() }
    val manual = try { ManualFocusStore.read(this)?.takeIf { it.active } } catch (_: Exception) { null }
    if (!active && routines.isEmpty() && manual == null) {
      handler.removeCallbacks(checkDeadline)
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      return
    }
    val remaining = if (CreditDeadline.accountMatches(preferences.getString(BloomBlockingModule.CREDIT_ACCOUNT, null), FocusRoutineStore.account(this))) CreditDeadline.remainingMillis(
      preferences.getLong(BloomBlockingModule.CREDIT_DEADLINE, 0),
      preferences.getInt(BloomBlockingModule.CREDIT_BOOT, -1),
      Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1),
      SystemClock.elapsedRealtime(),
    ) else 0L
    handler.removeCallbacks(checkDeadline)
    val personalWebsites = preferences.getStringSet(BloomBlockingModule.BLOCKED_WEBSITES, emptySet()).orEmpty()
    val managedWebsites = preferences.getStringSet(BloomBlockingModule.MANAGED_WEBSITES, emptySet()).orEmpty()
    val scheduledWebsites = routines.flatMap { it.websites }.toSet()
    val blockedWebsites = (if (active) personalWebsites + managedWebsites else emptySet()) + scheduledWebsites + (manual?.selection?.websites ?: emptySet())
    val websiteChecksEnabled = preferences.getBoolean(BloomBlockingModule.WEBSITE_CONSENT, false)
    val addressViewId = BrowserAddressIds.viewId(packageName)
    val root = rootInActiveWindow?.takeIf { it.packageName?.toString() == packageName }
    val address = if (websiteChecksEnabled && addressViewId != null && blockedWebsites.isNotEmpty()) {
      root?.findAccessibilityNodeInfosByViewId(addressViewId)?.asSequence()
        ?.mapNotNull { it.text?.toString() }
        ?.firstOrNull()
    } else null
    fun target(apps: Set<String>, websites: Set<String>): String? {
      val decision = if (websiteChecksEnabled) BrowserAddressIds.decide(packageName, address, websites)
        else BrowserAddressIds.Decision(BrowserAddressIds.DecisionKind.NONE)
      return when {
        packageName == this.packageName -> null
        packageName in apps -> "app:$packageName"
        decision.kind == BrowserAddressIds.DecisionKind.BLOCK_WEBSITE -> "website:$packageName:${decision.host}"
        decision.kind == BrowserAddressIds.DecisionKind.BLOCK_UNREADABLE_BROWSER -> "browser-unreadable:$packageName"
        else -> null
      }
    }
    // Parent restrictions are hard blocks; access grants apply only to personal targets.
    val managedTarget = if (active) target(managedApps, managedWebsites) else null
    val personalTarget = if (active) target(personalApps, personalWebsites) else null
    val scheduled = routines.mapNotNull { routine ->
      target(routine.apps, routine.websites)?.let { EffectiveAccess.Restriction(it, routine.name) }
    }
    val manualTarget = manual?.selection?.let { target(it.apps, it.websites) }
    val hard = EffectiveAccess.evaluate(managedTarget, manualTarget, scheduled, null, true)
    if (remaining > 0 && !hard.blocked) {
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
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
      return
    }
    if (target == lastBlockedTarget) return

    lastBlockedTarget = target
    performGlobalAction(GLOBAL_ACTION_HOME)
    try {
      startActivity(Intent(this, BloomBlockedActivity::class.java).apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        putExtra(BloomBlockedActivity.EXTRA_APP, packageName)
        putExtra(BloomBlockedActivity.EXTRA_REASONS, decision.reasons.joinToString(" and "))
      })
    } catch (_: SecurityException) {
      // Android may reject a background activity launch; the home action still exits the blocked app.
    }
  }

  override fun onInterrupt() {
    UsageTracker.setTracking(this, false)
    heartbeatRunning = false
    getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).edit()
      .putLong(BloomBlockingModule.SERVICE_HEARTBEAT, 0).apply()
    handler.removeCallbacks(heartbeat)
    handler.removeCallbacks(checkDeadline)
  }

  override fun onDestroy() {
    UsageTracker.setTracking(this, false)
    if (receiverRegistered) unregisterReceiver(screenReceiver)
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    preferences.edit().putLong(BloomBlockingModule.SERVICE_HEARTBEAT, 0).apply()
    preferences.unregisterOnSharedPreferenceChangeListener(preferenceListener)
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
