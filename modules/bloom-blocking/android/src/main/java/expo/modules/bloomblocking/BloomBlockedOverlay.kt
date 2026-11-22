package expo.modules.bloomblocking

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/** A touch-blocking accessibility window that explains why the foreground app is unavailable. */
internal class BloomBlockedOverlay(private val service: AccessibilityService) {
  private val windowManager = service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
  private var rootView: View? = null

  fun show(targetLabel: String, reasons: List<String>, onOpenBloom: () -> Unit, onGoHome: () -> Unit) {
    val root = FrameLayout(service).apply {
      setBackgroundColor(Color.rgb(24, 27, 42))
      isClickable = true
      isFocusable = true
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
    }

    val card = LinearLayout(service).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER_HORIZONTAL
      setPadding(dp(24), dp(28), dp(24), dp(24))
      background = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = dp(24).toFloat()
        setColor(Color.rgb(255, 255, 255))
      }
      elevation = dp(8).toFloat()
    }

    card.addView(text("BLOOM  ·  FOCUS", 13f, Color.rgb(109, 53, 199), true), matchWidth())
    card.addView(text("Blocked by Bloom", 25f, Color.rgb(20, 27, 53), true).apply {
      setPadding(0, dp(14), 0, dp(10))
    }, matchWidth())
    card.addView(text(
      BlockedNotice.message(targetLabel, reasons),
      16f,
      Color.rgb(51, 61, 83),
      false,
    ).apply {
      setPadding(0, 0, 0, dp(20))
    }, matchWidth())
    card.addView(Button(service).apply {
      text = "Open Bloom"
      setOnClickListener { onOpenBloom() }
    }, matchWidth())
    card.addView(Button(service).apply {
      text = "Go to home screen"
      setOnClickListener { onGoHome() }
    }, matchWidth())

    val cardParams = FrameLayout.LayoutParams(
      FrameLayout.LayoutParams.MATCH_PARENT,
      FrameLayout.LayoutParams.WRAP_CONTENT,
      Gravity.CENTER,
    ).apply {
      val margin = dp(24)
      setMargins(margin, margin, margin, margin)
    }
    root.addView(card, cardParams)

    val window = WindowManager.LayoutParams(
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.MATCH_PARENT,
      WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
      WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
      PixelFormat.TRANSLUCENT,
    ).apply {
      gravity = Gravity.TOP or Gravity.START
      title = "Bloom blocked app notice"
    }

    windowManager.addView(root, window)
    rootView = root
  }

  fun dismiss() {
    val view = rootView ?: return
    rootView = null
    runCatching { windowManager.removeViewImmediate(view) }
  }

  private fun text(value: String, size: Float, color: Int, bold: Boolean) = TextView(service).apply {
    text = value
    textSize = size
    setTextColor(color)
    gravity = Gravity.CENTER
    if (bold) setTypeface(typeface, Typeface.BOLD)
  }

  private fun matchWidth() = LinearLayout.LayoutParams(
    LinearLayout.LayoutParams.MATCH_PARENT,
    LinearLayout.LayoutParams.WRAP_CONTENT,
  )

  private fun dp(value: Int): Int = (value * service.resources.displayMetrics.density).toInt()
}
