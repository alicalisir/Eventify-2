import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/onboarding_provider.dart';
import '../../core/ui/app_button.dart';

enum PermissionType { location, notifications }

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;
  final PermissionType? permissionType;

  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
    this.permissionType,
  });
}

/// Onboarding Screen
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();

  final _pages = const [
    OnboardingPageData(
      icon: Icons.psychology,
      title: AppStrings.onboardingTitle1,
      description: AppStrings.onboardingDesc1,
      permissionType: null,
    ),
    OnboardingPageData(
      icon: Icons.location_on_outlined,
      title: AppStrings.onboardingTitle2,
      description: AppStrings.onboardingDesc2,
      permissionType: PermissionType.location,
    ),
    OnboardingPageData(
      icon: Icons.notifications_outlined,
      title: AppStrings.onboardingTitle3,
      description: AppStrings.onboardingDesc3,
      permissionType: PermissionType.notifications,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_pageController.page!.toInt() < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    ref.read(authProvider.notifier).completeOnboarding();
    ref.read(onboardingProvider.notifier).complete();
    context.goNamed('dashboard');
  }

  void _handlePermission(PermissionType type) {
    // Simulate permission grant
    if (type == PermissionType.location) {
      ref.read(onboardingProvider.notifier).grantLocation();
    } else if (type == PermissionType.notifications) {
      ref.read(onboardingProvider.notifier).grantNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingState = ref.watch(onboardingProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text(AppStrings.skip),
                ),
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  ref.read(onboardingProvider.notifier).setPage(index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  final isPermissionGranted = page.permissionType == null ||
                      (page.permissionType == PermissionType.location &&
                          onboardingState.locationGranted) ||
                      (page.permissionType == PermissionType.notifications &&
                          onboardingState.notificationsGranted);

                  return OnboardingPage(
                    data: page,
                    isPermissionGranted: isPermissionGranted,
                    onPermissionRequest: page.permissionType != null
                        ? () => _handlePermission(page.permissionType!)
                        : null,
                  );
                },
              ),
            ),
            // Bottom controls
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin:
                            const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                        width: onboardingState.currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: onboardingState.currentPage == index
                              ? AppColors.primary
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Next/Get Started button
                  AppButton(
                    text: onboardingState.currentPage == _pages.length - 1
                        ? AppStrings.getStarted
                        : AppStrings.next,
                    onPressed: _nextPage,
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

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final bool isPermissionGranted;
  final VoidCallback? onPermissionRequest;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.isPermissionGranted,
    this.onPermissionRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            data.icon,
            size: 120,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            data.title,
            style: theme.textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.description,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          if (data.permissionType != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _PermissionButton(
              isGranted: isPermissionGranted,
              onPressed: onPermissionRequest,
            ),
          ],
        ],
      ),
    );
  }
}

class _PermissionButton extends StatelessWidget {
  final bool isGranted;
  final VoidCallback? onPressed;

  const _PermissionButton({
    required this.isGranted,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isGranted) {
      return Semantics(
        label: 'Permission granted',
        child: ElevatedButton.icon(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            disabledBackgroundColor: AppColors.success,
            disabledForegroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check),
          label: const Text('Granted'),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Allow access button',
      child: ElevatedButton(
        onPressed: onPressed,
        child: const Text(AppStrings.allowAccess),
      ),
    );
  }
}
