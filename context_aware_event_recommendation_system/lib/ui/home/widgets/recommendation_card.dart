import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../di/providers.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../../domain/models/suggestion_model.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/tag.dart';
import '../providers/context_provider.dart';
import 'rationale_chip_row.dart';

class RecommendationCard extends ConsumerStatefulWidget {
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
  ConsumerState<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends ConsumerState<RecommendationCard> {
  bool _liked = false;

  void _handleLike() {
    final next = !_liked;
    setState(() => _liked = next);
    ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestion.id,
      action: next ? 'like' : 'dislike',
      suggestion: widget.suggestion,
    );
  }

  void _handleDismiss() {
    ref.read(dismissedSuggestionsProvider.notifier).dismiss(widget.suggestion.id);
    ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestion.id,
      action: 'dismiss',
      suggestion: widget.suggestion,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final divider = theme.dividerColor;
    final hue = widget.suggestion.category.categoryHue;
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.85).toColor();
    final accent = HSLColor.fromAHSL(1, (hue + 25) % 360, 0.55, 0.78).toColor();
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();
    final categoryTint = HSLColor.fromAHSL(1, hue, 0.65, 0.45).toColor();

    return AppPressable(
      semanticLabel: 'Open suggestion: ${widget.suggestion.title}',
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          border: Border.all(
            color: widget.priority ? AppColors.featuredCardBorder : divider,
          ),
          boxShadow: widget.priority
              ? [
                  BoxShadow(
                    color: AppColors.featuredCardShadow,
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
                height: AppSpacing.cardHeroHeight,
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
                        widget.suggestion.category.toUpperCase(),
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
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusXl,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.10),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.suggestion.category.categoryIcon,
                        size: 28,
                        color: iconTint,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.suggestion.title,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.suggestion.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // AI rationale band
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.intelligenceBand,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadiusSm,
                        ),
                        border: const Border(
                          left: BorderSide(color: AppColors.accent, width: 3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 14,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              widget.suggestion.rationale,
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
                    // Rationale signals
                    if (widget.suggestion.tags.isNotEmpty) ...[
                      RationaleChipRow(signals: widget.suggestion.tags),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    // Distance / duration meta tags
                    if (widget.suggestion.distance != null ||
                        widget.suggestion.estimatedMinutes != null)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (widget.suggestion.distance != null)
                            Tag(
                              icon: Icons.place,
                              label:
                                  '${widget.suggestion.distance!.toStringAsFixed(1)} km',
                            ),
                          if (widget.suggestion.estimatedMinutes != null)
                            Tag(
                              icon: Icons.schedule,
                              label: '${widget.suggestion.estimatedMinutes} min',
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              // Action bar
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.xs,
                  AppSpacing.xs,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        _liked ? Icons.favorite : Icons.favorite_border,
                        color: _liked
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _liked ? 'Liked' : 'Like',
                      iconSize: 20,
                      onPressed: _handleLike,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Dismiss',
                      iconSize: 20,
                      onPressed: _handleDismiss,
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
