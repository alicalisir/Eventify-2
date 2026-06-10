import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../di/providers.dart' show feedbackServiceProvider;
import '../../../domain/models/suggestion_category.dart' show SuggestionCategoryX;

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
          bottom: TabBar(
            tabs: const [
              Tab(icon: Icon(Icons.favorite, size: 18), text: 'Liked'),
              Tab(icon: Icon(Icons.thumb_down_outlined, size: 18), text: 'Disliked'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
          ),
        ),
        body: historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Could not load preferences.')),
          data: (history) => TabBarView(
            children: [
              _FeedbackList(
                items: history.liked,
                emptyMessage: "You haven't liked any suggestions yet.",
                icon: Icons.favorite,
                iconColor: Colors.redAccent,
              ),
              _FeedbackList(
                items: history.disliked,
                emptyMessage: "You haven't disliked any suggestions yet.",
                icon: Icons.thumb_down_outlined,
                iconColor: AppColors.error,
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
  final String emptyMessage;
  final IconData icon;
  final Color iconColor;

  const _FeedbackList({
    required this.items,
    required this.emptyMessage,
    required this.icon,
    required this.iconColor,
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
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, i) {
        final item = items[i];
        final snap = (item['suggestion_snapshot'] as Map?)?.cast<String, dynamic>() ?? {};
        final title = snap['title'] as String? ?? 'Unknown suggestion';
        final category = snap['category'] as String? ?? '';
        final createdAt = item['created_at'] as String? ?? '';

        final hue = category.categoryHue;
        final iconTint = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();

        return ListTile(
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
          trailing: Text(
            _formatDate(createdAt),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
}
