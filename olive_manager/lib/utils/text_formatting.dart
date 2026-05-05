// lib/utils/text_formatting.dart
// ✅ Centralized text formatting functions

import 'package:intl/intl.dart';

class TextFormatting {
  // ✅ Format date to Greek format (e.g., 25/03/2026)
  static String formatDateGreek(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  // ✅ Format date with month name (e.g., 25 Μαρτίου 2026)
  static String formatDateWithMonthName(DateTime date) {
    return DateFormat('dd MMMM yyyy', 'el_GR').format(date);
  }

  // ✅ Format time (e.g., 14:30)
  static String formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  // ✅ Format datetime (e.g., 25/03 14:30)
  static String formatDateTime(DateTime dateTime) {
    return '${formatDateGreek(dateTime).substring(0, 5)} ${formatTime(dateTime)}';
  }

  // ✅ Format currency (e.g., 1,234.56€)
  static String formatCurrency(double amount, {String symbol = '€'}) {
    return '${amount.toStringAsFixed(2)} $symbol';
  }

  // ✅ Format percentage (e.g., 12.5%)
  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  // ✅ Format oil volume (e.g., 1,234.5L)
  static String formatOilVolume(double liters) {
    return '${liters.toStringAsFixed(1)}L';
  }

  // ✅ Format area in stremmata (e.g., 12.5 Στρ.)
  static String formatArea(double stremmata) {
    return '${stremmata.toStringAsFixed(2)} Στρ.';
  }

  // ✅ Format temperature (e.g., 25.3°C)
  static String formatTemperature(double celsius) {
    return '${celsius.toStringAsFixed(1)}°C';
  }

  // ✅ Format wind speed (e.g., 15.2 m/s)
  static String formatWindSpeed(double mps) {
    return '${mps.toStringAsFixed(1)} m/s';
  }

  // ✅ Format acidity (e.g., 0.5%)
  static String formatAcidity(double acidity) {
    return '${acidity.toStringAsFixed(2)}%';
  }

  // ✅ Format large numbers with thousands separator (e.g., 1,234,567)
  static String formatNumber(double number) {
    final formatter = NumberFormat('#,##0.##');
    return formatter.format(number);
  }

  // ✅ Truncate text to max length with ellipsis
  static String truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength - 3)}...';
  }

  // ✅ Convert month number to Greek month name
  static String getGreekMonthName(int month) {
    const monthNames = [
      'Ιανουάριος',
      'Φεβρουάριος',
      'Μάρτιος',
      'Απρίλιος',
      'Μάιος',
      'Ιούνιος',
      'Ιούλιος',
      'Αύγουστος',
      'Σεπτέμβριος',
      'Οκτώβριος',
      'Νοέμβριος',
      'Δεκέμβριος',
    ];
    return monthNames[month - 1];
  }

  // ✅ Get relative time (e.g., "2 ημέρες από τώρα")
  static String getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'πριν ${difference.inDays} ημέρες';
    } else if (difference.inHours > 0) {
      return 'πριν ${difference.inHours} ώρες';
    } else if (difference.inMinutes > 0) {
      return 'πριν ${difference.inMinutes} λεπτά';
    } else {
      return 'μόλις τώρα';
    }
  }

  // ✅ Format ROI score with color coding text
  static String formatRoiScore(double roi) {
    if (roi >= 100) return '⭐ Εξαιρετικό (${roi.toStringAsFixed(0)}%)';
    if (roi >= 20) return '👍 Καλό (${roi.toStringAsFixed(0)}%)';
    if (roi >= 0) return '⚠️ Μέτριο (${roi.toStringAsFixed(0)}%)';
    return '❌ Αρνητικό (${roi.toStringAsFixed(0)}%)';
  }
}
