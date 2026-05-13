package com.example.context_aware_event_recommendation_system

import android.app.*
import android.content.*
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class ScreenEventService : Service() {

    companion object {
        const val CHANNEL_ID  = "caers_tracking"
        const val NOTIF_ID    = 1001
        const val PREFS_NAME  = "screen_events_buffer"
        const val PREFS_KEY   = "events"
    }

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val type = when (intent.action) {
                Intent.ACTION_SCREEN_ON   -> "on"
                Intent.ACTION_SCREEN_OFF  -> "off"
                Intent.ACTION_USER_PRESENT -> "unlock"
                else -> return
            }
            bufferEvent(type)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        registerReceiver(screenReceiver, filter)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        runCatching { unregisterReceiver(screenReceiver) }
        stopForeground(true)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun bufferEvent(eventType: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val arr = JSONArray(prefs.getString(PREFS_KEY, "[]") ?: "[]")
        arr.put(JSONObject().apply {
            put("event_type", eventType)
            put("timestamp", Instant.now().toString())
        })
        prefs.edit().putString(PREFS_KEY, arr.toString()).apply()
    }

    private fun buildNotification(): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Bağlam takibi aktif")
            .setContentText("Kişiselleştirilmiş öneriler için arka planda çalışıyor")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Bağlam Takibi",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Ekran ve konum verilerini toplar"
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }
}
