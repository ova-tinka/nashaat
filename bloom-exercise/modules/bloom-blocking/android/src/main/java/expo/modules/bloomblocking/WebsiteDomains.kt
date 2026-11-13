package expo.modules.bloomblocking

import java.net.IDN
import java.net.URI
import java.util.Locale

/** Parses an address without reading or retaining the page content. */
internal object WebsiteDomains {
  fun host(address: String): String? {
    val input = address.trim()
    if (input.isEmpty() || input.any(Char::isWhitespace) || input.length > 2048) return null
    return try {
      val uri = URI(if (input.contains("://")) input else "https://$input")
      if (uri.scheme?.lowercase(Locale.ROOT) !in setOf("http", "https") || uri.userInfo != null) return null
      val hostname = uri.host ?: return null
      val ascii = IDN.toASCII(hostname.trimEnd('.'), IDN.USE_STD3_ASCII_RULES).lowercase(Locale.ROOT)
      if (ascii.length !in 1..253 || !ascii.contains('.') || ascii.split('.').any { it.isEmpty() || it.length > 63 }) null else ascii
    } catch (_: IllegalArgumentException) { null }
    catch (_: java.net.URISyntaxException) { null }
  }

  fun matches(hostname: String, domains: Set<String>): Boolean =
    domains.any { hostname == it || hostname.endsWith(".$it") }
}
