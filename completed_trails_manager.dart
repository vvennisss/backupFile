import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/completed_trip_summary.dart';

class CompletedTrailsManager {
  static const String _completedTrailsKey = 'kiapenang_completed_trails_history';
  static const String _latestSummaryKey = 'kiapenang_latest_completed_trip_summary';

  static final ValueNotifier<List<TravelPlanRoute>> completedTrailsNotifier =
      ValueNotifier<List<TravelPlanRoute>>([]);

  static final ValueNotifier<CompletedTripSummary?> latestCompletedSummaryNotifier =
      ValueNotifier<CompletedTripSummary?>(null);

  static bool _initialized = false;

  /// Initializes manager and loads persisted completed trail routes
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load completed trail routes history
      final trailsJsonStr = prefs.getString(_completedTrailsKey);
      if (trailsJsonStr != null && trailsJsonStr.isNotEmpty) {
        final List<dynamic> decoded = json.decode(trailsJsonStr);
        final trails = decoded.map((item) => TravelPlanRoute.fromJson(item as Map<String, dynamic>)).toList();
        completedTrailsNotifier.value = trails;
      }

      // 2. Load latest completed trip summary if any
      final summaryJsonStr = prefs.getString(_latestSummaryKey);
      if (summaryJsonStr != null && summaryJsonStr.isNotEmpty) {
        final decoded = json.decode(summaryJsonStr);
        latestCompletedSummaryNotifier.value = CompletedTripSummary.fromJson(decoded as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('⚠️ [COMPLETED TRAILS] Error initializing: $e');
    }
  }

  /// Adds a newly completed trail route to history and persists it
  static Future<void> addCompletedTrail(TravelPlanRoute route) async {
    try {
      final current = List<TravelPlanRoute>.from(completedTrailsNotifier.value);
      // Remove any duplicate with same title and date
      current.removeWhere((r) => r.title == route.title && r.date == route.date);
      // Insert newest at the top
      current.insert(0, route);
      completedTrailsNotifier.value = current;

      final prefs = await SharedPreferences.getInstance();
      final payload = json.encode(current.map((r) => r.toJson()).toList());
      await prefs.setString(_completedTrailsKey, payload);
      debugPrint('🏁 [COMPLETED TRAILS] Successfully saved trail route: "${route.title}" (${route.distance}km)');
    } catch (e) {
      debugPrint('⚠️ [COMPLETED TRAILS] Error saving trail: $e');
    }
  }

  /// Saves the active completed trip summary for StoryTabScreen display
  static Future<void> saveCompletedSummary(CompletedTripSummary summary) async {
    try {
      latestCompletedSummaryNotifier.value = summary;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_latestSummaryKey, json.encode(summary.toJson()));
      debugPrint('🎉 [COMPLETED TRAILS] Saved latest trip summary for "${summary.planTitle}"');
    } catch (e) {
      debugPrint('⚠️ [COMPLETED TRAILS] Error saving summary: $e');
    }
  }

  /// Clears the active completed trip summary (e.g. when user chooses "Plan Another Trip")
  static Future<void> clearCompletedSummary() async {
    try {
      latestCompletedSummaryNotifier.value = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_latestSummaryKey);
      debugPrint('🧹 [COMPLETED TRAILS] Cleared active completed trip summary');
    } catch (e) {
      debugPrint('⚠️ [COMPLETED TRAILS] Error clearing summary: $e');
    }
  }

  /// Checks if a plan with given ID or title has been completed
  static bool isPlanCompleted(String planId, [String? title]) {
    if (latestCompletedSummaryNotifier.value?.planId == planId) {
      return true;
    }
    for (final trail in completedTrailsNotifier.value) {
      if (trail.planId != null && trail.planId == planId) {
        return true;
      }
      if (title != null &&
          title.trim().isNotEmpty &&
          trail.title.trim().toLowerCase() == title.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// Returns all completed trails (recorded user trails + default sample history)
  static List<TravelPlanRoute> getAllTrails() {
    return [...completedTrailsNotifier.value, ...kDefaultHistoryTrails];
  }

  /// Checks if a place name was visited across recorded completed trails
  static ({bool visited, String? trailTitle, String? date}) checkPlaceVisited(String placeName) {
    final query = placeName.toLowerCase().trim();
    if (query.isEmpty) return (visited: false, trailTitle: null, date: null);

    final all = getAllTrails();
    for (final trail in all) {
      // 1. Check stops array
      for (final s in trail.stops) {
        final sLower = s.toLowerCase().trim();
        if (sLower == query || sLower.contains(query) || query.contains(sLower)) {
          return (visited: true, trailTitle: trail.title, date: trail.date);
        }
      }
      // 2. Check stopDetails
      if (trail.stopDetails != null) {
        for (final s in trail.stopDetails!) {
          final sLower = s.placeName.toLowerCase().trim();
          if (sLower == query || sLower.contains(query) || query.contains(sLower)) {
            return (visited: true, trailTitle: trail.title, date: trail.date);
          }
        }
      }
      // 3. Check stampsEarned
      if (trail.stampsEarned != null) {
        for (final s in trail.stampsEarned!) {
          final sLower = s.title.toLowerCase().trim();
          if (sLower == query || sLower.contains(query) || query.contains(sLower)) {
            return (visited: true, trailTitle: trail.title, date: trail.date);
          }
        }
      }
    }
    return (visited: false, trailTitle: null, date: null);
  }

  /// Returns all unique visited place names across history
  static List<String> getAllVisitedPlaceNames() {
    final names = <String>{};
    for (final trail in getAllTrails()) {
      for (final s in trail.stops) {
        if (s.trim().isNotEmpty) names.add(s.trim());
      }
      if (trail.stopDetails != null) {
        for (final s in trail.stopDetails!) {
          if (s.placeName.trim().isNotEmpty) names.add(s.placeName.trim());
        }
      }
    }
    return names.toList();
  }
}

/// Default completed history trails shown in Travel History
final List<TravelPlanRoute> kDefaultHistoryTrails = [
  TravelPlanRoute(
    title: 'George Town Street Art Hunt',
    date: 'Aug 10, 2026',
    distance: 5.8,
    duration: '2.5 hrs',
    stops: ['Armenian Street Mural', 'Chew Jetty', 'Khoo Kongsi'],
  ),
  TravelPlanRoute(
    title: 'Penang Hill & Kek Lok Si Temple Tour',
    date: 'July 24, 2026',
    distance: 14.2,
    duration: '6.0 hrs',
    stops: ['Ayer Itam Laksa', 'Kek Lok Si Temple', 'Penang Hill Funicular'],
  ),
  TravelPlanRoute(
    title: 'Batu Ferringhi Coastline Walk',
    date: 'June 18, 2026',
    distance: 8.5,
    duration: '3.0 hrs',
    stops: ['Batu Ferringhi Beach', 'Penang National Park', 'Monkey Beach'],
  ),
  TravelPlanRoute(
    title: 'Balik Pulau Food & Heritage Ride',
    date: 'May 02, 2026',
    distance: 22.0,
    duration: '4.5 hrs',
    stops: ['Saei Lemoi Paddy Fields', 'Audi Dream Farm', 'Balik Pulau Town Center'],
  ),
];
