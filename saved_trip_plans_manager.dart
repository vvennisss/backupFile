import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String? sharedCode;
  final List<SavedPlanStop> stops;

  const SavedTripPlan({
    required this.id,
    required this.title,
    required this.savedAt,
    required this.travelDateRange,
    required this.travelSchedule,
    this.travelArea,
    this.pennyOverviewMessage = '',
    this.pennyModificationMessage,
    this.sharedCode,
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
    String? sharedCode,
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
      sharedCode: sharedCode ?? this.sharedCode,
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
    'sharedCode': sharedCode,
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
      sharedCode: json['sharedCode']?.toString(),
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

  static final ValueNotifier<String?> selectedPlanIdNotifier =
      ValueNotifier<String?>(null);

  static String? get selectedPlanId => selectedPlanIdNotifier.value;

  static void setSelectedPlanId(String? id) {
    selectedPlanIdNotifier.value = id;
  }

  /// Determines if a plan's scheduled travel date has completely ended/passed before today.
  static bool isPlanExpired(SavedTripPlan plan) {
    final raw = plan.travelDateRange.trim();
    if (raw.isEmpty || raw.toLowerCase().contains('unselected')) {
      return false; // Not scheduled yet, kept in active plans
    }

    final dates = <DateTime>[];

    // 1. Check ISO matches YYYY-MM-DD
    final isoMatches = RegExp(r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})').allMatches(raw);
    for (final m in isoMatches) {
      dates.add(DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!)));
    }

    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

    // 2. Check Text matches day-first: e.g. 14 Oct 2026 or 14 October 2026
    if (dates.isEmpty) {
      final textMatches = RegExp(r'(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{4})').allMatches(raw);
      for (final m in textMatches) {
        final day = int.parse(m.group(1)!);
        final monthStr = m.group(2)!;
        final monthName = monthStr.length >= 3 ? monthStr.substring(0, 3).toLowerCase() : '';
        final year = int.parse(m.group(3)!);
        final monthIdx = months.indexOf(monthName);
        if (monthIdx != -1) {
          dates.add(DateTime(year, monthIdx + 1, day));
        }
      }
    }

    // 3. Check Text matches month-first: e.g. Oct 14, 2026 or August 10, 2026
    if (dates.isEmpty) {
      final monthFirstMatches = RegExp(r'([a-zA-Z]{3,9})\s+(\d{1,2}),?\s+(\d{4})').allMatches(raw);
      for (final m in monthFirstMatches) {
        final monthStr = m.group(1)!;
        final monthName = monthStr.length >= 3 ? monthStr.substring(0, 3).toLowerCase() : '';
        final day = int.parse(m.group(2)!);
        final year = int.parse(m.group(3)!);
        final monthIdx = months.indexOf(monthName);
        if (monthIdx != -1) {
          dates.add(DateTime(year, monthIdx + 1, day));
        }
      }
    }

    if (dates.isEmpty) return false;

    final lastDate = dates.last;
    final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return lastDay.isBefore(today);
  }

  /// Initialize and load saved plans from persistent storage and Firestore
  static Future<void> init() async {
    // 1. Load from local cache first for instant UI response
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

    // 2. Sync with Firebase Firestore (downloads remote plans and uploads local plans)
    await syncWithFirestore();
  }

  /// Syncs saved trip plans with Firestore:
  /// - Downloads cloud plans for the current authenticated user
  /// - Automatically uploads any local plans (like current Penang Itinerary) to Firestore
  static Future<void> syncWithFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedTripPlans');

      final snapshot = await collection.get();
      final currentLocal = List<SavedTripPlan>.from(savedPlansNotifier.value);
      final List<SavedTripPlan> mergedPlans = [];
      final Set<String> processedIds = {};

      // 1. Process plans retrieved from Firestore
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final plan = SavedTripPlan.fromJson(data);
          mergedPlans.add(plan);
          processedIds.add(plan.id);
        } catch (e) {
          debugPrint('Error parsing Firestore trip plan ${doc.id}: $e');
        }
      }

      // 2. Upload any local plans not yet in Firestore (e.g. current Penang Itinerary)
      for (final localPlan in currentLocal) {
        if (!processedIds.contains(localPlan.id)) {
          final docId = localPlan.id.isNotEmpty
              ? localPlan.id
              : 'plan_${localPlan.savedAt.millisecondsSinceEpoch}';
          final planToSave = localPlan.id.isNotEmpty
              ? localPlan
              : localPlan.copyWith(id: docId);

          await collection.doc(docId).set(planToSave.toJson());
          mergedPlans.add(planToSave);
          processedIds.add(docId);
        }
      }

      // 3. Sort plans newest first
      mergedPlans.sort((a, b) => b.savedAt.compareTo(a.savedAt));

      // 4. Update notifier & persistent local cache
      savedPlansNotifier.value = mergedPlans;
      final prefs = await SharedPreferences.getInstance();
      final encodedList = mergedPlans.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, encodedList);

      // 5. Update user doc counter in Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlans': mergedPlans.length,
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('Error syncing saved trip plans with Firestore: $e');
    }
  }

  /// Save or update a trip plan
  static Future<void> savePlan(SavedTripPlan plan) async {
    try {
      // Ensure valid ID
      final planId = plan.id.isNotEmpty ? plan.id : 'plan_${DateTime.now().millisecondsSinceEpoch}';
      final planToSave = plan.id.isNotEmpty ? plan : plan.copyWith(id: planId);

      final prefs = await SharedPreferences.getInstance();
      final current = List<SavedTripPlan>.from(savedPlansNotifier.value);

      final existingIndex = current.indexWhere((p) => p.id == planToSave.id);
      if (existingIndex >= 0) {
        current[existingIndex] = planToSave;
      } else {
        current.insert(0, planToSave);
      }

      final encodedList = current.map((p) => json.encode(p.toJson())).toList();
      await prefs.setStringList(_storageKey, encodedList);
      savedPlansNotifier.value = current;

      // Persist to Firebase Firestore if authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedTripPlans')
            .doc(planToSave.id)
            .set(planToSave.toJson());

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlans': current.length,
        }, SetOptions(merge: true));
      }
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

        // Update in Firestore
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('savedTripPlans')
              .doc(planId)
              .update({'title': sanitized});
        }
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

      // Delete from Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedTripPlans')
            .doc(planId)
            .delete();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlans': current.length,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error deleting saved trip plan: $e');
    }
  }

  /// Clear local plans on user logout
  static Future<void> clearOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    savedPlansNotifier.value = [];
  }

  /// Generate a 6-digit trip sharing code
  static String _generateShareCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 900000 + 100000;
    return random.toString();
  }

  /// Share a saved trip plan to Firebase and return the 6-digit access code
  static Future<String> sharePlanToFirebase(SavedTripPlan plan) async {
    try {
      // 1. Check if plan already has an active shared code
      String code = plan.sharedCode ?? '';
      if (code.isEmpty || code.length != 6) {
        code = _generateShareCode();
      }

      final user = FirebaseAuth.instance.currentUser;
      final leaderName = (user?.displayName?.isNotEmpty == true)
          ? user!.displayName!
          : (user?.email?.split('@').first ?? 'Lead Traveler');

      // 2. Prepare payload for sharedTrips collection
      final tripPayload = {
        'code': code,
        'planId': plan.id,
        'title': plan.cleanTitle,
        'leader': leaderName,
        'leaderUid': user?.uid ?? 'anonymous',
        'createdAt': FieldValue.serverTimestamp(),
        'travelDateRange': plan.travelDateRange,
        'travelSchedule': plan.travelSchedule,
        'travelArea': plan.displayArea,
        'initialLeaderCommand': 'Regroup at the next attraction in 15 minutes.',
        'nextStopCountdownMinutes': 25,
        'leadLocation': {
          'lat': plan.stops.isNotEmpty ? plan.stops.first.lat : 5.4180,
          'lng': plan.stops.isNotEmpty ? plan.stops.first.lng : 100.3380,
          'name': '$leaderName (Lead Traveler)',
        },
        'stops': plan.stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          return {
            'id': idx + 1,
            'title': s.placeName,
            'time': s.timeSlot,
            'stay': s.stayDuration,
            'category': s.category,
            'area': s.area,
            'lat': s.lat,
            'lng': s.lng,
            'tip': s.pennyTip.isNotEmpty ? s.pennyTip : 'Explore and enjoy this stop with your team.',
            'isCurrent': idx == 0,
          };
        }).toList(),
      };

      // 3. Store in Firestore under root collection `sharedTrips`
      await FirebaseFirestore.instance.collection('sharedTrips').doc(code).set(tripPayload);

      // 4. Update the local SavedTripPlan with the sharedCode
      final updatedPlan = plan.copyWith(sharedCode: code);
      await savePlan(updatedPlan);

      return code;
    } catch (e) {
      debugPrint('Error sharing trip plan to Firebase: $e');
      rethrow;
    }
  }
}
