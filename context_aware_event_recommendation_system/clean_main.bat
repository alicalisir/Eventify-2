@echo off
cd /d "c:\Users\Huawei\Desktop\Klasorlerim\Projelerim\context_aware_event_recommendation_system\context_aware_event_recommendation_system\lib"

:: Create backup
copy main.dart main.dart.backup

:: Create clean main.dart
(
echo import 'package:flutter/material.dart';
echo import 'package:flutter_riverpod/flutter_riverpod.dart';
echo import 'package:google_fonts/google_fonts.dart';
echo import 'app.dart';
echo.
echo void main^(^) async {
echo   WidgetsFlutterBinding.ensureInitialized^(^);
echo   
echo   // Preload Google Fonts to avoid blocking the main thread
echo   try {
echo     await Future.wait^([
echo       GoogleFonts.pendingFonts^([
echo         GoogleFonts.poppins^(^),
echo         GoogleFonts.inter^(^),
echo       ]^),
echo     ]^);
echo   } catch ^(e^) {
echo     // Fonts will be loaded on demand if preloading fails
echo     debugPrint^('Failed to preload fonts: $e'^);
echo   }
echo   
echo   runApp^(const ProviderScope^(child: ContextAwareApp^(^)^)^);
echo }
) > main.dart

echo ✅ main.dart cleaned successfully!
echo 📦 Backup created at: lib\main.dart.backup
pause
