package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Test

class ManualFocusTimingTest {
  @Test fun indefiniteSessionContinuesUntilStopped() {
    assertEquals(ManualFocusTiming.Result(true, null), ManualFocusTiming.evaluate(true, -1, 3, 4, 1000))
    assertEquals(ManualFocusTiming.Result(false, null), ManualFocusTiming.evaluate(false, -1, 3, 4, 1000))
  }
  @Test fun timedSessionStopsAtDeadlineOrOnUnverifiableReboot() {
    assertEquals(ManualFocusTiming.Result(true, 500), ManualFocusTiming.evaluate(true, 1500, 3, 3, 1000))
    assertEquals(ManualFocusTiming.Result(false, 0), ManualFocusTiming.evaluate(true, 1500, 3, 3, 1500))
    assertEquals(ManualFocusTiming.Result(false, 0), ManualFocusTiming.evaluate(true, 1500, 3, 4, 1000))
    assertEquals(ManualFocusTiming.Result(false, 0), ManualFocusTiming.evaluate(true, 1500, -1, -1, 1000))
  }
}
