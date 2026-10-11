import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Get the current position with high accuracy.
  /// Falls back to the last known position if GPS fails or times out.
  /// Returns null if location cannot be determined at all.
  static Future<Position?> getCurrentPosition() async {
    try {
      // Check if location services are enabled at all
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      // Check/request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      // Try high-accuracy with a 10-second timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        return position;
      } catch (_) {
        // Fall back to last known
        final lastKnown = await Geolocator.getLastKnownPosition();
        return lastKnown;
      }
    } catch (_) {
      return null;
    }
  }

  /// Try to reverse-geocode is not available on-device without an API key,
  /// so we just return a human-friendly lat/lng string for display.
  static String formatLatLng(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }
}