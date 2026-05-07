import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import 'app_button.dart';

/// Widget for displaying error states
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.icon = Icons.error_outline,
  });

  factory ErrorStateWidget.error({VoidCallback? onRetry}) {
    return ErrorStateWidget(
      title: 'Error',
      message: 'Something went wrong. Please try again.',
      onRetry: onRetry,
      icon: Icons.error_outline,
    );
  }

  factory ErrorStateWidget.empty() {
    return const ErrorStateWidget(
      title: 'No Results',
      message: 'No suggestions available at the moment.',
      icon: Icons.search_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textSecondaryLight),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppButton(text: 'Try Again', onPressed: onRetry!),
            ],
          ],
        ),
      ),
    );
  }
}
