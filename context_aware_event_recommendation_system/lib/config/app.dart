import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../routing/app_router.dart';
import '../ui/core/themes/app_theme.dart';
import 'constants/app_strings.dart';

/// Main application widget
///
/// This widget sets up:
/// - MaterialApp.router configuration
/// - GoRouter for navigation
/// - Theme (light and dark modes)
/// - Provider dependencies
class ContextAwareApp extends ConsumerWidget {
  const ContextAwareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
