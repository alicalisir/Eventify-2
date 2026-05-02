import 'package:flutter/material.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../../domain/models/suggestion_model.dart';

/// Faux map hero — gradient backdrop, grid lines, dashed route, two pins,
/// and a compact distance/duration pill. Animates the dashed route.
class MapHero extends StatefulWidget {
  final SuggestionModel suggestion;
  final double height;

  const MapHero({super.key, required this.suggestion, this.height = 240});

  @override
  State<MapHero> createState() => _MapHeroState();
}

class _MapHeroState extends State<MapHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final theme = Theme.of(context);
    final hue = s.category.categoryHue;
    final base = HSLColor.fromAHSL(1, hue, 0.50, 0.85).toColor();
    final deep = HSLColor.fromAHSL(1, hue + 20, 0.60, 0.72).toColor();

    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [base, deep],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (_, _) => CustomPaint(
              painter: _MapPainter(dashOffset: _controller.value),
            ),
          ),
          // Walking pill
          Positioned(
            left: AppSpacing.md,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppSpacing.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.category.categoryIcon, size: 14, color: theme.colorScheme.onSurface),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    s.distance != null
                        ? '${s.estimatedMinutes} min · ${s.distance} km'
                        : '${s.estimatedMinutes} min',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final double dashOffset;

  _MapPainter({required this.dashOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Grid lines
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = 0.0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
    // Roads
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadPath = Path()
      ..moveTo(0, h * 0.75)
      ..quadraticBezierTo(w * 0.25, h * 0.66, w * 0.5, h * 0.71)
      ..quadraticBezierTo(w * 0.75, h * 0.78, w, h * 0.62);
    canvas.drawPath(roadPath, road);
    final road2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 10;
    canvas.drawLine(Offset(w * 0.20, 0), Offset(w * 0.30, h), road2);
    canvas.drawLine(Offset(w * 0.70, 0), Offset(w * 0.60, h), road2);
    // Animated dashed route
    final route = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(w * 0.25, h * 0.83)
      ..quadraticBezierTo(w * 0.40, h * 0.58, w * 0.55, h * 0.62)
      ..quadraticBezierTo(w * 0.70, h * 0.66, w * 0.80, h * 0.42);
    _drawDashed(canvas, routePath, route, 2, 6, dashOffset * 16);
    // Pins
    final pinFrom = Paint()..color = AppColors.primary;
    final pinTo = Paint()..color = AppColors.accent;
    final pinStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(Offset(w * 0.25, h * 0.83), 9, pinFrom);
    canvas.drawCircle(Offset(w * 0.25, h * 0.83), 9, pinStroke);
    canvas.drawCircle(Offset(w * 0.80, h * 0.42), 11, pinTo);
    canvas.drawCircle(Offset(w * 0.80, h * 0.42), 11, pinStroke);
  }

  void _drawDashed(
    Canvas canvas,
    Path source,
    Paint paint,
    double on,
    double off,
    double offset,
  ) {
    final metrics = source.computeMetrics();
    for (final metric in metrics) {
      var distance = -offset % (on + off);
      while (distance < metric.length) {
        final next = distance + on;
        canvas.drawPath(
          metric.extractPath(distance.clamp(0, metric.length), next.clamp(0, metric.length)),
          paint,
        );
        distance = next + off;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.dashOffset != dashOffset;
}
