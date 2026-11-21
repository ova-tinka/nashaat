package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class EffectiveAccessTest {
  @Test fun restrictionsCombineWithoutCreditsOverridingHardBlocks() {
    val night = EffectiveAccess.Restriction("instagram", "Night Routine")
    val study = EffectiveAccess.Restriction("instagram", "Study Routine")
    val active = EffectiveAccess.evaluate("instagram", "instagram", listOf(night, study), "instagram", true)
    assertEquals("instagram", active.target)
    assertEquals(listOf("Parent rule", "Manual Focus", "Night Routine", "Study Routine"), active.reasons)
    val afterOneEnds = EffectiveAccess.evaluate(null, null, listOf(night), "instagram", true)
    assertEquals(listOf("Night Routine"), afterOneEnds.reasons)
    assertFalse(EffectiveAccess.evaluate(null, null, emptyList(), "instagram", true).blocked)
  }

  @Test fun manualAndScheduleAreIndependentOfEachOtherAndCreditAccess() {
    val manual = EffectiveAccess.evaluate(null, "youtube", emptyList(), null, true)
    assertEquals(listOf("Manual Focus"), manual.reasons)
    val scheduled = EffectiveAccess.evaluate(null, null, listOf(EffectiveAccess.Restriction("tiktok", "Study Routine")), null, true)
    assertEquals(listOf("Study Routine"), scheduled.reasons)
    val afterManualEnds = EffectiveAccess.evaluate(null, null, listOf(EffectiveAccess.Restriction("instagram", "Night Routine")), "instagram", true)
    assertEquals(listOf("Night Routine"), afterManualEnds.reasons)
  }

  @Test fun personalTargetRequiresAValidGrant() {
    val blocked = EffectiveAccess.evaluate(null, null, emptyList(), "instagram", false)
    assertEquals("instagram", blocked.target)
    assertEquals(listOf("Focus blocking"), blocked.reasons)
    assertFalse(EffectiveAccess.evaluate(null, null, emptyList(), null, false).blocked)
  }
}
