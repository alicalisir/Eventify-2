import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ui/auth/widgets/login_screen.dart';
import '../ui/auth/widgets/register_screen.dart';
import '../ui/home/widgets/dashboard_screen.dart';
import '../ui/onboarding/widgets/onboarding_screen.dart';
import '../ui/profile/widgets/profile_screen.dart';
import '../ui/suggestion/widgets/suggestion_detail_screen.dart';

/// GoRouter configuration
///
/// Routes:
/// - /login → LoginScreen
/// - /register → RegisterScreen
/// - /onboarding → OnboardingScreen
/// - /dashboard → DashboardScreen
/// - /suggestion/:id → SuggestionDetailScreen
/// - /profile → ProfileScreen
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
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
    ],
  );
});
