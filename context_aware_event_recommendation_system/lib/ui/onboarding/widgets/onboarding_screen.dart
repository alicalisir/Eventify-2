import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../../di/providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/motion/app_curves.dart';
import '../../core/motion/app_durations.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_snackbar.dart';
import '../../core/ui/brand_mark.dart';
import '../providers/onboarding_provider.dart';

// ---------------------------------------------------------------------------
// Slide blueprint (slides 0-2)
// ---------------------------------------------------------------------------

class _Slide {
  final IconData icon;
  final double hue;
  final String title;
  final String description;
  final String ctaLabel;
  final _Permission? permission;

  const _Slide({
    required this.icon,
    required this.hue,
    required this.title,
    required this.description,
    required this.ctaLabel,
    this.permission,
  });
}

enum _Permission { location, notifications }

const _slides = <_Slide>[
  _Slide(
    icon: Icons.auto_awesome,
    hue: 270,
    title: 'AI that understands\nyour context',
    description:
        'Our intelligent system learns from your daily patterns to suggest exactly what you need, exactly when you need it.',
    ctaLabel: AppStrings.next,
  ),
  _Slide(
    icon: Icons.location_on_outlined,
    hue: 200,
    title: 'Location-aware\nsuggestions',
    description:
        'We use your location to suggest nearby walks, cafés, and places that match your current context.',
    ctaLabel: 'Allow Location',
    permission: _Permission.location,
  ),
  _Slide(
    icon: Icons.notifications_outlined,
    hue: 150,
    title: 'Timely\ninterventions',
    description:
        'Allow notifications so we can proactively suggest activities when the moment is right — never spammy.',
    ctaLabel: 'Allow Notifications',
    permission: _Permission.notifications,
  ),
];

// Page indices for new steps
const _interestsPageIndex = 3;
const _consentPageIndex = 4;
const _totalPages = 5;

// ---------------------------------------------------------------------------
// Interest categories
// ---------------------------------------------------------------------------

const _interestCategories = [
  (label: 'Sports & Activity', icon: Icons.directions_run),
  (label: 'Food & Drink', icon: Icons.restaurant),
  (label: 'Arts & Culture', icon: Icons.palette),
  (label: 'Nature & Outdoors', icon: Icons.park),
  (label: 'Entertainment & Nightlife', icon: Icons.nightlife),
  (label: 'Education & Workshops', icon: Icons.school),
  (label: 'Music & Concerts', icon: Icons.music_note),
  (label: 'Family & Kids', icon: Icons.family_restroom),
  (label: 'Calm & Solo', icon: Icons.self_improvement),
];

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  // Collected from new steps
  Set<String> _interests = {};
  bool _consentGiven = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _granted(OnboardingState s, _Permission? p) {
    if (p == null) return false;
    return p == _Permission.location
        ? s.locationGranted
        : s.notificationsGranted;
  }

  Future<void> _completeAndGo() async {
    final user = ref.read(authProvider).user;
    if (user != null) {
      try {
        await ref.read(authServiceProvider).updateInterestsAndConsent(
          userId: user.id,
          interests: _interests.toList(),
          consentAt: _consentGiven ? DateTime.now() : null,
        );
      } catch (_) {
        // non-blocking — don't prevent onboarding completion
      }
    }
    await ref.read(authProvider.notifier).completeOnboarding();
    ref.read(onboardingProvider.notifier).complete();
    if (!mounted) return;
    context.goNamed('dashboard');
  }

  void _advance() {
    if (_page < _totalPages - 1) {
      final noMotion = MediaQuery.disableAnimationsOf(context);
      if (noMotion) {
        _pageController.jumpToPage(_page + 1);
      } else {
        _pageController.animateToPage(
          _page + 1,
          duration: AppDurations.standard,
          curve: AppCurves.decelerate,
        );
      }
    } else {
      _completeAndGo();
    }
  }

  Future<void> _handleCta(_Slide slide) async {
    if (slide.permission == null) {
      _advance();
      return;
    }
    final granted = await showDialog<bool>(
      context: context,
      builder: (_) => _PermissionDialog(kind: slide.permission!),
    );
    if (!mounted) return;
    if (granted == true) {
      if (slide.permission == _Permission.location) {
        await ref.read(onboardingProvider.notifier).grantLocation();
      } else {
        await ref.read(onboardingProvider.notifier).grantNotifications();
      }
      await Future.delayed(AppDurations.slow);
      if (!mounted) return;
      _advance();
    } else {
      AppSnackbar.show(
        context,
        message: 'Permission denied — some features will be limited',
        kind: SnackKind.warning,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final isConsentPage = _page == _consentPageIndex;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header: brand + skip (hidden on consent page)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.md,
                horizontal: AppSpacing.lg,
              ),
              child: Row(
                children: [
                  const BrandMark(),
                  const Spacer(),
                  if (!isConsentPage)
                    TextButton(
                      onPressed: _completeAndGo,
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                      ),
                      child: const Text(AppStrings.skip),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (i) {
                  setState(() => _page = i);
                  if (i < _slides.length) {
                    ref.read(onboardingProvider.notifier).setPage(i);
                  }
                },
                itemBuilder: (_, i) {
                  if (i < _slides.length) {
                    return _SlideView(slide: _slides[i]);
                  }
                  if (i == _interestsPageIndex) {
                    return _InterestsPage(
                      selected: _interests,
                      onChanged: (updated) =>
                          setState(() => _interests = updated),
                    );
                  }
                  return _ConsentPage(
                    checked: _consentGiven,
                    onChanged: (v) => setState(() => _consentGiven = v),
                  );
                },
              ),
            ),
            // Page indicators
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : AppDurations.quick,
                    curve: AppCurves.standard,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    width: active ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color:
                          active ? AppColors.primary : theme.dividerColor,
                      borderRadius: BorderRadius.circular(AppSpacing.xxs),
                    ),
                  );
                }),
              ),
            ),
            // Bottom CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: _buildCta(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCta(OnboardingState state) {
    // Interests page
    if (_page == _interestsPageIndex) {
      final enough = _interests.length >= 3;
      return Column(
        children: [
          AppButton(
            text: 'Continue',
            onPressed: enough ? _advance : null,
          ),
          if (!enough)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Select at least 3 interests (${_interests.length}/3)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      );
    }

    // Consent page
    if (_page == _consentPageIndex) {
      return AppButton(
        text: AppStrings.getStarted,
        onPressed: _consentGiven ? _completeAndGo : null,
      );
    }

    // Original slides 0-2
    final slide = _slides[_page];
    final granted = _granted(state, slide.permission);
    if (granted) {
      return AppButton(
        text: 'Permission Granted',
        leadingIcon: Icons.check,
        backgroundColor: AppColors.success,
        onPressed: _advance,
      );
    }
    return Column(
      children: [
        AppButton(
          text: _page == _slides.length - 1 ? AppStrings.next : slide.ctaLabel,
          onPressed: () => _handleCta(slide),
        ),
        if (_page > 0)
          TextButton(
            onPressed: _advance,
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            child: const Text('Not now'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Interests page
// ---------------------------------------------------------------------------

class _InterestsPage extends StatelessWidget {
  const _InterestsPage({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you\ninto?',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Pick at least 3 interests — used to personalise your recommendations.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _interestCategories.map((cat) {
              final isSelected = selected.contains(cat.label);
              return FilterChip(
                avatar: Icon(
                  cat.icon,
                  size: 18,
                  color: isSelected
                      ? theme.colorScheme.onSecondaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                label: Text(cat.label),
                selected: isSelected,
                onSelected: (v) {
                  final next = Set<String>.from(selected);
                  if (v) {
                    next.add(cat.label);
                  } else {
                    next.remove(cat.label);
                  }
                  onChanged(next);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Consent page
// ---------------------------------------------------------------------------

class _ConsentPage extends StatelessWidget {
  const _ConsentPage({
    required this.checked,
    required this.onChanged,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.privacy_tip_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Your data,\nyour control',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'We need your consent to process personal data for personalised recommendations.',
            style: theme.textTheme.bodyLarge?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InfoTile(
            icon: Icons.location_on_outlined,
            title: 'Location data',
            body: 'Used to suggest nearby events and places. '
                'Stored at 3 decimal precision (~110 m accuracy).',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoTile(
            icon: Icons.cloud_outlined,
            title: 'On-device AI',
            body: 'The AI model runs on our own GPU server — '
                'your data is never shared with third-party AI providers.',
          ),
          const SizedBox(height: AppSpacing.sm),
          const _InfoTile(
            icon: Icons.delete_outline,
            title: 'Delete your data',
            body: 'You can permanently delete all your data at any '
                'time from the profile screen.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusSm),
            ),
            child: CheckboxListTile(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                'I consent to my personal data being processed '
                'for the purposes described above.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Consent is required to continue. You can withdraw it '
            'at any time from the profile screen.',
            style: theme.textTheme.labelSmall?.copyWith(color: secondaryText),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                body,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Existing widgets (unchanged)
// ---------------------------------------------------------------------------

class _SlideView extends StatelessWidget {
  final _Slide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final hueColor = HSLColor.fromAHSL(1, slide.hue, 0.6, 0.55).toColor();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _IllustrationTile(icon: slide.icon, hue: slide.hue),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: secondaryText),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            container: true,
            child: SizedBox(
              width: 1,
              height: 1,
              child: ColoredBox(color: hueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _IllustrationTile extends StatelessWidget {
  final IconData icon;
  final double hue;

  const _IllustrationTile({required this.icon, required this.hue});

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.85).toColor();
    final accent = HSLColor.fromAHSL(1, (hue + 30) % 360, 0.55, 0.78).toColor();
    final iconColor = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, accent],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _StripePainter())),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(AppSpacing.xl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    const step = 19.0;
    final diag = size.width + size.height;
    for (var x = -size.height; x < diag; x += step) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => false;
}

class _PermissionDialog extends StatelessWidget {
  final _Permission kind;

  const _PermissionDialog({required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final divider = theme.dividerColor;

    final (title, body) = switch (kind) {
      _Permission.location => (
        '${AppStrings.appName} Would Like to Use Your Location',
        'Used to suggest nearby walks, places to recharge, and route-aware tips. Never sold or shared.',
      ),
      _Permission.notifications => (
        '${AppStrings.appName} Would Like to Send Notifications',
        'Only proactive, context-rich nudges — typically 2–4 per day. You can mute anytime.',
      ),
    };

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusXl),
      ),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: divider, height: 1),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text("Don't Allow"),
                    ),
                  ),
                  VerticalDivider(width: 1, color: divider),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle:
                            const TextStyle(fontWeight: FontWeight.w600),
                        shape: const RoundedRectangleBorder(),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Allow'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
