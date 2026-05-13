package com.example.context_aware_event_recommendation_system

import android.content.*
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity

class ActivityRecognitionReceiver : BroadcastReceiver() {

    companion object {
        const val PREFS_NAME = "activity_recognition"
        const val PREFS_KEY  = "current_state"
        const val ACTION     = "com.example.caers.ACTIVITY_RECOGNITION"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (!ActivityRecognitionResult.hasResult(intent)) return
        val result = ActivityRecognitionResult.extractResult(intent) ?: return
        val activity = result.mostProbableActivity

        // Confidence threshold — ignore low-confidence readings
        if (activity.confidence < 50) return

        val state = when (activity.type) {
            DetectedActivity.WALKING,
            DetectedActivity.ON_FOOT,
            DetectedActivity.RUNNING  -> "walking"
            DetectedActivity.ON_BICYCLE -> "cycling"
            DetectedActivity.IN_VEHICLE -> "vehicle"
            DetectedActivity.STILL      -> "stationary"
            else                        -> return  // UNKNOWN / TILTING — keep previous
        }

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit().putString(PREFS_KEY, state).apply()
    }
}
