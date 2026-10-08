import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model representing a single saved stop within a saved trip plan
class SavedPlanStop {
  final int stopNumber;
  final String placeName;
  final String area;
  final String category;
  final String timeSlot;
  final String stayDuration;
  final String pennyTip;
  final String? adjustmentReason;
  final bool isAdjusted;
  final String? imageUrl;
  final String? address;
  final double lat;
  final double lng;

  const SavedPlanStop({
    required this.stopNumber,
    required this.placeName,
    required this.area,
    required this.category,
    required this.timeSlot,
    required this.stayDuration,
    required this.pennyTip,
    this.adjustmentReason,
    this.isAdjusted = false,
    this.imageUrl,
    this.address,
    this.lat = 5.414,
    this.lng = 100.328,
  });

  Map<String, dynamic> toJson() => {
    'stopNumber': stopNumber,
    'placeName': placeName,
    'area': area,
    'category': category,
    'timeSlot': timeSlot,
    'stayDuration': stayDuration,
    'pennyTip': pennyTip,
    'adjustmentReason': adjustmentReason,
    'isAdjusted': isAdjusted,
    'imageUrl': imageUrl,
    'address': address,
    'lat': lat,
    'lng': lng,
  };

  factory SavedPlanStop.fromJson(Map<String, dynamic> json) => SavedPlanStop(
    stopNumber: (json['stopNumber'] as num?)?.toInt() ?? 1,
    placeName: (json['placeName'] ?? 'Penang Attraction').toString(),
    area: (json['area'] ?? 'George Town').toString(),
    category: (json['category'] ?? 'Attraction').toString(),
    timeSlot: (json['timeSlot'] ?? '09:00 AM - 10:00 AM').toString(),
    stayDuration: (json['stayDuration'] ?? '60 min').toString(),
    pennyTip: (json['pennyTip'] ?? '').toString(),
    adjustmentReason: json['adjustmentReason']?.toString(),
    isAdjusted: json['isAdjusted'] == true,
    imageUrl: json['imageUrl']?.toString(),
    address: json['address']?.toString(),
    lat: (json['lat'] as num?)?.toDouble() ?? 5.414,
    lng: (json['lng'] as num?)?.toDouble() ?? 100.328,
  );
}

/// Model representing a full saved Penang itinerary plan
class SavedTripPlan {
  final String id;
  final String title;
  final DateTime savedAt;
  final String travelDateRange; // e.g. "2026-10-16 to 2026-10-17"
  final String travelSchedule; // e.g. "09:00 AM – 05:00 PM"
  final String? travelArea; // e.g. "George Town, Ayer Itam"
  final String pennyOverviewMessage;
  final String? pennyModificationMessage;
  final List<SavedPlanStop> stops;

  const SavedTripPlan({
    required this.id,
    required this.title,
    required this.savedAt,
    required this.travelDateRange,
    required this.travelSchedule,
    this.travelArea,
    required this.pennyOverviewMessage,
    this.pennyModificationMessage,
    required this.stops,
  });

  String get cleanTitle {
    final stopsRegex = RegExp(r'\s*\(\d+\s*stops\)$', caseSensitive: false);
    final cleaned = title.replaceAll(stopsRegex, '').trim();
    return cleaned.isEmpty ? 'Penang Itinerary' : cleaned;
  }

  String get displayArea {
    if (travelArea != null && travelArea!.trim().isNotEmpty) {
      return travelArea!.trim();
    }
    final areas = stops
        .map((s) => s.area.trim())
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'null')
        .toSet()
        .toList();
    if (areas.isEmpty) return 'George Town & Penang';
    return areas.join(', ');
  }

  SavedTripPlan copyWith({
    String? id,
    String? title,
    DateTime? savedAt,
    String? travelDateRange,
    String? travelSchedule,
    String? travelArea,
    String? pennyOverviewMessage,
    String? pennyModificationMessage,
    List<SavedPlanStop>? stops,
  }) {
    return SavedTripPlan(
      id: id ?? this.id,
      title: title ?? this.title,
      savedAt: savedAt ?? this.savedAt,
      travelDateRange: travelDateRange ?? this.travelDateRange,
      travelSchedule: travelSchedule ?? this.travelSchedule,
      travelArea: travelArea ?? this.travelArea,
      pennyOverviewMessage: pennyOverviewMessage ?? this.pennyOverviewMessage,
      pennyModificationMessage: pennyModificationMessage ?? this.pennyModificationMessage,
      stops: stops ?? this.stops,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'savedAt': savedAt.toIso8601String(),
    'travelDateRange': travelDateRange,
    'travelSchedule': travelSchedule,
    'travelArea': travelArea ?? displayArea,
    'pennyOverviewMessage': pennyOverviewMessage,
    'pennyModificationMessage': pennyModificationMessage,
    'stops': stops.map((s) => s.toJson()).toList(),
  };

  factory SavedTripPlan.fromJson(Map<String, dynamic> json) {
    String loadedTitle = (json['title'] ?? 'Penang Itinerary').toString();
    // Clean up any legacy title that appended " (x stops)"
    final stopsRegex = RegExp(r'\s*\(\d+\s*stops\)$', caseSensitive: false);
    if (stopsRegex.hasMatch(loadedTitle)) {
      loadedTitle = loadedTitle.replaceAll(stopsRegex, '').trim();
      if (loadedTitle.isEmpty) loadedTitle = 'Penang Itinerary';
    }

    return SavedTripPlan(
      id: (json['id'] ?? '').toString(),
      title: loadedTitle,
      savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      travelDateRange: (json['travelDateRange'] ?? '').toString(),
      travelSchedule: (json['travelSchedule'] ?? '09:00 AM – 05:00 PM').toString(),
      travelArea: json['travelArea']?.toString(),
      pennyOverviewMessage: (json['pennyOverviewMessage'] ?? '').toString(),
      pennyModificationMessage: json['pennyModificationMessage']?.toString(),
      stops: (json['stops'] as List? ?? [])
          .map((e) => SavedPlanStop.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Central manager for saving, loading, and deleting saved trip plans
class SavedTripPlansManager {
  static const String _storageKey = 'kiapenang_saved_trip_plans';

  static final ValueNotifier<List<SavedTripPlan>> savedPlansNotifier =
      ValueNotifier<List<SavedTripPlan>>([]);

  static List<SavedTripPlan> get savedPlans => savedPlansNotifier.value;

  /// Initialize and load saved plans from persistent storage
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final List<SavedTripPlan> loaded = [];
      for (final raw in rawList) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map<String, dynamic>) {
            loaded.add(SavedTripPlan.fromJson(decoded));
          }
        } catch (e) {
          debugPrint('Error parsing saved trip plan: $e');
        }
      }
      savedPlansNotifier.value = loaded;
    } catch (e) {
      debugPrint('Error loading saved trip plans: $e');
    }
  }

  /// Save or update a trip plan
  static Future<void> savePlan(SavedTripPlan plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<SavedTripPlan>.from(savedPlansNotifier.value);

      // Check if plan with same ID or title already exists, update if so
      final existingIndex = current.indexWhere((p) => p.id == plan.id);
      if (existingIndex >= 0) {
        current[existingIndex] = plan;
      } else {
        current.insert(0, plan);
      }

      final encodedList = current.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, encodedList);
      savedPlansNotifier.value = current;
    } catch (e) {
      debugPrint('Error saving trip plan: $e');
    }
  }

  /// Update the title of a saved plan by ID
  static Future<void> updatePlanTitle(String planId, String newTitle) async {
    try {
      final current = List<SavedTripPlan>.from(savedPlansNotifier.value);
      final index = current.indexWhere((p) => p.id == planId);
      if (index >= 0) {
        final sanitized = newTitle.trim().isEmpty ? 'Penang Itinerary' : newTitle.trim();
        final updated = current[index].copyWith(title: sanitized);
        current[index] = updated;
        final prefs = await SharedPreferences.getInstance();
        final encodedList = current.map((p) => json.encode(p.toJson())).toList();
        await prefs.setStringList(_storageKey, encodedList);
        savedPlansNotifier.value = current;
      }
    } catch (e) {
      debugPrint('Error updating plan title: $e');
    }
  }

  /// Delete a saved trip plan by ID
  static Future<void> deletePlan(String planId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = List<SavedTripPlan>.from(savedPlansNotifier.value);
      current.removeWhere((p) => p.id == planId);

      final encodedList = current.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, encodedList);
      savedPlansNotifier.value = current;
    } catch (e) {
      debugPrint('Error deleting saved trip plan: $e');
    }
  }
}
