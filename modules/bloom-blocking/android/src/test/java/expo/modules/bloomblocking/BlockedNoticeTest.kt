package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Test

class BlockedNoticeTest {
  @Test fun explainsTheAppAndTheActiveRulesWithAnAction() {
    assertEquals(
      "Instagram is blocked by Bloom. Active rules: Night Routine, Parent rule. Open Bloom to review your Focus settings or change your blocking rules.",
      BlockedNotice.message("Instagram", listOf("Night Routine", "Parent rule", "Night Routine")),
    )
  }

  @Test fun remainsClearWhenTheNativeDecisionHasNoReason() {
    assertEquals(
      "This app is blocked by Bloom. Open Bloom to review your Focus settings or change your blocking rules.",
      BlockedNotice.message(" ", emptyList()),
    )
  }
}
