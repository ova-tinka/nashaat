package expo.modules.bloomblocking

/** Browser packages whose foreground windows can be checked by the accessibility service. */
internal object BrowserAddressIds {
  data class Browser(val name: String, val viewId: String)

  enum class DecisionKind { NONE, BLOCK_WEBSITE, BLOCK_UNREADABLE_BROWSER }
  data class Decision(val kind: DecisionKind, val host: String? = null, val browserName: String? = null)

  private val browsers = mapOf(
    "com.android.chrome" to "Chrome",
    "com.chrome.beta" to "Chrome Beta",
    "com.chrome.dev" to "Chrome Dev",
    "com.chrome.canary" to "Chrome Canary",
    "com.brave.browser" to "Brave",
    "com.brave.browser.beta" to "Brave Beta",
    "com.microsoft.emmx" to "Microsoft Edge",
    "com.microsoft.emmx.beta" to "Microsoft Edge Beta",
    "org.mozilla.firefox" to "Firefox",
    "org.mozilla.firefox_beta" to "Firefox Beta",
    "org.mozilla.focus" to "Firefox Focus",
    "com.sec.android.app.sbrowser" to "Samsung Internet",
    "com.opera.browser" to "Opera",
    "com.vivaldi.browser" to "Vivaldi",
    "com.duckduckgo.mobile.android" to "DuckDuckGo",
  )

  fun browser(packageName: String): Browser? {
    val name = browsers[packageName] ?: return null
    val resource = when (packageName) {
      "org.mozilla.firefox", "org.mozilla.firefox_beta" -> "mozac_browser_toolbar_url_view"
      "org.mozilla.focus" -> "mozac_browser_toolbar_url_view"
      "com.sec.android.app.sbrowser" -> "location_bar_edit_text"
      "com.opera.browser" -> "url_field"
      "com.duckduckgo.mobile.android" -> "omnibarTextInput"
      else -> "url_bar"
    }
    return Browser(name, "$packageName:id/$resource")
  }

  fun viewId(packageName: String): String? = browser(packageName)?.viewId

  /** Unknown or hidden address bars are a browser-wide target while website rules are active. */
  fun decide(packageName: String, address: String?, blockedDomains: Set<String>): Decision {
    if (blockedDomains.isEmpty()) return Decision(DecisionKind.NONE)
    val browser = browser(packageName) ?: return Decision(DecisionKind.NONE)
    val host = address?.let(WebsiteDomains::host)
    if (host == null) return Decision(DecisionKind.BLOCK_UNREADABLE_BROWSER, browserName = browser.name)
    if (WebsiteDomains.matches(host, blockedDomains)) return Decision(DecisionKind.BLOCK_WEBSITE, host, browser.name)
    return Decision(DecisionKind.NONE)
  }

  val supportedNames: List<String>
    get() = browsers.values.distinct()
}
