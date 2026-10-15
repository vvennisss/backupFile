import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class RoutePolylineService {
  /// Fetches realistic driving car road coordinates connecting all given stop coordinates.
  /// Queries OSRM (Open Source Routing Machine) driving profile.
  /// Falls back to smooth Catmull-Rom spline road curves if offline or on error.
  static Future<List<Map<String, double>>> fetchDrivingCarPath({
    required List<Map<String, double>> stops,
  }) async {
    if (stops.length < 2) return stops;

    try {
      // Coordinates string: "lng1,lat1;lng2,lat2;..."
      final coordsParam = stops.map((p) => '${p['lng']},${p['lat']}').join(';');
      final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/$coordsParam?overview=full&geometries=geojson');

      final res = await http.get(url, headers: {
        'User-Agent': 'KiaPenangApp/1.0',
        'Accept': 'application/json',
      }).timeout(const Duration(milliseconds: 3500));

      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        if (data['code'] == 'Ok' &&
            data['routes'] != null &&
            (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final rawCoords = route['geometry']?['coordinates'] as List<dynamic>?;
          if (rawCoords != null && rawCoords.isNotEmpty) {
            final List<Map<String, double>> result = [];
            for (final pt in rawCoords) {
              if (pt is List && pt.length >= 2) {
                result.add({
                  'lng': (pt[0] as num).toDouble(),
                  'lat': (pt[1] as num).toDouble(),
                });
              }
            }
            if (result.isNotEmpty) {
              debugPrint('🚗 [ROUTE SERVICE] Successfully fetched OSRM car path with ${result.length} road coordinates.');
              return result;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ROUTE SERVICE] OSRM fetch failed or timed out: $e. Falling back to smooth road-spline interpolation.');
    }

    // Graceful offline fallback: Catmull-Rom road-spline interpolation
    return generateCurvedRoadPath(stops);
  }

  /// Catmull-Rom spline interpolation creating realistic curved car path between stops
  static List<Map<String, double>> generateCurvedRoadPath(List<Map<String, double>> stops) {
    if (stops.length < 2) return stops;
    final List<Map<String, double>> curvePoints = [];

    for (int i = 0; i < stops.length - 1; i++) {
      final p0 = i > 0 ? stops[i - 1] : stops[i];
      final p1 = stops[i];
      final p2 = stops[i + 1];
      final p3 = i < stops.length - 2 ? stops[i + 2] : p2;

      // Add intermediate road-curve steps between p1 and p2
      const steps = 18;
      for (int step = 0; step <= steps; step++) {
        final t = step / steps;
        final t2 = t * t;
        final t3 = t2 * t;

        // Catmull-Rom spline formulas
        final lat = 0.5 *
            ((2 * p1['lat']!) +
                (-p0['lat']! + p2['lat']!) * t +
                (2 * p0['lat']! - 5 * p1['lat']! + 4 * p2['lat']! - p3['lat']!) * t2 +
                (-p0['lat']! + 3 * p1['lat']! - 3 * p2['lat']! + p3['lat']!) * t3);
        final lng = 0.5 *
            ((2 * p1['lng']!) +
                (-p0['lng']! + p2['lng']!) * t +
                (2 * p0['lng']! - 5 * p1['lng']! + 4 * p2['lng']! - p3['lng']!) * t2 +
                (-p0['lng']! + 3 * p1['lng']! - 3 * p2['lng']! + p3['lng']!) * t3);

        curvePoints.add({'lat': lat, 'lng': lng});
      }
    }
    return curvePoints;
  }

  /// Calculates total distance in kilometers along a list of coordinates
  static double calculateTotalDistanceKm(List<Map<String, double>> points) {
    if (points.length < 2) return 0.0;
    double totalMeters = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalMeters += _haversineMeters(
        points[i]['lat']!,
        points[i]['lng']!,
        points[i + 1]['lat']!,
        points[i + 1]['lng']!,
      );
    }
    return totalMeters / 1000.0;
  }

  static double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a));
  }
}
