package com.example.context_aware_event_recommendation_system

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

/**
 * Collects app usage from UsageStatsManager and buffers to FlutterSharedPreferences.
 * The Dart background service reads this buffer and uploads to Supabase.
 *
 * Same SharedPreferences bridge pattern used by ScreenEventService and
 * ActivityRecognitionReceiver — no MethodChannel, works from any Android context.
 */
object AppUsageCollector {

    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    const val FLUTTER_KEY = "flutter.app_usage_buffer"

    private const val MIN_DURATION_MS = 30_000L // 30 seconds

    // Android ApplicationInfo.category → ML model category
    private fun systemCategory(context: Context, pkg: String): String? {
        return try {
            val info = context.packageManager.getApplicationInfo(pkg, 0)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                when (info.category) {
                    android.content.pm.ApplicationInfo.CATEGORY_GAME         -> "gaming"
                    android.content.pm.ApplicationInfo.CATEGORY_AUDIO        -> "music"
                    android.content.pm.ApplicationInfo.CATEGORY_VIDEO        -> "video"
                    android.content.pm.ApplicationInfo.CATEGORY_IMAGE        -> "photo"
                    android.content.pm.ApplicationInfo.CATEGORY_SOCIAL       -> "social"
                    android.content.pm.ApplicationInfo.CATEGORY_NEWS         -> "news"
                    android.content.pm.ApplicationInfo.CATEGORY_MAPS         -> "navigation"
                    android.content.pm.ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
                    else -> null
                }
            } else null
        } catch (e: Exception) { null }
    }

    private val PKG_CATEGORY = mapOf(
        // Social
        "com.instagram.android" to "social",
        "com.twitter.android" to "social",
        "com.twitter.android.lite" to "social",
        "com.facebook.katana" to "social",
        "com.facebook.lite" to "social",
        "com.snapchat.android" to "social",
        "com.reddit.frontpage" to "social",
        "com.pinterest" to "social",
        "com.linkedin.android" to "social",
        "com.tumblr" to "social",
        // Short video
        "com.zhiliaoapp.musically" to "short_video",
        "com.ss.android.ugc.trill" to "short_video",
        "com.ss.android.ugc.aweme" to "short_video",
        // Messaging
        "com.whatsapp" to "messaging",
        "com.whatsapp.w4b" to "messaging",
        "org.telegram.messenger" to "messaging",
        "org.thunderdog.challegram" to "messaging",
        "com.discord" to "messaging",
        "com.viber.voip" to "messaging",
        "com.skype.raider" to "messaging",
        "com.microsoft.teams" to "messaging",
        // Video
        "com.google.android.youtube" to "video",
        "com.google.android.youtube.tv" to "video",
        // Streaming
        "com.netflix.mediaclient" to "streaming",
        "tv.twitch.android.app" to "streaming",
        "com.disney.disneyplus" to "streaming",
        "com.amazon.avod.thirdpartyclient" to "streaming",
        "com.hbo.hbonow" to "streaming",
        // Music
        "com.spotify.music" to "music",
        "com.apple.android.music" to "music",
        "com.google.android.apps.youtube.music" to "music",
        "com.soundcloud.android" to "music",
        "com.deezer.android" to "music",
        // Gaming
        "com.mobile.legends" to "gaming",
        "com.tencent.ig" to "gaming",
        "com.tencent.tmgp.pubgmhd" to "gaming",
        "com.supercell.clashroyale" to "gaming",
        "com.supercell.clashofclans" to "gaming",
        "com.king.candycrushsaga" to "gaming",
        "com.riotgames.league.wildrift" to "gaming",
        "com.activision.callofduty.shooter" to "gaming",
        "com.ea.game.fifamobile" to "gaming",
        // Productivity
        "com.google.android.gm" to "productivity",
        "com.microsoft.office.outlook" to "productivity",
        "com.Slack" to "productivity",
        "notion.id" to "productivity",
        "com.microsoft.office.word" to "productivity",
        "com.microsoft.office.excel" to "productivity",
        "com.google.android.apps.docs" to "productivity",
        "com.google.android.apps.sheets" to "productivity",
        "com.todoist.android.Todoist" to "productivity",
        "com.anydo" to "productivity",
        // Browser
        "com.android.chrome" to "browser",
        "org.mozilla.firefox" to "browser",
        "com.opera.browser" to "browser",
        "com.microsoft.emmx" to "browser",
        "com.brave.browser" to "browser",
        "com.sec.android.app.sbrowser" to "browser",
        // Navigation
        "com.google.android.apps.maps" to "navigation",
        "ru.yandex.yandexmaps" to "navigation",
        "com.waze" to "navigation",
        "com.here.app.maps" to "navigation",
        // Ride share
        "com.ubercab" to "ride_share",
        "com.bitaksi" to "ride_share",
        "com.careem.acma" to "ride_share",
        "com.indriver.app" to "ride_share",
        // Fitness
        "com.strava" to "fitness",
        "com.nike.nikeplus.gps" to "fitness",
        "com.fitbit.FitbitMobile" to "fitness",
        "com.garmin.android.apps.connectmobile" to "fitness",
        "com.samsung.android.shealth" to "fitness",
        "com.google.android.apps.fitness" to "fitness",
        // Education
        "com.duolingo" to "education",
        "com.coursera.app" to "education",
        "org.khanacademy.android" to "education",
        "com.udemy.android" to "education",
        "com.memrise.android.memrisecompanion" to "education",
        // Reading
        "com.amazon.kindle" to "reading",
        "com.medium.reader" to "reading",
        "com.scribd.app.reader0" to "reading",
        "com.goodreads.android" to "reading",
        // News
        "com.google.android.apps.magazines" to "news",
        "com.bbc.news" to "news",
        "com.cnn.mobile.android.phone" to "news",
        "flipboard.app" to "news",
        "com.microsoft.amp.apps.bingnews" to "news",
        // Finance
        "com.google.android.apps.walletnfcrel" to "finance",
        "com.paypal.android.p2pmobile" to "finance",
        "com.akbank.android.apps.akbank" to "finance",
        "com.garanti.cepsubesi" to "finance",
        "com.ykb.android" to "finance",
        "com.isbank.iscepi" to "finance",
        // Shopping
        "com.trendyol.app" to "shopping",
        "com.getir" to "shopping",
        "com.amazon.mShop.android.shopping" to "shopping",
        "com.hepsiburada" to "shopping",
        "com.n11.android" to "shopping",
        // Dating
        "com.tinder" to "dating",
        "com.bumble.app" to "dating",
        "com.badoo.mobile" to "dating",
        // Photo
        "com.google.android.apps.photos" to "photo",
        "com.sec.android.gallery3d" to "photo",
        "com.snap.android" to "photo",
    )

    fun hasPermission(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        // MIUI returns MODE_DEFAULT (3) when permission is granted via UI — treat as allowed
        return mode == AppOpsManager.MODE_ALLOWED || mode == AppOpsManager.MODE_DEFAULT
    }

    fun collectAndBuffer(context: Context) {
        if (!hasPermission(context)) return

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val endMs = System.currentTimeMillis()
        val startMs = endMs - 24 * 60 * 60 * 1000L

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startMs, endMs)
        if (stats.isNullOrEmpty()) return

        val arr = JSONArray()
        for (stat in stats) {
            if (stat.totalTimeInForeground < MIN_DURATION_MS) continue
            val category = resolveCategory(context, stat.packageName)

            arr.put(JSONObject().apply {
                put("app_name", stat.packageName)
                put("category", category)
                put("duration_min", stat.totalTimeInForeground / 60_000.0)
                put("timestamp", java.time.LocalDateTime.ofInstant(
                    java.time.Instant.ofEpochMilli(stat.lastTimeUsed),
                    java.time.ZoneId.systemDefault()
                ).format(java.time.format.DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                put("state", "foreground")
            })
        }

        if (arr.length() == 0) return

        context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            .edit().putString(FLUTTER_KEY, arr.toString()).apply()
    }

    private fun resolveCategory(context: Context, pkg: String): String {
        PKG_CATEGORY[pkg]?.let { return it }
        val lower = pkg.lowercase()
        when {
            "game" in lower || "puzzle" in lower  -> return "gaming"
            "news" in lower || "haber" in lower   -> return "news"
            "music" in lower || "muzik" in lower  -> return "music"
            "shop" in lower || "market" in lower  -> return "shopping"
            "fitness" in lower || "sport" in lower -> return "fitness"
            "bank" in lower || "pay" in lower     -> return "finance"
            "edu" in lower || "learn" in lower    -> return "education"
            "photo" in lower || "camera" in lower -> return "photo"
        }
        return systemCategory(context, pkg) ?: "other"
    }
}
