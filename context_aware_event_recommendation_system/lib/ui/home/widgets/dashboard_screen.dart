import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/error_state_widget.dart';
import '../../core/ui/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/context_provider.dart';
import 'context_header_card.dart';
import 'recommendation_card.dart';

/// Dashboard Screen
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(suggestionProvider);
    final contextAsync = ref.watch(contextProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open menu',
          ),
        ),
        title: Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(suggestionProvider);
              ref.invalidate(contextProvider);
            },
            tooltip: AppStrings.refreshContext,
          ),
        ],
      ),
      drawer: AppDrawer(userName: user?.name ?? 'User'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(suggestionProvider);
          ref.invalidate(contextProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Context header
            SliverToBoxAdapter(
              child: contextAsync.when(
                data: (context) => ContextHeaderCard(contextState: context),
                loading: () => const _ContextHeaderShimmer(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
            // Suggestions
            suggestionsAsync.when(
              data: (suggestions) {
                if (suggestions.isEmpty) {
                  return SliverFillRemaining(
                    child: ErrorStateWidget.empty(),
                  );
                }
                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final suggestion = suggestions[index];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Dismissible(
                            key: Key(suggestion.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.borderRadius),
                              ),
                              child: const Icon(
                                Icons.close,
                                color: AppColors.error,
                              ),
                            ),
                            onDismissed: (_) {
                              // TODO: Handle dismiss feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Suggestion dismissed'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: RecommendationCard(
                              suggestion: suggestion,
                              onTap: () =>
                                  context.pushNamed('suggestion', pathParameters: {
                                'id': suggestion.id,
                              }),
                            ),
                          ),
                        );
                      },
                      childCount: suggestions.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, _) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: _RecommendationCardShimmer(),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: ErrorStateWidget.error(
                  onRetry: () => ref.invalidate(suggestionProvider),
                ),
              ),
            ),
            const SliverToBoxAdapter(
                child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ref.invalidate(suggestionProvider);
          ref.invalidate(contextProvider);
        },
        tooltip: AppStrings.refreshContext,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// App Drawer
class AppDrawer extends ConsumerWidget {
  final String userName;

  const AppDrawer({super.key, required this.userName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    userName,
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            const Divider(),
            // Navigation items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    title: AppStrings.home,
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.person_outlined,
                    title: AppStrings.profile,
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed('profile');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    title: AppStrings.settings,
                    onTap: () {
                      Navigator.pop(context);
                      context.pushNamed('profile');
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            _DrawerItem(
              icon: Icons.logout,
              title: AppStrings.logOut,
              onTap: () {
                _showLogoutDialog(context, ref);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.logOut),
        content: const Text(AppStrings.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text(AppStrings.logOut),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: onTap,
        minVerticalPadding: AppSpacing.sm,
      ),
    );
  }
}

class _ContextHeaderShimmer extends StatelessWidget {
  const _ContextHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerLoading(width: 200, height: 28),
              const SizedBox(height: AppSpacing.xs),
              ShimmerLoading(width: double.infinity, height: 20),
              const SizedBox(height: AppSpacing.sm),
              ShimmerLoading(width: 100, height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationCardShimmer extends StatelessWidget {
  const _RecommendationCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(
            width: double.infinity,
            height: 140,
            borderRadius: 0,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerLoading(width: 200, height: 20),
                const SizedBox(height: AppSpacing.xs),
                ShimmerLoading(width: double.infinity, height: 16),
                const SizedBox(height: AppSpacing.xxs),
                ShimmerLoading(width: 150, height: 16),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    ShimmerLoading(width: 60, height: 24),
                    const SizedBox(width: AppSpacing.xs),
                    ShimmerLoading(width: 60, height: 24),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
