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

class _RecommendationCardState extends ConsumerState<RecommendationCard>
    with SingleTickerProviderStateMixin {
  bool _liked = false;
  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = Tween<double>(begin: 1, end: 1.35).animate(
      CurvedAnimation(parent: _likeCtrl, curve: Curves.elasticOut),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedbackServiceProvider).logAction(
        suggestionId: widget.suggestion.id,
        action: 'view',
        suggestion: widget.suggestion,
      );
    });
  }

  @override
  void dispose() {
    _likeCtrl.dispose();
    super.dispose();
  }

  void _handleLike() {
    final next = !_liked;
    setState(() => _liked = next);
    _likeCtrl.forward(from: 0);
    ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestion.id,
      action: next ? 'like' : 'dislike',
      suggestion: widget.suggestion,
    );
    if (!next) {
      ref.read(dislikedSuggestionsProvider.notifier).dislike(widget.suggestion.id);
    } else {
      ref.read(dislikedSuggestionsProvider.notifier).undislike(widget.suggestion.id);
    }
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
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          border: Border.all(
            color: widget.priority
                ? AppColors.featuredCardBorder
                : theme.dividerColor.withValues(alpha: 0.7),
          ),
          boxShadow: widget.priority
              ? [
                  BoxShadow(
                    color: AppColors.featuredCardShadow,
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: real map or gradient ─────────────────────────────
              if (hasCoords)
                StaticMapThumbnail(suggestion: s, height: 140)
              else
                _GradientBanner(suggestion: s, priority: widget.priority),

              // ── Body ─────────────────────────────────────────────────────
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
                    // Category badge
                    _CategoryBadge(category: s.category, hue: hue),
                    const SizedBox(height: AppSpacing.xs),
                    // Title
                    Text(
                      s.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // Description
                    Text(
                      s.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // AI rationale
                    _RationaleBand(rationale: s.rationale),
                    const SizedBox(height: AppSpacing.sm),
                    // Signal chips
                    if (s.tags.isNotEmpty) RationaleChipRow(signals: s.tags),
                  ],
                ),
              ),

              // ── Action bar ───────────────────────────────────────────────
              _ActionBar(
                liked: _liked,
                likeScale: _likeScale,
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

// ─── Gradient banner (events without coords) ─────────────────────────────────

class _GradientBanner extends StatelessWidget {
  final SuggestionModel suggestion;
  final bool priority;

  const _GradientBanner({required this.suggestion, required this.priority});

  @override
  Widget build(BuildContext context) {
    final hue = suggestion.category.categoryHue;
    final base = HSLColor.fromAHSL(1, hue, 0.52, 0.80).toColor();
    final deep = HSLColor.fromAHSL(1, (hue + 28) % 360, 0.60, 0.64).toColor();
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.40).toColor();

    return Container(
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, deep],
        ),
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 24,
            top: 12,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                suggestion.category.categoryIcon,
                size: 26,
                color: iconTint,
              ),
            ),
          ),
          if (priority)
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppSpacing.pill),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 10, color: AppColors.accent),
                    SizedBox(width: 3),
                    Text(
                      'TOP PICK',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Category badge ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  final String category;
  final double hue;

  const _CategoryBadge({required this.category, required this.hue});

  @override
  Widget build(BuildContext context) {
    final bg = HSLColor.fromAHSL(1, hue, 0.70, 0.93).toColor();
    final fg = HSLColor.fromAHSL(1, hue, 0.55, 0.38).toColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.pill),
      ),
      child: Text(
        category.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

// ─── AI rationale band ────────────────────────────────────────────────────────

class _RationaleBand extends StatelessWidget {
  final String rationale;

  const _RationaleBand({required this.rationale});

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
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(Icons.auto_awesome, size: 12, color: AppColors.accent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              rationale,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.accent,
                height: 1.5,
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

// ─── Action bar ───────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  final bool liked;
  final Animation<double> likeScale;
  final double? distance;
  final int? estimatedMinutes;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback onDismiss;

  const _ActionBar({
    required this.liked,
    required this.likeScale,
    required this.distance,
    required this.estimatedMinutes,
    required this.onLike,
    required this.onDislike,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.xs, AppSpacing.xs),
      child: Row(
        children: [
          // Distance / time meta
          if (distance != null || estimatedMinutes != null) ...[
            Icon(Icons.place_outlined, size: 13, color: secondary),
            const SizedBox(width: 3),
            Text(
              [
                if (distance != null) '${distance!.toStringAsFixed(1)} km',
                if (estimatedMinutes != null) '$estimatedMinutes min',
              ].join(' · '),
              style: TextStyle(
                fontSize: 11,
                color: secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          // Dismiss (X) – session only
          _ActionBtn(
            icon: Icons.close_rounded,
            color: secondary,
            tooltip: 'Dismiss',
            onTap: onDismiss,
          ),
          const SizedBox(width: 2),
          // Dislike (👎) – permanent
          _ActionBtn(
            icon: Icons.thumb_down_outlined,
            color: secondary,
            tooltip: 'Not for me',
            onTap: onDislike,
          ),
          const SizedBox(width: 2),
          // Like (❤️) – toggle
          ScaleTransition(
            scale: likeScale,
            child: _ActionBtn(
              icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? Colors.redAccent : secondary,
              tooltip: liked ? 'Liked' : 'Like',
              onTap: onLike,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
