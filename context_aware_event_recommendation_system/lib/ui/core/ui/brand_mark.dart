import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';

/// Brand identity mark — gradient logo tile + product wordmark.
/// Used on Login, Onboarding, Drawer header.
class BrandMark extends StatelessWidget {
  final double tileSize;
  final double iconSize;
  final bool showLabel;
  final Color? labelColor;

  const BrandMark({
    super.key,
    this.tileSize = 44,
    this.iconSize = 22,
    this.showLabel = true,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'ContextAI logo',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.brandGradient,
              ),
              borderRadius: BorderRadius.circular(tileSize * 0.32),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandLogoHalo,
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome,
              size: iconSize,
              color: Colors.white,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              'ContextAI',
              style: theme.textTheme.titleLarge?.copyWith(
                color: labelColor,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
