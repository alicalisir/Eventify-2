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

    // Start GPS immediately if session was already restored before the widget
    // tree was built (restoreSession runs before runApp, so ref.listen misses
    // the initial authenticated state).
    final gps = ref.read(gpsCollectionServiceProvider);
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      gps.start(authState.user!.id);
    }

    // Also handle future auth state changes (login / logout).
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
