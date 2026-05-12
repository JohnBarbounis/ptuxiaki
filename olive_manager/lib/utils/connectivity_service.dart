// lib/utils/connectivity_service.dart
// ✅ Offline mode management service

import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_logger.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      AppLogger.warning('Connectivity check error: $e');
      return false;
    }
  }

  /// Get user-friendly offline message
  static String getOfflineMessage() {
    return '📡 Δεν υπάρχει σύνδεση στο internet. Η εφαρμογή λειτουργεί offline.';
  }

  /// Get specific offline message for feature
  static String getOfflineFeatureMessage(String feature) {
    return '📡 Δεν υπάρχει σύνδεση. Τα δεδομένα "$feature" δεν είναι διαθέσιμα offline.';
  }
}
