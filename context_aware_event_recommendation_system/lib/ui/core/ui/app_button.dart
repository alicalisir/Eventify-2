import 'package:flutter/material.dart';
import 'package:context_aware_event_recommendation_system/config/constants/app_spacing.dart';

/// Primary app button with loading state
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Widget buttonChild = isLoading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: AppSpacing.iconSizeSm),
                  const SizedBox(width: AppSpacing.xs),
                  Text(text),
                ],
              )
            : Text(text);

    if (isOutlined) {
      return Semantics(
        button: true,
        enabled: !isLoading && onPressed != null,
        label: text,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: foregroundColor,
            side: foregroundColor != null
                ? BorderSide(color: foregroundColor!)
                : null,
          ),
          child: buttonChild,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: !isLoading && onPressed != null,
      label: text,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
        child: buttonChild,
      ),
    );
  }
}
