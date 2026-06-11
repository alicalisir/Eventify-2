import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../../domain/models/suggestion_model.dart';
import '../../core/ui/app_pressable.dart';
import '../../suggestion/widgets/map_hero.dart';
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedbackServiceProvider).logAction(
        suggestionId: widget.suggestion.id,
        action: 'view',
        suggestion: widget.suggestion,
      );
    });
  }

  void _handleLike() {
    ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestion.id,
      action: 'like',
      suggestion: widget.suggestion,
    );
    ref.read(likedSuggestionsProvider.notifier).like(widget.suggestion.id);
  }

  void _handleDislike() {
    ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestion.id,
      action: 'dislike',
      suggestion: widget.suggestion,
    );
    ref.read(dislikedSuggestionsProvider.notifier).dislike(widget.suggestion.id);
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
    final s = widget.suggestion;
    final hue = s.category.categoryHue;
    final hasCoords = s.latitude != null && s.longitude != null;

    return AppPressable(
      semanticLabel: 'Open suggestion: ${s.title}',
      onTap: widget.onTap,
      child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
            border: Border.all(
              color: widget.priority
                  ? AppColors.accent.withValues(alpha: 0.30)
                  : theme.dividerColor.withValues(alpha: 0.60),
              width: widget.priority ? 1.5 : 1.0,
            ),
            boxShadow: widget.priority
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.14),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero ─────────────────────────────────────────────────
                Stack(
                  children: [
                    if (hasCoords)
                      StaticMapThumbnail(suggestion: s, height: 162)
                    else
                      _HeroGradient(suggestion: s, priority: widget.priority),
                    // Floating badges over hero
                    Positioned(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      bottom: AppSpacing.sm,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _FloatingCategoryBadge(
                            category: s.category,
                            hue: hue,
                          ),
                          if (widget.priority) const _FloatingTopPickBadge(),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Body ──────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xs,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        s.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _AiRationaleBand(rationale: s.rationale),
                      if (s.tags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        RationaleChipRow(signals: s.tags),
                      ],
                    ],
                  ),
                ),

                // ── Action bar ────────────────────────────────────────────
                _ActionBar(
                  distance: s.distance,
                  estimatedMinutes: s.estimatedMinutes,
                  onLike: _handleLike,
                  onDislike: _handleDislike,
                  onDismiss: _handleDismiss,
                ),
              ],
            ),
          ),
        ),
      );
  }
}

// ─── Hero gradient banner ─────────────────────────────────────────────────────

class _HeroGradient extends StatelessWidget {
  final SuggestionModel suggestion;
  final bool priority;

  const _HeroGradient({required this.suggestion, required this.priority});

  @override
  Widget build(BuildContext context) {
    final hue = suggestion.category.categoryHue;
    final topLeft = HSLColor.fromAHSL(1, hue, 0.52, 0.72).toColor();
    final bottomRight =
        HSLColor.fromAHSL(1, (hue + 35) % 360, 0.60, 0.56).toColor();

    return Container(
      height: 162,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [topLeft, bottomRight],
        ),
      ),
      child: Stack(
        children: [
          // Background circles
          Positioned(
            right: -50,
            bottom: -50,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Centered icon
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Icon(
                suggestion.category.categoryIcon,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating category badge (over hero) ────────────────────────────────────

class _FloatingCategoryBadge extends StatelessWidget {
  final String category;
  final double hue;

  const _FloatingCategoryBadge({required this.category, required this.hue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.categoryIcon,
            size: 11,
            color: Colors.white.withValues(alpha: 0.90),
          ),
          const SizedBox(width: 5),
          Text(
            category.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Floating "TOP PICK" badge ────────────────────────────────────────────────

class _FloatingTopPickBadge extends StatelessWidget {
  const _FloatingTopPickBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.accent),
          SizedBox(width: 4),
          Text(
            'TOP PICK',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI rationale band ───────────────────────────────────────────────────────

class _AiRationaleBand extends StatelessWidget {
  final String rationale;

  const _AiRationaleBand({required this.rationale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.accent50,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 13,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              rationale,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.accent,
                height: 1.5,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action bar ──────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final double? distance;
  final int? estimatedMinutes;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onDismiss;

  const _ActionBar({
    required this.distance,
    required this.estimatedMinutes,
    required this.onLike,
    required this.onDislike,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.50),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              // Meta chip
              if (distance != null || estimatedMinutes != null)
                _MetaInfo(
                  distance: distance,
                  estimatedMinutes: estimatedMinutes,
                  color: muted,
                ),
              const Spacer(),
              // Pass button
              _GhostActionBtn(
                icon: Icons.close_rounded,
                label: 'Pass',
                color: muted,
                onTap: onDismiss,
              ),
              const SizedBox(width: 6),
              // Dislike button
              _GhostActionBtn(
                icon: Icons.thumb_down_outlined,
                label: 'Nope',
                color: AppColors.error.withValues(alpha: 0.85),
                onTap: onDislike,
              ),
              const SizedBox(width: 8),
              // Save (like) button — primary filled pill
              _SaveBtn(onTap: onLike),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaInfo extends StatelessWidget {
  final double? distance;
  final int? estimatedMinutes;
  final Color color;

  const _MetaInfo({
    required this.distance,
    required this.estimatedMinutes,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final parts = [
      if (distance != null) '${distance!.toStringAsFixed(1)} km',
      if (estimatedMinutes != null) '$estimatedMinutes min',
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.place_outlined, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          parts.join(' · '),
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _GhostActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GhostActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveBtn extends StatelessWidget {
  final VoidCallback onTap;

  const _SaveBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        splashColor: Colors.white.withValues(alpha: 0.20),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, size: 14, color: Colors.white),
              SizedBox(width: 5),
              Text(
                'Save',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
