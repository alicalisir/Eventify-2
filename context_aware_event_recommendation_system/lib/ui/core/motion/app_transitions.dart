import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_curves.dart';
import 'app_durations.dart';

/// Page-transition factory for go_router.
///
/// Two patterns:
/// - [fadeThroughPage] — top-level context switches (auth → home, major flows).
///   Old page fades + shrinks away; new page fades + grows in.
/// - [sharedAxisXPage] — drill-down navigation (dashboard → detail, → profile).
///   New page slides in from the right; old page slides out to the left.
///
/// Both builders honour [MediaQuery.disableAnimations]: when the user has
/// "Reduce motion" enabled, transitions are cut instantly.
abstract final class AppTransitions {
  static CustomTransitionPage<T> fadeThroughPage<T>({
    required LocalKey pageKey,
    required Widget child,
  }) =>
      CustomTransitionPage<T>(
        key: pageKey,
        child: child,
        transitionDuration: AppDurations.standard,
        reverseTransitionDuration: AppDurations.quick,
        transitionsBuilder: _fadeThrough,
      );

  static CustomTransitionPage<T> sharedAxisXPage<T>({
    required LocalKey pageKey,
    required Widget child,
  }) =>
      CustomTransitionPage<T>(
        key: pageKey,
        child: child,
        transitionDuration: AppDurations.standard,
        reverseTransitionDuration: AppDurations.quick,
        transitionsBuilder: _sharedAxisX,
      );

  // ── builders ────────────────────────────────────────────────────────────────

  static Widget _fadeThrough(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _FadeThroughTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  static Widget _sharedAxisX(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _SharedAxisXTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

// ── Fade-through ─────────────────────────────────────────────────────────────

class _FadeThroughTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _FadeThroughTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: animation, curve: AppCurves.decelerate);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: AppCurves.accelerate);

    return FadeTransition(
      opacity: enter,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(enter),
        child: FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.0).animate(exit),
          child: child,
        ),
      ),
    );
  }
}

// ── Shared-axis horizontal ───────────────────────────────────────────────────

class _SharedAxisXTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _SharedAxisXTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enter = CurvedAnimation(parent: animation, curve: AppCurves.decelerate);
    final exit = CurvedAnimation(parent: secondaryAnimation, curve: AppCurves.accelerate);

    // Incoming: slide from +8 % right → 0, fade in.
    // Outgoing: slide to -8 % left, fade out.
    // The two SlideTransitions compose additively; when one is active the other
    // contributes zero offset (its driving animation is at 0 or 1).
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(enter),
      child: FadeTransition(
        opacity: enter,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.08, 0),
          ).animate(exit),
          child: FadeTransition(
            opacity: Tween(begin: 1.0, end: 0.0).animate(exit),
            child: child,
          ),
        ),
      ),
    );
  }
}
