package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Test

class CreditDeadlineTest {
  @Test fun countsDownAndExpires() {
    assertEquals(500L, CreditDeadline.remainingMillis(1500, 3, 3, 1000))
    assertEquals(0L, CreditDeadline.remainingMillis(1500, 3, 3, 1500))
    assertEquals(0L, CreditDeadline.remainingMillis(1500, 3, 3, 2000))
  }

  @Test fun rebootOrMissingClockFailsClosed() {
    assertEquals(0L, CreditDeadline.remainingMillis(1500, 3, 4, 100))
    assertEquals(0L, CreditDeadline.remainingMillis(1500, -1, -1, 100))
    assertEquals(0L, CreditDeadline.remainingMillis(0, 3, 3, 100))
  }

  @Test fun serverDeadlineAccountsForRoundTripAndReboot() {
    assertEquals(11000L, CreditDeadline.fromServerRemaining(10000, 1000, 1500, 3, 3))
    assertEquals(0L, CreditDeadline.fromServerRemaining(10000, 1000, 12000, 3, 3))
    assertEquals(0L, CreditDeadline.fromServerRemaining(10000, 1000, 1500, 3, 4))
    assertEquals(0L, CreditDeadline.fromServerRemaining(10000, 1500, 1000, 3, 3))
  }
}
