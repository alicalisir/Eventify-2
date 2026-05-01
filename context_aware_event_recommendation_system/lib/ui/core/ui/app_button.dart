import 'package:flutter/material.dart';
import 'package:context_aware_event_recommendation_system/config/constants/app_colors.dart';
import 'package:context_aware_event_recommendation_system/config/constants/app_spacing.dart';

/// Primary app button — supports filled, outlined, loading, leading icon,
/// trailing icon, and explicit color override (e.g. success-state buttons).
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.leadingIcon,
    this.trailingIcon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 52,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final effectiveFg =
        foregroundColor ?? (isOutlined ? AppColors.textPrimaryLight : Colors.white);
    final effectiveBg = backgroundColor ?? AppColors.primary;

    final child = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveFg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 20, color: effectiveFg),
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: effectiveFg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailingIcon != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(trailingIcon, size: 18, color: effectiveFg),
              ],
            ],
          );

    final size = Size(fullWidth ? double.infinity : 0, height);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
    );

    final button = Semantics(
      button: true,
      enabled: !disabled,
      label: text,
      child: isOutlined
          ? OutlinedButton(
              onPressed: disabled ? null : onPressed,
              style: OutlinedButton.styleFrom(
                minimumSize: size,
                foregroundColor: effectiveFg,
                side: BorderSide(
                  color: foregroundColor ?? AppColors.dividerLight,
                  width: 1.5,
                ),
                shape: shape,
              ),
              child: child,
            )
          : ElevatedButton(
              onPressed: disabled ? null : onPressed,
              style: ElevatedButton.styleFrom(
                minimumSize: size,
                backgroundColor: effectiveBg,
                foregroundColor: effectiveFg,
                shape: shape,
                elevation: 0,
                shadowColor: Colors.transparent,
              ),
              child: child,
            ),
    );

    if (isOutlined || backgroundColor != null) return button;

    // Filled primary button gets the brand glow.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.30),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: button,
    );
  }
}
