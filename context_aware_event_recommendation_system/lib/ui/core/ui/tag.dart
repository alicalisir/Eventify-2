import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';

/// Pill-shaped tag with optional leading icon.
/// Used in suggestion cards, detail metadata, profile chips.
class Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? background;
  final Color? foreground;
  final Color? borderColor;

  const Tag({
    super.key,
    required this.label,
    this.icon,
    this.background,
    this.foreground,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fg =
        foreground ??
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);
    final bg =
        background ??
        (isDark ? AppColors.backgroundDark : AppColors.backgroundLight);
    final border =
        borderColor ??
        (isDark ? AppColors.dividerDark : AppColors.dividerLight);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
