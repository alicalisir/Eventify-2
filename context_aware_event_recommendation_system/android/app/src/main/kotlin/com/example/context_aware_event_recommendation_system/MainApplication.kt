package com.example.context_aware_event_recommendation_system

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

class MainApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
        scheduleAppUsageWorker()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)

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

    private fun scheduleAppUsageWorker() {
        val request = PeriodicWorkRequestBuilder<AppUsageWorker>(15, TimeUnit.MINUTES)
            .build()
        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "app_usage_collection",
            ExistingPeriodicWorkPolicy.KEEP,
            request
        )
    }
}
