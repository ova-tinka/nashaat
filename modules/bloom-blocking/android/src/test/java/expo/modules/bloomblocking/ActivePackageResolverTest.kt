package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ActivePackageResolverTest {
  @Test fun usesWindowStateEventWhenActiveRootIsUnavailable() {
    assertEquals(
      "com.example.reader",
      ActivePackageResolver.resolve(null, "com.example.reader", isWindowStateChanged = true),
    )
  }

  @Test fun prefersTheActiveRootOverAnEventFromAnotherWindow() {
    assertEquals(
      "com.example.reader",
      ActivePackageResolver.resolve("com.example.reader", "com.example.background", isWindowStateChanged = true),
    )
  }

  @Test fun ignoresNonStateEventsWhenTheActiveRootIsUnavailable() {
    assertNull(ActivePackageResolver.resolve(null, "com.example.background", isWindowStateChanged = false))
  }

  @Test fun ignoresBlankPackageNames() {
    assertNull(ActivePackageResolver.resolve(" ", " ", isWindowStateChanged = true))
  }
}
