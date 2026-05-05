// lib/utils/error_handler.dart
// ✅ Centralized error handling and user-friendly messages

import 'dart:io';
import 'dart:async';

class ErrorHandler {
  // ✅ Get user-friendly error message based on exception type
  static String getApiErrorMessage(Exception e) {
    print('❌ API Error: ${e.runtimeType} - $e');

    if (e is SocketException) {
      return 'Σφάλμα σύνδεσης. Ελέγξτε το Internet.';
    }

    if (e is TimeoutException) {
      return 'Αργή απάντηση του server. Δοκιμήστε αργότερα.';
    }

    if (e is FormatException) {
      return 'Σφάλμα δεδομένων. Επικοινωνήστε με support.';
    }

    if (e is HttpException) {
      return 'Σφάλμα δικτύου. Δοκιμήστε αργότερα.';
    }

    return 'Κάτι πήγε λάθος. Δοκιμήστε ξανά.';
  }

  // ✅ Get user-friendly message for database errors
  static String getDatabaseErrorMessage(Exception e) {
    print('❌ Database Error: ${e.runtimeType} - $e');

    if (e.toString().contains('database is locked')) {
      return '🔒 Η βάση δεδομένων είναι κλειδωμένη. Δοκιμήστε ξανά.';
    }

    if (e.toString().contains('no such table')) {
      return '❌ Σφάλμα δομής δεδομένων. Επαναφέρετε την εφαρμογή.';
    }

    if (e.toString().contains('UNIQUE constraint failed')) {
      return '⚠️ Αυτό το χωράφι ή δεδομένο υπάρχει ήδη.';
    }

    return '⚠️ Σφάλμα αποθήκευσης. Δοκιμήστε ξανά.';
  }

  // ✅ Get user-friendly message for location/GPS errors
  static String getLocationErrorMessage(Exception e) {
    print('❌ Location Error: ${e.runtimeType} - $e');

    if (e.toString().contains('Location services are disabled')) {
      return '📍 GPS απενεργοποιημένο. Ενεργοποιήστε το στις Ρυθμίσεις.';
    }

    if (e.toString().contains('Permission denied')) {
      return '🚫 Δεν έχετε δώσει άδεια πρόσβασης GPS.';
    }

    if (e.toString().contains('timeout') || e is TimeoutException) {
      return '⏱️ GPS timeout. Δοκιμήστε ξανά σε ανοιχτό χώρο.';
    }

    return '📍 Σφάλμα προσδιορισμού θέσης. Δοκιμήστε ξανά.';
  }

  // ✅ Get user-friendly message for permission errors
  static String getPermissionErrorMessage(String permissionType) {
    switch (permissionType) {
      case 'location':
        return '📍 Χρειάζεστε άδεια πρόσβασης στο GPS.';
      case 'storage':
        return '💾 Χρειάζεστε άδεια πρόσβασης στη μνήμη.';
      case 'camera':
        return '📷 Χρειάζεστε άδεια πρόσβασης στη κάμερα.';
      default:
        return '🔐 Χρειάζεται άδεια πρόσβασης.';
    }
  }

  // ✅ Validate API response format
  static void validateApiResponse(dynamic response, String source) {
    if (response == null) {
      throw FormatException('Κενή απάντηση από $source');
    }

    if (response is! Map && response is! List) {
      throw FormatException('Μη αναμενόμενη μορφή δεδομένων από $source');
    }
  }

  // ✅ Safe double parsing with error handling
  static double safeParseDouble(dynamic value, {double defaultValue = 0.0}) {
    try {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        return double.parse(value.replaceAll(',', '.'));
      }
      return defaultValue;
    } catch (e) {
      print('⚠️ Parse error for $value: $e');
      return defaultValue;
    }
  }

  // ✅ Safe int parsing with error handling
  static int safeParseInt(dynamic value, {int defaultValue = 0}) {
    try {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.parse(value);
      return defaultValue;
    } catch (e) {
      print('⚠️ Parse error for $value: $e');
      return defaultValue;
    }
  }

  // ✅ Safe DateTime parsing
  static DateTime safeParseDatetime(dynamic value, {DateTime? defaultValue}) {
    try {
      if (value == null) return defaultValue ?? DateTime.now();
      if (value is DateTime) return value;
      if (value is String) return DateTime.parse(value);
      return defaultValue ?? DateTime.now();
    } catch (e) {
      print('⚠️ DateTime parse error for $value: $e');
      return defaultValue ?? DateTime.now();
    }
  }
}
