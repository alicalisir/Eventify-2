/// 8-point grid spacing system
abstract final class AppSpacing {
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const double minTouchTarget = 48.0;
  static const double borderRadiusSm = 8.0;
  static const double borderRadius = 12.0;
  static const double borderRadiusLg = 16.0;
  static const double borderRadiusXl = 18.0;
  static const double iconSizeXxs = 12.0;
  static const double iconSizeXs = 14.0;
  static const double iconSize = 24.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeLg = 32.0;

  /// Fully-rounded "pill" shape — use instead of the magic number 999.
  static const double pill = 999.0;

  /// Shimmer animation duration — used by all shimmer widgets for visual sync.
  static const Duration shimmerDuration = Duration(milliseconds: 1500);
}
