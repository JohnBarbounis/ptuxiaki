// lib/utils/app_logger.dart
// ✅ Centralized logging utility to replace print() calls

import 'dart:developer' as developer;

class AppLogger {
  // Log levels
  static const int levelDebug = 0;
  static const int levelInfo = 800;
  static const int levelWarning = 900;
  static const int levelError = 1000;

  /// Log debug message
  static void debug(String message) {
    developer.log('[DEBUG] $message', level: levelDebug);
  }

  /// Log info message
  static void info(String message) {
    developer.log('[INFO] $message', level: levelInfo);
  }

  /// Log warning message
  static void warning(String message) {
    developer.log('[WARNING] $message', level: levelWarning);
  }

  /// Log error message
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      '[ERROR] $message${error != null ? '\n$error' : ''}',
      level: levelError,
      stackTrace: stackTrace,
    );
  }

  /// Log API response or data
  static void trace(String label, dynamic data) {
    developer.log('[TRACE] $label: $data', level: levelDebug);
  }
}
