package expo.modules.bloomblocking

import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import android.provider.Settings.Secure
import android.text.TextUtils
import android.content.Context
import android.os.SystemClock

class BloomBlockingModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("BloomBlocking")

    Function("getStatus") {
      val context = appContext.reactContext ?: return@Function status(null)
      val enabled = isAccessibilityEnabled(context)
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      val targets = prefs
        .getStringSet(BLOCKED_APPS, emptySet()).orEmpty()
        .plus(prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty())
      val websites = prefs
        .getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty()
        .plus(prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty())
      val active = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getBoolean(BLOCKING_ACTIVE, false)
      status(context, enabled, active && enabled, targets.size, websites.size)
    }

    Function("getInstalledApps") {
      val context = appContext.reactContext ?: return@Function emptyList<Map<String, String>>()
      val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
      @Suppress("DEPRECATION")
      context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        .asSequence()
        .filter { it.activityInfo.packageName != context.packageName }
        .distinctBy { it.activityInfo.packageName }
        .map {
          mapOf(
            "id" to it.activityInfo.packageName,
            "name" to it.loadLabel(context.packageManager).toString(),
          )
        }
        .sortedBy { it["name"]?.lowercase() }
        .toList()
    }

    Function("getSelectedApps") {
      val context = appContext.reactContext ?: return@Function emptyList<String>()
      context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getStringSet(BLOCKED_APPS, emptySet()).orEmpty().toList()
    }

    Function("getManagedTargets") {
      val context = appContext.reactContext ?: return@Function mapOf("apps" to emptyList<String>(), "websites" to emptyList<String>(), "accountId" to null)
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      mapOf("apps" to prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().sorted(),
        "websites" to prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().sorted(),
        "accountId" to prefs.getString(MANAGED_ACCOUNT, null))
    }

    Function("getWebsites") {
      val context = appContext.reactContext ?: return@Function emptyList<String>()
      context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty().sorted()
    }

    Function("getWebsiteConsent") {
      val context = appContext.reactContext ?: return@Function false
      context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getBoolean(WEBSITE_CONSENT, false)
    }

    AsyncFunction("setWebsiteConsent") { enabled: Boolean ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      check(enabled || prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isEmpty()) { "Parent-set website rules require website checks to stay enabled." }
      val edit = prefs.edit().putBoolean(WEBSITE_CONSENT, enabled)
      if (enabled && (prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isNotEmpty()
        || prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isNotEmpty())) edit.putBoolean(BLOCKING_ACTIVE, true)
      if (!enabled && prefs.getStringSet(BLOCKED_APPS, emptySet()).orEmpty().isEmpty()
        && prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isEmpty()) {
        edit.putBoolean(BLOCKING_ACTIVE, false)
      }
      edit.apply()
    }

    AsyncFunction("requestAccessibilityPermission") {
      val activity = appContext.currentActivity ?: return@AsyncFunction false
      activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
      true
    }

    AsyncFunction("saveApps") { packageIds: List<String> ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      val allowed = getLaunchablePackages(context)
      require(packageIds.size <= MAX_TARGETS && packageIds.all { it in allowed }) { "Choose apps from the installed-app list." }
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      val edit = prefs.edit().putStringSet(BLOCKED_APPS, packageIds.toSet())
      val websiteTargetsEnabled = prefs.getBoolean(WEBSITE_CONSENT, false)
        && (prefs.getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty().isNotEmpty()
          || prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isNotEmpty())
      if (packageIds.isEmpty() && prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isEmpty() && !websiteTargetsEnabled) {
        edit.putBoolean(BLOCKING_ACTIVE, false)
      }
      edit.apply()
    }

    AsyncFunction("saveWebsites") { addresses: List<String> ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      require(addresses.size <= MAX_TARGETS) { "Too many websites selected." }
      val domains = addresses.map { WebsiteDomains.host(it) ?: throw IllegalArgumentException("Enter a valid website domain.") }.toSet()
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      check(domains.isEmpty() || prefs.getBoolean(WEBSITE_CONSENT, false)) { "Enable website checks first." }
      val edit = prefs.edit().putStringSet(BLOCKED_WEBSITES, domains)
      if (domains.isEmpty() && prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isEmpty()
        && prefs.getStringSet(BLOCKED_APPS, emptySet()).orEmpty().isEmpty()
        && prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isEmpty()) {
        edit.putBoolean(BLOCKING_ACTIVE, false)
      }
      edit.apply()
    }

    AsyncFunction("setManagedTargets") { packageIds: List<String>, addresses: List<String>, accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      require(packageIds.size <= MAX_TARGETS && packageIds.all { PACKAGE_ID.matches(it) && it != context.packageName }) { "A parent app rule is invalid." }
      require(addresses.size <= MAX_TARGETS) { "Too many parent website rules." }
      require(accountId.isNotBlank() && accountId.length <= 64) { "A parent account identifier is invalid." }
      val domains = addresses.map { WebsiteDomains.host(it) ?: throw IllegalArgumentException("A parent website rule is invalid.") }.toSet()
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      val previousApps = prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty()
      val wasManaged = previousApps.isNotEmpty() || prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isNotEmpty()
      val edit = prefs.edit().putStringSet(MANAGED_APPS, packageIds.toSet()).putStringSet(MANAGED_WEBSITES, domains)
        .putString(MANAGED_ACCOUNT, accountId)
      if (packageIds.isNotEmpty() || (domains.isNotEmpty() && prefs.getBoolean(WEBSITE_CONSENT, false))) edit.putBoolean(BLOCKING_ACTIVE, true)
      else if (wasManaged && prefs.getStringSet(BLOCKED_APPS, emptySet()).orEmpty().isEmpty()
        && prefs.getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty().isEmpty()) edit.putBoolean(BLOCKING_ACTIVE, false)
      check(edit.commit()) { "Could not save parent-set blocking rules." }
    }

    AsyncFunction("startBlocking") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      check(isAccessibilityEnabled(context)) { "Enable Bloom in Android Accessibility settings first." }
      val targets = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getStringSet(BLOCKED_APPS, emptySet()).orEmpty()
        .plus(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getStringSet(MANAGED_APPS, emptySet()).orEmpty())
      val websites = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty()
        .plus(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty())
      val websiteConsent = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        .getBoolean(WEBSITE_CONSENT, false)
      check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isEmpty() || websiteConsent) {
        "Enable website checks before starting parent-set website rules."
      }
      check(targets.isNotEmpty() || (websiteConsent && websites.isNotEmpty())) { "Choose at least one app or website to block." }
      context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        .putBoolean(BLOCKING_ACTIVE, true)
        .remove(CREDIT_DEADLINE)
        .remove(CREDIT_BOOT)
        .apply()
    }

    // Keep blocking enabled; the service temporarily allows access until this deadline.
    Function("getCreditClock") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      mapOf("elapsedMillis" to SystemClock.elapsedRealtime().toDouble(), "boot" to Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1))
    }

    Function("getCreditAccessRemaining") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      creditRemaining(context).toDouble()
    }

    Function("getUsageAccess") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      UsageTracker.state(context)?.let { usageStatus(it) }
    }

    AsyncFunction("startUsageAccess") { session: String, user: String, budget: Double, expiresIn: Double, requestElapsed: Double, requestBoot: Int ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      check(isAccessibilityEnabled(context) && prefs.getBoolean(BLOCKING_ACTIVE, false)) { "Start blocking before using screen time." }
      check(creditRemaining(context) <= 0) { "A countdown is already active." }
      require(budget.isFinite() && expiresIn.isFinite() && requestElapsed.isFinite()) { "Invalid screen-time reservation." }
      UsageTracker.start(context, session, user, budget.toLong(), expiresIn.toLong(), requestElapsed.toLong(), requestBoot)
    }

    AsyncFunction("closeUsageAccess") { user: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      UsageTracker.close(context, user)?.let { usageStatus(it) }
    }

    AsyncFunction("clearUsageAccess") { user: String, session: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      UsageTracker.clear(context, user, session)
    }

    AsyncFunction("startCreditAccess") { durationMillis: Double, requestElapsedMillis: Double, requestBoot: Int ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      check(isAccessibilityEnabled(context) && prefs.getBoolean(BLOCKING_ACTIVE, false)) { "Start blocking before using screen time." }
      require(durationMillis.isFinite() && durationMillis >= 1000 && durationMillis <= 86400000 && requestElapsedMillis.isFinite() && requestElapsedMillis >= 0) { "Invalid screen-time duration." }
      val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
      val now = SystemClock.elapsedRealtime()
      check(boot >= 0 && boot == requestBoot && requestElapsedMillis <= now) { "Could not verify device uptime." }
      val deadline = CreditDeadline.fromServerRemaining(durationMillis.toLong(), requestElapsedMillis.toLong(), now, requestBoot, boot)
      check(deadline - now >= 1000) { "Screen-time session has ended." }
      check(prefs.edit().putLong(CREDIT_DEADLINE, deadline).putInt(CREDIT_BOOT, boot).commit()) { "Could not save the screen-time deadline." }
    }

    AsyncFunction("endCreditAccess") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        .remove(CREDIT_DEADLINE).remove(CREDIT_BOOT).commit()) { "Could not end screen time." }
    }

    AsyncFunction("stopBlocking") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      check(prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isEmpty()
        && (prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isEmpty() || !prefs.getBoolean(WEBSITE_CONSENT, false))) {
        "Parent-set blocking rules must stay active."
      }
      context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        .putBoolean(BLOCKING_ACTIVE, false)
        .remove(CREDIT_DEADLINE)
        .remove(CREDIT_BOOT)
        .apply()
    }
  }

  private fun status(context: Context?, authorized: Boolean = false, active: Boolean = false,
    appCount: Int = 0, websiteCount: Int = 0): Map<String, Any> {
    val connected = context?.let(::isServiceConnected) ?: false
    return mapOf(
      "supported" to true,
      "authorized" to authorized,
      "active" to active,
      "appCount" to appCount,
      "websiteCount" to websiteCount,
      "categoryCount" to 0,
      "serviceConnected" to connected,
      "serviceHealth" to when {
        !authorized -> "permissionRequired"
        connected -> "connected"
        active -> "serviceUnavailable"
        else -> "stopped"
      },
      "supportedBrowsers" to BrowserAddressIds.supportedNames,
    )
  }

  private fun isServiceConnected(context: Context): Boolean {
    if (!isAccessibilityEnabled(context)) return false
    val heartbeat = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      .getLong(SERVICE_HEARTBEAT, 0)
    return ServiceHeartbeat.isFresh(heartbeat, SystemClock.elapsedRealtime(), SERVICE_HEARTBEAT_MAX_AGE)
  }

  private fun creditRemaining(context: Context): Long {
    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    return CreditDeadline.remainingMillis(prefs.getLong(CREDIT_DEADLINE, 0), prefs.getInt(CREDIT_BOOT, -1),
      Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1), SystemClock.elapsedRealtime())
  }

  private fun checkNoActiveAccess(context: Context) {
    check(creditRemaining(context) <= 0 && UsageTracker.state(context)?.closed != false) { "Finish screen time before changing blocking settings." }
  }

  private fun usageStatus(state: UsageTracker.State) = mapOf(
    "sessionId" to state.session, "userId" to state.user, "budgetMillis" to state.budget.toDouble(),
    "usedMillis" to state.used.toDouble(), "remainingMillis" to state.remaining.toDouble(),
    "closed" to state.closed, "tracking" to state.tracking,
  )

  private fun isAccessibilityEnabled(context: Context): Boolean {
    val service = "${context.packageName}/${BloomAccessibilityService::class.java.name}"
    val enabled = Secure.getString(context.contentResolver, Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
    val splitter = TextUtils.SimpleStringSplitter(':')
    splitter.setString(enabled)
    return splitter.any { it.equals(service, ignoreCase = true) }
  }

  private fun getLaunchablePackages(context: Context): Set<String> {
    val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
    @Suppress("DEPRECATION")
    return context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
      .map { it.activityInfo.packageName }
      .filter { it != context.packageName }
      .toSet()
  }

  companion object {
    const val PREFERENCES = "bloom_blocking"
    const val BLOCKED_APPS = "blocked_apps"
    const val BLOCKED_WEBSITES = "blocked_websites"
    const val WEBSITE_CONSENT = "website_checks_enabled"
    const val MANAGED_APPS = "managed_apps"
    const val MANAGED_WEBSITES = "managed_websites"
    const val MANAGED_ACCOUNT = "managed_account"
    const val BLOCKING_ACTIVE = "is_active"
    const val SERVICE_HEARTBEAT = "service_heartbeat_elapsed"
    const val CREDIT_DEADLINE = "credit_deadline_elapsed"
    const val CREDIT_BOOT = "credit_boot_count"
    const val MAX_TARGETS = 500
    private const val SERVICE_HEARTBEAT_MAX_AGE = 15_000L
    private val PACKAGE_ID = Regex("^[A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)+$")
  }
}
