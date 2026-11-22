package expo.modules.bloomblocking

/** Resolves the foreground package across Android's window-transition gap. */
internal object ActivePackageResolver {
  fun resolve(activeWindowPackage: String?, eventPackage: String?, isWindowStateChanged: Boolean): String? {
    activeWindowPackage?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
    return eventPackage?.trim()?.takeIf { isWindowStateChanged && it.isNotEmpty() }
  }
}
