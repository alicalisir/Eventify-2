import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart' show SuggestionCategoryX;
import '../../../domain/models/suggestion_model.dart';
import '../../home/providers/context_provider.dart';

final _feedbackHistoryProvider = FutureProvider.autoDispose(
  (ref) => ref.read(feedbackServiceProvider).loadFeedbackHistory(),
);

class PreferencesScreen extends ConsumerWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_feedbackHistoryProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Preferences'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.favorite, size: 18), text: 'Liked'),
              Tab(icon: Icon(Icons.thumb_down_outlined, size: 18), text: 'Disliked'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
          ),
        ),
        body: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text('Could not load preferences.')),
          data: (history) => TabBarView(
            children: [
              _FeedbackList(
                items: history.liked,
                currentAction: 'like',
                emptyMessage: "You haven't liked any suggestions yet.",
                icon: Icons.favorite,
                iconColor: Colors.redAccent,
                onChanged: () => ref.invalidate(_feedbackHistoryProvider),
              ),
              _FeedbackList(
                items: history.disliked,
                currentAction: 'dislike',
                emptyMessage: "You haven't disliked any suggestions yet.",
                icon: Icons.thumb_down_outlined,
                iconColor: AppColors.error,
                onChanged: () => ref.invalidate(_feedbackHistoryProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final String currentAction;
  final String emptyMessage;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onChanged;

  const _FeedbackList({
    required this.items,
    required this.currentAction,
    required this.emptyMessage,
    required this.icon,
    required this.iconColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.md),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, i) {
        final item = items[i];
        final snap = (item['suggestion_snapshot'] as Map?)?.cast<String, dynamic>() ?? {};
        final title = snap['title'] as String? ?? 'Unknown suggestion';
        final category = snap['category'] as String? ?? '';
        final createdAt = item['created_at'] as String? ?? '';
        final suggestionId = item['suggestion_id'] as String? ?? '';

        final hue = category.categoryHue;
        final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();

        return ListTile(
          onTap: () => _showPreferenceSheet(
            context,
            suggestionId: suggestionId,
            title: title,
            category: category,
            snap: snap,
            currentAction: currentAction,
            onChanged: onChanged,
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor(),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.categoryIcon, size: 20, color: iconTint),
          ),
          title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
          subtitle: category.isNotEmpty
              ? Text(
                  category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatDate(createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  void _showPreferenceSheet(
    BuildContext context, {
    required String suggestionId,
    required String title,
    required String category,
    required Map<String, dynamic> snap,
    required String currentAction,
    required VoidCallback onChanged,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PreferenceSheet(
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

class _PreferenceSheet extends ConsumerWidget {
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

  SuggestionModel _buildStub() => SuggestionModel(
        id: suggestionId,
        title: snap['title'] as String? ?? title,
        description: '',
        rationale: snap['rationale'] as String? ?? '',
        category: category,
        tags: [],
        signals: [],
        createdAt: DateTime.now(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hue = category.categoryHue;
    final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();
    final iconBg = HSLColor.fromAHSL(1, hue, 0.55, 0.92).toColor();
    final isLiked = currentAction == 'like';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Suggestion header
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(category.categoryIcon, size: 24, color: iconTint),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.isNotEmpty)
                        Text(
                          category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Change your preference',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _SheetButton(
                    icon: Icons.favorite_rounded,
                    label: 'Like',
                    color: Colors.redAccent,
                    selected: isLiked,
                    onTap: () async {
                      if (!isLiked) {
                        await ref.read(feedbackServiceProvider).logAction(
                          suggestionId: suggestionId,
                          action: 'like',
                          suggestion: _buildStub(),
                        );
                        ref.read(dislikedSuggestionsProvider.notifier).undislike(suggestionId);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onChanged();
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SheetButton(
                    icon: Icons.thumb_down_rounded,
                    label: 'Dislike',
                    color: AppColors.error,
                    selected: !isLiked,
                    onTap: () async {
                      if (isLiked) {
                        await ref.read(feedbackServiceProvider).logAction(
                          suggestionId: suggestionId,
                          action: 'dislike',
                          suggestion: _buildStub(),
                        );
                        ref.read(dislikedSuggestionsProvider.notifier).dislike(suggestionId);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        onChanged();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Remove entirely
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remove from history'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
                  ),
                ),
                onPressed: () {
                  // Dismiss the bottom sheet — history is read-only from DB;
                  // "remove from history" just closes (no hard-delete by design).
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.4) : Theme.of(context).dividerColor,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
              if (selected) ...[
                const SizedBox(height: 2),
                Text(
                  'current',
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7),
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
