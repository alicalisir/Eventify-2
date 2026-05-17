import 'package:app_usage/app_usage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/app_logger.dart';

/// Collects app usage statistics and uploads them to Supabase.
///
/// Reads from Android's UsageStatsManager (requires PACKAGE_USAGE_STATS
/// special permission — user must grant via Settings).
class AppUsageService {
  AppUsageService(this._client);

  final SupabaseClient _client;

  // ─────────────────────────────────────── package → category mapping ───────

  static const _pkgCategory = <String, String>{
    // Social
    'com.instagram.android': 'social',
    'com.twitter.android': 'social',
    'com.twitter.android.lite': 'social',
    'com.facebook.katana': 'social',
    'com.facebook.lite': 'social',
    'com.snapchat.android': 'social',
    'com.reddit.frontpage': 'social',
    'com.pinterest': 'social',
    'com.linkedin.android': 'social',
    'com.vkontakte.android': 'social',
    'com.tumblr': 'social',
    // Short video
    'com.zhiliaoapp.musically': 'short_video',   // TikTok
    'com.ss.android.ugc.trill': 'short_video',
    'com.ss.android.ugc.aweme': 'short_video',
    'com.reelshort': 'short_video',
    // Messaging
    'com.whatsapp': 'messaging',
    'com.whatsapp.w4b': 'messaging',
    'org.telegram.messenger': 'messaging',
    'org.thunderdog.challegram': 'messaging',
    'com.discord': 'messaging',
    'com.viber.voip': 'messaging',
    'com.skype.raider': 'messaging',
    'com.microsoft.teams': 'messaging',
    // Video
    'com.google.android.youtube': 'video',
    'com.google.android.youtube.tv': 'video',
    // Streaming
    'com.netflix.mediaclient': 'streaming',
    'tv.twitch.android.app': 'streaming',
    'com.disney.disneyplus': 'streaming',
    'com.amazon.avod.thirdpartyclient': 'streaming',
    'com.hbo.hbonow': 'streaming',
    // Music
    'com.spotify.music': 'music',
    'com.apple.android.music': 'music',
    'com.google.android.apps.youtube.music': 'music',
    'com.soundcloud.android': 'music',
    'com.deezer.android': 'music',
    // Gaming
    'com.mobile.legends': 'gaming',
    'com.tencent.ig': 'gaming',          // PUBG Mobile
    'com.tencent.tmgp.pubgmhd': 'gaming',
    'com.supercell.clashroyale': 'gaming',
    'com.supercell.clashofclans': 'gaming',
    'com.king.candycrushsaga': 'gaming',
    'com.riotgames.league.wildrift': 'gaming',
    'com.activision.callofduty.shooter': 'gaming',
    'com.ea.game.fifamobile': 'gaming',
    // Productivity
    'com.google.android.gm': 'productivity',
    'com.microsoft.office.outlook': 'productivity',
    'com.Slack': 'productivity',
    'notion.id': 'productivity',
    'com.microsoft.office.word': 'productivity',
    'com.microsoft.office.excel': 'productivity',
    'com.google.android.apps.docs': 'productivity',
    'com.google.android.apps.sheets': 'productivity',
    'com.todoist.android.Todoist': 'productivity',
    'com.anydo': 'productivity',
    // Browser
    'com.android.chrome': 'browser',
    'org.mozilla.firefox': 'browser',
    'com.opera.browser': 'browser',
    'com.microsoft.emmx': 'browser',
    'com.brave.browser': 'browser',
    'com.sec.android.app.sbrowser': 'browser',
    // Navigation
    'com.google.android.apps.maps': 'navigation',
    'ru.yandex.yandexmaps': 'navigation',
    'com.waze': 'navigation',
    'com.here.app.maps': 'navigation',
    // Ride share
    'com.ubercab': 'ride_share',
    'com.bitaksi': 'ride_share',
    'com.careem.acma': 'ride_share',
    'com.indriver.app': 'ride_share',
    // Fitness
    'com.strava': 'fitness',
    'com.nike.nikeplus.gps': 'fitness',
    'com.fitbit.FitbitMobile': 'fitness',
    'com.garmin.android.apps.connectmobile': 'fitness',
    'com.noom.android.v2': 'fitness',
    'com.samsung.android.shealth': 'fitness',
    'com.google.android.apps.fitness': 'fitness',
    // Education
    'com.duolingo': 'education',
    'com.coursera.app': 'education',
    'org.khanacademy.android': 'education',
    'com.udemy.android': 'education',
    'com.memrise.android.memrisecompanion': 'education',
    // Reading
    'com.amazon.kindle': 'reading',
    'com.medium.reader': 'reading',
    'com.scribd.app.reader0': 'reading',
    'com.goodreads.android': 'reading',
    // News
    'com.google.android.apps.magazines': 'news',
    'com.bbc.news': 'news',
    'com.cnn.mobile.android.phone': 'news',
    'com.nytimes.android': 'news',
    'flipboard.app': 'news',
    'com.microsoft.amp.apps.bingnews': 'news',
    // Finance
    'com.google.android.apps.walletnfcrel': 'finance',
    'com.paypal.android.p2pmobile': 'finance',
    'com.akbank.android.apps.akbank': 'finance',
    'com.garanti.cepsubesi': 'finance',
    'com.ykb.android': 'finance',
    'com.isbank.iscepi': 'finance',
    // Shopping
    'com.trendyol.app': 'shopping',
    'com.getir': 'shopping',
    'com.amazon.mShop.android.shopping': 'shopping',
    'com.hepsiburada': 'shopping',
    'com.n11.android': 'shopping',
    // Dating
    'com.tinder': 'dating',
    'com.bumble.app': 'dating',
    'com.badoo.mobile': 'dating',
    // Photo
    'com.google.android.apps.photos': 'photo',
    'com.sec.android.gallery3d': 'photo',
    'com.instagram.android.camera': 'photo',
    'com.snap.android': 'photo',
  };

  /// Looks up category for a package name.
  /// Falls back to keyword-based heuristics, then returns null.
  static String? _category(String pkg) {
    final direct = _pkgCategory[pkg];
    if (direct != null) return direct;

    final lower = pkg.toLowerCase();
    if (lower.contains('game') || lower.contains('puzzle')) return 'gaming';
    if (lower.contains('news') || lower.contains('haber')) return 'news';
    if (lower.contains('music') || lower.contains('muzik')) return 'music';
    if (lower.contains('shop') || lower.contains('market')) return 'shopping';
    if (lower.contains('fitness') || lower.contains('sport')) return 'fitness';
    if (lower.contains('bank') || lower.contains('pay')) return 'finance';
    if (lower.contains('edu') || lower.contains('learn')) return 'education';
    if (lower.contains('photo') || lower.contains('camera')) return 'photo';
    return null; // unknown — skip
  }

  // ───────────────────────────────────────────────── public API ─────────────

  /// Collects app usage for the last [windowHours] hours and uploads to Supabase.
  /// Should be called periodically (e.g. every hour alongside GPS collection).
  Future<void> collectAndUpload(String userId, {int windowHours = 24}) async {
    try {
      final end = DateTime.now();
      final start = end.subtract(Duration(hours: windowHours));

      final usage = await AppUsage().getAppUsage(start, end);

      final sessions = <Map<String, dynamic>>[];
      int estimatedUnlocks = 0;

      for (final info in usage) {
        final durationMin = info.usage.inSeconds / 60.0;
        if (durationMin < 0.5) continue; // skip < 30 seconds

        final category = _category(info.packageName);
        if (category == null) continue; // skip uncategorised system apps

        sessions.add({
          'user_id': userId,
          'timestamp': info.lastForeground.toIso8601String(),
          'app_name': info.packageName,
          'category': category,
          'duration_min': durationMin,
          'state': 'foreground',
        });

        estimatedUnlocks++;
      }

      if (sessions.isNotEmpty) {
        await _client
            .from('app_sessions')
            .upsert(sessions, onConflict: 'user_id,app_name,timestamp');
        AppLogger.i('[AppUsage] Uploaded ${sessions.length} sessions');
      }

      // Upload estimated screen events derived from app usage.
      await _uploadScreenEvents(userId, start, estimatedUnlocks);
    } catch (e) {
      AppLogger.w('[AppUsage] Failed to collect/upload', e);
    }
  }

  // Screen events are estimated because true screen-state tracking requires
  // a native foreground service. Each app that was used is treated as one
  // unlock cycle; notifications are estimated at 3× unlocks.
  Future<void> _uploadScreenEvents(
    String userId,
    DateTime windowStart,
    int estimatedUnlocks,
  ) async {
    if (estimatedUnlocks == 0) return;

    final events = <Map<String, dynamic>>[];
    final base = windowStart.toIso8601String();

    for (var i = 0; i < estimatedUnlocks; i++) {
      events.add({'user_id': userId, 'timestamp': base, 'event_type': 'unlock'});
      events.add({'user_id': userId, 'timestamp': base, 'event_type': 'on'});
      events.add({'user_id': userId, 'timestamp': base, 'event_type': 'off'});
    }
    // Notifications: rough 3× unlock rate
    for (var i = 0; i < estimatedUnlocks * 3; i++) {
      events.add({
        'user_id': userId,
        'timestamp': base,
        'event_type': 'notification',
      });
    }

    await _client.from('screen_events').insert(events);
    AppLogger.d('[AppUsage] Estimated $estimatedUnlocks unlocks uploaded');
  }
}
