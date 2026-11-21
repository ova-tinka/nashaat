package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FocusScheduleTest {
  private fun routine(id: String, start: Int, end: Int, days: Set<Int>, app: String, enabled: Boolean = true) =
    FocusSchedule.Routine(id, id, enabled, start, end, days, setOf(app), emptySet())

  @Test fun overnightUsesPreviousDayBeforeEnd() {
    val night = routine("night", 22 * 60, 6 * 60, setOf(0), "a")
    assertTrue(FocusSchedule.isActive(night, 0, 22 * 60))
    assertTrue(FocusSchedule.isActive(night, 1, 5 * 60 + 59))
    assertFalse(FocusSchedule.isActive(night, 1, 6 * 60))
    assertFalse(FocusSchedule.isActive(night, 0, 5 * 60))
  }

  @Test fun overnightWrapsAcrossTheWeek() {
    val saturday = routine("weekend", 23 * 60, 60, setOf(6), "a")
    assertTrue(FocusSchedule.isActive(saturday, 0, 30))
    assertFalse(FocusSchedule.isActive(saturday, 0, 60))
  }

  @Test fun overlappingRoutinesRemainIndependent() {
    val a = routine("a", 16 * 60, 18 * 60, setOf(1), "instagram")
    val b = routine("b", 17 * 60, 19 * 60, setOf(1), "youtube")
    fun blocked(minute: Int) = listOf(a, b).filter { FocusSchedule.isActive(it, 1, minute) }.flatMap { it.apps }.toSet()
    assertEquals(setOf("instagram", "youtube"), blocked(17 * 60))
    assertEquals(setOf("youtube"), blocked(18 * 60))
    assertFalse(FocusSchedule.isActive(b.copy(enabled = false), 1, 17 * 60))
  }
}
