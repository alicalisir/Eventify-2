import 'package:flutter/material.dart';

/// Pressable surface that scales to 0.97 when pressed.
/// Mirrors the design system's `Pressable` primitive — low-affordance
/// interactive surface used outside of standard buttons (cards, list rows,
/// chips with tap behavior).
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final BorderRadius? borderRadius;
  final Duration duration;
  final double pressedScale;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 120),
    this.pressedScale = 0.97,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1.0,
          duration: widget.duration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: disabled ? 0.5 : 1,
            duration: widget.duration,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
