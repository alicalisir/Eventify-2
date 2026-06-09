import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/error_state_widget.dart';
import '../../home/providers/context_provider.dart';
import 'map_hero.dart';
import 'meta_tile.dart';

/// Suggestion detail — sticky collapsing app bar over a faux map hero,
/// then content card with metadata, AI rationale, address, tags, and a
/// fixed bottom action bar.
class SuggestionDetailScreen extends ConsumerStatefulWidget {
  final String suggestionId;

  const SuggestionDetailScreen({super.key, required this.suggestionId});

  @override
  ConsumerState<SuggestionDetailScreen> createState() =>
      _SuggestionDetailScreenState();
}

class _SuggestionDetailScreenState
    extends ConsumerState<SuggestionDetailScreen> {
  static const _heroHeight = 240.0;
  // Bottom padding to clear the fixed action bar (button + padding + safe area).
  static const _actionBarClearance = 120.0;
  final _scrollController = ScrollController();
  bool _accepted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openDirections({
    required String? address,
    double? latitude,
    double? longitude,
  }) async {
    Uri url;
    if (latitude != null && longitude != null) {
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    } else if (address != null) {
      final encoded = Uri.encodeComponent(address);
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded',
      );
    } else {
      return;
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      AppSnackbar.show(
        context,
        message: AppStrings.couldNotOpenMaps,
        kind: SnackKind.error,
      );
    }
  }

  Future<void> _accept() async {
    setState(() => _accepted = true);
    AppSnackbar.show(
      context,
      message: AppStrings.addedToCalendar,
      kind: SnackKind.success,
    );
    await Future.delayed(const Duration(milliseconds: 1100));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final asyncSuggestions = ref.watch(suggestionStreamProvider);

    return asyncSuggestions.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(
        body: ErrorStateWidget.error(
          onRetry: () => ref.invalidate(suggestionStreamProvider),
        ),
      ),
      data: (all) {
        final suggestion = all.firstWhere(
          (s) => s.id == widget.suggestionId,
          orElse: () => all.first,
        );
        return Scaffold(
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: _heroHeight,
                backgroundColor: theme.colorScheme.surface,
                surfaceTintColor: theme.colorScheme.surface,
                leading: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: AppPressable(
                    semanticLabel: 'Back',
                    onTap: () => context.pop(),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      child: const Icon(Icons.arrow_back),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: LayoutBuilder(
                    builder: (_, constraints) {
                      final collapsed = constraints.maxHeight <= 80 + 56;
                      return AnimatedOpacity(
                        opacity: collapsed ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          suggestion.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                      );
                    },
                  ),
                  background: MapHero(suggestion: suggestion),
                ),
              ),
              SliverToBoxAdapter(
                child: Transform.translate(
                  offset: const Offset(0, -24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppSpacing.lg),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      _actionBarClearance,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(
                                2,
                              ), // ignore: no_raw_spacing_literals — drag handle indicator, half its 4 px height
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Category chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pill,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                suggestion.category.categoryIcon,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(
                                suggestion.category.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          suggestion.title,
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          suggestion.description,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Metadata row
                        Row(
                          children: [
                            if (suggestion.estimatedMinutes != null)
                              Expanded(
                                child: MetaTile(
                                  icon: Icons.schedule,
                                  label: AppStrings.estimatedTime,
                                  value: '${suggestion.estimatedMinutes} min',
                                ),
                              ),
                            if (suggestion.distance != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: MetaTile(
                                  icon: Icons.place,
                                  label: AppStrings.distance,
                                  value: '${suggestion.distance} km',
                                ),
                              ),
                            ],
                            if (suggestion.weather != null) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: MetaTile(
                                  icon: Icons.wb_sunny,
                                  label: AppStrings.weather,
                                  value: suggestion.weather!,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Why this card
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.accent50,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.borderRadiusLg,
                            ),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_awesome,
                                    size: 18,
                                    color: AppColors.accent,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Flexible(
                                    child: Text(
                                      AppStrings.whyThisSuggestion,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            color: AppColors.accent,
                                            fontSize: 15,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                suggestion.rationale,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (suggestion.signals.isNotEmpty
                                        ? suggestion.signals
                                        : const ['Time of day', 'Activity', 'Location', 'Weather'])
                                    .map((s) => _SignalPill(label: s))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        if (suggestion.address != null) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            AppStrings.location,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppPressable(
                            semanticLabel:
                                '${AppStrings.openInMaps}: ${suggestion.address}',
                            onTap: () => _openDirections(
                              address: suggestion.address,
                              latitude: suggestion.latitude,
                              longitude: suggestion.longitude,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              decoration: BoxDecoration(
                                color: theme.scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.borderRadius,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary50,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.borderRadius,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.place,
                                      size: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          suggestion.address!,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                        Text(
                                          AppStrings.tapForDirections,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: secondaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: secondaryText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (suggestion.tags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            AppStrings.tags,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: suggestion.tags
                                .map((t) => Chip(label: Text(t)))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  AppPressable(
                    semanticLabel: AppStrings.dismiss,
                    onTap: () => context.pop(),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.dividerColor,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.borderRadius,
                        ),
                      ),
                      child: Icon(Icons.close, color: secondaryText),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      text: _accepted ? 'Added!' : AppStrings.acceptAndGo,
                      leadingIcon: _accepted
                          ? Icons.check
                          : Icons.calendar_today_outlined,
                      backgroundColor: _accepted
                          ? AppColors.success
                          : AppColors.primary,
                      onPressed: _accepted ? null : _accept,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignalPill extends StatelessWidget {
  final String label;

  const _SignalPill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
