package expo.modules.bloomblocking

import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.provider.Settings
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import android.provider.Settings.Secure
import android.text.TextUtils
import android.content.Context
import android.os.SystemClock
import android.util.Base64
import java.io.ByteArrayOutputStream

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

    AsyncFunction("setFocusAccount") { accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      FocusRoutineStore.setAccount(context, accountId)
    }

    Function("getFocusAccount") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      FocusRoutineStore.account(context)
    }

    AsyncFunction("clearFocusAccount") { accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      FocusRoutineStore.clearAccount(context, accountId)
    }

    Function("getFocusRoutines") { accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      FocusRoutineStore.json(context, accountId)
    }

    AsyncFunction("saveFocusRoutines") { accountId: String, raw: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      synchronized(FocusRoutineStore) {
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        // Reject configurations that cannot enforce their enabled website targets.
        val routines = FocusRoutineStore.parseForValidation(raw, context.packageName)
        check(prefs.getBoolean(WEBSITE_CONSENT, false) || routines.none { it.enabled && it.websites.isNotEmpty() }) {
          "Enable website checks before saving an enabled website routine."
        }
        FocusRoutineStore.write(context, accountId, raw)
      }
    }

    Function("getManualFocus") { accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      check(FocusRoutineStore.account(context) == accountId) { "The device account changed. Sync and try again." }
      ManualFocusStore.json(ManualFocusStore.read(context, accountId))
    }

    AsyncFunction("saveManualFocus") { accountId: String, raw: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      ManualFocusStore.save(context, accountId, raw)
    }

    AsyncFunction("startManualFocus") { accountId: String, durationMillis: Double ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      require(durationMillis.isFinite() && durationMillis >= 0 && durationMillis <= 604800000 && durationMillis % 1.0 == 0.0) { "Invalid duration." }
      check(isServiceConnected(context)) { "Enable the Android Accessibility service before starting Manual Focus." }
      ManualFocusStore.start(context, accountId, durationMillis.toLong())
    }

    AsyncFunction("stopManualFocus") { accountId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      ManualFocusStore.stop(context, accountId)
    }

    Function("getAppAccessDecision") { accountId: String, packageId: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      require(PACKAGE_ID.matches(packageId) && packageId != context.packageName) { "Choose an app on this device." }
      targetDecision(context, accountId, packageId, false)
    }

    Function("getWebsiteAccessDecision") { accountId: String, address: String ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      val host = WebsiteDomains.host(address) ?: throw IllegalArgumentException("Enter a valid website domain.")
      targetDecision(context, accountId, host, true)
    }

    Function("getInstalledApps") {
      val context = appContext.reactContext ?: return@Function emptyList<Map<String, String>>()
      val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
      @Suppress("DEPRECATION")
      context.packageManager.queryIntentActivities(intent, PackageManager.MATCH_ALL)
        .asSequence()
        .filter { !ProtectedPackages.isProtected(context, it.activityInfo.packageName) }
        .distinctBy { it.activityInfo.packageName }
        .map {
          mapOf(
            "id" to it.activityInfo.packageName,
            "name" to it.loadLabel(context.packageManager).toString(),
            "icon" to runCatching { appIconUri(it.loadIcon(context.packageManager)) }.getOrDefault(""),
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

    Function("getSafariContentBlockerState") { mapOf("bundled" to false, "stateAvailable" to false, "enabled" to false) }

    AsyncFunction("setSafariWebsiteRules") { _alwaysDomains: List<String>, _focusDomains: List<String>, _accountId: String ->
      mapOf("alwaysApplied" to false, "authorizationRequired" to false, "alwaysDomainCount" to 0)
    }

    AsyncFunction("setWebsiteConsent") { enabled: Boolean ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      checkNoActiveAccess(context)
      synchronized(FocusRoutineStore) {
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        check(enabled || prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isEmpty()) { "Parent-set website rules require website checks to stay enabled." }
        check(enabled || FocusRoutineStore.read(context).none { it.enabled && it.websites.isNotEmpty() }) { "Disable website routines before turning off website checks." }
        val manual = ManualFocusStore.read(context)
        check(enabled || manual?.active != true || manual.selection.websites.isEmpty()) { "Stop Manual Focus before turning off website checks." }
        val edit = prefs.edit().putBoolean(WEBSITE_CONSENT, enabled)
        if (enabled && (prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isNotEmpty()
          || prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isNotEmpty())) edit.putBoolean(BLOCKING_ACTIVE, true)
        if (!enabled && prefs.getStringSet(BLOCKED_APPS, emptySet()).orEmpty().isEmpty()
          && prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty().isEmpty()) {
          edit.putBoolean(BLOCKING_ACTIVE, false)
        }
        edit.apply()
      }
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
      val filteredApps = packageIds.filterNot { ProtectedPackages.isProtected(context, it) }.toSet()
      require(addresses.size <= MAX_TARGETS) { "Too many parent website rules." }
      require(accountId.isNotBlank() && accountId.length <= 64) { "A parent account identifier is invalid." }
      val domains = addresses.map { WebsiteDomains.host(it) ?: throw IllegalArgumentException("A parent website rule is invalid.") }.toSet()
      val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
      val previousApps = prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty()
      val wasManaged = previousApps.isNotEmpty() || prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty().isNotEmpty()
      val edit = prefs.edit().putStringSet(MANAGED_APPS, filteredApps).putStringSet(MANAGED_WEBSITES, domains)
        .putString(MANAGED_ACCOUNT, accountId)
      if (filteredApps.isNotEmpty() || (domains.isNotEmpty() && prefs.getBoolean(WEBSITE_CONSENT, false))) edit.putBoolean(BLOCKING_ACTIVE, true)
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
        .remove(CREDIT_ACCOUNT)
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
      UsageTracker.state(context)?.let { usageStatus(it, isServiceConnected(context)) }
    }

    AsyncFunction("startUsageAccess") { session: String, user: String, budget: Double, expiresIn: Double, requestElapsed: Double, requestBoot: Int ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      synchronized(FocusRoutineStore) {
        check(FocusRoutineStore.account(context) == user) { "The device account changed. Sync and try again." }
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        check(isAccessibilityEnabled(context) && prefs.getBoolean(BLOCKING_ACTIVE, false)) { "Start blocking before using screen time." }
        check(creditRemaining(context) <= 0) { "A countdown is already active." }
        require(budget.isFinite() && expiresIn.isFinite() && requestElapsed.isFinite()) { "Invalid screen-time reservation." }
        UsageTracker.start(context, session, user, budget.toLong(), expiresIn.toLong(), requestElapsed.toLong(), requestBoot)
      }
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
      startCreditWindow(context, durationMillis, requestElapsedMillis, requestBoot, null)
    }

    AsyncFunction("startCreditAccessForAccount") { accountId: String, durationMillis: Double, requestElapsedMillis: Double, requestBoot: Int ->
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      startCreditWindow(context, durationMillis, requestElapsedMillis, requestBoot, accountId)
    }

    AsyncFunction("endCreditAccess") {
      val context = appContext.reactContext ?: throw IllegalStateException("Bloom is not available.")
      check(context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit()
        .remove(CREDIT_DEADLINE).remove(CREDIT_BOOT).remove(CREDIT_ACCOUNT).commit()) { "Could not end screen time." }
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
        .remove(CREDIT_ACCOUNT)
        .apply()
    }
  }

  private fun targetDecision(context: Context, accountId: String, target: String, website: Boolean): Map<String, Any> = synchronized(FocusRoutineStore) {
    check(FocusRoutineStore.account(context) == accountId) { "The device account changed. Sync and try again." }
    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    fun matches(apps: Set<String>, sites: Set<String>): Boolean = if (website) WebsiteDomains.matches(target, sites) else target in apps
    val active = prefs.getBoolean(BLOCKING_ACTIVE, false)
    val guardian = if (active && matches(prefs.getStringSet(MANAGED_APPS, emptySet()).orEmpty(), prefs.getStringSet(MANAGED_WEBSITES, emptySet()).orEmpty())) target else null
    val personal = if (active && matches(prefs.getStringSet(BLOCKED_APPS, emptySet()).orEmpty(), prefs.getStringSet(BLOCKED_WEBSITES, emptySet()).orEmpty())) target else null
    val manual = ManualFocusStore.read(context, accountId)?.takeIf { it.active && matches(it.selection.apps, it.selection.websites) }?.let { target }
    val scheduled = FocusSchedule.active(FocusRoutineStore.read(context)).filter { matches(it.apps, it.websites) }
      .map { EffectiveAccess.Restriction(target, it.name) }
    val usage = UsageTracker.state(context)
    val creditAccess = creditRemaining(context) > 0 || (usage != null && usage.user == accountId && !usage.closed)
    val decision = EffectiveAccess.evaluate(guardian, manual, scheduled, personal, creditAccess)
    mapOf("blocked" to decision.blocked, "reasons" to decision.reasons,
      "enforceable" to (isAccessibilityEnabled(context) && isServiceConnected(context) && (!website || prefs.getBoolean(WEBSITE_CONSENT, false))))
  }

  private fun startCreditWindow(context: Context, durationMillis: Double, requestElapsedMillis: Double, requestBoot: Int, expectedAccount: String?) = synchronized(FocusRoutineStore) {
    val account = FocusRoutineStore.account(context)
    check(expectedAccount == null || account == expectedAccount) { "The device account changed. Sync and try again." }
    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    check(isAccessibilityEnabled(context) && prefs.getBoolean(BLOCKING_ACTIVE, false)) { "Start blocking before using screen time." }
    require(durationMillis.isFinite() && durationMillis >= 1000 && durationMillis <= 86400000 && requestElapsedMillis.isFinite() && requestElapsedMillis >= 0) { "Invalid screen-time duration." }
    val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    val now = SystemClock.elapsedRealtime()
    check(boot >= 0 && boot == requestBoot && requestElapsedMillis <= now) { "Could not verify device uptime." }
    val deadline = CreditDeadline.fromServerRemaining(durationMillis.toLong(), requestElapsedMillis.toLong(), now, requestBoot, boot)
    check(deadline - now >= 1000) { "Screen-time session has ended." }
    val edit = prefs.edit().putLong(CREDIT_DEADLINE, deadline).putInt(CREDIT_BOOT, boot)
    if (account == null) edit.remove(CREDIT_ACCOUNT) else edit.putString(CREDIT_ACCOUNT, account)
    check(edit.commit()) { "Could not save the screen-time deadline." }
  }

  private fun status(context: Context?, authorized: Boolean = false, active: Boolean = false,
    appCount: Int = 0, websiteCount: Int = 0): Map<String, Any> {
    val connected = context?.let(::isServiceConnected) ?: false
    val routines = context?.let { runCatching { FocusRoutineStore.read(it) } }
    val manual = context?.let { runCatching { ManualFocusStore.read(it) } }
    val scheduledCount = routines?.getOrNull()?.let { FocusSchedule.active(it).size } ?: 0
    val manualActive = manual?.getOrNull()?.active == true
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
        active || manualActive || scheduledCount > 0 -> "serviceUnavailable"
        else -> "stopped"
      },
      "supportedBrowsers" to BrowserAddressIds.supportedNames,
      "scheduleError" to (routines?.isFailure == true),
      "manualFocusError" to (manual?.isFailure == true),
      "manualFocusActive" to manualActive,
      "scheduledActiveCount" to scheduledCount,
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
    if (!CreditDeadline.accountMatches(prefs.getString(CREDIT_ACCOUNT, null), FocusRoutineStore.account(context))) return 0
    return CreditDeadline.remainingMillis(prefs.getLong(CREDIT_DEADLINE, 0), prefs.getInt(CREDIT_BOOT, -1),
      Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1), SystemClock.elapsedRealtime())
  }

  private fun checkNoActiveAccess(context: Context) {
    check(creditRemaining(context) <= 0 && UsageTracker.state(context)?.closed != false) { "Finish screen time before changing blocking settings." }
  }

  private fun usageStatus(state: UsageTracker.State, serviceConnected: Boolean = true) = mapOf(
    "sessionId" to state.session, "userId" to state.user, "budgetMillis" to state.budget.toDouble(),
    "usedMillis" to state.used.toDouble(), "remainingMillis" to state.remaining.toDouble(),
    "closed" to state.closed, "tracking" to (state.tracking && serviceConnected),
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
      .filter { !ProtectedPackages.isProtected(context, it) }
      .toSet()
  }

  private fun appIconUri(drawable: android.graphics.drawable.Drawable): String {
    val size = 48
    val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    drawable.setBounds(0, 0, size, size)
    drawable.draw(canvas)
    val output = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
    bitmap.recycle()
    return "data:image/png;base64," + Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
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
    const val CREDIT_ACCOUNT = "credit_account"
    const val MAX_TARGETS = 500
    private const val SERVICE_HEARTBEAT_MAX_AGE = 15_000L
    private val PACKAGE_ID = Regex("^[A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)+$")
  }
}
