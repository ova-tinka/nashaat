package com.example.nashaat

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Foreground service that keeps the blocking session alive.
///
/// The actual enforcement is done by [BlockingAccessibilityService].
/// This service simply holds a persistent notification so Android
/// does not kill the process while blocking is active.
class AppBlockingService : Service() {

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int =
        START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        getSharedPreferences(BlockingPlugin.PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putBoolean("is_active", false)
            .apply()
    }

    private fun createChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "App Blocking",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Nashaat is actively blocking selected apps."
        }
        getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Nashaat Blocking Active")
            .setContentText("Your selected apps are being blocked.")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .build()

    companion object {
        private const val CHANNEL_ID = "nashaat_blocking"
        private const val NOTIFICATION_ID = 1001
    }
}
