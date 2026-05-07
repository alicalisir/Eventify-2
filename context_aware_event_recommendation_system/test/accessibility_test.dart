// Accessibility audit tests.
//
// Covers:
//  - androidTapTargetGuideline  — every interactive element ≥ 48×48 dp
//  - labeledTapTargetGuideline  — every tappable element has a semantic label
//  - textContrastGuideline      — text contrast ≥ 4.5:1 (WCAG AA)
//
// Run with:
//   flutter test test/accessibility_test.dart

import 'package:context_aware_event_recommendation_system/ui/auth/widgets/login_screen.dart';
import 'package:context_aware_event_recommendation_system/ui/auth/widgets/register_screen.dart';
import 'package:context_aware_event_recommendation_system/ui/onboarding/widgets/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(Widget child, {ThemeData? theme}) => ProviderScope(
  child: MaterialApp(theme: theme ?? ThemeData.light(), home: child),
);

// ---------------------------------------------------------------------------
// LoginScreen
// ---------------------------------------------------------------------------

void main() {
  group('Accessibility – LoginScreen (light)', () {
    testWidgets('tap targets ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tappable element has a semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text contrast ≥ 4.5:1', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('Accessibility – LoginScreen (dark)', () {
    testWidgets('text contrast ≥ 4.5:1', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(const LoginScreen(), theme: ThemeData.dark()),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // RegisterScreen
  // ---------------------------------------------------------------------------

  group('Accessibility – RegisterScreen (light)', () {
    testWidgets('tap targets ≥ 48 dp', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tappable element has a semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('text contrast ≥ 4.5:1', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('terms checkbox exposes checked state to screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      // The checkbox is below the fold — scroll to it first.
      final checkboxFinder = find.bySemanticsLabel(
        'Agree to Terms of Service and Privacy Policy',
      );
      await tester.ensureVisible(checkboxFinder);
      await tester.pumpAndSettle();

      final uncheckedNode = tester.getSemantics(checkboxFinder);
      expect(uncheckedNode.flagsCollection.isChecked, isFalse);
      expect(uncheckedNode.flagsCollection.isButton, isTrue);

      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();

      final checkedNode = tester.getSemantics(
        find.bySemanticsLabel('Terms of Service and Privacy Policy, agreed'),
      );
      expect(checkedNode.flagsCollection.isChecked, isTrue);

      handle.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // OnboardingScreen
  // ---------------------------------------------------------------------------

  group('Accessibility – OnboardingScreen (light)', () {
    testWidgets('tap targets ≥ 48 dp', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390×844 @3x
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('every tappable element has a semantic label', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390×844 @3x
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(const OnboardingScreen()));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
