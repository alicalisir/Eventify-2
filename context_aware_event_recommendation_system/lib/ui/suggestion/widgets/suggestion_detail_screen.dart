import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/error_state_widget.dart';
import '../../home/providers/context_provider.dart';
import 'metadata_row.dart';

/// Suggestion Detail Screen
class SuggestionDetailScreen extends ConsumerWidget {
  final String suggestionId;

  const SuggestionDetailScreen({super.key, required this.suggestionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionProvider);
    final theme = Theme.of(context);

    return suggestionsAsync.when(
      data: (suggestions) {
        final suggestion = suggestions.firstWhere(
          (s) => s.id == suggestionId,
          orElse: () => suggestions.first,
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(
                        Icons.map_outlined,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                  tooltip: 'Go back',
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.title,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Metadata rows
                      Column(
                        children: [
                          MetadataRow(
                            icon: Icons.category,
                            label: 'Category',
                            value: suggestion.category,
                          ),
                          if (suggestion.distance != null)
                            MetadataRow(
                              icon: Icons.location_on,
                              label: 'Distance',
                              value: '${suggestion.distance!.toStringAsFixed(1)} km',
                            ),
                          if (suggestion.estimatedMinutes != null)
                            MetadataRow(
                              icon: Icons.access_time,
                              label: 'Duration',
                              value: '${suggestion.estimatedMinutes} mins',
                            ),
                          if (suggestion.address != null)
                            MetadataRow(
                              icon: Icons.place,
                              label: 'Address',
                              value: suggestion.address!,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        suggestion.description,
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      // AI Rationale
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.borderRadius),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.psychology,
                                  size: AppSpacing.iconSizeSm,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  AppStrings.whyThisSuggestion,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: AppColors.accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              suggestion.rationale,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      if (suggestion.address != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                suggestion.address!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      // Tags
                      if (suggestion.tags.isNotEmpty)
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: suggestion.tags
                              .map((tag) => Chip(
                                    label: Text(tag),
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHighest,
                                  ))
                              .toList(),
                        ),
                      const SizedBox(height: 120), // Space for bottom buttons
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppButton(
                    text: AppStrings.acceptAndGo,
                    icon: Icons.directions,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Opening navigation...'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    text: AppStrings.dismiss,
                    isOutlined: true,
                    onPressed: () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, stack) => Scaffold(
        body: ErrorStateWidget.error(
          onRetry: () => ref.invalidate(suggestionProvider),
        ),
      ),
    );
  }
}
