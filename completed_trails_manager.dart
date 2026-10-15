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
}
