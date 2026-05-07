import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/auth/providers/auth_provider.dart';
import '../ui/auth/widgets/login_screen.dart';
import '../ui/auth/widgets/register_screen.dart';
import '../ui/core/motion/app_transitions.dart';
import '../ui/error/widgets/error_screen.dart';
import '../ui/home/widgets/dashboard_screen.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/suggestion/widgets/suggestion_detail_screen.dart';

/// GoRouter configuration.
///
/// Routes:
/// - /login → LoginScreen
/// - /register → RegisterScreen
/// - /onboarding → OnboardingScreen
/// - /dashboard → DashboardScreen
/// - /suggestion/:id → SuggestionDetailScreen
/// - /profile → ProfileScreen
/// - /error?kind=offline|location → ErrorScreen
final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthRouterListenable(ref);
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      // Don't bounce the user mid sign-in/up.
      if (auth.status == AuthStatus.loading) return null;

      final atAuthRoute = loc == '/login' || loc == '/register';
      final atOnboarding = loc == '/onboarding';

      if (auth.status != AuthStatus.authenticated) {
        return atAuthRoute ? null : '/login';
      }

      final user = auth.user;
      if (user != null && !user.hasCompletedOnboarding) {
        return atOnboarding ? null : '/onboarding';
      }

      if (atAuthRoute || atOnboarding) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: '/suggestion/:id',
        name: 'suggestion',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return AppTransitions.sharedAxisXPage(
            pageKey: state.pageKey,
            child: SuggestionDetailScreen(suggestionId: id),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => AppTransitions.sharedAxisXPage(
          pageKey: state.pageKey,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/error',
        name: 'error',
        pageBuilder: (context, state) {
          final raw = state.uri.queryParameters['kind'];
          final kind = ErrorKind.values.firstWhere(
            (k) => k.name == raw,
            orElse: () => ErrorKind.offline,
          );
          return AppTransitions.fadeThroughPage(
            pageKey: state.pageKey,
            child: ErrorScreen(
              kind: kind,
              onRetry: () => context.goNamed('dashboard'),
            ),
          );
        },
      ),
    ],
  );
});

/// Bridges Riverpod's [authProvider] to a [Listenable] so GoRouter can
/// re-evaluate redirects on sign-in / sign-out.
class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(Ref ref) {
    ref.listen<AuthState>(
      authProvider,
      (_, _) => notifyListeners(),
    );
  }
}
