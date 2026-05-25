import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/error_state_widget.dart';
import '../../core/ui/shimmer_loading.dart';
import '../providers/context_provider.dart';
import 'context_header_card.dart';
import 'empty_dashboard.dart';
import 'home_drawer.dart';
import 'recommendation_card.dart';
import 'section_label.dart';

/// Dashboard — context hero, today's suggestions (streamed one by one), drawer.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(suggestionRepositoryProvider).invalidateCache();
    ref.read(contextRepositoryProvider).invalidateContext();
    await ref.read(dismissedSuggestionsProvider.notifier).clear();
    ref.invalidate(suggestionStreamProvider);
    ref.invalidate(ambientContextProvider);
    // Await at least the first suggestion so the refresh indicator stays visible
    await ref.read(suggestionStreamProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // suggestionStreamProvider drives loading / error state
    final suggestionsAsync = ref.watch(suggestionStreamProvider);
    // visibleSuggestionsProvider is synchronous — no shimmer flicker on each card
    final visible = ref.watch(visibleSuggestionsProvider);
    final contextAsync = ref.watch(ambientContextProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppStrings.refreshContext,
            onPressed: () async {
              await _refresh(ref);
              if (context.mounted) {
                AppSnackbar.show(
                  context,
                  message: 'Context refreshed',
                  kind: SnackKind.success,
                );
              }
            },
          ),
        ],
      ),
      drawer: const HomeDrawer(),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: [
            // Context hero
            contextAsync.when(
              data: (ctx) => ContextHeaderCard(
                contextState: ctx,
                userName: user?.name.split(' ').first ?? 'there',
              ),
              loading: () => const _HeroShimmer(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.lg),
            // Suggestions — streamed card by card
            suggestionsAsync.when(
              // Loading: show shimmer until the first card arrives
              loading: () => const _SuggestionListShimmer(),
              // Error: show retry button
              error: (_, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: ErrorStateWidget.error(
                  onRetry: () => ref.invalidate(suggestionStreamProvider),
                ),
              ),
              // Data: render visible (filtered) list — grows as stream emits
              data: (_) {
                if (visible.isEmpty) {
                  return EmptyDashboard(onRefresh: () => _refresh(ref));
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionLabel(
                      label: 'For you, right now',
                      count: visible.length,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < visible.length; i++) ...[
                      Semantics(
                        customSemanticsActions: {
                          const CustomSemanticsAction(label: 'Dismiss'): () {
                            ref
                                .read(dismissedSuggestionsProvider.notifier)
                                .dismiss(visible[i].id);
                            AppSnackbar.show(
                              context,
                              message: "Got it — we'll suggest fewer like that",
                              kind: SnackKind.info,
                            );
                          },
                        },
                        child: Dismissible(
                          key: ValueKey(visible[i].id),
                          direction: DismissDirection.endToStart,
                          background: const _DismissBackground(),
                          onDismissed: (_) {
                            ref
                                .read(dismissedSuggestionsProvider.notifier)
                                .dismiss(visible[i].id);
                            AppSnackbar.show(
                              context,
                              message: "Got it — we'll suggest fewer like that",
                              kind: SnackKind.info,
                            );
                          },
                          child: RecommendationCard(
                            suggestion: visible[i],
                            priority: i == 0,
                            onTap: () => context.pushNamed(
                              'suggestion',
                              pathParameters: {'id': visible[i].id},
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    const _SwipeHint(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.error50,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.close, color: AppColors.error),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              'Dismiss',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.error),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.swipe_left,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              'Swipe a card to dismiss · Pull down to refresh',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroShimmer extends StatelessWidget {
  const _HeroShimmer();

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      width: double.infinity,
      height: 156,
      borderRadius: AppSpacing.borderRadiusLg,
    );
  }
}

class _SuggestionListShimmer extends StatelessWidget {
  const _SuggestionListShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Opacity(
            opacity: 1 - i * 0.2,
            child: const ShimmerLoading(
              width: double.infinity,
              height: 240,
              borderRadius: AppSpacing.borderRadiusLg,
            ),
          ),
        );
      }),
    );
  }
}
