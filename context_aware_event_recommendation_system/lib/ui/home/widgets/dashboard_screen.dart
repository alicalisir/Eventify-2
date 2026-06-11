import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../di/providers.dart'
    show
        feedbackServiceProvider,
        locationRepositoryProvider,
        llmServiceProvider,
        weatherServiceProvider;
import '../../../utils/app_logger.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/motion/app_durations.dart';
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
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshIfMoved();
    }
  }

  Future<void> _checkAndRefreshIfMoved() async {
    final llmService = ref.read(llmServiceProvider);
    final locationRepo = ref.read(locationRepositoryProvider);
    final weatherService = ref.read(weatherServiceProvider);

    final position = await locationRepo.getCurrentPosition();
    if (position == null) return;

    final weather =
        await weatherService.getCurrentWeather(position.latitude, position.longitude);
    final weatherCondition = weather?.condition ?? 'clear';

    if (llmService.hasMoved(position.latitude, position.longitude, weatherCondition)) {
      AppLogger.i('[Dashboard] Context changed >500m or weather shifted — refreshing');
      await _refresh();
    }
  }

  Future<void> _refresh() async {
    ref.read(suggestionRepositoryProvider).invalidateCache();
    ref.read(contextRepositoryProvider).invalidateContext();
    ref.invalidate(suggestionStreamProvider);
    ref.invalidate(ambientContextProvider);
    await ref.read(suggestionStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final suggestionsAsync = ref.watch(suggestionStreamProvider);
    final visible = ref.watch(visibleSuggestionsProvider);
    final contextAsync = ref.watch(ambientContextProvider);
    final user = ref.watch(authProvider).user;

    // Auto-refresh when the user runs out of visible suggestions.
    // Guard against firing during the loading phase when visible temporarily
    // drops to [] — only trigger after suggestions have fully loaded.
    ref.listen(visibleSuggestionsProvider, (prev, next) {
      final isLoading = ref.read(suggestionStreamProvider).isLoading;
      if (!isLoading && prev != null && prev.isNotEmpty && next.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _refresh();
        });
      }
    });

    // Build suggestion slivers based on async state
    final List<Widget> suggestionSlivers;
    if (suggestionsAsync.isLoading) {
      suggestionSlivers = [
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(child: _SuggestionListShimmer()),
        ),
      ];
    } else if (suggestionsAsync.hasError) {
      suggestionSlivers = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
          sliver: SliverToBoxAdapter(
            child: ErrorStateWidget.error(
              onRetry: () => ref.invalidate(suggestionStreamProvider),
            ),
          ),
        ),
      ];
    } else if (visible.isEmpty) {
      suggestionSlivers = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          sliver: SliverToBoxAdapter(child: EmptyDashboard(onRefresh: _refresh)),
        ),
      ];
    } else {
      suggestionSlivers = [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          sliver: SliverToBoxAdapter(
            child: SectionLabel(label: 'For you, right now', count: visible.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (ctx, i) {
              final suggestion = visible[i];
              return _EntranceCard(
                key: ValueKey('entrance_${suggestion.id}'),
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Dismissible(
                    key: ValueKey(suggestion.id),
                    direction: DismissDirection.endToStart,
                    movementDuration: AppDurations.slow,
                    resizeDuration: AppDurations.slow,
                    background: const _DismissBackground(),
                    onDismissed: (_) {
                      ref
                          .read(dismissedSuggestionsProvider.notifier)
                          .dismiss(suggestion.id);
                      ref.read(feedbackServiceProvider).logAction(
                        suggestionId: suggestion.id,
                        action: 'dismiss',
                        suggestion: suggestion,
                      );
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Got it — we'll suggest fewer like that",
                            ),
                            duration: const Duration(seconds: 4),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () => ref
                                  .read(dismissedSuggestionsProvider.notifier)
                                  .undismiss(suggestion.id),
                            ),
                          ),
                        );
                    },
                    child: RecommendationCard(
                      suggestion: suggestion,
                      priority: i == 0,
                      onTap: () => context.pushNamed(
                        'suggestion',
                        pathParameters: {'id': suggestion.id},
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
          sliver: SliverToBoxAdapter(child: _SwipeHint()),
        ),
      ];
    }

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
              await _refresh();
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
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              sliver: SliverToBoxAdapter(
                child: contextAsync.when(
                  data: (ctx) => ContextHeaderCard(
                    contextState: ctx,
                    userName: user?.name.split(' ').first ?? 'there',
                  ),
                  loading: () => const _HeroShimmer(),
                  error: (_, _) => _ContextErrorCard(
                    onRetry: () => ref.invalidate(ambientContextProvider),
                  ),
                ),
              ),
            ),
            ...suggestionSlivers,
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

// ── Entrance animation ───────────────────────────────────────────────────────

class _EntranceCard extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceCard({super.key, required this.index, required this.child});

  @override
  State<_EntranceCard> createState() => _EntranceCardState();
}

class _EntranceCardState extends State<_EntranceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: AppDurations.standard,
      vsync: this,
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    final stagger = Duration(
      milliseconds: (widget.index * 80).clamp(0, 200),
    );
    if (stagger == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(stagger, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Swipe hint ───────────────────────────────────────────────────────────────

class _SwipeHint extends StatefulWidget {
  const _SwipeHint();

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  static const _prefsKey = 'swipe_hint_seen';
  AnimationController? _shakeCtrl;
  Animation<double>? _shake;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      if (prefs.getBool(_prefsKey) ?? false) return;
      _shakeCtrl = AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      );
      _shake = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 0.0, end: -5.0), weight: 1),
        TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: 5.0, end: -5.0), weight: 2),
        TweenSequenceItem(tween: Tween(begin: -5.0, end: 0.0), weight: 1),
      ]).animate(_shakeCtrl!);
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _shakeCtrl!.forward().then(
                (_) => prefs.setBool(_prefsKey, true),
              );
        }
      });
    });
  }

  @override
  void dispose() {
    _shakeCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.onSurfaceVariant;

    Widget iconWidget = ExcludeSemantics(
      child: Icon(
        Icons.swipe_left,
        size: AppSpacing.iconSizeXxs,
        color: iconColor,
      ),
    );
    if (_shake != null && !MediaQuery.disableAnimationsOf(context)) {
      iconWidget = AnimatedBuilder(
        animation: _shake!,
        builder: (_, child) => Transform.translate(
          offset: Offset(_shake!.value, 0),
          child: child,
        ),
        child: iconWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              'Swipe a card to dismiss · Pull down to refresh',
              style: theme.textTheme.labelSmall?.copyWith(color: iconColor),
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

class _ContextErrorCard extends StatelessWidget {
  final VoidCallback onRetry;

  const _ContextErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: secondary, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Context unavailable', style: theme.textTheme.titleSmall),
                Text(
                  'Could not load your current context.',
                  style: theme.textTheme.labelSmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
