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
    final authState = ref.watch(authProvider);

    // Start GPS + screen tracking immediately if already authenticated.
    final gps = ref.read(gpsCollectionServiceProvider);
    final screenEvents = ref.read(screenEventServiceProvider);
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      gps.start(authState.user!.id);
      screenEvents.start();
    }

    // Handle future auth state changes (login / logout).
    ref.listen<AuthState>(authProvider, (previous, next) {
      final gps = ref.read(gpsCollectionServiceProvider);
      final screenEvents = ref.read(screenEventServiceProvider);
      if (next.status == AuthStatus.authenticated && next.user != null) {
        gps.start(next.user!.id);
        screenEvents.start();
      } else if (next.status == AuthStatus.unauthenticated) {
        gps.stop();
        screenEvents.stop();
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
