import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/app_button.dart';

/// Kind of error fallback the user is shown.
enum ErrorKind { offline, location }

/// Full-page illustrated fallback. Used for offline / location-disabled
/// states (and any other future blocking failure modes).
class ErrorScreen extends StatelessWidget {
  final ErrorKind kind;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, this.kind = ErrorKind.offline, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final copy = _copy(kind);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.goNamed('dashboard'),
        ),
        title: const Text(''),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: _IllustrationTile(icon: copy.icon, hue: copy.hue),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    copy.description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 280),
                child: Column(
                  children: [
                    AppButton(
                      text: copy.ctaLabel,
                      leadingIcon: Icons.refresh,
                      onPressed: onRetry,
                    ),
                    TextButton(
                      onPressed: () => context.goNamed('dashboard'),
                      style: TextButton.styleFrom(
                        foregroundColor: secondaryText,
                      ),
                      child: const Text('Back to dashboard'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _ErrorCopy _copy(ErrorKind kind) {
    switch (kind) {
      case ErrorKind.offline:
        return const _ErrorCopy(
          icon: Icons.power_off_outlined,
          hue: 10,
          title: AppStrings.noInternet,
          description: AppStrings.noInternetDesc,
          ctaLabel: AppStrings.tryAgain,
        );
      case ErrorKind.location:
        return const _ErrorCopy(
          icon: Icons.location_off_outlined,
          hue: 200,
          title: AppStrings.locationDisabled,
          description: AppStrings.locationDisabledDesc,
          ctaLabel: AppStrings.checkSettings,
        );
    }
  }
}

class _ErrorCopy {
  final IconData icon;
  final double hue;
  final String title;
  final String description;
  final String ctaLabel;

  const _ErrorCopy({
    required this.icon,
    required this.hue,
    required this.title,
    required this.description,
    required this.ctaLabel,
  });
}

class _IllustrationTile extends StatelessWidget {
  final IconData icon;
  final double hue;

  const _IllustrationTile({required this.icon, required this.hue});

  @override
  Widget build(BuildContext context) {
    final base = HSLColor.fromAHSL(1, hue, 0.55, 0.86).toColor();
    final accent = HSLColor.fromAHSL(1, hue + 20, 0.55, 0.78).toColor();
    final iconColor = HSLColor.fromAHSL(1, hue, 0.55, 0.50).toColor();
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base, accent],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.xl),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppSpacing.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Icon(icon, size: 40, color: iconColor),
      ),
    );
  }
}
