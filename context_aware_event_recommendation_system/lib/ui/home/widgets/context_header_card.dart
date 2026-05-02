import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/context_state.dart';

/// Gradient hero card showing greeting + activity + ambient context chips.
class ContextHeaderCard extends StatelessWidget {
  final ContextState contextState;
  final String userName;
  final bool isRefreshing;

  const ContextHeaderCard({
    super.key,
    required this.contextState,
    required this.userName,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.borderRadiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandCardShadow,
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative circle
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${contextState.greeting}, $userName',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 2), // ignore: no_raw_spacing_literals — deliberate 2 px hairline gap between greeting and activity text
              Text(
                contextState.contextDescription,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (contextState.locationLabel != null)
                    _ContextChip(
                      icon: Icons.place,
                      label: contextState.locationLabel!,
                    )
                  else if (contextState.isLocationEnabled)
                    const _ContextChip(
                      icon: Icons.place,
                      label: 'Location active',
                    ),
                  if (contextState.weather != null)
                    _ContextChip(
                      icon: Icons.wb_sunny,
                      label: contextState.weather!,
                    ),
                  _ContextChip(
                    icon: Icons.sensors,
                    label: contextState.activityLabel,
                    pulse: isRefreshing,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _updatedLabel(contextState.lastUpdated),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _updatedLabel(DateTime? lastUpdated) {
    if (lastUpdated == null) return 'Not yet updated';
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 60) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
    final h = lastUpdated.hour.toString().padLeft(2, '0');
    final m = lastUpdated.minute.toString().padLeft(2, '0');
    return 'Updated at $h:$m';
  }
}

class _ContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool pulse;

  const _ContextChip({
    required this.icon,
    required this.label,
    this.pulse = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            const _PulseDot()
          else
            Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: AppSpacing.iconSizeXs,
      height: AppSpacing.iconSizeXs,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14 * (1 + t * 1.2),
                height: 14 * (1 + t * 1.2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: (1 - t) * 0.4),
                ),
              ),
              const Icon(Icons.sensors, size: 14, color: Colors.white),
            ],
          );
        },
      ),
    );
  }
}
