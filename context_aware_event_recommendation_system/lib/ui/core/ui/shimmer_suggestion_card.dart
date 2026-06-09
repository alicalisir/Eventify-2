import 'package:context_aware_event_recommendation_system/config/constants/app_colors.dart';
import 'package:context_aware_event_recommendation_system/config/constants/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shimmer loading effect widget
class ShimmerSuggestionCard extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerSuggestionCard({
    super.key,
    this.width = double.infinity,
    this.height = 200,
    this.borderRadius = AppSpacing.borderRadius,
  });

  @override
  State<ShimmerSuggestionCard> createState() => _ShimmerSuggestionCardState();
}

class _ShimmerSuggestionCardState extends State<ShimmerSuggestionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppSpacing.shimmerDuration,
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.shimmerBaseDark
        : AppColors.shimmerBaseLight;
    final highlightColor = isDark
        ? AppColors.shimmerHighlightDark
        : AppColors.shimmerHighlightLight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [baseColor, highlightColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}
