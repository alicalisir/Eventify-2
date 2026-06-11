import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart' show SuggestionCategoryX;
import '../../../domain/models/suggestion_model.dart';
import '../../home/providers/context_provider.dart';

// Bug 2 fix: use ref.watch (not ref.read) so the provider tracks dependencies properly.
final _feedbackHistoryProvider = FutureProvider.autoDispose(
  (ref) => ref.watch(feedbackServiceProvider).loadFeedbackHistory(),
);

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_feedbackHistoryProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'My Preferences',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              color: theme.colorScheme.surface,
              child: TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.pill),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Liked'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.thumb_down_rounded, size: 16),
                        SizedBox(width: 6),
                        Text('Disliked'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: historyAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Could not load preferences.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          data: (history) => TabBarView(
            children: [
              _FeedbackList(
                items: history.liked,
                currentAction: 'like',
                emptyMessage: "You haven't liked any suggestions yet.",
                emptyIcon: Icons.favorite_border_rounded,
                emptyColor: Colors.redAccent,
                onChanged: () => ref.invalidate(_feedbackHistoryProvider),
              ),
              _FeedbackList(
                items: history.disliked,
                currentAction: 'dislike',
                emptyMessage: "You haven't disliked any suggestions yet.",
                emptyIcon: Icons.thumb_down_outlined,
                emptyColor: AppColors.error,
                onChanged: () => ref.invalidate(_feedbackHistoryProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Feedback list ────────────────────────────────────────────────────────────

class _FeedbackList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String currentAction;
  final String emptyMessage;
  final IconData emptyIcon;
  final Color emptyColor;
  final VoidCallback onChanged;

  const _FeedbackList({
    required this.items,
    required this.currentAction,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.emptyColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: emptyColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 36,
                  color: emptyColor.withValues(alpha: 0.50),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                emptyMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final snap =
            (item['suggestion_snapshot'] as Map?)?.cast<String, dynamic>() ??
                {};
        final title = snap['title'] as String? ?? 'Unknown suggestion';
        final category = snap['category'] as String? ?? '';
        final createdAt = item['created_at'] as String? ?? '';
        final suggestionId = item['suggestion_id'] as String? ?? '';
        final isLiked = currentAction == 'like';

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _FeedbackCard(
            suggestionId: suggestionId,
            title: title,
            category: category,
            createdAt: createdAt,
            snap: snap,
            isLiked: isLiked,
            currentAction: currentAction,
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}

// ─── Individual feedback card ─────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final String suggestionId;
  final String title;
  final String category;
  final String createdAt;
  final Map<String, dynamic> snap;
  final bool isLiked;
  final String currentAction;
  final VoidCallback onChanged;

  const _FeedbackCard({
    required this.suggestionId,
    required this.title,
    required this.category,
    required this.createdAt,
    required this.snap,
    required this.isLiked,
    required this.currentAction,
    required this.onChanged,
  });

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hue = category.categoryHue;
    final iconBg = HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor();
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
    final actionColor = isLiked ? Colors.redAccent : AppColors.error;
    final actionIcon =
        isLiked ? Icons.favorite_rounded : Icons.thumb_down_rounded;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
      child: InkWell(
        onTap: () => _showPreferenceSheet(context),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.60),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(category.categoryIcon, size: 22, color: iconTint),
              ),
              const SizedBox(width: AppSpacing.md),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (category.isNotEmpty) ...[
                          Text(
                            category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            ' · ',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        Text(
                          _formatDate(createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Action badge + chevron
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(actionIcon, size: 15, color: actionColor),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.50),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPreferenceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PreferenceSheet(
        suggestionId: suggestionId,
        title: title,
        category: category,
        snap: snap,
        currentAction: currentAction,
        onChanged: onChanged,
      ),
    );
  }
}

// ─── Preference bottom sheet ──────────────────────────────────────────────────
// Bug 3 fix: ConsumerStatefulWidget with proper mounted check and direct invalidation.

class _PreferenceSheet extends ConsumerStatefulWidget {
  final String suggestionId;
  final String title;
  final String category;
  final Map<String, dynamic> snap;
  final String currentAction;
  final VoidCallback onChanged;

  const _PreferenceSheet({
    required this.suggestionId,
    required this.title,
    required this.category,
    required this.snap,
    required this.currentAction,
    required this.onChanged,
  });

  @override
  ConsumerState<_PreferenceSheet> createState() => _PreferenceSheetState();
}

class _PreferenceSheetState extends ConsumerState<_PreferenceSheet> {
  bool _loading = false;

  SuggestionModel _buildStub() => SuggestionModel(
        id: widget.suggestionId,
        title: widget.snap['title'] as String? ?? widget.title,
        description: '',
        rationale: widget.snap['rationale'] as String? ?? '',
        category: widget.category,
        tags: [],
        signals: [],
        createdAt: DateTime.now(),
      );

  Future<void> _setLike() async {
    if (_loading) return;
    setState(() => _loading = true);
    await ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestionId,
      action: 'like',
      suggestion: _buildStub(),
    );
    if (!mounted) return;
    // Update in-memory notifiers so home screen reflects change immediately
    ref.read(dislikedSuggestionsProvider.notifier).undislike(widget.suggestionId);
    ref.read(likedSuggestionsProvider.notifier).like(widget.suggestionId);
    // Bug 3 fix: invalidate BEFORE pop so provider rebuilds while still mounted
    ref.invalidate(_feedbackHistoryProvider);
    Navigator.of(context).pop();
    widget.onChanged();
  }

  Future<void> _setDislike() async {
    if (_loading) return;
    setState(() => _loading = true);
    await ref.read(feedbackServiceProvider).logAction(
      suggestionId: widget.suggestionId,
      action: 'dislike',
      suggestion: _buildStub(),
    );
    if (!mounted) return;
    ref.read(dislikedSuggestionsProvider.notifier).dislike(widget.suggestionId);
    ref.read(likedSuggestionsProvider.notifier).unlike(widget.suggestionId);
    ref.invalidate(_feedbackHistoryProvider);
    Navigator.of(context).pop();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hue = widget.category.categoryHue;
    final iconBg = HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor();
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.42).toColor();
    final isLiked = widget.currentAction == 'like';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Suggestion header row
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.category.categoryIcon,
                      size: 26,
                      color: iconTint,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.category,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: AppSpacing.md),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Update preference',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _OptionButton(
                      icon: Icons.favorite_rounded,
                      label: 'Like',
                      color: Colors.redAccent,
                      selected: isLiked,
                      loading: _loading,
                      onTap: isLiked ? null : _setLike,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _OptionButton(
                      icon: Icons.thumb_down_rounded,
                      label: 'Dislike',
                      color: AppColors.error,
                      selected: !isLiked,
                      loading: _loading,
                      onTap: !isLiked ? null : _setDislike,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Remove from history (no-op — history is read-only from DB)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    'Remove from history',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.borderRadius,
                      ),
                      side: BorderSide(
                        color: theme.dividerColor,
                      ),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Option button (Like / Dislike toggle) ────────────────────────────────────

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? color.withValues(alpha: 0.10) : Colors.transparent;
    final borderColor = selected
        ? color.withValues(alpha: 0.45)
        : theme.dividerColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1.0),
      ),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: selected
                    ? color
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? color
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.pill),
                  ),
                  child: Text(
                    'current',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
