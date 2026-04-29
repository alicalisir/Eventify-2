import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/context_state.dart';

/// Context header card for displaying user context information
class ContextHeaderCard extends StatelessWidget {
  final ContextState contextState;

  const ContextHeaderCard({
    super.key,
    required this.contextState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          side: BorderSide(
            color: AppColors.dividerLight,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contextState.greeting,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                contextState.contextDescription,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (contextState.isLocationEnabled)
                    Chip(
                      avatar: const Icon(Icons.location_on, size: 18),
                      label: const Text('Location enabled'),
                      onDeleted: () {},
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  if (contextState.isNotificationsEnabled)
                    Chip(
                      avatar: const Icon(Icons.notifications, size: 18),
                      label: const Text('Notifications on'),
                      onDeleted: () {},
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
