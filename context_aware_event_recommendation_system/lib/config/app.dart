import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../di/providers.dart';
import '../routing/app_router.dart';
import '../ui/auth/providers/auth_provider.dart';
import '../ui/core/themes/app_theme.dart';
import '../utils/app_logger.dart';
import 'constants/app_strings.dart';

class ContextAwareApp extends ConsumerStatefulWidget {
  const ContextAwareApp({super.key});

  @override
  ConsumerState<ContextAwareApp> createState() => _ContextAwareAppState();
}

class _ContextAwareAppState extends ConsumerState<ContextAwareApp>
    with WidgetsBindingObserver {
  DateTime? _sessionStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionStart = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _sessionStart = DateTime.now();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _flushSession();
    }
  }

  void _flushSession() {
    final start = _sessionStart;
    if (start == null) return;
    final durationMin = DateTime.now().difference(start).inSeconds / 60.0;
    if (durationMin < 0.1) return; // ignore sub-6s blips
    _sessionStart = null;

    final userId =
        ref.read(sharedPreferencesProvider).getString('current_user_id');
    if (userId == null) return;

    Supabase.instance.client.from('app_sessions').insert({
      'user_id': userId,
      'timestamp': start.toUtc().toIso8601String(),
      'app_name': 'Eventify',
      'category': 'recommendation',
      'duration_min': durationMin,
      'state': 'foreground',
    }).then((_) {
      AppLogger.d('[Session] ${durationMin.toStringAsFixed(1)} min logged');
    }).catchError((e) {
      AppLogger.w('[Session] flush failed', e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authState = ref.watch(authProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final screenEvents = ref.read(screenEventServiceProvider);

    // Sync current auth state on build (handles hot-restart / session restore)
    if (authState.status == AuthStatus.authenticated && authState.user != null) {
      prefs.setString('current_user_id', authState.user!.id);
      screenEvents.start();
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
