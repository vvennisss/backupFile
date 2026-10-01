import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Default fallback if GPS is disabled or denied (George Town, Penang)
  static const double defaultLat = 5.4141;
  static const double defaultLng = 100.3288;

  Position? _lastKnownPosition;
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check and request location permission from the device
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled on the device.');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied by user.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return false;
    }

    return true;
  }

  /// Get real-time phone GPS location
  Future<Position?> getCurrentPosition({Duration timeLimit = const Duration(seconds: 10)}) async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) {
        // Try getting last known position if permissions were previously available
        _lastKnownPosition = await Geolocator.getLastKnownPosition();
        return _lastKnownPosition;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(timeLimit, onTimeout: () async {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
        throw TimeoutException('GPS lookup timed out');
      });

      _lastKnownPosition = position;
      return position;
    } catch (e) {
      debugPrint('Error obtaining real-time GPS position: $e');
      _lastKnownPosition = await Geolocator.getLastKnownPosition();
      return _lastKnownPosition;
    }
  }

  /// Live real-time position stream subscription
  Stream<Position>? getPositionStream({int distanceFilter = 5}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    );
  }
}
