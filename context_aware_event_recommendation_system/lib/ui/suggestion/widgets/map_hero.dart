import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';

import '../../../config/constants/app_colors.dart';
import '../../../config/constants/app_spacing.dart';
import '../../../domain/models/suggestion_category.dart';
import '../../../domain/models/suggestion_model.dart';

// ─── Public widgets ──────────────────────────────────────────────────────────

/// Full-height map hero for the detail screen.
/// Shows venue pin + user location + route line when coordinates are available.
class MapHero extends StatefulWidget {
  final SuggestionModel suggestion;
  final double height;

  const MapHero({super.key, required this.suggestion, this.height = 240});

  @override
  State<MapHero> createState() => _MapHeroState();
}

class _MapHeroState extends State<MapHero> with SingleTickerProviderStateMixin {
  late final AnimationController _fauxCtrl;
  Position? _userPos;

  @override
  void initState() {
    super.initState();
    _fauxCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    _loadUserPosition();
  }

  Future<void> _loadUserPosition() async {
    try {
      final pos = await Geolocator.getLastKnownPosition()
          .timeout(const Duration(seconds: 3));
      if (mounted && pos != null) setState(() => _userPos = pos);
    } catch (_) {}
  }

  @override
  void dispose() {
    _fauxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    if (s.latitude != null && s.longitude != null) {
      return _RealMapHero(
        suggestion: s,
        userPos: _userPos,
        height: widget.height,
        fauxCtrl: _fauxCtrl,
        showUserIndicator: true,
      );
    }
    return _FauxMapHero(suggestion: s, height: widget.height, ctrl: _fauxCtrl);
  }
}

/// Compact map thumbnail for use inside recommendation cards.
/// Only shows venue location (no user pin) to keep rendering fast.
class StaticMapThumbnail extends StatefulWidget {
  final SuggestionModel suggestion;
  final double height;

  const StaticMapThumbnail({
    super.key,
    required this.suggestion,
    this.height = 140,
  });

  @override
  State<StaticMapThumbnail> createState() => _StaticMapThumbnailState();
}

class _StaticMapThumbnailState extends State<StaticMapThumbnail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fauxCtrl;

  @override
  void initState() {
    super.initState();
    _fauxCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
  }

  @override
  void dispose() {
    _fauxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    if (s.latitude != null && s.longitude != null) {
      return _RealMapHero(
        suggestion: s,
        userPos: null,
        height: widget.height,
        fauxCtrl: _fauxCtrl,
        showUserIndicator: false,
        zoom: 15,
      );
    }
    return _FauxMapHero(suggestion: s, height: widget.height, ctrl: _fauxCtrl);
  }
}

// ─── Real map ────────────────────────────────────────────────────────────────

class _RealMapHero extends StatelessWidget {
  final SuggestionModel suggestion;
  final Position? userPos;
  final double height;
  final AnimationController fauxCtrl;
  final bool showUserIndicator;
  final int? zoom;

  const _RealMapHero({
    required this.suggestion,
    required this.userPos,
    required this.height,
    required this.fauxCtrl,
    required this.showUserIndicator,
    this.zoom,
  });

  String _buildUrl(String apiKey) {
    final vLat = suggestion.latitude!;
    final vLon = suggestion.longitude!;
    final h = height.toInt().clamp(80, 400);
    final buf = StringBuffer(
      'https://maps.googleapis.com/maps/api/staticmap?size=600x$h&scale=2&maptype=roadmap',
    );

    final uPos = userPos;
    if (uPos != null) {
      // Centre between user and venue
      final cLat = ((uPos.latitude + vLat) / 2).toStringAsFixed(6);
      final cLon = ((uPos.longitude + vLon) / 2).toStringAsFixed(6);
      buf.write('&center=$cLat,$cLon');
      // Blue user marker
      buf.write(
        '&markers=color:0x4F46E5|size:small|${uPos.latitude.toStringAsFixed(6)},${uPos.longitude.toStringAsFixed(6)}',
      );
      // Indigo route line
      buf.write(
        '&path=color:0x4F46E5AA|weight:4|geodesic:true'
        '|${uPos.latitude.toStringAsFixed(6)},${uPos.longitude.toStringAsFixed(6)}'
        '|${vLat.toStringAsFixed(6)},${vLon.toStringAsFixed(6)}',
      );
    } else {
      buf.write('&center=${vLat.toStringAsFixed(6)},${vLon.toStringAsFixed(6)}');
      buf.write('&zoom=${zoom ?? 15}');
    }

    // Red venue marker
    buf.write(
      '&markers=color:red|size:mid|${vLat.toStringAsFixed(6)},${vLon.toStringAsFixed(6)}',
    );
    // Cleaner map style
    buf.write('&style=feature:poi|visibility:off');
    buf.write('&style=feature:transit|visibility:off');
    buf.write('&key=$apiKey');
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return _FauxMapHero(suggestion: suggestion, height: height, ctrl: fauxCtrl);
    }

    final url = _buildUrl(apiKey);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            cacheWidth: 600,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return _FauxMapHero(suggestion: suggestion, height: height, ctrl: fauxCtrl);
            },
            errorBuilder: (_, __, ___) =>
                _FauxMapHero(suggestion: suggestion, height: height, ctrl: fauxCtrl),
          ),
          // Bottom gradient for text/pill readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                  stops: const [0.45, 1.0],
                ),
              ),
            ),
          ),
          // Info pill (bottom-left)
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _InfoPill(suggestion: suggestion),
          ),
          // "You are here" indicator (bottom-right, only when user pos is known)
          if (showUserIndicator && userPos != null)
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'You',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
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

// ─── Faux map (fallback / events) ────────────────────────────────────────────

class _FauxMapHero extends StatelessWidget {
  final SuggestionModel suggestion;
  final double height;
  final AnimationController ctrl;

  const _FauxMapHero({
    required this.suggestion,
    required this.height,
    required this.ctrl,
  });

  @override
  Widget build(BuildContext context) {
    final hue = suggestion.category.categoryHue;
    final base = HSLColor.fromAHSL(1, hue, 0.50, 0.82).toColor();
    final deep = HSLColor.fromAHSL(1, (hue + 25) % 360, 0.60, 0.68).toColor();

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base, deep],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, _) => CustomPaint(
              painter: _MapPainter(dashOffset: ctrl.value),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withValues(alpha: 0.35)],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            bottom: AppSpacing.md,
            child: _InfoPill(suggestion: suggestion),
          ),
        ],
      ),
    );
  }
}

// ─── Shared info pill ─────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final SuggestionModel suggestion;

  const _InfoPill({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    String label;
    if (s.distance != null && s.estimatedMinutes != null) {
      label = '${s.estimatedMinutes} min · ${s.distance!.toStringAsFixed(1)} km';
    } else if (s.estimatedMinutes != null) {
      label = '${s.estimatedMinutes} min';
    } else if (s.distance != null) {
      label = '${s.distance!.toStringAsFixed(1)} km';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppSpacing.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            s.category.categoryIcon,
            size: 12,
            color: AppColors.textPrimaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Faux map painter ─────────────────────────────────────────────────────────

class _MapPainter extends CustomPainter {
  final double dashOffset;

  _MapPainter({required this.dashOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    const step = 28.0;
    for (var x = 0.0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (var y = 0.0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.80)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final roadPath = Path()
      ..moveTo(0, h * 0.75)
      ..quadraticBezierTo(w * 0.25, h * 0.66, w * 0.5, h * 0.71)
      ..quadraticBezierTo(w * 0.75, h * 0.78, w, h * 0.62);
    canvas.drawPath(roadPath, road);

    final road2 = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(w * 0.20, 0), Offset(w * 0.30, h), road2);
    canvas.drawLine(Offset(w * 0.70, 0), Offset(w * 0.60, h), road2);

    final route = Paint()
      ..color = AppColors.secondary.withValues(alpha: 0.9)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final routePath = Path()
      ..moveTo(w * 0.22, h * 0.82)
      ..cubicTo(w * 0.35, h * 0.55, w * 0.55, h * 0.60, w * 0.78, h * 0.38);
    _drawDashed(canvas, routePath, route, 2, 6, dashOffset * 16);

    void drawPin(double x, double y, Color fill, double r) {
      final pinFill = Paint()..color = fill;
      final pinStroke = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;
      canvas.drawCircle(Offset(x, y), r, pinFill);
      canvas.drawCircle(Offset(x, y), r, pinStroke);
    }

    drawPin(w * 0.22, h * 0.82, AppColors.primary, 8);
    drawPin(w * 0.78, h * 0.38, AppColors.accent, 10);
  }

  void _drawDashed(
    Canvas canvas,
    Path source,
    Paint paint,
    double on,
    double off,
    double offset,
  ) {
    for (final metric in source.computeMetrics()) {
      var distance = -offset % (on + off);
      while (distance < metric.length) {
        final next = distance + on;
        canvas.drawPath(
          metric.extractPath(
            distance.clamp(0, metric.length),
            next.clamp(0, metric.length),
          ),
          paint,
        );
        distance = next + off;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.dashOffset != dashOffset;
}
