import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/auth/providers/auth_provider.dart';
import '../ui/auth/widgets/login_screen.dart';
import '../ui/auth/widgets/register_screen.dart';
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
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/suggestion/:id',
        name: 'suggestion',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SuggestionDetailScreen(suggestionId: id);
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/error',
        name: 'error',
        builder: (context, state) {
          final raw = state.uri.queryParameters['kind'];
          final kind = ErrorKind.values.firstWhere(
            (k) => k.name == raw,
            orElse: () => ErrorKind.offline,
          );
          return ErrorScreen(
            kind: kind,
            onRetry: () => context.goNamed('dashboard'),
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
