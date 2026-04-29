import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'config/app.dart';

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
  
  runApp(const ProviderScope(child: ContextAwareApp()));
}
