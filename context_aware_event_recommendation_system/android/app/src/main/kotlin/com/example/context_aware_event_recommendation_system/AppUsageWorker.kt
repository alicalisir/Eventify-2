package com.example.context_aware_event_recommendation_system

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters

/**
 * WorkManager job that collects app usage statistics and writes them to
 * SharedPreferences so the Dart background service can flush to Supabase.
 *
 * Runs every 15 minutes — the minimum periodic interval allowed by WorkManager.
 * WorkManager is preferred over Handler.postDelayed because it survives process
 * death, device restarts, and Xiaomi's aggressive battery-management policies.
 */
class AppUsageWorker(appContext: Context, params: WorkerParameters) :
    Worker(appContext, params) {

    override fun doWork(): Result {
        AppUsageCollector.collectAndBuffer(applicationContext)
        return Result.success()
    }
}
