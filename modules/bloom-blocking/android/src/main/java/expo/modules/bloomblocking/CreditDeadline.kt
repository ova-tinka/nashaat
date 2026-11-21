package expo.modules.bloomblocking

/** A countdown uses elapsed time, and is invalid after a reboot or invalid clock state. */
internal object CreditDeadline {
  fun fromServerRemaining(remaining: Long, requestElapsed: Long, nowElapsed: Long, requestBoot: Int, nowBoot: Int): Long {
    if (remaining <= 0 || requestElapsed < 0 || nowElapsed < requestElapsed || requestBoot < 0 || requestBoot != nowBoot) return 0
    val adjusted = remaining - (nowElapsed - requestElapsed)
    return if (adjusted > 0 && nowElapsed <= Long.MAX_VALUE - adjusted) nowElapsed + adjusted else 0
  }

  /** Older, unbound countdowns retain their previous behavior until they expire. */
  fun accountMatches(owner: String?, activeAccount: String?): Boolean = owner == null || owner == activeAccount

  fun remainingMillis(deadline: Long, bootAtStart: Int, bootNow: Int, elapsedNow: Long): Long {
    if (deadline <= 0 || elapsedNow < 0 || bootAtStart < 0 || bootNow < 0 || bootAtStart != bootNow) return 0
    return (deadline - elapsedNow).coerceAtLeast(0)
  }
}
