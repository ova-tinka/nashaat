package expo.modules.bloomblocking

internal object UsageAccounting {
  fun used(started: Long, now: Long, expiry: Long, budget: Long, sameBoot: Boolean): Long {
    require(budget >= 0)
    if (!sameBoot || started < 0 || now < started) return 0
    return (minOf(now, expiry) - started).coerceAtLeast(0).coerceAtMost(budget)
  }
}
