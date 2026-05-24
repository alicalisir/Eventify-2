import 'package:flutter/material.dart';

import '../../../config/constants/app_spacing.dart';

class RationaleChipRow extends StatelessWidget {
  const RationaleChipRow({super.key, required this.signals});

  final List<String> signals;

  @override
  Widget build(BuildContext context) {
    if (signals.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final color = theme.colorScheme.secondaryContainer;
    final labelColor = theme.colorScheme.onSecondaryContainer;

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: signals.map((signal) {
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppSpacing.pill),
          ),
          child: Text(
            signal,
            style: theme.textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    );
  }
}
