// Smoke tests for the Faz 2 UX fixes.
//
// Run all:  flutter test test/faz2_smoke_test.dart
// One group: flutter test test/faz2_smoke_test.dart --name "2.4"
//
// NOTE: the "2.4 – Session restore timeout" test intentionally takes ~3 s.

import 'dart:async';

import 'package:context_aware_event_recommendation_system/data/repositories/auth_repository.dart';
import 'package:context_aware_event_recommendation_system/data/services/auth_service.dart';
import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/user_model.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/providers/auth_provider.dart';
import 'package:context_aware_event_recommendation_system/ui/core/ui/app_back_button.dart';
import 'package:context_aware_event_recommendation_system/ui/home/providers/context_provider.dart';
import 'package:context_aware_event_recommendation_system/ui/home/widgets/dashboard_screen.dart';
import 'package:context_aware_event_recommendation_system/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

final _testUser = UserModel(
  id: 'u1',
  email: 'test@example.com',
  name: 'Test User',
  createdAt: DateTime(2024),
  hasCompletedOnboarding: false,
);

// ─── Fake providers ───────────────────────────────────────────────────────────

/// Auth notifier that starts authenticated without touching Supabase.
class _FakeAuth extends Auth {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: _testUser,
  );

  @override
  Future<void> completeOnboarding() async {
    state = state.copyWith(
      user: state.user?.copyWith(hasCompletedOnboarding: true),
    );
  }
}

/// Auth notifier with a safe build() — skips the Supabase listener so the
/// real restoreSession() (which uses authRepositoryProvider) can be tested.
class _SafeAuth extends Auth {
  @override
  AuthState build() => const AuthState(); // no Supabase subscription
  // restoreSession() is inherited from Auth
}

/// AuthRepository whose restoreSession() never resolves — forces a 3 s timeout.
class _HangingAuthRepository implements AuthRepository {
  @override
  Future<UserModel?> restoreSession() => Completer<UserModel?>().future;

  @override
  Future<UserModel?> signIn(String e, String p) => throw UnimplementedError();
  @override
  Future<UserModel?> signUp(String n, String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<UserModel> markOnboardingCompleted(UserModel u) =>
      throw UnimplementedError();
  @override
  Future<void> sendPasswordReset(String e) => throw UnimplementedError();
  @override
  Future<void> updatePassword(String p) => throw UnimplementedError();
}

/// AuthService whose updateInterestsAndConsent always throws — simulates a
/// network failure during the onboarding completion step.
class _ThrowingAuthService implements AuthService {
  @override
  Future<void> updateInterestsAndConsent({
    required String userId,
    required List<String> interests,
    DateTime? consentAt,
  }) async => throw Exception('Simulated network error');

  @override
  Future<UserModel?> signIn(String e, String p) => throw UnimplementedError();
  @override
  Future<UserModel?> signUp(String n, String e, String p) =>
      throw UnimplementedError();
  @override
  Future<void> signOut() => throw UnimplementedError();
  @override
  Future<void> sendPasswordReset(String e) => throw UnimplementedError();
  @override
  Future<void> updatePassword(String p) => throw UnimplementedError();
  @override
  Future<UserModel?> getSessionUser() => throw UnimplementedError();
  @override
  Future<void> updateOnboardingCompleted(String u) =>
      throw UnimplementedError();
}

/// Suggestion stream that immediately resolves to an empty list so the
/// dashboard renders EmptyDashboard (no animation, no Supabase calls).
class _FakeSuggestions extends SuggestionStreamNotifier {
  @override
  Future<List<SuggestionModel>> build() async => [];
}

/// Dismissed-suggestions notifier backed by an empty set — no Supabase needed.
class _FakeDismissed extends DismissedSuggestions {
  @override
  Future<Set<String>> build() async => {};
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── 2.5 – AppBackButton ────────────────────────────────────────────────────

  group('2.5 – AppBackButton', () {
    testWidgets('renders an arrow_back icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(appBar: AppBar(leading: const AppBackButton())),
      ));
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('fires custom onPressed when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: AppBackButton(onPressed: () => tapped = true),
          ),
        ),
      ));
      await tester.tap(find.byType(AppBackButton));
      expect(tapped, isTrue);
    });

    testWidgets('pops the current GoRouter route when no onPressed provided',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/a',
        routes: [
          GoRoute(
            path: '/a',
            builder: (ctx, _) => Scaffold(
              body: TextButton(
                onPressed: () => ctx.push('/b'),
                child: const Text('Go to B'),
              ),
            ),
          ),
          GoRoute(
            path: '/b',
            builder: (_, _) => Scaffold(
              appBar: AppBar(leading: const AppBackButton()),
              body: const Text('Page B'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to B'));
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsOneWidget);

      await tester.tap(find.byType(AppBackButton));
      await tester.pumpAndSettle();
      expect(find.text('Page B'), findsNothing);
    });
  });

  // ─── 2.4 – Session restore timeout ──────────────────────────────────────────
  //
  // This test intentionally takes ~3 s (the configured timeout value).

  group('2.4 – Session restore timeout', () {
    test('marks state unauthenticated when the repo never resolves (>3 s)',
        () async {
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_SafeAuth.new),
        authRepositoryProvider.overrideWithValue(_HangingAuthRepository()),
      ]);
      addTearDown(container.dispose);

      await container.read(authProvider.notifier).restoreSession();

      expect(
        container.read(authProvider).status,
        AuthStatus.unauthenticated,
        reason: 'Should fall back to unauthenticated after a 3 s timeout',
      );
    });
  });

  // ─── 2.1 – Dashboard context error card ────────────────────────────────────

  group('2.1 – Dashboard context error card', () {
    testWidgets(
        'shows "Context unavailable" with a Retry button when the '
        'ambientContextProvider throws', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_FakeAuth.new),
            ambientContextProvider.overrideWith(
              (ref) => Future<ContextState>.error(Exception('simulated failure')),
            ),
            suggestionStreamProvider.overrideWith(_FakeSuggestions.new),
            dismissedSuggestionsProvider.overrideWith(_FakeDismissed.new),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Context unavailable'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  // ─── 2.3 – Onboarding preferences snackbar ─────────────────────────────────

  group('2.3 – Onboarding preferences snackbar', () {
    testWidgets(
        'shows a warning snackbar when updateInterestsAndConsent throws, '
        'then still navigates to dashboard', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // Minimal router: onboarding → dashboard stub
      final router = GoRouter(
        initialLocation: '/onboarding',
        routes: [
          GoRoute(
            path: '/onboarding',
            name: 'onboarding',
            builder: (_, _) => const OnboardingScreen(),
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (_, _) =>
                const Scaffold(body: Text('Dashboard stub')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Authenticated user so _completeAndGo() enters the try block.
            authProvider.overrideWith(_FakeAuth.new),
            // Throwing service so the catch block runs.
            authServiceProvider.overrideWithValue(_ThrowingAuthService()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping "Skip" on the first slide calls _completeAndGo() immediately.
      await tester.tap(find.text('Skip'));
      // Pump 1: async gap — the throwing authService future resolves.
      await tester.pump();
      // Pump 2: catch block runs, AppSnackbar.show() schedules the snackbar.
      await tester.pump();
      // Pump 3: snackbar widget is inserted into the overlay.
      await tester.pump(const Duration(milliseconds: 150));

      expect(
        find.text(
          'Preferences could not be saved — you can update them from Profile.',
        ),
        findsOneWidget,
        reason: 'Warning snackbar must appear even though navigation proceeds',
      );

      // After the snackbar, _completeAndGo() should still navigate to dashboard.
      await tester.pumpAndSettle();
      expect(find.text('Dashboard stub'), findsOneWidget);
    });
  });
}
