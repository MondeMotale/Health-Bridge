import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;

  LocationResult({this.latitude, this.longitude, this.error});

  bool get hasLocation => latitude != null && longitude != null;
}

class LocationService {
  /// Request permission and fetch a position.
  /// Returns a [LocationResult] — check `.hasLocation` before using.
  static Future<LocationResult> fetch() async {
    try {
      // 1. Is location service on at all?
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationResult(
          error: 'Location services are turned off. Please enable GPS.',
        );
      }

      // 2. Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return LocationResult(
          error: 'Location permission was denied.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationResult(
          error:
              'Location permission permanently denied. Enable it in Settings.',
        );
      }

      // 3. Try high-accuracy with a 10s timeout
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return LocationResult(
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
      } catch (_) {
        // 4. Fall back to last known
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          return LocationResult(
            latitude: last.latitude,
            longitude: last.longitude,
          );
        }
        return LocationResult(
          error: 'Could not determine your location. Try again in a moment.',
        );
      }
    } catch (e) {
      return LocationResult(error: 'Location error: $e');
    }
  }

  // Kept for existing call sites.
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