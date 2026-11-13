package expo.modules.bloomblocking

internal object ServiceHeartbeat {
  fun isFresh(lastHeartbeatElapsed: Long, nowElapsed: Long, maximumAgeMillis: Long = 15_000L): Boolean =
    lastHeartbeatElapsed > 0 && nowElapsed >= lastHeartbeatElapsed
      && nowElapsed - lastHeartbeatElapsed <= maximumAgeMillis
}
