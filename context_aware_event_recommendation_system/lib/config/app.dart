import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../routing/app_router.dart';
import '../ui/auth/providers/auth_provider.dart';
import '../ui/core/themes/app_theme.dart';
import 'constants/app_strings.dart';

class ContextAwareApp extends ConsumerWidget {
  const ContextAwareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // Start GPS collection when authenticated, stop on sign-out.
    ref.listen<AuthState>(authProvider, (previous, next) {
      final gps = ref.read(gpsCollectionServiceProvider);
      if (next.status == AuthStatus.authenticated && next.user != null) {
        gps.start(next.user!.id);
      } else if (next.status == AuthStatus.unauthenticated) {
        gps.stop();
      }
    });

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
