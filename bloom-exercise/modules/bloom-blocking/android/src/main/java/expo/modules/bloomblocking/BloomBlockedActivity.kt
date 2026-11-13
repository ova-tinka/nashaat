package expo.modules.bloomblocking

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class BloomBlockedActivity : Activity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val content = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      setPadding(32, 32, 32, 32)
      setBackgroundColor(Color.rgb(21, 17, 14))
    }
    content.addView(TextView(this).apply {
      text = "This app is blocked during your focus time."
      textSize = 24f
      setTextColor(Color.rgb(248, 242, 232))
      gravity = Gravity.CENTER
      setPadding(0, 0, 0, 20)
    })
    content.addView(Button(this).apply {
      text = "Go to home screen"
      setOnClickListener { returnToHome() }
    })
    setContentView(content)
  }

  override fun onBackPressed() = returnToHome()

  private fun returnToHome() {
    startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    finish()
  }

  companion object {
    const val EXTRA_APP = "bloom_blocked_app"
  }
}
