package com.example.context_aware_event_recommendation_system

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

            // ScreenEventService channel
            nm?.createNotificationChannel(
                NotificationChannel(
                    "caers_tracking",
                    "Bağlam Takibi",
                    NotificationManager.IMPORTANCE_MIN
                ).apply {
                    description = "Ekran ve konum verilerini toplar"
                    setShowBadge(false)
                }
            )

            // flutter_background_service channel
            nm?.createNotificationChannel(
                NotificationChannel(
                    "caers_bg_service",
                    "Arka Plan Veri Servisi",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "GPS ve uygulama verisi toplar"
                    setShowBadge(false)
                }
            )
        }
    }
}
