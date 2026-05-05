// lib/constants/app_constants.dart
// ✅ Centralized constants for API, UI, and configuration

class AppConstants {
  // --- API ENDPOINTS ---
  static const String openMeteoUrl = 'https://api.open-meteo.com/v1/forecast';
  static const String bigDataCloudUrl =
      'https://api.bigdatacloud.net/data/reverse-geocode-client';
  static const String nominatimUrl =
      'https://nominatim.openstreetmap.org/reverse';

  // --- API TIMEOUTS (in seconds) ---
  static const int apiTimeoutSeconds = 5;
  static const int gpsTimeoutSeconds = 5;

  // --- DEFAULT LOCATIONS (Fallback) ---
  static const double defaultLatitude = 35.3387; // Ηράκλειο
  static const double defaultLongitude = 25.1442;
  static const String defaultLocationName = 'Ηράκλειο';

  // --- DATABASE ---
  static const String databaseName = 'olive_manager.db';
  static const int databaseVersion = 2;

  // --- WEATHER ---
  static const int weatherForecastDays = 14;
  static const String weatherCodeParam = 'weathercode';
  static const String temperatureParam = 'temperature_2m';
  static const String maxTemperatureParam = 'temperature_2m_max';
  static const String minTemperatureParam = 'temperature_2m_min';

  // --- THRESHOLDS FOR FARMING ADVICE ---
  static const double strongWindThreshold = 15.0; // m/s
  static const double heatwaveThreshold = 35.0; // °C
  static const double coldThreshold = -2.0; // °C
  static const double highHumidityThreshold = 85.0; // %
  static const double highRainfallThreshold = 20.0; // mm

  // --- WEATHER CODES (WMO) ---
  static const int weatherCodeRain = 51;
  static const int weatherCodeSnow = 71;
  static const int weatherCodeFrost = 77;

  // --- UI CONSTANTS ---
  static const double cardElevation = 1.0;
  static const double borderRadius = 16.0;
  static const double cornerRadius = 8.0;

  // --- CACHE & PERFORMANCE ---
  static const int maxGrovesToDisplay = 50;
  static const Duration cacheExpiration = Duration(hours: 6);

  // --- FEATURE FLAGS ---
  static const bool enableOfflineMode = true;
  static const bool enableAutoRefresh = true;
}
