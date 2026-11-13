package expo.modules.bloomblocking

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ServiceHeartbeatTest {
  @Test fun acceptsOnlyRecentMonotonicHeartbeats() {
    assertTrue(ServiceHeartbeat.isFresh(10_000, 25_000))
    assertFalse(ServiceHeartbeat.isFresh(10_000, 25_001))
    assertFalse(ServiceHeartbeat.isFresh(0, 10_000))
    assertFalse(ServiceHeartbeat.isFresh(10_001, 10_000))
  }
}
