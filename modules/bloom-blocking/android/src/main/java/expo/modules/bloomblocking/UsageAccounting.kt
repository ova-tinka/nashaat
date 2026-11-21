package expo.modules.bloomblocking

internal object UsageAccounting {
  /** Foreground observation is a status signal; it does not affect server-timed billing. */
  fun isTracking(closed: Boolean, since: Long, now: Long): Boolean =
    !closed && since >= 0 && since <= now

  fun used(started: Long, now: Long, expiry: Long, budget: Long, sameBoot: Boolean): Long {
    require(budget >= 0)
    if (!sameBoot || started < 0 || now < started) return 0
    return (minOf(now, expiry) - started).coerceAtLeast(0).coerceAtMost(budget)
  }
}
