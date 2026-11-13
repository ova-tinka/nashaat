package expo.modules.bloomblocking

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class BrowserAddressIdsTest {
  @Test fun selectsOnlyKnownAddressFields() {
    assertEquals("org.mozilla.firefox:id/mozac_browser_toolbar_url_view", BrowserAddressIds.viewId("org.mozilla.firefox"))
    assertEquals("com.android.chrome:id/url_bar", BrowserAddressIds.viewId("com.android.chrome"))
    assertEquals("com.sec.android.app.sbrowser:id/location_bar_edit_text", BrowserAddressIds.viewId("com.sec.android.app.sbrowser"))
    assertEquals("com.opera.browser:id/url_field", BrowserAddressIds.viewId("com.opera.browser"))
    assertNull(BrowserAddressIds.viewId("com.example.browser"))
  }

  @Test fun unreadableKnownBrowserIsBlockedAsAWhole() {
    val result = BrowserAddressIds.decide("com.android.chrome", null, setOf("example.com"))
    assertEquals(BrowserAddressIds.DecisionKind.BLOCK_UNREADABLE_BROWSER, result.kind)
    assertEquals("Chrome", result.browserName)
  }

  @Test fun readableBlockedAndAllowedAddressesAreDistinguished() {
    val blocked = BrowserAddressIds.decide("org.mozilla.firefox", "https://news.example.com/story", setOf("example.com"))
    assertEquals(BrowserAddressIds.DecisionKind.BLOCK_WEBSITE, blocked.kind)
    assertEquals("news.example.com", blocked.host)

    val allowed = BrowserAddressIds.decide("org.mozilla.firefox", "https://other.test/story", setOf("example.com"))
    assertEquals(BrowserAddressIds.DecisionKind.NONE, allowed.kind)
  }

  @Test fun noRulesOrUnknownAppDoesNotTreatAnAppAsABrowser() {
    assertEquals(BrowserAddressIds.DecisionKind.NONE,
      BrowserAddressIds.decide("com.android.chrome", null, emptySet()).kind)
    assertEquals(BrowserAddressIds.DecisionKind.NONE,
      BrowserAddressIds.decide("com.example.browser", null, setOf("example.com")).kind)
  }
}
