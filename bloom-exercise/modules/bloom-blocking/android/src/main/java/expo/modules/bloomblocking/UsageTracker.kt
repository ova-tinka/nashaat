package expo.modules.bloomblocking

import android.content.Context
import android.os.SystemClock
import android.provider.Settings

/** Local, crash-recoverable accounting for one server-reserved usage allowance. */
internal object UsageTracker {
  private const val PREFS = "bloom_actual_usage"
  private const val SESSION = "session"
  private const val USER = "user"
  private const val BUDGET = "budget"
  private const val USED = "used"
  private const val STARTED = "started"
  private const val SINCE = "since"
  private const val EXPIRES = "expires"
  private const val BOOT = "boot"
  private const val CLOSED = "closed"

  data class State(val session: String, val user: String, val budget: Long, val used: Long,
    val remaining: Long, val expiryRemaining: Long, val closed: Boolean, val tracking: Boolean, val observedAt: Long)

  private fun boot(context: Context) = Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT, -1)

  @Synchronized fun start(context: Context, session: String, user: String, budget: Long,
    expiresIn: Long, requestElapsed: Long, requestBoot: Int) {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val existing = prefs.getString(SESSION, null)
    if (existing != null) {
      check(existing == session && prefs.getString(USER, null) == user) { "Finish the existing screen-time session first." }
      check(!state(context)!!.closed) { "This screen-time session has ended." }
      return
    }
    val now = SystemClock.elapsedRealtime()
    val currentBoot = boot(context)
    require(session.isNotBlank() && user.isNotBlank() && budget in 1000..604800000 && expiresIn in 1000..1209600000) { "Invalid screen-time reservation." }
    val expiry = CreditDeadline.fromServerRemaining(expiresIn, requestElapsed, now, requestBoot, currentBoot)
    check(expiry > now) { "Screen-time reservation has expired." }
    check(prefs.edit().putString(SESSION, session).putString(USER, user).putLong(BUDGET, budget)
      .putLong(USED, 0).putLong(STARTED, requestElapsed).putLong(SINCE, -1).putLong(EXPIRES, expiry).putInt(BOOT, currentBoot)
      .putBoolean(CLOSED, false).commit()) { "Could not save screen-time session." }
  }

  @Synchronized fun state(context: Context): State? {
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    val session = prefs.getString(SESSION, null) ?: return null
    val user = prefs.getString(USER, null) ?: return null
    val now = SystemClock.elapsedRealtime()
    val start = prefs.getLong(STARTED, -1)
    val budget = prefs.getLong(BUDGET, 0)
    val expiry = prefs.getLong(EXPIRES, 0)
    val bootMatches = boot(context).let { it >= 0 && it == prefs.getInt(BOOT, -1) }
    val used = UsageAccounting.used(start, now, expiry, budget, bootMatches)
    val closed = prefs.getBoolean(CLOSED, false) || !bootMatches || start < 0 || now >= expiry || used >= budget
    if (closed && !prefs.getBoolean(CLOSED, false)) {
      check(prefs.edit().putLong(USED, used).putLong(SINCE, -1).putBoolean(CLOSED, true).commit()) { "Could not close screen-time session." }
    }
    return State(session, user, budget, used, (budget - used).coerceAtLeast(0),
      if (bootMatches) (expiry - now).coerceAtLeast(0) else 0, closed, !closed && start >= 0, now)
  }

  @Synchronized fun setTracking(context: Context, tracking: Boolean): State? {
    val state = state(context) ?: return null
    if (state.closed) return state
    val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    if (state.tracking == tracking && (!tracking || state.observedAt - prefs.getLong(SINCE, -1) < 1000)) return state
    check(prefs.edit().putLong(USED, state.used).putLong(SINCE, if (tracking) state.observedAt else -1).commit()) { "Could not update screen-time usage." }
    return state(context)
  }

  // The server-timed window continues while the accessibility service restarts.
  // Target visibility is only a status signal and does not pause its clock.
  @Synchronized fun recoverAfterInterruption(context: Context) {
    setTracking(context, false)
  }

  @Synchronized fun close(context: Context, user: String): State? {
    val state = state(context) ?: return null
    check(state.user == user) { "This screen-time session belongs to a different account." }
    if (!state.closed) {
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      check(prefs.edit().putLong(USED, state.used).putLong(SINCE, -1).putBoolean(CLOSED, true).commit()) { "Could not close screen-time session." }
    }
    return state(context)
  }

  @Synchronized fun clear(context: Context, user: String, session: String) {
    val state = state(context) ?: return
    check(state.user == user && state.session == session && state.closed) { "Finish this screen-time session before clearing it." }
    check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()) { "Could not clear screen-time session." }
  }
}
