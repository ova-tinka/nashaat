package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Test

class UsageAccountingTest {
  @Test fun elapsedWindowContinuesWhileTargetIsInactive() {
    assertEquals(3000L, UsageAccounting.used(1000, 4000, 20000, 10000, true))
    assertEquals(7000L, UsageAccounting.used(1000, 8000, 20000, 10000, true))
    assertEquals(9000L, UsageAccounting.used(1000, 10000, 20000, 10000, true))
  }

  @Test fun respectsBudgetExpiryAndReboot() {
    assertEquals(8000L, UsageAccounting.used(1000, 9000, 20000, 10000, true))
    assertEquals(3000L, UsageAccounting.used(1000, 9000, 4000, 10000, true))
    assertEquals(0L, UsageAccounting.used(1000, 9000, 20000, 10000, false))
  }
}
