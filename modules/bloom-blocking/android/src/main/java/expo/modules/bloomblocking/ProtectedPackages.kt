package expo.modules.bloomblocking

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.telecom.TelecomManager

internal object ProtectedPackages {
  private val essential = setOf(
    "com.android.settings",
    "com.android.phone",
    "com.android.emergency",
    "com.android.systemui",
    "com.android.server.telecom",
    "com.android.dialer",
    "com.google.android.dialer",
    "com.samsung.android.dialer",
    "com.samsung.android.incallui",
  )

  fun isProtected(packageName: String, ownPackage: String): Boolean {
    return packageName == ownPackage || packageName in essential
  }

  fun isProtected(context: Context, packageName: String): Boolean {
    if (isProtected(packageName, context.packageName)) return true
    val dialer = runCatching {
      context.getSystemService(TelecomManager::class.java)?.defaultDialerPackage
    }.getOrNull()
    if (!dialer.isNullOrEmpty() && packageName == dialer) return true
    val homePackage = runCatching {
      val homeIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
      @Suppress("DEPRECATION")
      context.packageManager.resolveActivity(homeIntent, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
    }.getOrNull()
    return !homePackage.isNullOrEmpty() && packageName == homePackage
  }
}
