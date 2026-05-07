import 'package:flutter/material.dart';

abstract final class AppCurves {
  /// Material 3 "emphasized" — default for most UI transitions.
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;

  /// Decelerate: elements arriving (ease out).
  static const Curve decelerate = Curves.easeOutCubic;

  /// Accelerate: elements departing (ease in).
  static const Curve accelerate = Curves.easeInCubic;

  /// Standard symmetric ease — micro-interactions, toggles.
  static const Curve standard = Curves.easeInOutCubic;
}
