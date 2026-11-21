package expo.modules.bloomblocking

/** Effective restrictions combine; a credit grant only relaxes the legacy personal target. */
internal object EffectiveAccess {
  data class Restriction(val target: String, val reason: String)
  data class Decision(val target: String?, val reasons: List<String>) {
    val blocked: Boolean get() = target != null
  }

  fun evaluate(
    guardian: String?, manual: String?, scheduled: List<Restriction>, personal: String?, creditAccess: Boolean,
  ): Decision {
    val restrictions = buildList {
      if (guardian != null) add(Restriction(guardian, "Parent rule"))
      if (manual != null) add(Restriction(manual, "Manual Focus"))
      addAll(scheduled)
      if (personal != null && !creditAccess) add(Restriction(personal, "Focus blocking"))
    }
    return Decision(restrictions.firstOrNull()?.target, restrictions.map { it.reason })
  }
}
