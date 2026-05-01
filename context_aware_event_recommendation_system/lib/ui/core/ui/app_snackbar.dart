import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';

/// Snackbar kind — drives background color + leading icon.
enum SnackKind { info, success, error, warning }

/// Theme-aware snackbar helper. Mirrors the Snackbar component
/// from the Calm Intelligence design system: floating, rounded,
/// gradient/colored background, leading semantic icon.
abstract final class AppSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    SnackKind kind = SnackKind.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = _palette(kind, scheme);

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          backgroundColor: palette.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
          ),
          content: Row(
            children: [
              Icon(palette.icon, size: 18, color: Colors.white),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static _Palette _palette(SnackKind kind, ColorScheme scheme) {
    switch (kind) {
      case SnackKind.success:
        return const _Palette(AppColors.success, Icons.check_rounded);
      case SnackKind.error:
        return const _Palette(AppColors.error, Icons.close_rounded);
      case SnackKind.warning:
        return const _Palette(AppColors.warning, Icons.warning_amber_rounded);
      case SnackKind.info:
        return _Palette(scheme.onSurface, Icons.auto_awesome);
    }
  }
}

class _Palette {
  final Color background;
  final IconData icon;
  const _Palette(this.background, this.icon);
}
