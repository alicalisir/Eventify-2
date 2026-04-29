import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/shimmer_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'persona_chip.dart';
import 'settings_tile.dart';

/// Profile Screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final personaAsync = ref.watch(personaProvider);
    final profileState = ref.watch(profileProvider);
    final settings = profileState.settings;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: 'Go back',
        ),
        title: const Text(AppStrings.profile),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // User header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : 'U',
                    style: theme.textTheme.displayLarge
                        ?.copyWith(color: Colors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  user?.name ?? 'User',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  user?.email ?? '',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Persona section
          Text(
            AppStrings.myPersona,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          personaAsync.when(
            data: (persona) => Semantics(
              label: 'Your persona traits: ${persona.traits.join(', ')}',
              child: Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: persona.traits
                    .map((trait) => PersonaChip(label: trait))
                    .toList(),
              ),
            ),
            loading: () => Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: List.generate(
                5,
                (_) => ShimmerLoading(width: 100, height: 32),
              ),
            ),
            error: (_, _) => const Text('Unable to load persona'),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Data controls
          Text(
            AppStrings.dataControls,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.location_on_outlined,
                  title: AppStrings.locationTracking,
                  trailing: Switch(
                    value: settings.locationTrackingEnabled,
                    onChanged: (_) {
                      ref
                          .read(profileProvider.notifier)
                          .toggleLocationTracking();
                    },
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.directions_walk_outlined,
                  title: AppStrings.activityRecognition,
                  trailing: Switch(
                    value: settings.activityRecognitionEnabled,
                    onChanged: (_) {
                      ref
                          .read(profileProvider.notifier)
                          .toggleActivityRecognition();
                    },
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: AppStrings.notifications,
                  trailing: Switch(
                    value: settings.notificationsEnabled,
                    onChanged: (_) {
                      ref
                          .read(profileProvider.notifier)
                          .toggleNotifications();
                    },
                  ),
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.pause_circle_outline,
                  title: AppStrings.pauseTracking,
                  subtitle: AppStrings.for24Hours,
                  trailing: Switch(
                    value: settings.trackingPaused,
                    onChanged: (_) {
                      ref
                          .read(profileProvider.notifier)
                          .toggleTrackingPause();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Other settings
          Card(
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: AppStrings.privacyPolicy,
                  onTap: () {
                    // TODO: Open privacy policy
                  },
                ),
                const Divider(height: 1),
                SettingsTile(
                  icon: Icons.delete_outline,
                  title: AppStrings.deleteMyData,
                  onTap: () {
                    _showDeleteDataDialog(context);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Log out button
          AppButton(
            text: AppStrings.logOut,
            isOutlined: true,
            foregroundColor: AppColors.error,
            onPressed: () {
              _showLogoutDialog(context, ref);
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
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

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteMyData),
        content: const Text(
            'This will permanently delete all your data. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data deletion requested'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
