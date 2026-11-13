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
      handler.postDelayed(this, SERVICE_HEARTBEAT_INTERVAL)
    }
  }
  private val preferenceListener = SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
    if (key == BloomBlockingModule.CREDIT_DEADLINE || key == BloomBlockingModule.CREDIT_BOOT || key == BloomBlockingModule.BLOCKING_ACTIVE
      || key == BloomBlockingModule.MANAGED_APPS || key == BloomBlockingModule.MANAGED_WEBSITES) {
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
    val packageName = rootInActiveWindow?.packageName?.toString() ?: event?.packageName?.toString() ?: return
    checkWindow(packageName)
  }

  private fun checkActiveWindow() {
    val packageName = rootInActiveWindow?.packageName?.toString()
    if (packageName == null) { UsageTracker.setTracking(this, false); return }
    checkWindow(packageName)
  }

  private fun checkWindow(packageName: String) {
    val preferences = getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    val active = preferences.getBoolean(BloomBlockingModule.BLOCKING_ACTIVE, false)
    val blocked = preferences.getStringSet(BloomBlockingModule.BLOCKED_APPS, emptySet()).orEmpty()
      .plus(preferences.getStringSet(BloomBlockingModule.MANAGED_APPS, emptySet()).orEmpty())
    if (!active) {
      handler.removeCallbacks(checkDeadline)
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      return
    }
    val remaining = CreditDeadline.remainingMillis(
      preferences.getLong(BloomBlockingModule.CREDIT_DEADLINE, 0),
      preferences.getInt(BloomBlockingModule.CREDIT_BOOT, -1),
      Settings.Global.getInt(contentResolver, Settings.Global.BOOT_COUNT, -1),
      SystemClock.elapsedRealtime(),
    )
    handler.removeCallbacks(checkDeadline)
    if (remaining > 0) {
      UsageTracker.setTracking(this, false)
      lastBlockedTarget = null
      handler.postDelayed(checkDeadline, remaining)
      return
    }
    val blockedWebsites = preferences.getStringSet(BloomBlockingModule.BLOCKED_WEBSITES, emptySet()).orEmpty()
      .plus(preferences.getStringSet(BloomBlockingModule.MANAGED_WEBSITES, emptySet()).orEmpty())
    val websiteChecksEnabled = preferences.getBoolean(BloomBlockingModule.WEBSITE_CONSENT, false)
    val addressViewId = BrowserAddressIds.viewId(packageName)
    val root = rootInActiveWindow?.takeIf { it.packageName?.toString() == packageName }
    val address = if (websiteChecksEnabled && addressViewId != null && blockedWebsites.isNotEmpty()) {
      root?.findAccessibilityNodeInfosByViewId(addressViewId)?.asSequence()
        ?.mapNotNull { it.text?.toString() }
        ?.firstOrNull()
    } else null
    val websiteDecision = if (websiteChecksEnabled) {
      BrowserAddressIds.decide(packageName, address, blockedWebsites)
    } else BrowserAddressIds.Decision(BrowserAddressIds.DecisionKind.NONE)

    val target = when {
      packageName == this.packageName -> null
      packageName in blocked -> "app:$packageName"
      websiteDecision.kind == BrowserAddressIds.DecisionKind.BLOCK_WEBSITE -> "website:$packageName:${websiteDecision.host}"
      websiteDecision.kind == BrowserAddressIds.DecisionKind.BLOCK_UNREADABLE_BROWSER -> "browser-unreadable:$packageName"
      else -> null
    }
    val interactive = (getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive
    val usage = UsageTracker.setTracking(this, target != null && interactive)
    if (usage != null && !usage.closed) {
      val untilCheck = if (usage.tracking) minOf(usage.remaining, usage.expiryRemaining, 1000L)
        else minOf(usage.remaining, usage.expiryRemaining)
      if (untilCheck > 0) handler.postDelayed(checkDeadline, untilCheck)
      if (target != null && interactive) {
        lastBlockedTarget = null
        return
      }
    }
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
