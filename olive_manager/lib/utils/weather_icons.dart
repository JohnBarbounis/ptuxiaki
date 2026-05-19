import 'package:flutter/material.dart';

class WeatherIcons {
  // WMO Weather Code to Flutter IconData mapping
  static IconData getWeatherIcon(int? code) {
    code ??= 0;

    if (code == 0 || code == 1) return Icons.wb_sunny;
    if (code == 2) return Icons.wb_sunny; // Partly cloudy
    if (code == 3) return Icons.cloud;
    if (code >= 45 && code <= 48) return Icons.cloud; // Foggy
    if (code >= 51 && code <= 67) return Icons.cloud_queue; // Drizzle/Rain
    if (code >= 71 && code <= 85) return Icons.ac_unit; // Snow
    if (code >= 80 && code <= 82) return Icons.cloud_download; // Rain showers
    if (code == 85 || code == 86) return Icons.cloud_download; // Snow showers
    if (code >= 80 && code <= 99) return Icons.grain; // Thunderstorm

    return Icons.help_outline; // Unknown
  }

  // Weather code severity for farming advice
  static ({bool isDangerous, String message, Color color}) getWeatherSeverity(
    int? code,
  ) {
    code ??= 0;

    if (code >= 51) {
      // Rain/Snow/Thunderstorm
      return (
        isDangerous: true,
        message: 'Κακοκαιρία - Αποφύγετε τις εργασίες',
        color: Colors.red,
      );
    }

    if (code >= 45 && code <= 48) {
      // Fog
      return (
        isDangerous: true,
        message: 'Ομίχλη - Δύσκολες συνθήκες',
        color: Colors.orange,
      );
    }

    if (code >= 0 && code <= 3) {
      // Clear/Sunny
      return (
        isDangerous: false,
        message: 'Καλός καιρός - Ιδανικές συνθήκες',
        color: Colors.green,
      );
    }

    return (
      isDangerous: false,
      message: 'Συνθήκες κανονικές',
      color: Colors.blueGrey,
    );
  }

  // Frost risk based on weather code and temperature
  static bool isFrostRisk(int? code, double? temperature) {
    code ??= 0;
    temperature ??= 0.0;

    return temperature < 0 || (code >= 71 && code <= 77); // Frost codes or snow
  }

  // Pest activity risk (Olive fly) based on conditions
  static bool isPestActivityHigh(double? temperature, double? humidity) {
    temperature ??= 0.0;
    humidity ??= 0.0;

    return temperature > 20 && humidity > 60;
  }
}
