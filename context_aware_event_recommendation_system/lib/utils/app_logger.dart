import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

abstract final class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 80,
      colors: false,
      printEmojis: true,
    ),
    level: kReleaseMode ? Level.warning : Level.trace,
  );

  static void d(String message, [Object? extra]) =>
      _logger.d(message, error: extra);

  static void i(String message, [Object? extra]) =>
      _logger.i(message, error: extra);

  static void w(String message, [Object? extra]) {
    _logger.w(message, error: extra);
    Sentry.addBreadcrumb(
      Breadcrumb(message: message, level: SentryLevel.warning),
    );
  }

  static void e(String message, [Object? error, StackTrace? stack]) {
    _logger.e(message, error: error, stackTrace: stack);
    if (error != null) {
      Sentry.captureException(error, stackTrace: stack);
    } else {
      Sentry.captureMessage(message, level: SentryLevel.error);
    }
  }
}
