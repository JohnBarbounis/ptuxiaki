// lib/services/weather_service.dart
// ✅ Centralized weather API handling (avoid duplication)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../constants/app_constants.dart';

class WeatherService {
  // Singleton pattern
  static final WeatherService _instance = WeatherService._internal();

  factory WeatherService() {
    return _instance;
  }

  WeatherService._internal();

  // ✅ Get current GPS position or return default
  Future<({double lat, double lng})> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return (
          lat: AppConstants.defaultLatitude,
          lng: AppConstants.defaultLongitude,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition().timeout(
          Duration(seconds: AppConstants.gpsTimeoutSeconds),
        );
        return (lat: position.latitude, lng: position.longitude);
      }
    } catch (e) {
      print('GPS Error: $e');
    }

    // Fallback to default location
    return (
      lat: AppConstants.defaultLatitude,
      lng: AppConstants.defaultLongitude,
    );
  }

  // ✅ Get location name from coordinates (Reverse Geocoding)
  Future<String> getLocationName(double lat, double lng) async {
    try {
      // Try BigDataCloud first
      final geoUrl = Uri.parse(
        '${AppConstants.bigDataCloudUrl}?latitude=$lat&longitude=$lng&localityLanguage=el',
      );
      final geoResponse = await http
          .get(geoUrl)
          .timeout(Duration(seconds: AppConstants.apiTimeoutSeconds));

      if (geoResponse.statusCode == 200) {
        final geoData = json.decode(geoResponse.body);
        return geoData['city'] ??
            geoData['locality'] ??
            AppConstants.defaultLocationName;
      }

      // Fallback to Nominatim
      final nominatimUrl = Uri.parse(
        '${AppConstants.nominatimUrl}?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1&accept-language=el',
      );
      final nominatimResponse = await http
          .get(nominatimUrl)
          .timeout(Duration(seconds: AppConstants.apiTimeoutSeconds));

      if (nominatimResponse.statusCode == 200) {
        final nominatimData = json.decode(nominatimResponse.body);
        final address = nominatimData['address'] ?? {};
        return address['city'] ??
            address['town'] ??
            address['county'] ??
            AppConstants.defaultLocationName;
      }
    } catch (e) {
      print('Location Error: $e');
    }

    return AppConstants.defaultLocationName;
  }

  // ✅ Fetch 14-day weather forecast
  Future<Map<String, dynamic>> getWeatherForecast(
    double lat,
    double lng,
  ) async {
    try {
      final weatherUrl = Uri.parse(
        '${AppConstants.openMeteoUrl}?latitude=$lat&longitude=$lng&current_weather=true&daily=${AppConstants.maxTemperatureParam},${AppConstants.minTemperatureParam},${AppConstants.weatherCodeParam}&forecast_days=${AppConstants.weatherForecastDays}&timezone=auto',
      );

      final weatherResponse = await http
          .get(weatherUrl)
          .timeout(Duration(seconds: AppConstants.apiTimeoutSeconds));

      if (weatherResponse.statusCode == 200) {
        return json.decode(weatherResponse.body);
      } else {
        throw Exception(
          'Open-Meteo API returned status ${weatherResponse.statusCode}',
        );
      }
    } catch (e) {
      print('Weather API Error: $e');
      rethrow;
    }
  }

  // ✅ Extract current weather from API response
  Map<String, dynamic> extractCurrentWeather(Map<String, dynamic> data) {
    try {
      final current = data['current_weather'] ?? {};
      return {
        'temperature': current['temperature'] ?? 0.0,
        'windspeed': current['windspeed'] ?? 0.0,
        'weathercode': current['weathercode'] ?? 0,
      };
    } catch (e) {
      return {'temperature': null, 'windspeed': null, 'weathercode': null};
    }
  }

  // ✅ Extract daily forecast from API response
  Map<String, dynamic> extractDailyForecast(Map<String, dynamic> data) {
    try {
      final daily = data['daily'] ?? {};
      return {
        'dates': daily['time'] ?? [],
        'maxTemps': daily[AppConstants.maxTemperatureParam] ?? [],
        'minTemps': daily[AppConstants.minTemperatureParam] ?? [],
        'weatherCodes': daily[AppConstants.weatherCodeParam] ?? [],
      };
    } catch (e) {
      return {'dates': [], 'maxTemps': [], 'minTemps': [], 'weatherCodes': []};
    }
  }
}
