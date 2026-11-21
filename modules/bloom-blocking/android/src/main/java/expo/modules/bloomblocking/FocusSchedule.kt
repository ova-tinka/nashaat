package expo.modules.bloomblocking

import java.util.Calendar

/** Local wall-clock schedules. Days use Sunday=0, matching the picker. */
internal object FocusSchedule {
  data class Routine(
    val id: String, val name: String, val enabled: Boolean,
    val startMinute: Int, val endMinute: Int, val days: Set<Int>,
    val apps: Set<String>, val websites: Set<String>,
  )

  fun isActive(routine: Routine, day: Int, minute: Int): Boolean {
    if (!routine.enabled) return false
    return if (routine.startMinute < routine.endMinute) {
      day in routine.days && minute >= routine.startMinute && minute < routine.endMinute
    } else {
      (day in routine.days && minute >= routine.startMinute) ||
        ((day + 6) % 7 in routine.days && minute < routine.endMinute)
    }
  }

  fun active(routines: List<Routine>, now: Calendar = Calendar.getInstance()): List<Routine> {
    val day = now.get(Calendar.DAY_OF_WEEK) - Calendar.SUNDAY
    val minute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
    return routines.filter { isActive(it, day, minute) }
  }
}
