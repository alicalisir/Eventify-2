import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app.dart';
import 'config/app_env.dart';
import 'data/services/background_service.dart';
import 'ui/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    debug: kDebugMode,
  );

  // Store Supabase credentials so background service can init independently
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('supabase_url', dotenv.env['SUPABASE_URL']!);
  await prefs.setString('supabase_anon_key', dotenv.env['SUPABASE_ANON_KEY']!);

  final sentryDsn = dotenv.env['SENTRY_DSN'] ?? '';
  if (sentryDsn.isEmpty) {
    debugPrint('[Sentry] DSN not configured — error reporting disabled');
  }
  try {
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = AppEnv.flavor;
      options.tracesSampleRate =
          kDebugMode ? 1.0 : AppEnv.sentryTracesSampleRate;
      options.debug = kDebugMode;
      options.beforeSend = (event, hint) {
        // Strip auth tokens and email from breadcrumbs to avoid PII leaks.
        final sanitized = event.breadcrumbs?.map((b) {
          final data = Map<String, dynamic>.from(b.data ?? {});
          data.remove('token');
          data.remove('access_token');
          data.remove('email');
          return b.copyWith(data: data);
        }).toList();
        return event.copyWith(breadcrumbs: sanitized);
      };
    });
  } catch (_) {}

  await _bootstrap();
}

Future<void> _bootstrap() async {
  try {
    await Future.wait([
      GoogleFonts.pendingFonts([GoogleFonts.poppins(), GoogleFonts.inter()]),
    ]);
  } catch (e) {
    debugPrint('Failed to preload fonts: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Run app immediately — router waits at /login while auth is initial.
  // Session restore runs async so a slow network never blocks the UI.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ContextAwareApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    container.read(authProvider.notifier).restoreSession();
    initBackgroundService().catchError(
      (Object e) => debugPrint('[BackgroundService] Init failed: $e'),
    );
  });
}
