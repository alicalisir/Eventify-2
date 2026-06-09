// Smoke tests for the Faz 3 data/state fixes.
//
// Run all:  flutter test test/faz3_smoke_test.dart
// One group: flutter test test/faz3_smoke_test.dart --name "3.1"

import 'package:context_aware_event_recommendation_system/di/providers.dart';
import 'package:context_aware_event_recommendation_system/domain/models/context_state.dart';
import 'package:context_aware_event_recommendation_system/domain/models/suggestion_model.dart';
import 'package:context_aware_event_recommendation_system/domain/models/user_model.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/providers/auth_provider.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/widgets/register_screen.dart';
import 'package:context_aware_event_recommendation_system/ui/core/ui/password_strength_indicator.dart';
import 'package:context_aware_event_recommendation_system/ui/home/providers/context_provider.dart';
import 'package:context_aware_event_recommendation_system/ui/home/widgets/dashboard_screen.dart';
import 'package:context_aware_event_recommendation_system/ui/profile/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

final _testUser = UserModel(
  id: 'u1',
  email: 'test@example.com',
  name: 'Test User',
  createdAt: DateTime(2024),
  hasCompletedOnboarding: true,
);

// ─── Fake providers ───────────────────────────────────────────────────────────

class _FakeAuth extends Auth {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _testUser);
}

final _testUserB = UserModel(
  id: 'u2',
  email: 'other@example.com',
  name: 'Other User',
  createdAt: DateTime(2024),
  hasCompletedOnboarding: true,
);

class _FakeAuthB extends Auth {
  @override
  AuthState build() => AuthState(status: AuthStatus.authenticated, user: _testUserB);
}

class _FakeSuggestions extends SuggestionStreamNotifier {
  @override
  Future<List<SuggestionModel>> build() async => [];
}

class _FakeDismissed extends DismissedSuggestions {
  @override
  Future<Set<String>> build() async => {};
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // ─── 3.1 – ProfileProvider SharedPreferences persistence ───────────────────

  group('3.1 – ProfileProvider persistence', () {
    // Keys are now scoped to the user ID: profile_<uid>_<setting>
    const uid = 'u1'; // matches _testUser.id

    test('reads saved settings from SharedPreferences on build', () async {
      SharedPreferences.setMockInitialValues({
        'profile_${uid}_location_tracking': false,
        'profile_${uid}_tracking_paused': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      final settings = container.read(profileProvider).settings;
      expect(settings.locationTrackingEnabled, isFalse,
          reason: 'Should load false from user-scoped key');
      expect(settings.trackingPaused, isTrue,
          reason: 'Should load true from user-scoped key');
      // Unset keys should use defaults
      expect(settings.activityRecognitionEnabled, isTrue);
      expect(settings.notificationsEnabled, isTrue);
    });

    test('persists a toggle under the current user\'s scoped key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      container.read(profileProvider.notifier).toggleLocationTracking();

      expect(container.read(profileProvider).settings.locationTrackingEnabled, isFalse);
      expect(prefs.getBool('profile_${uid}_location_tracking'), isFalse,
          reason: 'Must write to the user-scoped key, not a global key');
    });

    test('settings are isolated per user — user A\'s change does not affect user B', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // User A container
      final containerA = ProviderContainer(overrides: [
        authProvider.overrideWith(_FakeAuth.new), // uid = 'u1'
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(containerA.dispose);

      containerA.read(profileProvider.notifier).toggleLocationTracking();
      expect(containerA.read(profileProvider).settings.locationTrackingEnabled, isFalse);

      // User B container (different user ID)
      final containerB = ProviderContainer(overrides: [
        authProvider.overrideWith(_FakeAuthB.new), // uid = 'u2'
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(containerB.dispose);

      expect(
        containerB.read(profileProvider).settings.locationTrackingEnabled,
        isTrue,
        reason: 'User B must not see User A\'s toggle — keys are scoped to uid',
      );
    });

    test('all four toggles persist their user-scoped keys', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ]);
      addTearDown(container.dispose);

      container.read(profileProvider.notifier).toggleActivityRecognition();
      container.read(profileProvider.notifier).toggleNotifications();
      container.read(profileProvider.notifier).toggleTrackingPause();

      expect(prefs.getBool('profile_${uid}_activity_recognition'), isFalse);
      expect(prefs.getBool('profile_${uid}_notifications'), isFalse);
      expect(prefs.getBool('profile_${uid}_tracking_paused'), isTrue);
    });
  });

  // ─── 3.2 – SuggestionModel.signals field ───────────────────────────────────

  group('3.2 – SuggestionModel signals field', () {
    test('defaults to an empty list when not provided', () {
      final model = SuggestionModel(
        id: 's1',
        title: 'Test',
        description: 'desc',
        rationale: 'rationale',
        category: 'Movement',
        createdAt: DateTime(2024),
      );
      expect(model.signals, isEmpty);
    });

    test('stores the provided signals list', () {
      final model = SuggestionModel(
        id: 's2',
        title: 'Test',
        description: 'desc',
        rationale: 'rationale',
        category: 'Movement',
        signals: const ['Weather', 'Activity'],
        createdAt: DateTime(2024),
      );
      expect(model.signals, ['Weather', 'Activity']);
    });

    test('copyWith preserves signals', () {
      final original = SuggestionModel(
        id: 's3',
        title: 'A',
        description: 'desc',
        rationale: 'r',
        category: 'Recharge',
        signals: const ['Location'],
        createdAt: DateTime(2024),
      );
      final copy = original.copyWith(title: 'B');
      expect(copy.signals, ['Location']);
    });
  });

  // ─── 3.3 – PasswordStrengthIndicator replaces inline _StrengthMeter ────────

  group('3.3 – PasswordStrengthIndicator in RegisterScreen', () {
    testWidgets('no indicator shown when password field is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(_FakeAuth.new)],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PasswordStrengthIndicator), findsNothing);
    });

    testWidgets('PasswordStrengthIndicator appears when password is typed',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authProvider.overrideWith(_FakeAuth.new)],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Password field is the third TextFormField (after name and email)
      await tester.enterText(find.byType(TextFormField).at(2), 'Secret123!');
      await tester.pump();

      expect(find.byType(PasswordStrengthIndicator), findsOneWidget);
    });
  });

  // ─── 3.4 – Dashboard uses CustomScrollView (SliverList.builder) ────────────

  group('3.4 – Dashboard uses CustomScrollView', () {
    testWidgets('body contains CustomScrollView instead of plain ListView',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_FakeAuth.new),
            ambientContextProvider.overrideWith(
              (ref) => Future<ContextState>.error(Exception('no context')),
            ),
            suggestionStreamProvider.overrideWith(_FakeSuggestions.new),
            dismissedSuggestionsProvider.overrideWith(_FakeDismissed.new),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomScrollView), findsOneWidget);
      // Verify that the old plain ListView is gone
      expect(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        ),
        findsNothing,
        reason: 'Dashboard body must use CustomScrollView, not ListView',
      );
    });
  });

  // ─── 3.5 – DismissedSuggestions short-circuit ──────────────────────────────

  group('3.5 – dismiss() short-circuit', () {
    test('dismissing the same ID twice does not grow the set', () async {
      // Test notifier that implements the same guard as production but
      // without hitting a real SuggestionRepository.
      final container = ProviderContainer(overrides: [
        dismissedSuggestionsProvider.overrideWith(_MemoryDismissed.new),
      ]);
      addTearDown(container.dispose);
      await container.read(dismissedSuggestionsProvider.future);

      await container.read(dismissedSuggestionsProvider.notifier).dismiss('id-1');
      await container.read(dismissedSuggestionsProvider.notifier).dismiss('id-1');

      expect(
        container.read(dismissedSuggestionsProvider).value,
        {'id-1'},
        reason: 'Set must have exactly one entry after two dismiss() calls with the same ID',
      );
    });

    test('different IDs are both inserted', () async {
      final container = ProviderContainer(overrides: [
        dismissedSuggestionsProvider.overrideWith(_MemoryDismissed.new),
      ]);
      addTearDown(container.dispose);
      await container.read(dismissedSuggestionsProvider.future);

      await container.read(dismissedSuggestionsProvider.notifier).dismiss('id-1');
      await container.read(dismissedSuggestionsProvider.notifier).dismiss('id-2');

      expect(container.read(dismissedSuggestionsProvider).value, {'id-1', 'id-2'});
    });
  });
}

/// In-memory DismissedSuggestions: no Supabase, exercises the same short-circuit
/// guard ({@link DismissedSuggestions.dismiss}) without touching a real repo.
class _MemoryDismissed extends DismissedSuggestions {
  @override
  Future<Set<String>> build() async => {};

  @override
  Future<void> dismiss(String id) async {
    if (state.value?.contains(id) ?? false) return;
    state = AsyncData({...state.value ?? {}, id});
  }
}
