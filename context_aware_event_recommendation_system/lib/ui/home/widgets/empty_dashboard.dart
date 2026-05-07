import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/app_button.dart';

/// Empty / "all caught up" dashboard state.
class EmptyDashboard extends StatelessWidget {
  final VoidCallback? onRefresh;

  const EmptyDashboard({super.key, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.12),
                ],
              ),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 64,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.allCaughtUp,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              AppStrings.enjoyActivity,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: 'Refresh context',
            leadingIcon: Icons.refresh,
            isOutlined: true,
            fullWidth: false,
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}
