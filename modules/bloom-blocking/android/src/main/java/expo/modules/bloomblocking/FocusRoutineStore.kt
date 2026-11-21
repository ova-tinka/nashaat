package expo.modules.bloomblocking

import android.content.Context
import org.json.JSONArray

/** The selected account and its routines remain device-local. */
internal object FocusRoutineStore {
  private const val ACCOUNT = "focus_routine_account"
  private const val PREFIX = "focus_routines:"
  private val packageId = Regex("^[A-Za-z0-9_]+(?:\\.[A-Za-z0-9_]+)+$")

  @Synchronized fun setAccount(context: Context, account: String) {
    require(account.matches(Regex("^[A-Za-z0-9-]{1,64}$"))) { "Invalid account." }
    check(context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
      .edit().putString(ACCOUNT, account).commit()) { "Could not update the device account." }
  }

  @Synchronized fun clearAccount(context: Context, account: String) {
    val prefs = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
    if (prefs.getString(ACCOUNT, null) == account) {
      check(prefs.edit().remove(ACCOUNT).commit()) { "Could not close routine access." }
    }
  }

  @Synchronized fun account(context: Context): String? = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).getString(ACCOUNT, null)

  @Synchronized fun read(context: Context): List<FocusSchedule.Routine> {
    val account = account(context) ?: return emptyList()
    val raw = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).getString(PREFIX + account, "[]") ?: "[]"
    return parse(raw, context.packageName)
  }

  @Synchronized fun json(context: Context, expectedAccount: String): String {
    val account = account(context)
    check(account == expectedAccount) { "The device account changed. Sync and try again." }
    val raw = context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE).getString(PREFIX + account, "[]") ?: "[]"
    parse(raw, context.packageName)
    return raw
  }

  @Synchronized fun write(context: Context, expectedAccount: String, raw: String) {
    val account = account(context)
    check(account == expectedAccount) { "The device account changed. Sync and try again." }
    parse(raw, context.packageName)
    check(context.getSharedPreferences(BloomBlockingModule.PREFERENCES, Context.MODE_PRIVATE)
      .edit().putString(PREFIX + account, raw).commit()) { "Could not save routines." }
  }

  fun parseForValidation(raw: String, ownPackage: String) = parse(raw, ownPackage)

  private fun parse(raw: String, ownPackage: String): List<FocusSchedule.Routine> {
    require(raw.length <= 250_000) { "Too many routines." }
    val array = JSONArray(raw)
    require(array.length() <= 50) { "Choose at most 50 routines." }
    val ids = mutableSetOf<String>()
    return (0 until array.length()).map { index ->
      val item = array.getJSONObject(index)
      val id = item.getString("id")
      val name = item.getString("name").trim()
      val start = item.getInt("startMinute")
      val end = item.getInt("endMinute")
      val days = integers(item.getJSONArray("days"))
      val apps = strings(item.getJSONArray("apps"))
      val sites = strings(item.getJSONArray("websites"))
      require(id.matches(Regex("^[A-Za-z0-9-]{1,64}$")) && ids.add(id)) { "Invalid routine identifier." }
      require(name.isNotEmpty() && name.length <= 80 && start in 0..1439 && end in 0..1439 && start != end) { "Check the routine name and times." }
      require(days.isNotEmpty() && days.all { it in 0..6 }) { "Choose at least one day." }
      require(apps.size <= 500 && apps.all { it.matches(packageId) && it != ownPackage }) { "Invalid app selection." }
      require(sites.size <= 500 && sites.all { WebsiteDomains.host(it) == it }) { "Invalid website selection." }
      require(apps.isNotEmpty() || sites.isNotEmpty()) { "Choose an app or website." }
      FocusSchedule.Routine(id, name, item.getBoolean("enabled"), start, end, days, apps, sites)
    }
  }

  private fun strings(array: JSONArray): Set<String> = (0 until array.length()).map { array.getString(it) }.toSet()
  private fun integers(array: JSONArray): Set<Int> = (0 until array.length()).map { array.getInt(it) }.toSet()
}
