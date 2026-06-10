import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ui/auth/providers/auth_provider.dart';
import '../ui/auth/widgets/forgot_password_screen.dart';
import '../ui/auth/widgets/login_screen.dart';
import '../ui/auth/widgets/register_screen.dart';
import '../ui/auth/widgets/reset_password_screen.dart';
import '../ui/core/motion/app_transitions.dart';
import '../ui/error/widgets/error_screen.dart';
import '../ui/home/widgets/dashboard_screen.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';
import '../ui/profile/widgets/privacy_policy_screen.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/suggestion/widgets/suggestion_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authListenable = _AuthRouterListenable(ref);
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    errorPageBuilder: (context, state) => AppTransitions.fadeThroughPage(
      pageKey: state.pageKey,
      child: ErrorScreen(
        kind: ErrorKind.offline,
        onRetry: () => context.goNamed('dashboard'),
      ),
    ),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.loading ||
          auth.status == AuthStatus.initial) {
        return null;
      }

      // Password recovery flow takes priority.
      if (auth.status == AuthStatus.passwordRecovery) {
        return loc == '/reset-password' ? null : '/reset-password';
      }

      final atAuthRoute = loc == '/login' ||
          loc == '/register' ||
          loc == '/forgot-password';

      if (auth.status != AuthStatus.authenticated) {
        return atAuthRoute ? null : '/login';
      }

      final user = auth.user;
      if (user != null && !user.hasCompletedOnboarding) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      if (atAuthRoute || loc == '/onboarding') return '/dashboard';
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
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const ForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        pageBuilder: (context, state) => AppTransitions.fadeThroughPage(
          pageKey: state.pageKey,
          child: const ResetPasswordScreen(),
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
              onRetry: kind == ErrorKind.location
                  ? () => openAppSettings()
                  : () => context.goNamed('dashboard'),
            ),
          );
        },
      ),
      GoRoute(
        path: '/privacy-policy',
        name: 'privacy-policy',
        pageBuilder: (context, state) => AppTransitions.sharedAxisXPage(
          pageKey: state.pageKey,
          child: const PrivacyPolicyScreen(),
        ),
      ),
    ],
  );
});

class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}
