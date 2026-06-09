import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';

/// App-wide navigation drawer — gradient header with avatar + nav rows.
class HomeDrawer extends ConsumerWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final divider = theme.dividerColor;
    final initial = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()[0].toUpperCase()
        : 'U';

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gradient header
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.brandGradient,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    user?.name ?? 'Guest',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Navigation
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                children: [
                  _DrawerItem(
                    icon: Icons.home_outlined,
                    label: AppStrings.home,
                    active: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  _DrawerItem(
                    icon: Icons.person_outline,
                    label: AppStrings.profile,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.pushNamed('profile');
                    },
                  ),
                ],
              ),
            ),
            Divider(color: divider, height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _DrawerItem(
                icon: Icons.logout,
                label: AppStrings.logOut,
                color: AppColors.error,
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await ref.read(authProvider.notifier).signOut();
                  } catch (_) {
                    if (context.mounted) {
                      AppSnackbar.show(
                        context,
                        message: 'Sign out failed. Please try again.',
                        kind: SnackKind.error,
                      );
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color? color;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg =
        color ?? (active ? AppColors.primary : theme.colorScheme.onSurface);
    return AppPressable(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        height: AppSpacing.minTouchTarget,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        color: active ? AppColors.activeItemBackground : Colors.transparent,
        child: Row(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: fg,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
