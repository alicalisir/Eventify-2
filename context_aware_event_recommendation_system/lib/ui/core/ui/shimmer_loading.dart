import 'package:flutter/material.dart';
import '../../../config/constants/app_colors.dart';

/// Shimmer loading placeholder widget
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  stops: [
                    _controller.value - 0.3,
                    _controller.value,
                    _controller.value + 0.3,
                  ],
                  colors: [
                    AppColors.shimmerBaseLight.withValues(alpha: 0.5),
                    AppColors.shimmerHighlightLight.withValues(alpha: 0.9),
                    AppColors.shimmerBaseLight.withValues(alpha: 0.5),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
