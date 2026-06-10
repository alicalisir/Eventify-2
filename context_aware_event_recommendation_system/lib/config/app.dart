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
    final prefs = ref.read(sharedPreferencesProvider);
    final screenEvents = ref.read(screenEventServiceProvider);

    // Sync current auth state on build (handles hot-restart / session restore)
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      prefs.setString('current_user_id', authState.user!.id);
      screenEvents.start(); // starts native ScreenEventService.kt (screen on/off capture)
    }

    // Handle auth state transitions (login / logout)
    ref.listen<AuthState>(authProvider, (previous, next) {
      final screenEvents = ref.read(screenEventServiceProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      if (next.status == AuthStatus.authenticated && next.user != null) {
        prefs.setString('current_user_id', next.user!.id);
        screenEvents.start();
      } else if (next.status == AuthStatus.unauthenticated) {
        prefs.remove('current_user_id');
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
      builder: (ctx, child) => Consumer(
        builder: (context, watchRef, _) {
          final isLoading = watchRef.watch(globalLoadingProvider);
          final inner = child ?? const SizedBox.shrink();
          if (!isLoading) return inner;
          return Stack(
            children: [
              inner,
              Semantics(
                liveRegion: true,
                label: 'Loading',
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
