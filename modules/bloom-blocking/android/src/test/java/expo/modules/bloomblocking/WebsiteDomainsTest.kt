package expo.modules.bloomblocking

import org.junit.Assert.*
import org.junit.Test

class WebsiteDomainsTest {
  @Test fun normalizesAddresses() {
    assertEquals("example.com", WebsiteDomains.host(" HTTPS://Example.COM:443/path?q=1 "))
    assertEquals("www.example.com", WebsiteDomains.host("www.example.com/a"))
    assertEquals("example.com", WebsiteDomains.host("example.com."))
  }

  @Test fun matchesOnlyTheDomainAndItsSubdomains() {
    val blocked = setOf("example.com")
    assertTrue(WebsiteDomains.matches("example.com", blocked))
    assertTrue(WebsiteDomains.matches("www.example.com", blocked))
    assertFalse(WebsiteDomains.matches("notexample.com", blocked))
    assertFalse(WebsiteDomains.matches("example.com.other.test", blocked))
  }

  @Test fun rejectsNonWebAndAmbiguousAddresses() {
    for (value in listOf("", "hello world", "localhost", "javascript://example.com", "https://user@example.com", "https://example..com")) {
      assertNull(value, WebsiteDomains.host(value))
    }
  }
}
