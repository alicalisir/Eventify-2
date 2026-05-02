import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../../domain/models/suggestion_model.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/tag.dart';

/// Suggestion card — hero strip + body + AI rationale band + meta tags.
/// Priority cards (the first one) get an accent halo.
class RecommendationCard extends StatelessWidget {
  final SuggestionModel suggestion;
  final VoidCallback? onTap;
  final bool priority;

  const RecommendationCard({
    super.key,
    required this.suggestion,
    this.onTap,
    this.priority = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.dividerColor;
    final hue = suggestion.category.categoryHue;
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.85).toColor();
    final accent = HSLColor.fromAHSL(1, hue + 25, 0.55, 0.78).toColor();
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();
    final categoryTint = HSLColor.fromAHSL(1, hue, 0.65, 0.45).toColor();

    return AppPressable(
      semanticLabel: 'Open suggestion: ${suggestion.title}',
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          border: Border.all(
            color: priority
                ? AppColors.accent.withValues(alpha: 0.25)
                : divider,
          ),
          boxShadow: priority
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero strip
              Container(
                height: 110,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [base, accent],
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppSpacing.pill),
                      ),
                      child: Text(
                        suggestion.category.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: categoryTint,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(suggestion.category.categoryIcon, size: 28, color: iconTint),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      suggestion.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // AI rationale band
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.accent50,
                        borderRadius: BorderRadius.circular(
                            AppSpacing.borderRadiusSm),
                        border: Border(
                          left: BorderSide(
                            color: AppColors.accent,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: AppColors.accent),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              suggestion.rationale,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.accent,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (suggestion.distance != null)
                          Tag(
                            icon: Icons.place,
                            label:
                                '${suggestion.distance!.toStringAsFixed(1)} km',
                          ),
                        if (suggestion.estimatedMinutes != null)
                          Tag(
                            icon: Icons.schedule,
                            label: '${suggestion.estimatedMinutes} min',
                          ),
                        ...suggestion.tags.take(2).map((t) => Tag(label: t)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
