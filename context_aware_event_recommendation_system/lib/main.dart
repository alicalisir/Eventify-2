import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app.dart';
import 'ui/auth/providers/auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Preload Google Fonts to avoid blocking the main thread
  try {
    await Future.wait([
      GoogleFonts.pendingFonts([
        GoogleFonts.poppins(),
        GoogleFonts.inter(),
      ]),
    ]);
  } catch (e) {
    // Fonts will be loaded on demand if preloading fails
    debugPrint('Failed to preload fonts: $e');
  }

  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Hydrate persisted session before the router runs its first redirect.
  await container.read(authProvider.notifier).restoreSession();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ContextAwareApp(),
    ),
  );
}
