package expo.modules.bloomblocking

import android.content.Context
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

/** Manual sessions are device- and account-specific and never change credit grants. */
internal object ManualFocusStore {
  data class Selection(val apps: Set<String>, val websites: Set<String>)
  data class State(val selection: Selection, val active: Boolean, val remainingMillis: Long?)
  private const val CONFIG = "manual_focus_config:"
  private const val ACTIVE = "manual_focus_active:"
  private const val BOOT = "manual_focus_boot:"
  private const val DEADLINE = "manual_focus_deadline:"
  private val packageId = Regex("^[A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)+$")

  fun parse(raw: String, ownPackage: String): Selection {
    require(raw.length <= 100_000) { "Too many targets." }
    val obj = JSONObject(raw)
    fun strings(key: String): Set<String> {
      val values = obj.getJSONArray(key)
      require(values.length() <= 500) { "Too many targets." }
      return (0 until values.length()).map { values.getString(it) }.toSet()
    }
    val apps = strings("apps")
    val sites = strings("websites")
    require(apps.all { it.matches(packageId) && it != ownPackage }) { "Invalid app selection." }
    require(sites.all { WebsiteDomains.host(it) == it }) { "Invalid website selection." }
    return Selection(apps, sites)
  }

  fun read(context: Context, expectedAccount: String? = null): State? = synchronized(FocusRoutineStore) {
    val account = FocusRoutineStore.account(context) ?: return@synchronized null
    if (expectedAccount != null) check(account == expectedAccount) { "The device account changed. Sync and try again." }
    val prefs = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    val selection = parse(prefs.getString(CONFIG + account, "{\"apps\":[],\"websites\":[]}")!!, context.packageName)
    val enabled = prefs.getBoolean(ACTIVE + account, false)
    val deadline = prefs.getLong(DEADLINE + account, -1)
    val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    val timing = ManualFocusTiming.evaluate(enabled, deadline, prefs.getInt(BOOT + account, -1), boot, SystemClock.elapsedRealtime())
    State(selection, timing.active, timing.remainingMillis)
  }

  fun save(context: Context, account: String, raw: String) = synchronized(FocusRoutineStore) {
    check(FocusRoutineStore.account(context) == account) { "The device account changed. Sync and try again." }
    val selection = parse(raw, context.packageName)
    val prefs = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    check(read(context, account)?.active != true || selection.apps.isNotEmpty() || selection.websites.isNotEmpty()) { "Choose a target while Manual Focus is active." }
    check(selection.websites.isEmpty() || prefs.getBoolean(BloomBlockingModule.WEBSITE_CONSENT, false)) { "Enable website checks before selecting websites." }
    check(prefs.edit().putString(CONFIG + account, raw).commit()) { "Could not save Manual Focus." }
  }

  fun start(context: Context, account: String, duration: Long) = synchronized(FocusRoutineStore) {
    require(duration in 0..604800000) { "Choose a duration of up to seven days." }
    val state = read(context, account) ?: error("Sync the device account first.")
    check(!state.active) { "Manual Focus is already active." }
    check(state.selection.apps.isNotEmpty() || state.selection.websites.isNotEmpty()) { "Choose an app or website first." }
    val prefs = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    check(state.selection.websites.isEmpty() || prefs.getBoolean(BloomBlockingModule.WEBSITE_CONSENT, false)) { "Enable website checks first." }
    val boot = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)
    check(duration == 0L || boot >= 0) { "Could not verify device uptime." }
    val deadline = if (duration == 0L) -1L else SystemClock.elapsedRealtime() + duration
    check(prefs.edit().putBoolean(ACTIVE + account, true).putLong(DEADLINE + account, deadline)
      .putInt(BOOT + account, boot).commit()) { "Could not start Manual Focus." }
  }

  fun stop(context: Context, account: String) = synchronized(FocusRoutineStore) {
    check(FocusRoutineStore.account(context) == account) { "The device account changed. Sync and try again." }
    check(context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
      .edit().putBoolean(ACTIVE + account, false).commit()) { "Could not stop Manual Focus." }
  }

  fun json(state: State?): String {
    val selection = state?.selection ?: Selection(emptySet(), emptySet())
    return JSONObject().put("apps", JSONArray(selection.apps.sorted())).put("websites", JSONArray(selection.websites.sorted()))
      .put("active", state?.active == true).put("remainingMillis", state?.remainingMillis ?: JSONObject.NULL).toString()
  }
}
