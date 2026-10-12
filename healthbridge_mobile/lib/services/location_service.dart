import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;

  LocationResult({this.latitude, this.longitude, this.error});

  bool get hasLocation => latitude != null && longitude != null;
}

class LocationService {
  /// Request permission and fetch a position.
  /// Strategy: try high accuracy → low accuracy → last known.
  static Future<LocationResult> fetch() async {
    try {
      // 1. GPS enabled?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[Location] serviceEnabled=$serviceEnabled');
      if (!serviceEnabled) {
        return LocationResult(
          error: 'Location services are turned off. Please enable GPS.',
        );
      }

      // 2. Permission
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('[Location] checkPermission=$permission');
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        debugPrint('[Location] after request=$permission');
      }
      if (permission == LocationPermission.denied) {
        return LocationResult(error: 'Location permission was denied.');
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          error: 'Location permission permanently denied. Enable it in Settings.',
        );
      }

      // 3. High accuracy (15s timeout)
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        );
        debugPrint(
          '[Location] high OK: ${pos.latitude}, ${pos.longitude} acc=${pos.accuracy}m',
        );
        return LocationResult(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (e) {
        debugPrint('[Location] high failed: $e');
      }

      // 4. Low accuracy (works with approximate permission; ~1km accuracy)
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 10),
          ),
        );
        debugPrint(
          '[Location] low OK: ${pos.latitude}, ${pos.longitude} acc=${pos.accuracy}m',
        );
        return LocationResult(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (e) {
        debugPrint('[Location] low failed: $e');
      }

      // 5. Last known
      final last = await Geolocator.getLastKnownPosition();
      debugPrint('[Location] lastKnown=$last');
      if (last != null) {
        return LocationResult(
          latitude: last.latitude,
          longitude: last.longitude,
        );
      }

      return LocationResult(
        error: 'Could not determine location. Move to an open area and retry.',
      );
    } catch (e) {
      debugPrint('[Location] error: $e');
      return LocationResult(error: 'Location error: $e');
    }
  }

  static Future<Position?> getCurrentPosition() async {
    final result = await fetch();
    if (!result.hasLocation) return null;
    return Position(
      latitude: result.latitude!,
      longitude: result.longitude!,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  static String formatLatLng(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}