import '../services/live_journey_service.dart';
import '../services/saved_trip_plans_manager.dart';

/// Model representing a completed trail route in Travel History
class TravelPlanRoute {
  final String? planId;
  final String title;
  final String date;
  final double distance; // in km
  final String duration;
  final List<String> stops;
  final List<Map<String, double>>? routePoints; // Road polyline points: [{'lat': ..., 'lng': ...}]
  final List<SavedPlanStop>? stopDetails; // Full stop objects with lat/lng

  TravelPlanRoute({
    this.planId,
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.stops,
    this.routePoints,
    this.stopDetails,
  });

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'title': title,
        'date': date,
        'distance': distance,
        'duration': duration,
        'stops': stops,
        'routePoints': routePoints,
        'stopDetails': stopDetails?.map((s) => s.toJson()).toList(),
      };

  factory TravelPlanRoute.fromJson(Map<String, dynamic> json) => TravelPlanRoute(
        planId: json['planId']?.toString(),
        title: json['title']?.toString() ?? 'Penang Heritage Trail',
        date: json['date']?.toString() ?? '',
        distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
        duration: json['duration']?.toString() ?? '',
        stops: (json['stops'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        routePoints: (json['routePoints'] as List<dynamic>?)?.map((p) => {
              'lat': (p['lat'] as num).toDouble(),
              'lng': (p['lng'] as num).toDouble(),
            }).toList(),
        stopDetails: (json['stopDetails'] as List<dynamic>?)
            ?.map((s) => SavedPlanStop.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  /// Resolves full SavedPlanStop objects for map rendering
  List<SavedPlanStop> getResolvedStops() {
    if (stopDetails != null && stopDetails!.isNotEmpty) {
      return stopDetails!;
    }
    if (routePoints != null && routePoints!.isNotEmpty) {
      final count = stops.isNotEmpty ? stops.length : routePoints!.length;
      return List.generate(count, (i) {
        final ptIndex = (i * (routePoints!.length - 1) / (count > 1 ? count - 1 : 1)).round();
        final pt = routePoints![ptIndex.clamp(0, routePoints!.length - 1)];
        final name = i < stops.length ? stops[i] : 'Stop ${i + 1}';
        return SavedPlanStop(
          stopNumber: i + 1,
          placeName: name,
          area: 'Penang',
          category: 'Heritage',
          timeSlot: '',
          stayDuration: '',
          pennyTip: '',
          lat: pt['lat']!,
          lng: pt['lng']!,
        );
      });
    }
    return stops.asMap().entries.map((e) => SavedPlanStop(
          stopNumber: e.key + 1,
          placeName: e.value,
          area: 'Penang',
          category: 'Heritage',
          timeSlot: '',
          stayDuration: '',
          pennyTip: '',
          lat: 5.4140 + (e.key * 0.005),
          lng: 100.3288 + (e.key * 0.005),
        )).toList();
  }
}

/// Comprehensive summary of a completed trip displayed on StoryTabScreen
class CompletedTripSummary {
  final String planId;
  final String planTitle;
  final String travelDateRange;
  final double totalDistanceKm;
  final String totalDurationStr;
  final DateTime startTime;
  final DateTime endTime;
  final int totalStayMinutes;
  final int totalOverstayMinutes;
  final List<SavedPlanStop> stops;
  final List<DepartureRecord> departureRecords;
  final List<Map<String, double>> routeCoordinates; // Full driving road coordinates

  CompletedTripSummary({
    required this.planId,
    required this.planTitle,
    required this.travelDateRange,
    required this.totalDistanceKm,
    required this.totalDurationStr,
    required this.startTime,
    required this.endTime,
    required this.totalStayMinutes,
    required this.totalOverstayMinutes,
    required this.stops,
    required this.departureRecords,
    required this.routeCoordinates,
  });

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'planTitle': planTitle,
        'travelDateRange': travelDateRange,
        'totalDistanceKm': totalDistanceKm,
        'totalDurationStr': totalDurationStr,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'totalStayMinutes': totalStayMinutes,
        'totalOverstayMinutes': totalOverstayMinutes,
        'stops': stops.map((s) => s.toJson()).toList(),
        'departureRecords': departureRecords.map((r) => r.toJson()).toList(),
        'routeCoordinates': routeCoordinates,
      };

  factory CompletedTripSummary.fromJson(Map<String, dynamic> json) => CompletedTripSummary(
        planId: json['planId']?.toString() ?? '',
        planTitle: json['planTitle']?.toString() ?? 'Penang Trip',
        travelDateRange: json['travelDateRange']?.toString() ?? '',
        totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0.0,
        totalDurationStr: json['totalDurationStr']?.toString() ?? '2.5 hrs',
        startTime: DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now(),
        endTime: DateTime.tryParse(json['endTime']?.toString() ?? '') ?? DateTime.now(),
        totalStayMinutes: (json['totalStayMinutes'] as num?)?.toInt() ?? 0,
        totalOverstayMinutes: (json['totalOverstayMinutes'] as num?)?.toInt() ?? 0,
        stops: (json['stops'] as List<dynamic>?)
                ?.map((s) => SavedPlanStop.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        departureRecords: (json['departureRecords'] as List<dynamic>?)
                ?.map((r) => DepartureRecord.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        routeCoordinates: (json['routeCoordinates'] as List<dynamic>?)
                ?.map((p) => {
                      'lat': (p['lat'] as num).toDouble(),
                      'lng': (p['lng'] as num).toDouble(),
                    })
                .toList() ??
            [],
      );
}
