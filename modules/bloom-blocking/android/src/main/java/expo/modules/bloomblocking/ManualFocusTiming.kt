package expo.modules.bloomblocking

internal object ManualFocusTiming {
  data class Result(val active: Boolean, val remainingMillis: Long?)
  fun evaluate(enabled: Boolean, deadline: Long, recordedBoot: Int, currentBoot: Int, now: Long): Result {
    if (!enabled) return Result(false, null)
    if (deadline < 0) return Result(true, null)
    val remaining = if (currentBoot >= 0 && recordedBoot == currentBoot) (deadline - now).coerceAtLeast(0) else 0
    return Result(remaining > 0, remaining)
  }
}
