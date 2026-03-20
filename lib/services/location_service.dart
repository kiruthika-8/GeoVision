import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  // Max acceptable GPS accuracy in meters
  static const double kMaxAccuracyMeters = 100.0;

  Future<bool> requestLocationPermission() async {
    PermissionStatus status = await Permission.location.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    // Retry once if denied
    status = await Permission.location.request();
    return status.isGranted;
  }

  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      if (!await isLocationServiceEnabled()) {
        return {
          'success': false,
          'message': 'Location services are disabled. Please enable GPS.',
        };
      }

      if (!await requestLocationPermission()) {
        return {
          'success': false,
          'message': 'Location permission denied.',
        };
      }

      // Try high-accuracy first
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 20),
          ),
        );
        return _positionToMap(position);
      } catch (_) {
        // Fallback to medium accuracy
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 15),
          ),
        );
        return {
          ..._positionToMap(position),
          'warning': 'Using reduced accuracy location.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to get location: ${e.toString()}',
      };
    }
  }

  Map<String, dynamic> _positionToMap(Position position) {
    return {
      'success': true,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'accuracy': position.accuracy,
      'timestamp': position.timestamp,
    };
  }

  /// Returns true if the current position is within [radiusMeters] of target.
  Future<bool> isWithinRadius({
    required double targetLat,
    required double targetLng,
    double radiusMeters = 500.0,
  }) async {
    final loc = await getCurrentLocation();
    if (loc['success'] != true) return false;

    final distance = calculateDistance(
      loc['latitude'] as double,
      loc['longitude'] as double,
      targetLat,
      targetLng,
    );
    return distance <= radiusMeters;
  }

  double calculateDistance(
      double startLat, double startLng, double endLat, double endLng) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Human-readable accuracy label
  String accuracyLabel(double? accuracy) {
    if (accuracy == null) return 'Unknown';
    if (accuracy <= 10) return 'Excellent (${accuracy.toStringAsFixed(0)}m)';
    if (accuracy <= 30) return 'Good (${accuracy.toStringAsFixed(0)}m)';
    if (accuracy <= kMaxAccuracyMeters) return 'Fair (${accuracy.toStringAsFixed(0)}m)';
    return 'Poor (${accuracy.toStringAsFixed(0)}m)';
  }
}
