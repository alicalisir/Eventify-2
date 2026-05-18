import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app.dart';
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

  await SentryFlutter.init((options) {
    options.dsn = dotenv.env['SENTRY_DSN'] ?? '';
    options.environment = kDebugMode ? 'development' : 'production';
    options.tracesSampleRate = 0.2;
    options.debug = kDebugMode;
  });

  // Start persistent background service (GPS + app usage + screen events)
  await initBackgroundService();

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

  await container.read(authProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ContextAwareApp(),
    ),
  );
}
