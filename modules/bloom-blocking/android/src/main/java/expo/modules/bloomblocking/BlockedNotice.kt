package expo.modules.bloomblocking

internal object BlockedNotice {
  fun message(targetLabel: String, reasons: List<String>): String {
    val label = targetLabel.trim().ifBlank { "This app" }
    val activeRules = reasons.map { it.trim() }.filter { it.isNotEmpty() }.distinct()
    val reasonText = if (activeRules.isEmpty()) "" else " Active rules: ${activeRules.joinToString(", ")}."
    return "$label is blocked by Bloom.$reasonText Open Bloom to review your Focus settings or change your blocking rules."
  }
}
