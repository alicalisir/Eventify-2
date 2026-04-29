import 'package:flutter/material.dart';

/// Accessible tap target widget that ensures minimum touch target size
class AccessibleTapTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? tooltip;
  final double minSize;

  const AccessibleTapTarget({
    super.key,
    required this.child,
    this.onTap,
    this.tooltip,
    this.minSize = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: minSize,
          height: minSize,
          child: Center(child: child),
        ),
      ),
    );
  }
}
