package com.example.context_aware_event_recommendation_system

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import com.google.android.gms.location.ActivityRecognition
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val SCREEN_CHANNEL   = "com.example.caers/screen_events"
        const val ACTIVITY_CHANNEL = "com.example.caers/activity_recognition"

        // Mirrors ScreenEventService bridge constants
        const val FLUTTER_PREFS    = "FlutterSharedPreferences"
        const val SCREEN_BUFFER_KEY = "flutter.screen_events_buffer"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        registerScreenChannel(flutterEngine)
        registerActivityChannel(flutterEngine)
    }

    // ─────────────────────────────────────── Screen events ───────────────────

    private fun registerScreenChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startService" -> {
                        val intent = Intent(this, ScreenEventService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stopService" -> {
                        stopService(Intent(this, ScreenEventService::class.java))
                        result.success(null)
                    }
                    "getPendingEvents" -> {
                        val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                        result.success(prefs.getString(SCREEN_BUFFER_KEY, "[]"))
                    }
                    "clearEvents" -> {
                        getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                            .edit().putString(SCREEN_BUFFER_KEY, "[]").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─────────────────────────────────────── Activity recognition ────────────

    private fun registerActivityChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ACTIVITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startTracking" -> {
                        runCatching { startActivityRecognition() }
                        result.success(null)
                    }
                    "stopTracking" -> {
                        runCatching { stopActivityRecognition() }
                        result.success(null)
                    }
                    "getCurrentActivity" -> {
                        val prefs = getSharedPreferences(
                            ActivityRecognitionReceiver.PREFS_NAME, Context.MODE_PRIVATE
                        )
                        result.success(
                            prefs.getString(ActivityRecognitionReceiver.PREFS_KEY, "stationary")
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun activityPendingIntent(): PendingIntent {
        val intent = Intent(this, ActivityRecognitionReceiver::class.java).apply {
            action = ActivityRecognitionReceiver.ACTION
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        return PendingIntent.getBroadcast(this, 0, intent, flags)
    }

    private fun startActivityRecognition() {
        ActivityRecognition.getClient(this)
            .requestActivityUpdates(30_000L, activityPendingIntent())
    }

    private fun stopActivityRecognition() {
        ActivityRecognition.getClient(this)
            .removeActivityUpdates(activityPendingIntent())
    }
}
