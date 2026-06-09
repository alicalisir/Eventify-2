/// Runtime flavor configuration. Set values in flavor entry points
/// (main_development.dart, main_staging.dart) before calling base.main().
abstract final class AppEnv {
  static String flavor = 'production';

  /// Overrides BACKEND_URL from .env when non-null.
  static String? backendUrlOverride;

  /// Sentry traces sample rate (0.0–1.0). Defaults applied per flavor.
  static double sentryTracesSampleRate = 0.5;
}
