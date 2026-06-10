import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../config/constants/app_strings.dart';
import '../../auth/providers/auth_provider.dart';
import '../../core/ui/app_back_button.dart';
import '../../core/ui/app_button.dart';
import '../../core/ui/app_pressable.dart';
import '../../core/ui/app_snackbar.dart';
import '../../home/providers/context_provider.dart';
import '../providers/profile_provider.dart';
import 'persona_chip.dart';

/// Profile & settings screen — identity header, persona chips with %,
/// data-control switch rows, privacy nav rows, log-out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final personaAsync = ref.watch(personaProvider);
    final profileState = ref.watch(profileProvider);
    final settings = profileState.settings;
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final divider = theme.dividerColor;
    final notifier = ref.read(profileProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: const Text(AppStrings.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: AppStrings.editProfile,
            onPressed: () => _showEditProfileSheet(context, ref, user?.name ?? ''),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          // Identity header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: divider),
              borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: AppColors.brandGradient,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandCardShadow,
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initial(user?.name),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Guest',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.permissionGrantedBackground,
                          borderRadius: BorderRadius.circular(AppSpacing.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xxs),
                            Text(
                              AppStrings.personaActive,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Persona section
          const _SectionTitle(
            label: AppStrings.myPersona,
            hint: 'Inferred from your activity',
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: _sectionCardDecoration(theme),
            child: personaAsync.when(
              data: (persona) {
                final lastUpdated = _formatRelativeTime(persona.lastUpdated);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: persona.traits
                          .map((t) => PersonaChip(trait: t))
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Divider(color: divider, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: AppColors.accent,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Updated $lastUpdated · ${persona.signalsProcessedToday} signals processed today',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const SizedBox(
                height: AppSpacing.minTouchTarget,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                'Unable to load persona',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondaryText,
                ),
              ),
            ),
          ),

          // Data controls
          const _SectionTitle(label: AppStrings.dataControls),
          Container(
            decoration: _sectionCardDecoration(theme),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _SwitchRow(
                  icon: Icons.schedule,
                  title: AppStrings.pauseTracking,
                  subtitle: settings.trackingPaused
                      ? 'Tracking resumes in 23h 14m'
                      : AppStrings.for24Hours,
                  value: settings.trackingPaused,
                  onChanged: (_) => notifier.toggleTrackingPause(),
                ),
                _RowDivider(divider: divider),
                _SwitchRow(
                  icon: Icons.place,
                  title: AppStrings.locationTracking,
                  subtitle: 'Used for nearby suggestions',
                  value: settings.locationTrackingEnabled,
                  onChanged: (_) => notifier.toggleLocationTracking(),
                ),
                _RowDivider(divider: divider),
                _SwitchRow(
                  icon: Icons.directions_walk,
                  title: AppStrings.activityRecognition,
                  subtitle: 'Detects walking, focus, etc.',
                  value: settings.activityRecognitionEnabled,
                  onChanged: (_) => notifier.toggleActivityRecognition(),
                ),
                _RowDivider(divider: divider),
                _SwitchRow(
                  icon: Icons.notifications_outlined,
                  title: AppStrings.notifications,
                  subtitle: 'Smart, low-frequency nudges',
                  value: settings.notificationsEnabled,
                  onChanged: (_) => notifier.toggleNotifications(),
                ),
              ],
            ),
          ),

          // Privacy
          const _SectionTitle(label: AppStrings.privacy),
          Container(
            decoration: _sectionCardDecoration(theme),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavRow(
                  icon: Icons.shield_outlined,
                  title: AppStrings.privacyPolicy,
                  onTap: () => context.pushNamed('privacy-policy'),
                ),
                _RowDivider(divider: divider),
                _NavRow(
                  icon: Icons.delete_outline,
                  title: AppStrings.deleteMyData,
                  color: AppColors.error,
                  onTap: () => _confirmDeleteData(context, ref),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: AppStrings.logOut,
            leadingIcon: Icons.logout,
            isOutlined: true,
            foregroundColor: AppColors.error,
            onPressed: () => ref.read(authProvider.notifier).signOut(),
          ),
        ],
      ),
    );
  }

  static Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.borderRadiusLg),
        ),
      ),
      builder: (ctx) => _ProfileEditSheet(
        currentName: currentName,
        onSave: (name) async {
          final ok = await ref.read(authProvider.notifier).updateName(name);
          if (ctx.mounted) {
            Navigator.of(ctx).pop();
            AppSnackbar.show(
              context,
              message: ok
                  ? AppStrings.profileUpdated
                  : AppStrings.somethingWentWrongRetry,
              kind: ok ? SnackKind.success : SnackKind.error,
            );
          }
        },
      ),
    );
  }

  static Future<void> _confirmDeleteData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteDataConfirmTitle),
        content: const Text(AppStrings.deleteDataConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(AppStrings.deleteDataButton),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      AppSnackbar.show(
        context,
        message: AppStrings.deleteDataRequested,
        kind: SnackKind.info,
        duration: const Duration(seconds: 5),
      );
    }
  }

  static String _initial(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  static String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  BoxDecoration _sectionCardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border.all(color: theme.dividerColor),
      borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final String? hint;

  const _SectionTitle({required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: secondaryText,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: secondaryText,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  final Color divider;

  const _RowDivider({required this.divider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xxl),
      child: Divider(color: divider, height: 1),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    return AppPressable(
      semanticLabel: '$title: ${value ? 'on' : 'off'}',
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: value
                    ? AppColors.activeItemBackground
                    : theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
              child: Icon(
                icon,
                size: 18,
                color: value ? AppColors.primary : secondaryText,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppColors.primary,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: theme.dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEditSheet extends StatefulWidget {
  final String currentName;
  final Future<void> Function(String name) onSave;

  const _ProfileEditSheet({required this.currentName, required this.onSave});

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  late final TextEditingController _nameCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    await widget.onSave(name);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.editProfile, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(labelText: AppStrings.yourName),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: AppStrings.saveChanges,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? color;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryText = theme.colorScheme.onSurfaceVariant;
    final fg = color ?? theme.colorScheme.onSurface;
    return AppPressable(
      semanticLabel: title,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(AppSpacing.borderRadius),
              ),
              child: Icon(icon, size: 18, color: color ?? secondaryText),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: secondaryText),
          ],
        ),
      ),
    );
  }
}
