import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/weather_service.dart';
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../services/stamps_service.dart';
import '../services/completed_trails_manager.dart';

// --- MASCOT STATES ---
enum MascotState {
  idle,
  thinking,
  happy,
  success,
  shocked,
  sad,
  flyAway,
}

extension MascotStateExtension on MascotState {
  String get assetPath {
    switch (this) {
      case MascotState.idle:
        return 'assets/pink-bird-idle.gif';
      case MascotState.thinking:
        return 'assets/pink-bird-thinking.gif';
      case MascotState.happy:
        return 'assets/pink-bird-happy.gif';
      case MascotState.success:
        return 'assets/pink-bird-success.gif';
      case MascotState.shocked:
        return 'assets/pink-bird-shock.gif';
      case MascotState.sad:
        return 'assets/pink-bird-sad.gif';
      case MascotState.flyAway:
        return 'assets/pink-bird-fly-away.gif';
    }
  }

  String get moodLabel {
    switch (this) {
      case MascotState.idle:
        return 'Ready to Help';
      case MascotState.thinking:
        return 'Crafting Plan...';
      case MascotState.happy:
        return 'Excited!';
      case MascotState.success:
        return 'Trip Ready!';
      case MascotState.shocked:
        return 'Route Conflict!';
      case MascotState.sad:
        return 'Item Removed';
      case MascotState.flyAway:
        return 'Off to Map...';
    }
  }

  Color get moodColor {
    switch (this) {
      case MascotState.idle:
        return const Color(0xFF3B82F6);
      case MascotState.thinking:
        return const Color(0xFFF59E0B);
      case MascotState.happy:
        return const Color(0xFF10B981);
      case MascotState.success:
        return const Color(0xFF059669);
      case MascotState.shocked:
        return const Color(0xFFEF4444);
      case MascotState.sad:
        return const Color(0xFF6B7280);
      case MascotState.flyAway:
        return const Color(0xFF8B5CF6);
    }
  }
}

// --- TIMELINE CONTRACT MODELS ---
abstract class TimelineItem {
  final String type; // 'stop' or 'free_time'
  final String timeSlot;

  const TimelineItem({
    required this.type,
    required this.timeSlot,
  });
}

class TimelineStopItem extends TimelineItem {
  final String placeName;
  final String area;
  final String category;
  final double lat;
  final double lng;
  final String tip;
  final String? warningFlag; // 'PEAK_HEAT', 'CLOSED', or null
  final bool isAdjusted;
  final String? adjustmentReason;

  const TimelineStopItem({
    required this.placeName,
    required this.area,
    required this.category,
    required this.lat,
    required this.lng,
    required super.timeSlot,
    required this.tip,
    this.warningFlag,
    this.isAdjusted = false,
    this.adjustmentReason,
  }) : super(type: 'stop');

  bool get isPeakHeat => warningFlag == 'PEAK_HEAT';
  bool get isClosed => warningFlag == 'CLOSED';
  bool get isTimeConflict => warningFlag == 'TIME_CONFLICT';

  factory TimelineStopItem.fromJson(Map<String, dynamic> json) {
    return TimelineStopItem(
      placeName: (json['place_name'] ?? json['name'] ?? 'Penang Place').toString(),
      area: (json['area'] ?? 'Penang').toString(),
      category: (json['category'] ?? 'Attraction').toString(),
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 5.414,
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : 100.328,
      timeSlot: (json['time_slot'] ?? '10:00 AM - 11:30 AM').toString(),
      tip: (json['tip'] ?? 'Recommended Penang attraction').toString(),
      warningFlag: json['warning_flag']?.toString(),
      isAdjusted: json['is_adjusted'] == true,
      adjustmentReason: json['adjustment_reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'stop',
    'place_name': placeName,
    'area': area,
    'category': category,
    'lat': lat,
    'lng': lng,
    'time_slot': timeSlot,
    'tip': tip,
    'warning_flag': warningFlag,
    'is_adjusted': isAdjusted,
    'adjustment_reason': adjustmentReason,
  };
}

class WeatherRecommendation {
  final String id;
  final String name;
  final String area;
  final String category;
  final double lat;
  final double lng;
  final String imageUrl;
  final String suggestedVisitTime;
  final String reason;
  final String businessHours;
  final String description;

  const WeatherRecommendation({
    required this.id,
    required this.name,
    required this.area,
    required this.category,
    required this.lat,
    required this.lng,
    required this.imageUrl,
    required this.suggestedVisitTime,
    required this.reason,
    this.businessHours = '9:00 AM - 6:00 PM',
    this.description = '',
  });

  factory WeatherRecommendation.fromJson(Map<String, dynamic> json) {
    return WeatherRecommendation(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      area: (json['area'] ?? 'Penang').toString(),
      category: (json['category'] ?? 'Indoor Attraction').toString(),
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 5.416,
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : 100.33,
      imageUrl: (json['imageUrl'] ?? json['image'] ?? '').toString(),
      suggestedVisitTime: (json['suggestedVisitTime'] ?? json['suggested_visit_time'] ?? '12:30 PM - 02:00 PM').toString(),
      reason: (json['reason'] ?? 'Indoor shelter escaping weather conflict.').toString(),
      businessHours: (json['businessHours'] ?? json['business_hours'] ?? '9:00 AM - 6:00 PM').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }

  ItineraryPlace toItineraryPlace() {
    return ItineraryPlace(
      id: id,
      name: name,
      area: area,
      description: description.isNotEmpty ? description : reason,
      lat: lat,
      lng: lng,
      category: category,
      imageUrl: imageUrl,
      businessHours: businessHours,
      estimatedStayMinutes: 60,
      tip: reason,
      bestVisitTime: suggestedVisitTime,
    );
  }
}

class FreeTimeOptions {
  final String optionA;
  final String optionB;
  final String optionC;

  const FreeTimeOptions({
    required this.optionA,
    required this.optionB,
    required this.optionC,
  });

  factory FreeTimeOptions.fromJson(Map<String, dynamic>? json) {
    return FreeTimeOptions(
      optionA: json?['A']?.toString() ?? 'Explore local cafes and street art nearby.',
      optionB: json?['B']?.toString() ?? 'Head early towards the next area for seaside views.',
      optionC: json?['C']?.toString() ?? 'Free exploration or rest at accommodation.',
    );
  }
}

class TimelineFreeTimeItem extends TimelineItem {
  final String duration;
  final FreeTimeOptions options;

  const TimelineFreeTimeItem({
    required super.timeSlot,
    required this.duration,
    required this.options,
  }) : super(type: 'free_time');

  factory TimelineFreeTimeItem.fromJson(Map<String, dynamic> json) {
    return TimelineFreeTimeItem(
      timeSlot: (json['time_slot'] ?? '01:30 PM - 03:00 PM').toString(),
      duration: (json['duration'] ?? '1.5 hours').toString(),
      options: FreeTimeOptions.fromJson(json['options'] is Map<String, dynamic> ? json['options'] as Map<String, dynamic> : null),
    );
  }
}

class WeatherAlertInfo {
  final bool isRainy;
  final String condition;
  final String description;
  final String date;
  final String message;

  const WeatherAlertInfo({
    required this.isRainy,
    required this.condition,
    required this.description,
    required this.date,
    required this.message,
  });

  factory WeatherAlertInfo.fromJson(Map<String, dynamic> json) {
    return WeatherAlertInfo(
      isRainy: json['is_rainy'] == true,
      condition: (json['condition'] ?? 'Rain').toString(),
      description: (json['description'] ?? 'Rain showers forecasted').toString(),
      date: (json['date'] ?? '').toString(),
      message: (json['message'] ?? 'Rain is forecasted for your travel date. We have prepared an indoor backup plan.').toString(),
    );
  }
}

// --- PENANG AREA & STAY DURATION INTELLIGENCE ---

/// Resolves a specific Penang locality/district from postcodes, place names, and descriptions.
String resolveSpecificPenangArea({
  required String placeName,
  String? area,
  String? address,
  String? description,
}) {
  // 0. If area is already specified and valid (not generic 'Penang' / 'Pulau Pinang' / 'Malaysia'), prioritize it directly!
  if (area != null &&
      area.trim().isNotEmpty &&
      area.trim().toLowerCase() != 'penang' &&
      area.trim().toLowerCase() != 'pulau pinang' &&
      area.trim().toLowerCase() != 'malaysia') {
    final lowerArea = area.trim().toLowerCase();
    if (lowerArea == 'georgetown') return 'George Town';
    if (lowerArea == 'ayer itam') return 'Air Itam';
    return area.trim();
  }

  final combined = '$placeName ${address ?? ''} ${description ?? ''}'.toLowerCase();

  // 1. Postcode detection (Penang postcodes: 10000 - 14400)
  final postcodeRegex = RegExp(r'\b(1[0-4]\d{3})\b');
  final match = postcodeRegex.firstMatch('${address ?? ''} ${description ?? ''} $placeName');
  if (match != null) {
    final code = int.tryParse(match.group(1) ?? '') ?? 0;
    if (code >= 10000 && code <= 10200) return 'George Town';
    if (code == 10250 || code == 10350) return 'Pulau Tikus';
    if (code == 10450) return 'George Town';
    if (code == 10470) return 'Tanjung Tokong';
    if (code == 11000 || code == 11010 || code == 11020) return 'Balik Pulau';
    if (code == 11050) return 'Teluk Bahang';
    if (code == 11100) return 'Batu Ferringhi';
    if (code == 11200) return 'Tanjung Bungah';
    if (code == 11300 || code == 11400 || code == 11500) return 'Air Itam';
    if (code == 11600) return 'Jelutong';
    if (code == 11700) return 'Gelugor';
    if (code == 11900 || code == 11920) return 'Bayan Lepas';
    if (code == 11950) return 'Bayan Baru';
    if (code >= 12000 && code <= 13800) return 'Butterworth';
    if (code >= 14000 && code <= 14400) return 'Bukit Mertajam';
  }

  // 2. High-priority keyword matches in Place Name / Combined text
  if (combined.contains('batu ferringhi') || combined.contains('ferringhi') || combined.contains('miami beach')) {
    return 'Batu Ferringhi';
  }
  final lowerName = placeName.toLowerCase();
  final isEscapeThemePark = lowerName.contains('escape') ||
      combined.contains('escape penang') ||
      combined.contains('escape theme park') ||
      combined.contains('escape adventureplay') ||
      combined.contains('escape waterplay');
  if (combined.contains('teluk bahang') ||
      isEscapeThemePark ||
      combined.contains('entopia') ||
      combined.contains('butterfly farm') ||
      combined.contains('monkey beach') ||
      combined.contains('pantai kerachut') ||
      combined.contains('penang national park') ||
      combined.contains('taman negara')) {
    return 'Teluk Bahang';
  }
  if (combined.contains('air itam') ||
      combined.contains('ayer itam') ||
      combined.contains('kek lok si') ||
      combined.contains('penang hill') ||
      combined.contains('bukit bendera') ||
      combined.contains('the habitat')) {
    return 'Air Itam';
  }
  if (combined.contains('tanjung bungah') || combined.contains('floating mosque')) {
    return 'Tanjung Bungah';
  }
  if (combined.contains('tanjung tokong') || combined.contains('straits quay') || combined.contains('lotus tanjung')) {
    return 'Tanjung Tokong';
  }
  if (combined.contains('pulau tikus') ||
      combined.contains('gurney') ||
      combined.contains('dhammikarama') ||
      combined.contains('wat chayamangkalaram')) {
    return 'Pulau Tikus';
  }
  if (combined.contains('bayan lepas') ||
      combined.contains('snake temple') ||
      combined.contains('war museum') ||
      combined.contains('penang airport')) {
    return 'Bayan Lepas';
  }
  if (combined.contains('bayan baru') || combined.contains('queensbay')) {
    return 'Bayan Lepas';
  }
  if (combined.contains('balik pulau') ||
      combined.contains('audi dream farm') ||
      combined.contains('nutmeg factory') ||
      combined.contains('kim laksa')) {
    return 'Balik Pulau';
  }
  if (combined.contains('butterworth') ||
      combined.contains('raja uda') ||
      combined.contains('tow boo kong') ||
      combined.contains('bird park') ||
      combined.contains('sunway carnival')) {
    return 'Butterworth';
  }
  if (combined.contains('bukit mertajam') || combined.contains('st anne')) {
    return 'Bukit Mertajam';
  }
  if (combined.contains('gelugor') || combined.contains('usm')) {
    return 'Gelugor';
  }
  if (combined.contains('jelutong')) {
    return 'Jelutong';
  }
  if (combined.contains('george town') ||
      combined.contains('georgetown') ||
      combined.contains('chew jetty') ||
      combined.contains('clan jetty') ||
      combined.contains('jetties') ||
      combined.contains('peranakan') ||
      combined.contains('blue mansion') ||
      combined.contains('cheong fatt tze') ||
      combined.contains('khoo kongsi') ||
      combined.contains('fort cornwallis') ||
      combined.contains('street art') ||
      combined.contains('armenian') ||
      combined.contains('chulia') ||
      combined.contains('love lane') ||
      combined.contains('beach street') ||
      combined.contains('weld quay') ||
      combined.contains('campbell') ||
      combined.contains('kimberley') ||
      combined.contains('komtar') ||
      combined.contains('little india') ||
      combined.contains('kapitan keling') ||
      combined.contains('daily dose') ||
      combined.contains('toh soon') ||
      combined.contains('new lane')) {
    return 'George Town';
  }

  // 3. Default to George Town
  return 'George Town';
}

/// Dynamically calculates recommended stay duration (minutes) for a Penang place.
int calculateDynamicStayDuration({
  required String name,
  required String category,
  String? description,
  int? currentStayMinutes,
}) {
  // If stay duration is explicitly budgeted, prioritize it directly
  if (currentStayMinutes != null && currentStayMinutes > 0) {
    return currentStayMinutes;
  }

  final n = name.toLowerCase();
  final c = category.toLowerCase();
  final d = (description ?? '').toLowerCase();

  // 1. Theme parks & mega adventure parks: 180 mins (3h)
  if (n.contains('escape') || n.contains('entopia') || c.contains('adventure') || c.contains('theme park')) {
    return 180;
  }

  // 2. Heritage building that can tour (Mansions, Khoo Kongsi, Museums, Forts): 120 mins (2h)
  if (n.contains('mansion') ||
      n.contains('peranakan') ||
      n.contains('cheong fatt tze') ||
      n.contains('blue mansion') ||
      n.contains('khoo kongsi') ||
      n.contains('fort cornwallis') ||
      n.contains('leong san tong') ||
      c.contains('museum') ||
      c.contains('gallery') ||
      d.contains('guided tour') ||
      d.contains('ancestral mansion') ||
      d.contains('clanhouse') ||
      d.contains('heritage tour')) {
    return 120;
  }

  // 3. Nature parks, hills & discovery trails: 120 mins (2h)
  if (n.contains('penang hill') ||
      n.contains('bukit bendera') ||
      n.contains('the habitat') ||
      n.contains('national park') ||
      n.contains('spice garden')) {
    return 120;
  }

  // 4. Cafes, Hawker Centers, Food Courts & Kopitiams: 90 mins (1h30m)
  if (c.contains('cafe') ||
      c.contains('hawker') ||
      c.contains('food') ||
      c.contains('restaurant') ||
      c.contains('kopitiam') ||
      c.contains('dining') ||
      c.contains('dessert') ||
      n.contains('cafe') ||
      n.contains('hawker') ||
      n.contains('kopitiam') ||
      n.contains('coffee') ||
      n.contains('laksa') ||
      n.contains('daily dose') ||
      n.contains('toh soon') ||
      n.contains('new lane') ||
      n.contains('kimberley')) {
    return 90;
  }

  // 5. Shopping Malls & Lifestyle Centers: 90 mins (1h30m)
  if (c.contains('shopping') ||
      c.contains('mall') ||
      n.contains('plaza') ||
      n.contains('mall') ||
      n.contains('straits quay')) {
    return 90;
  }

  // 6. Clan Jetties: 45 mins
  if (n.contains('jetty') || n.contains('jetties') || c.contains('clan jetty')) {
    return 45;
  }

  // 7. Street Art & Murals: 45 mins
  if (n.contains('street art') ||
      n.contains('mural') ||
      c.contains('art') ||
      c.contains('mural') ||
      n.contains('armenian street')) {
    return 45;
  }

  // 8. Places of worship / Temples / Mosques: 60 mins (1h)
  if (c.contains('worship') ||
      c.contains('temple') ||
      c.contains('mosque') ||
      c.contains('church') ||
      n.contains('kek lok si') ||
      n.contains('temple') ||
      n.contains('mosque') ||
      n.contains('church') ||
      n.contains('pagoda')) {
    return 60;
  }

  // 9. Beaches & Coastal spots: 60 mins (1h)
  if (c.contains('beach') || n.contains('beach') || n.contains('pantai')) {
    return 60;
  }

  // 10. Night Markets (Pasar Malam): 60 mins (1h)
  if (c.contains('night market') || n.contains('pasar malam') || n.contains('night market')) {
    return 60;
  }

  // 11. Countryside farms & orchards: 60 mins (1h)
  if (n.contains('farm') || n.contains('factory') || c.contains('country')) {
    return 60;
  }

  // If currentStayMinutes is explicitly set and not the default 60
  if (currentStayMinutes != null && currentStayMinutes > 0 && currentStayMinutes != 60) {
    return currentStayMinutes;
  }

  // Default fallback: 60 mins (1h)
  return 60;
}

/// Formats minutes into human-readable stay duration string (e.g. "90 min (1h30m)", "120 min (2h)", "45 min").
String formatStayDuration(int mins) {
  if (mins >= 60) {
    final hours = mins ~/ 60;
    final rem = mins % 60;
    if (rem == 0) {
      return '$mins min (${hours}h)';
    } else {
      return '$mins min (${hours}h${rem}m)';
    }
  }
  return '$mins min';
}

// --- ITINERARY MODELS ---
class ItineraryPlace {
  final String id;
  final String name;
  final String area;
  final String description;
  final double lat;
  final double lng;
  final String category;
  final int estimatedStayMinutes;
  final IconData icon;
  final String? bestVisitTime;
  final String? timeReason;
  final String? warningFlag;
  final String? address;
  // --- Extended fields for Draft Page tags ---
  final String? primaryCategory;
  final List<String> subCategories;
  final Map<String, bool> features;
  final dynamic openingHours;
  final String? businessHours;
  final String? imageUrl;
  final String? tip;
  final bool isAdjusted;
  final String? adjustmentReason;
  final String? suggestedVisitTime;

  const ItineraryPlace({
    required this.id,
    required this.name,
    required this.area,
    required this.description,
    required this.lat,
    required this.lng,
    required this.category,
    this.estimatedStayMinutes = 60,
    this.icon = Icons.place,
    this.bestVisitTime,
    this.timeReason,
    this.warningFlag,
    this.address,
    this.primaryCategory,
    this.subCategories = const [],
    this.features = const {},
    this.openingHours,
    this.businessHours,
    this.imageUrl,
    this.tip,
    this.isAdjusted = false,
    this.adjustmentReason,
    this.suggestedVisitTime,
  });

  /// Specific Penang area resolved dynamically via postcodes, keywords, and known districts.
  String get specificArea => resolveSpecificPenangArea(
    placeName: name,
    area: area,
    address: address,
    description: description,
  );

  /// Dynamically calculated stay duration in minutes based on category and place type.
  int get dynamicStayMinutes => estimatedStayMinutes > 0
      ? estimatedStayMinutes
      : calculateDynamicStayDuration(
          name: name,
          category: category,
          description: description,
          currentStayMinutes: estimatedStayMinutes,
        );

  /// Human-readable stay duration string (e.g. "90 min (1h30m)", "120 min (2h)", "45 min").
  String get formattedStayDuration => formatStayDuration(dynamicStayMinutes);

  ItineraryPlace copyWith({
    String? id,
    String? name,
    String? area,
    String? description,
    double? lat,
    double? lng,
    String? category,
    int? estimatedStayMinutes,
    IconData? icon,
    String? bestVisitTime,
    String? timeReason,
    String? warningFlag,
    String? address,
    String? primaryCategory,
    List<String>? subCategories,
    Map<String, bool>? features,
    dynamic openingHours,
    String? businessHours,
    String? imageUrl,
    String? tip,
    bool? isAdjusted,
    String? adjustmentReason,
    String? suggestedVisitTime,
  }) {
    return ItineraryPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      area: area ?? this.area,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      category: category ?? this.category,
      estimatedStayMinutes: estimatedStayMinutes ?? this.estimatedStayMinutes,
      icon: icon ?? this.icon,
      bestVisitTime: bestVisitTime ?? this.bestVisitTime,
      timeReason: timeReason ?? this.timeReason,
      warningFlag: warningFlag ?? this.warningFlag,
      address: address ?? this.address,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      subCategories: subCategories ?? this.subCategories,
      features: features ?? this.features,
      openingHours: openingHours ?? this.openingHours,
      businessHours: businessHours ?? this.businessHours,
      imageUrl: imageUrl ?? this.imageUrl,
      tip: tip ?? this.tip,
      isAdjusted: isAdjusted ?? this.isAdjusted,
      adjustmentReason: adjustmentReason ?? this.adjustmentReason,
      suggestedVisitTime: suggestedVisitTime ?? this.suggestedVisitTime,
    );
  }
}

class ItineraryTrip {
  final String id;
  final String title;
  final List<ItineraryPlace> places;
  final List<TimelineItem> timeline;
  final DateTime createdAt;
  final DateTimeRange? travelDates;
  final TimeOfDay? departTime;
  final TimeOfDay? endTripTime;
  final bool isCompleted;

  ItineraryTrip({
    required this.id,
    required this.title,
    required this.places,
    this.timeline = const [],
    required this.createdAt,
    this.travelDates,
    this.departTime,
    this.endTripTime,
    this.isCompleted = false,
  });

  double get totalEstimatedHours {
    int totalMins = 0;
    for (var p in places) {
      totalMins += p.estimatedStayMinutes;
    }
    if (places.length > 1) {
      totalMins += (places.length - 1) * 20;
    }
    return totalMins / 60.0;
  }
}

// --- CHAT MESSAGE MODEL ---
enum MessageSender { user, ai, system }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final bool showActionChips;
  final List<ItineraryPlace>? referencedPlaces;
  final List<ItineraryPlace>? suggestedPlaces;
  final List<TimelineItem>? timelineItems;
  final WeatherAlertInfo? weatherAlert;
  final bool isWeatherDecisionCard;
  final bool isTimelinePreviewCard;
  final bool isPlanDecisionCard;
  final List<String>? quickReplies;
  final String? action;
  bool isOptionChosen;
  String? selectedOption;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.showActionChips = false,
    this.referencedPlaces,
    this.suggestedPlaces,
    this.timelineItems,
    this.weatherAlert,
    this.isWeatherDecisionCard = false,
    this.isTimelinePreviewCard = false,
    this.isPlanDecisionCard = false,
    this.quickReplies,
    this.action,
    this.isOptionChosen = false,
    this.selectedOption,
  });
}

// --- CURATED PENANG DATABASE FOR FAST LOCAL INTELLIGENCE ---
final List<ItineraryPlace> kPenangPredefinedPlaces = [
  const ItineraryPlace(
    id: 'george_town_art',
    name: 'George Town Street Art',
    area: 'George Town',
    description: 'Iconic street murals including "Children on a Bicycle" along Armenian Street.',
    lat: 5.4150,
    lng: 100.3390,
    category: 'Heritage',
    estimatedStayMinutes: 60,
    icon: Icons.palette,
  ),
  const ItineraryPlace(
    id: 'kek_lok_si',
    name: 'Kek Lok Si Temple',
    area: 'Air Itam',
    description: 'Magnificent 7-tier pagoda and the towering 30-meter bronze Goddess of Mercy statue.',
    lat: 5.4012,
    lng: 100.2780,
    category: 'Worship',
    estimatedStayMinutes: 90,
    icon: Icons.temple_buddhist,
  ),
  const ItineraryPlace(
    id: 'penang_hill',
    name: 'Penang Hill (Bukit Bendera)',
    area: 'Air Itam',
    description: 'Historic funicular railway ascent to panoramic views over George Town and mainland.',
    lat: 5.4084,
    lng: 100.2687,
    category: 'Nature',
    estimatedStayMinutes: 100,
    icon: Icons.landscape,
  ),
  const ItineraryPlace(
    id: 'chew_jetty',
    name: 'Chew Clan Jetty',
    area: 'George Town',
    description: 'Historic wooden stilt village floating above the water, steeped in clan traditions.',
    lat: 5.4126,
    lng: 100.3396,
    category: 'Heritage',
    estimatedStayMinutes: 45,
    icon: Icons.house,
  ),
  const ItineraryPlace(
    id: 'khoo_kongsi',
    name: 'Leong San Tong Khoo Kongsi',
    area: 'George Town',
    description: 'Elaborately carved Chinese clanhouse showcasing sublime Hokkien architectural mastery.',
    lat: 5.4151,
    lng: 100.3364,
    category: 'Heritage',
    estimatedStayMinutes: 50,
    icon: Icons.temple_buddhist,
  ),
  const ItineraryPlace(
    id: 'batu_ferringhi',
    name: 'Batu Ferringhi Beach',
    area: 'Batu Ferringhi',
    description: 'Golden sand strip famous for watersports, beach dining, and sunset sea views.',
    lat: 5.4748,
    lng: 100.2483,
    category: 'Beach',
    estimatedStayMinutes: 75,
    icon: Icons.beach_access,
  ),
  const ItineraryPlace(
    id: 'escape_penang',
    name: 'ESCAPE Theme Park',
    area: 'Teluk Bahang',
    description: 'Guinness world record water slide and thrill obstacle courses set within lush rainforest.',
    lat: 5.4492,
    lng: 100.2154,
    category: 'Adventure',
    estimatedStayMinutes: 150,
    icon: Icons.attractions,
  ),
  const ItineraryPlace(
    id: 'gurney_drive',
    name: 'Gurney Drive Hawker Center',
    area: 'George Town',
    description: 'Famous seafront open-air hawker strip serving Char Kway Teow, Pasembur, and Hokkien Mee.',
    lat: 5.4398,
    lng: 100.3090,
    category: 'Food',
    estimatedStayMinutes: 60,
    icon: Icons.restaurant,
  ),
  const ItineraryPlace(
    id: 'entopia',
    name: 'Entopia Butterfly Sanctuary',
    area: 'Teluk Bahang',
    description: 'Giant living glass dome with thousands of free-flying tropical butterflies and flora.',
    lat: 5.4470,
    lng: 100.2185,
    category: 'Nature',
    estimatedStayMinutes: 90,
    icon: Icons.eco,
  ),
  const ItineraryPlace(
    id: 'balik_pulau',
    name: 'Balik Pulau Countryside',
    area: 'Balik Pulau',
    description: 'Quiet western valleys known for lush nutmeg orchards, durian plantations, and fishing villages.',
    lat: 5.3516,
    lng: 100.2369,
    category: 'Country',
    estimatedStayMinutes: 75,
    icon: Icons.agriculture,
  ),
  const ItineraryPlace(
    id: 'fort_cornwallis',
    name: 'Fort Cornwallis',
    area: 'George Town',
    description: 'Historic 18th-century star-shaped bastion fortress built by the British East India Company.',
    lat: 5.4206,
    lng: 100.3440,
    category: 'Historic',
    estimatedStayMinutes: 45,
    icon: Icons.fort,
  ),
  const ItineraryPlace(
    id: 'butterworth_art',
    name: 'Butterworth Art Walk (Mainland)',
    area: 'Butterworth',
    description: 'Mainland alleyway murals depicting agricultural history, ferries, and railway development.',
    lat: 5.3991,
    lng: 100.3638,
    category: 'Art',
    estimatedStayMinutes: 50,
    icon: Icons.palette,
  ),
];

// --- 3 TO 5 PLACES CURATED SHORT TRIPS / TOURS BY PENANG AREA ---
class PenangAreaTour {
  final String areaKey;
  final String displayName;
  final String emoji;
  final String summary;
  final List<ItineraryPlace> places;

  const PenangAreaTour({
    required this.areaKey,
    required this.displayName,
    required this.emoji,
    required this.summary,
    required this.places,
  });
}

final Map<String, PenangAreaTour> kPenangAreaTourCatalog = {
  'george_town': const PenangAreaTour(
    areaKey: 'george_town',
    displayName: 'George Town UNESCO Heritage',
    emoji: '🏛️',
    summary: 'Explore world-renowned street murals, stilt clan jetties, and historic heritage mansions in the heart of George Town.',
    places: [
      ItineraryPlace(
        id: 'gt_street_art',
        name: 'George Town Street Art',
        area: 'George Town',
        description: 'Iconic street murals including "Children on a Bicycle" along Armenian Street.',
        lat: 5.4150,
        lng: 100.3390,
        category: 'Heritage',
        estimatedStayMinutes: 45,
        icon: Icons.palette,
      ),
      ItineraryPlace(
        id: 'gt_chew_jetty',
        name: 'Chew Clan Jetty',
        area: 'George Town',
        description: 'Historic wooden stilt village floating above the water, steeped in maritime clan traditions.',
        lat: 5.4126,
        lng: 100.3396,
        category: 'Heritage',
        estimatedStayMinutes: 45,
        icon: Icons.house,
      ),
      ItineraryPlace(
        id: 'gt_peranakan',
        name: 'Pinang Peranakan Mansion',
        area: 'George Town',
        description: 'Opulent Baba Nyonya ancestral mansion showcasing over 1,000 Straits Chinese antiques.',
        lat: 5.4180,
        lng: 100.3410,
        category: 'Museum',
        estimatedStayMinutes: 120,
        icon: Icons.museum,
      ),
    ],
  ),
  'air_itam': const PenangAreaTour(
    areaKey: 'air_itam',
    displayName: 'Air Itam & Penang Hill',
    emoji: '⛰️',
    summary: 'Ascend Penang Hill on the historic funicular train, visit majestic Buddhist shrines, and taste authentic local hawker food.',
    places: [
      ItineraryPlace(
        id: 'ai_kek_lok_si',
        name: 'Kek Lok Si Temple',
        area: 'Air Itam',
        description: 'Magnificent 7-tier pagoda and the towering 30-meter bronze Goddess of Mercy statue.',
        lat: 5.4012,
        lng: 100.2780,
        category: 'Worship',
        estimatedStayMinutes: 90,
        icon: Icons.temple_buddhist,
      ),
      ItineraryPlace(
        id: 'ai_assam_laksa',
        name: 'Air Itam Market & Famous Laksa',
        area: 'Air Itam',
        description: 'Legendary morning wet market stall famous for Penang Assam Laksa with prawn paste.',
        lat: 5.4019,
        lng: 100.2773,
        category: 'Food',
        estimatedStayMinutes: 45,
        icon: Icons.restaurant,
      ),
      ItineraryPlace(
        id: 'ai_penang_hill',
        name: 'Penang Hill (Bukit Bendera)',
        area: 'Air Itam',
        description: 'Historic funicular railway ascent to panoramic views over George Town and mainland.',
        lat: 5.4084,
        lng: 100.2687,
        category: 'Nature',
        estimatedStayMinutes: 90,
        icon: Icons.landscape,
      ),
    ],
  ),
  'batu_ferringhi': const PenangAreaTour(
    areaKey: 'batu_ferringhi',
    displayName: 'Batu Ferringhi Beach & Coast',
    emoji: '🌊',
    summary: 'Golden sandy beaches, aromatic tropical spice reserves, and vibrant seaside evening shopping.',
    places: [
      ItineraryPlace(
        id: 'bf_beach',
        name: 'Batu Ferringhi Beach',
        area: 'Batu Ferringhi',
        description: 'Golden sand strip famous for watersports, beach relaxation, and panoramic ocean breeze.',
        lat: 5.4748,
        lng: 100.2483,
        category: 'Beach',
        estimatedStayMinutes: 75,
        icon: Icons.beach_access,
      ),
      ItineraryPlace(
        id: 'bf_spice_garden',
        name: 'Tropical Spice Garden',
        area: 'Batu Ferringhi',
        description: 'Lush 8-acre living museum featuring over 500 species of tropical spices and herbs.',
        lat: 5.4632,
        lng: 100.2291,
        category: 'Nature',
        estimatedStayMinutes: 75,
        icon: Icons.eco,
      ),
      ItineraryPlace(
        id: 'bf_night_market',
        name: 'Batu Ferringhi Night Market',
        area: 'Batu Ferringhi',
        description: 'Vibrant seaside night bazaar offering local handicrafts, souvenirs, and street snacks.',
        lat: 5.4742,
        lng: 100.2471,
        category: 'Shopping',
        estimatedStayMinutes: 60,
        icon: Icons.shopping_bag,
      ),
    ],
  ),
  'teluk_bahang': const PenangAreaTour(
    areaKey: 'teluk_bahang',
    displayName: 'Teluk Bahang Eco & Adventure',
    emoji: '🎢',
    summary: 'Thrill-seeking theme parks, thousands of free-flying butterflies, and unspoiled national rainforest coastlines.',
    places: [
      ItineraryPlace(
        id: 'tb_escape',
        name: 'ESCAPE Penang',
        area: 'Teluk Bahang',
        description: 'Guinness world record water slide and obstacle adventure courses set in tropical rainforest.',
        lat: 5.4492,
        lng: 100.2154,
        category: 'Adventure',
        estimatedStayMinutes: 150,
        icon: Icons.attractions,
      ),
      ItineraryPlace(
        id: 'tb_entopia',
        name: 'Entopia Butterfly Sanctuary',
        area: 'Teluk Bahang',
        description: 'Giant living glass dome with thousands of free-flying tropical butterflies and flora.',
        lat: 5.4470,
        lng: 100.2185,
        category: 'Nature',
        estimatedStayMinutes: 90,
        icon: Icons.eco,
      ),
      ItineraryPlace(
        id: 'tb_national_park',
        name: 'Penang National Park',
        area: 'Teluk Bahang',
        description: 'Scenic coastal park trails leading to Monkey Beach and Pantai Kerachut turtle sanctuary.',
        lat: 5.4590,
        lng: 100.2080,
        category: 'Nature',
        estimatedStayMinutes: 90,
        icon: Icons.landscape,
      ),
    ],
  ),
  'balik_pulau': const PenangAreaTour(
    areaKey: 'balik_pulau',
    displayName: 'Balik Pulau Countryside & Orchards',
    emoji: '🌾',
    summary: 'Interactive family petting farms, traditional nutmeg plantations, and authentic Penang Laksa.',
    places: [
      ItineraryPlace(
        id: 'bp_audi_farm',
        name: 'Audi Dream Farm',
        area: 'Balik Pulau',
        description: 'Interactive family petting farm with deer, rabbits, birds, and organic vegetable patches.',
        lat: 5.3420,
        lng: 100.2215,
        category: 'Nature',
        estimatedStayMinutes: 60,
        icon: Icons.pets,
      ),
      ItineraryPlace(
        id: 'bp_nutmeg',
        name: 'Ghee Hup Nutmeg Factory',
        area: 'Balik Pulau',
        description: 'Traditional nutmeg plantation with fresh herbal processing and freshly brewed nutmeg drinks.',
        lat: 5.3582,
        lng: 100.2410,
        category: 'Heritage',
        estimatedStayMinutes: 45,
        icon: Icons.eco,
      ),
      ItineraryPlace(
        id: 'bp_kim_laksa',
        name: 'Kim Laksa Balik Pulau',
        area: 'Balik Pulau',
        description: 'Celebrated local stall serving authentic Siamese Coconut Laksa and tangy Penang Assam Laksa.',
        lat: 5.3524,
        lng: 100.2372,
        category: 'Food',
        estimatedStayMinutes: 45,
        icon: Icons.restaurant,
      ),
    ],
  ),
  'bayan_lepas': const PenangAreaTour(
    areaKey: 'bayan_lepas',
    displayName: 'Bayan Lepas & Southern Penang',
    emoji: '🐍',
    summary: 'Historic temples with live pit vipers, massive WWII fortress tunnels, and scenic coastal seaside promenades.',
    places: [
      ItineraryPlace(
        id: 'bl_snake_temple',
        name: 'Snake Temple (Ban Ka Lan)',
        area: 'Bayan Lepas',
        description: 'Historic 1850s temple where sacred green pit vipers rest coiled around incense burners.',
        lat: 5.3138,
        lng: 100.2852,
        category: 'Worship',
        estimatedStayMinutes: 50,
        icon: Icons.temple_buddhist,
      ),
      ItineraryPlace(
        id: 'bl_war_museum',
        name: 'Penang War Museum (Batu Maung)',
        area: 'Bayan Lepas',
        description: 'Expansive historic WWII fortress built on a coastal hill with underground bunkers and tunnels.',
        lat: 5.2814,
        lng: 100.2889,
        category: 'Historic',
        estimatedStayMinutes: 75,
        icon: Icons.fort,
      ),
      ItineraryPlace(
        id: 'bl_queensbay',
        name: 'Queensbay Coastal Waterfront',
        area: 'Bayan Lepas',
        description: 'Scenic seafront promenade with breezes, sunset views of Pulau Jerejak, and waterfront dining.',
        lat: 5.3328,
        lng: 100.3066,
        category: 'Leisure',
        estimatedStayMinutes: 60,
        icon: Icons.storefront,
      ),
    ],
  ),
  'butterworth': const PenangAreaTour(
    areaKey: 'butterworth',
    displayName: 'Butterworth & Mainland Penang',
    emoji: '🎨',
    summary: 'Vibrant street art alleys, Southeast Asia’s largest Taoist Nine Emperor temple, and bird conservation parks.',
    places: [
      ItineraryPlace(
        id: 'bw_art_walk',
        name: 'Butterworth Art Walk',
        area: 'Butterworth',
        description: 'Mainland alleyway murals depicting agricultural history, ferry crossings, and local trade.',
        lat: 5.3991,
        lng: 100.3638,
        category: 'Art',
        estimatedStayMinutes: 50,
        icon: Icons.palette,
      ),
      ItineraryPlace(
        id: 'bw_bird_park',
        name: 'Penang Bird Park (Seberang Jaya)',
        area: 'Butterworth',
        description: 'Malaysia\'s first bird park featuring over 300 avian species in landscaped walk-in aviaries.',
        lat: 5.3942,
        lng: 100.3985,
        category: 'Nature',
        estimatedStayMinutes: 75,
        icon: Icons.eco,
      ),
      ItineraryPlace(
        id: 'bw_tow_boo_kong',
        name: 'Tow Boo Kong Temple (Raja Uda)',
        area: 'Butterworth',
        description: 'Grand Nine Emperor Gods temple renowned for majestic carved archways and dragon pillars.',
        lat: 5.4332,
        lng: 100.3846,
        category: 'Worship',
        estimatedStayMinutes: 50,
        icon: Icons.temple_buddhist,
      ),
    ],
  ),
  'tanjung_bungah': const PenangAreaTour(
    areaKey: 'tanjung_bungah',
    displayName: 'Tanjung Bungah & Tanjung Tokong',
    emoji: '🕌',
    summary: 'Seaside floating architecture, lively marina boardwalks, and illuminated neon banyan gardens.',
    places: [
      ItineraryPlace(
        id: 'tb_floating_mosque',
        name: 'Penang Floating Mosque',
        area: 'Tanjung Bungah',
        description: 'Striking modern coastal mosque constructed on stilts over the ocean waters.',
        lat: 5.4667,
        lng: 100.2764,
        category: 'Worship',
        estimatedStayMinutes: 45,
        icon: Icons.temple_buddhist,
      ),
      ItineraryPlace(
        id: 'tb_straits_quay',
        name: 'Straits Quay Marina',
        area: 'Tanjung Tokong',
        description: 'Mediterranean-style marina promenade with yachts, cafes, and breezy lighthouse walkways.',
        lat: 5.4583,
        lng: 100.3133,
        category: 'Leisure',
        estimatedStayMinutes: 60,
        icon: Icons.sailing,
      ),
      ItineraryPlace(
        id: 'tb_avatar_garden',
        name: 'Penang Avatar Secret Garden',
        area: 'Tanjung Tokong',
        description: 'Illuminated seaside sanctuary where historic banyan trees glow with magical LED ribbons.',
        lat: 5.4628,
        lng: 100.3060,
        category: 'Art',
        estimatedStayMinutes: 45,
        icon: Icons.wb_twilight,
      ),
    ],
  ),
  'gurney': const PenangAreaTour(
    areaKey: 'gurney',
    displayName: 'Gurney Drive & Pulau Tikus',
    emoji: '🍜',
    summary: 'World-famous hawker foods, modern seafront public parks, and historic golden Buddhist temples.',
    places: [
      ItineraryPlace(
        id: 'gu_gurney_drive',
        name: 'Gurney Drive Hawker Center',
        area: 'George Town',
        description: 'Famous seafront open-air food market serving Char Kway Teow, Pasembur, and Hokkien Mee.',
        lat: 5.4398,
        lng: 100.3090,
        category: 'Food',
        estimatedStayMinutes: 60,
        icon: Icons.restaurant,
        businessHours: '3:00 PM – 12:00 AM',
        openingHours: {
          'monday': '3:00 PM – 12:00 AM',
          'tuesday': '3:00 PM – 10:30 PM',
          'wednesday': '3:00 PM – 12:00 AM',
          'thursday': '3:00 PM – 12:00 AM',
          'friday': '3:00 PM – 12:00 AM',
          'saturday': '3:00 PM – 12:00 AM',
          'sunday': '3:00 PM – 12:00 AM',
        },
      ),
      ItineraryPlace(
        id: 'gu_gurney_bay',
        name: 'Gurney Bay Waterfront Promenade',
        area: 'George Town',
        description: 'Modern waterfront park featuring seaside jogging tracks and sunset viewing decks.',
        lat: 5.4365,
        lng: 100.3120,
        category: 'Nature',
        estimatedStayMinutes: 50,
        icon: Icons.park,
        businessHours: 'Open 24 Hours',
        openingHours: {
          'is_24_hours': true,
          'monday': 'Open 24 Hours',
          'tuesday': 'Open 24 Hours',
          'wednesday': 'Open 24 Hours',
          'thursday': 'Open 24 Hours',
          'friday': 'Open 24 Hours',
          'saturday': 'Open 24 Hours',
          'sunday': 'Open 24 Hours',
        },
      ),
      ItineraryPlace(
        id: 'gu_dhammikarama',
        name: 'Dhammikarama Burmese Buddhist Temple',
        area: 'Pulau Tikus',
        description: 'The sole Burmese temple in Penang featuring historic wishing wells and golden stupas.',
        lat: 5.4312,
        lng: 100.3138,
        category: 'Worship',
        estimatedStayMinutes: 45,
        icon: Icons.temple_buddhist,
        businessHours: '8:00 AM – 5:00 PM',
        openingHours: {
          'monday': '8:00 AM – 5:00 PM',
          'tuesday': '8:00 AM – 5:00 PM',
          'wednesday': '8:00 AM – 5:00 PM',
          'thursday': '8:00 AM – 5:00 PM',
          'friday': '8:00 AM – 5:00 PM',
          'saturday': '8:00 AM – 5:00 PM',
          'sunday': '8:00 AM – 5:00 PM',
        },
      ),
    ],
  ),
  'penang_general': const PenangAreaTour(
    areaKey: 'penang_general',
    displayName: 'Penang Island Highlights',
    emoji: '🌟',
    summary: 'A complete short trip combining George Town heritage street art, Chew Clan Jetty, and Kek Lok Si.',
    places: [
      ItineraryPlace(
        id: 'pg_street_art',
        name: 'George Town Street Art',
        area: 'George Town',
        description: 'Iconic street murals including "Children on a Bicycle" along Armenian Street.',
        lat: 5.4150,
        lng: 100.3390,
        category: 'Heritage',
        estimatedStayMinutes: 60,
        icon: Icons.palette,
      ),
      ItineraryPlace(
        id: 'pg_chew_jetty',
        name: 'Chew Clan Jetty',
        area: 'George Town',
        description: 'Historic wooden stilt village floating above the water on Weld Quay.',
        lat: 5.4126,
        lng: 100.3396,
        category: 'Heritage',
        estimatedStayMinutes: 45,
        icon: Icons.house,
      ),
      ItineraryPlace(
        id: 'pg_kek_lok_si',
        name: 'Kek Lok Si Temple',
        area: 'Air Itam',
        description: 'Magnificent 7-tier pagoda and the towering 30-meter bronze Goddess of Mercy statue.',
        lat: 5.4012,
        lng: 100.2780,
        category: 'Worship',
        estimatedStayMinutes: 80,
        icon: Icons.temple_buddhist,
      ),
    ],
  ),
};

// --- TRIP CONTROLLER (SINGLE SOURCE OF TRUTH) ---
class TripController extends ChangeNotifier {
  static final TripController _instance = TripController._internal();
  factory TripController() => _instance;

  TripController._internal() {
    _initInitialWelcome();
  }

  // State Properties
  MascotState _mascotState = MascotState.idle;
  Timer? _transientResetTimer;

  bool _hasActiveTrip = false;
  bool _isPlanSavedToProfile = false;
  bool get isPlanSavedToProfile => _isPlanSavedToProfile;
  void markPlanSavedToProfile([bool value = true]) {
    _isPlanSavedToProfile = value;
    notifyListeners();
  }

  // Track if plan has been generated (independent of whether user saved it to profile)
  bool _isPlanGenerated = false;
  bool get isPlanGenerated => _isPlanGenerated;
  void markPlanGenerated([bool value = true]) {
    _isPlanGenerated = value;
    if (value) {
      _hasUnplannedChanges = false;
      _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    }
    notifyListeners();
  }

  void clearUnplannedChanges() {
    _hasUnplannedChanges = false;
    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    notifyListeners();
  }
  ItineraryTrip? _activeTrip;
  List<ItineraryPlace> _draftItinerary = [];
  final List<ChatMessage> _chatMessages = [];

  // Travel Dates & AI Timeline State
  DateTimeRange? _travelDates;
  TimeOfDay _departTime = const TimeOfDay(hour: 8, minute: 10);
  TimeOfDay _endTripTime = const TimeOfDay(hour: 13, minute: 10);
  List<TimelineItem> _timeline = [];
  List<TimelineItem>? _backupTimeline;
  WeatherAlertInfo? _weatherAlert;
  VoidCallback? onRequireDatesTriggered;
  VoidCallback? onPromptSaveTrip;

  // Weather Recommendations (Heat & Rain)
  List<WeatherRecommendation> _heatRecommendations = [];
  List<WeatherRecommendation> _rainRecommendations = [];

  // Plan Modification & Decision State
  bool _hasPendingPlanDecision = false;
  bool _isRecomputingAiPlan = false;
  List<TimelineItem>? _aiRecomputedTimeline;
  List<ItineraryPlace>? _aiRecomputedPlaces;

  // User Plan vs Model-Optimized Plan tracking
  bool _isUserCustomPlanActive = false;
  bool get isUserCustomPlanActive => _isUserCustomPlanActive;
  List<ItineraryPlace>? _userCustomPlaces;
  List<TimelineItem>? _userCustomTimeline;
  List<ItineraryPlace>? _aiOptimizedPlaces;
  List<TimelineItem>? _aiOptimizedTimeline;

  bool get hasBothPlansAvailable =>
      (_userCustomPlaces != null && _userCustomPlaces!.isNotEmpty) &&
      (_aiOptimizedPlaces != null && _aiOptimizedPlaces!.isNotEmpty);

  // Track planned places for the current draft itinerary
  Set<String> _plannedPlaceKeys = {};
  bool _hasUnplannedChanges = false;
  bool get hasUnplannedChanges => _hasUnplannedChanges;

  bool get hasGeneratedPlanForCurrentDraft {
    if (_draftItinerary.isEmpty) return false;
    // If explicitly marked generated and no unplanned additions, it's ready
    if (_isPlanGenerated && !_hasUnplannedChanges) return true;
    // If timeline and travel dates exist and no unplanned additions, it's ready
    if (_timeline.isNotEmpty && _travelDates != null && !_hasUnplannedChanges) return true;
    if (_timeline.isEmpty) return false;
    if (_hasUnplannedChanges) return false;
    final currentKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    if (_plannedPlaceKeys.isEmpty) return _timeline.isNotEmpty;
    if (currentKeys.length != _plannedPlaceKeys.length) return false;
    return currentKeys.containsAll(_plannedPlaceKeys);
  }

  // Active User-Specified Target Area & Postcode State
  // Preserved when GPS is unavailable and overridden whenever user mentions an area/postcode
  String? _userSpecifiedArea;
  String? _userSpecifiedPostcode;
  String? _userSpecifiedCatalogKey;
  String? _mascotPlanMessage;
  String? _mascotModificationMessage;

  int _activePlaceIndex = 0;
  int get activePlaceIndex => _activePlaceIndex;
  void setActivePlaceIndex(int index) {
    _activePlaceIndex = index;
    notifyListeners();
  }

  // Getters
  String? get userSpecifiedArea => _userSpecifiedArea;
  String? get userSpecifiedPostcode => _userSpecifiedPostcode;
  String? get mascotPlanMessage => _mascotPlanMessage;
  String? get mascotModificationMessage => _mascotModificationMessage;
  MascotState get mascotState => _mascotState;
  bool get hasActiveTrip => _hasActiveTrip;
  ItineraryTrip? get activeTrip => _activeTrip;
  List<ItineraryPlace> get draftItinerary => List.unmodifiable(_draftItinerary);
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  DateTimeRange? get travelDates => _travelDates;
  TimeOfDay get departTime => _departTime;
  TimeOfDay get endTripTime => _endTripTime;
  List<TimelineItem> get timeline => List.unmodifiable(_timeline);
  List<TimelineItem>? get backupTimeline => _backupTimeline;
  WeatherAlertInfo? get weatherAlert => _weatherAlert;
  List<WeatherRecommendation> get heatRecommendations => List.unmodifiable(_heatRecommendations);
  List<WeatherRecommendation> get rainRecommendations => List.unmodifiable(_rainRecommendations);
  bool get hasPendingPlanDecision => _hasPendingPlanDecision;
  bool get isRecomputingAiPlan => _isRecomputingAiPlan;
  List<TimelineItem>? get aiRecomputedTimeline => _aiRecomputedTimeline;

  String get birdModeLabel {
    if (_hasActiveTrip) {
      return 'On-Trip Assistant';
    } else if (_draftItinerary.isNotEmpty) {
      return 'Trip Planning Mode';
    } else {
      return 'Travel Guide Mode';
    }
  }

  IconData get birdModeIcon {
    if (_hasActiveTrip) {
      return Icons.navigation_rounded;
    } else if (_draftItinerary.isNotEmpty) {
      return Icons.edit_calendar_rounded;
    } else {
      return Icons.explore_rounded;
    }
  }

  Color get birdModeColor {
    if (_hasActiveTrip) {
      return const Color(0xFF10B981);
    } else if (_draftItinerary.isNotEmpty) {
      return const Color(0xFF304FFE);
    } else {
      return const Color(0xFFF59E0B);
    }
  }

  void setTravelDates(DateTimeRange? range) {
    _travelDates = range;
    notifyListeners();
  }

  static TimeOfDay defaultEndTimeFor(TimeOfDay depart) {
    final totalMins = (depart.hour * 60 + depart.minute + 5 * 60) % (24 * 60);
    return TimeOfDay(hour: totalMins ~/ 60, minute: totalMins % 60);
  }

  void setDepartTime(TimeOfDay time, {bool updateEndTime = false}) {
    _departTime = time;
    if (updateEndTime) {
      _endTripTime = defaultEndTimeFor(time);
    }
    if (_draftItinerary.isNotEmpty) {
      _recalculateReviewTimeline();
    }
    notifyListeners();
  }

  void setEndTripTime(TimeOfDay time) {
    _endTripTime = time;
    if (_draftItinerary.isNotEmpty) {
      _recalculateReviewTimeline();
    }
    notifyListeners();
  }

  // --- REVIEW MODIFICATION DECISION HANDLERS ---

  // User Chooses: [ 🤖 Use AI-Optimized Plan ]
  void acceptAiPlan() {
    if (_aiRecomputedPlaces != null && _aiRecomputedPlaces!.isNotEmpty) {
      _draftItinerary = List.from(_aiRecomputedPlaces!);
    }
    if (_aiRecomputedTimeline != null && _aiRecomputedTimeline!.isNotEmpty) {
      _timeline = List.from(_aiRecomputedTimeline!);
    }

    _hasPendingPlanDecision = false;
    _aiRecomputedTimeline = null;
    _aiRecomputedPlaces = null;

    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _hasUnplannedChanges = false;

    setMascotState(MascotState.happy);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Applied the AI-Optimized Sequence! 🤖✨ Stops and visit times are balanced to avoid heat & traffic. Ready when you are!",
        timestamp: DateTime.now(),
        timelineItems: _timeline,
        isTimelinePreviewCard: true,
      ),
    );

    notifyListeners();
  }

  // User Chooses: [ ✍️ Keep My Custom Sequence ]
  void keepUserDecision() {
    _hasPendingPlanDecision = false;
    _aiRecomputedTimeline = null;
    _aiRecomputedPlaces = null;

    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _hasUnplannedChanges = false;

    setMascotState(MascotState.happy);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Got it! We'll stick with your custom order and manual sequence. ✍️ Tap Start Journey on Map whenever you're ready!",
        timestamp: DateTime.now(),
        timelineItems: _timeline,
        isTimelinePreviewCard: true,
      ),
    );

    notifyListeners();
  }

  // Switch active itinerary to User Custom Plan
  void switchToUserCustomPlan() {
    if (_userCustomPlaces == null || _userCustomPlaces!.isEmpty) return;
    _draftItinerary = List.from(_userCustomPlaces!);
    if (_userCustomTimeline != null && _userCustomTimeline!.isNotEmpty) {
      _timeline = List.from(_userCustomTimeline!);
    } else {
      _recalculateReviewTimeline();
    }
    _isUserCustomPlanActive = true;
    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _mascotModificationMessage = "Sticking to your custom plan! ✍️ Visit times have been scheduled for your exact sequence.";
    setMascotState(MascotState.happy);
    notifyListeners();
  }

  // Switch active itinerary to Model-Optimized Plan
  void switchToAiOptimizedPlan() {
    if (_aiOptimizedPlaces == null || _aiOptimizedPlaces!.isEmpty) return;
    _draftItinerary = List.from(_aiOptimizedPlaces!);
    if (_aiOptimizedTimeline != null && _aiOptimizedTimeline!.isNotEmpty) {
      _timeline = List.from(_aiOptimizedTimeline!);
    }
    _isUserCustomPlanActive = false;
    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _mascotModificationMessage = "Following Model-Optimized Plan! 🤖 Sequence optimized to minimize travel distance.";
    setMascotState(MascotState.happy);
    notifyListeners();
  }

  // Auto-trigger AI Re-planning whenever user modifies itinerary in Review Mode
  Future<void> _triggerAiReplanForModification() async {
    if (_draftItinerary.isEmpty) return;

    _isRecomputingAiPlan = true;
    notifyListeners();

    try {
      final startDateStr = _travelDates != null
          ? _travelDates!.start.toIso8601String().split('T').first
          : DateTime.now().toIso8601String().split('T').first;
      final endDateStr = _travelDates != null
          ? _travelDates!.end.toIso8601String().split('T').first
          : DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T').first;

      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/bird/plan-itinerary');
      final payload = {
        'places': _draftItinerary.map((p) => {
          'id': p.id,
          'name': p.name,
          'area': p.area,
          'category': p.category,
          'estimatedStayMinutes': p.estimatedStayMinutes,
          'lat': p.lat,
          'lng': p.lng,
          'description': p.description,
        }).toList(),
        'travel_dates': {
          'start_date': startDateStr,
          'end_date': endDateStr,
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['timeline'] is List) {
          final List<dynamic> rawTimeline = data['timeline'];
          final List<TimelineItem> parsedTimeline = [];
          final List<ItineraryPlace> aiPlaces = [];

          for (final item in rawTimeline) {
            final type = item['type']?.toString() ?? 'stop';
            if (type == 'free_time') {
              parsedTimeline.add(TimelineFreeTimeItem.fromJson(item));
            } else {
              final stop = TimelineStopItem.fromJson(item);
              parsedTimeline.add(stop);
              aiPlaces.add(
                ItineraryPlace(
                  id: 'ai_mod_${DateTime.now().millisecondsSinceEpoch}_${aiPlaces.length}',
                  name: stop.placeName,
                  area: stop.area,
                  description: stop.tip,
                  lat: stop.lat,
                  lng: stop.lng,
                  category: stop.category,
                  bestVisitTime: stop.timeSlot,
                  timeReason: stop.tip,
                  warningFlag: stop.warningFlag,
                  icon: _getCategoryIcon(stop.category),
                ),
              );
            }
          }

          _aiRecomputedTimeline = parsedTimeline;
          _aiRecomputedPlaces = aiPlaces;
          _hasPendingPlanDecision = true;
          _isRecomputingAiPlan = false;

          // Emit Plan Decision Card in Chat
          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: "You modified your itinerary! 🤖 I recalculated an optimal AI sequence to avoid traffic & midday heat. Would you like to use the AI-optimized plan or keep your custom order?",
              timestamp: DateTime.now(),
              timelineItems: _aiRecomputedTimeline,
              isPlanDecisionCard: true,
            ),
          );

          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint("AI Replan background error: $e");
    }

    _isRecomputingAiPlan = false;
    notifyListeners();
  }

  // Initialize initial friendly welcome message
  void _initInitialWelcome() {
    if (_chatMessages.isEmpty) {
      _chatMessages.add(
        ChatMessage(
          id: 'welcome_1',
          sender: MessageSender.ai,
          text: "Chirp chirp! 🌸 I'm your Penang Bird Companion. Tell me what places you'd like to visit, or tap below to plan an itinerary together!",
          timestamp: DateTime.now(),
          showActionChips: false,
        ),
      );
    }
  }

  // Clear chat history for testing
  void clearChat() {
    _chatMessages.clear();
    _initInitialWelcome();
    setMascotState(MascotState.idle);
    notifyListeners();
  }

  /// Completely resets the chat and planning session so the user can start
  /// a brand-new trip plan from scratch. Clears chat, draft itinerary, timeline,
  /// active trip, travel dates, and planned place tracking.
  void resetForNewTrip() {
    _chatMessages.clear();
    _initInitialWelcome();
    _draftItinerary.clear();
    _timeline.clear();
    _plannedPlaceKeys.clear();
    _hasUnplannedChanges = false;
    _isPlanGenerated = false;
    _backupTimeline = null;
    _activeTrip = null;
    _hasActiveTrip = false;
    _isPlanSavedToProfile = false;
    _weatherAlert = null;
    _heatRecommendations.clear();
    _rainRecommendations.clear();
    _hasPendingPlanDecision = false;
    _isRecomputingAiPlan = false;
    _aiRecomputedTimeline = null;
    _aiRecomputedPlaces = null;
    _userCustomPlaces = null;
    _userCustomTimeline = null;
    _aiOptimizedPlaces = null;
    _aiOptimizedTimeline = null;
    _isUserCustomPlanActive = false;
    _userSpecifiedArea = null;
    _userSpecifiedPostcode = null;
    _userSpecifiedCatalogKey = null;
    _mascotPlanMessage = null;
    _mascotModificationMessage = null;
    _travelDates = null;
    _departTime = const TimeOfDay(hour: 8, minute: 10);
    _endTripTime = const TimeOfDay(hour: 13, minute: 10);
    _activePlaceIndex = 0;
    _transientResetTimer?.cancel();
    _mascotState = MascotState.idle;
    notifyListeners();
  }

  // Set Mascot State with automatic transient reset back to idle
  void setMascotState(MascotState state, {Duration? autoResetDuration = const Duration(milliseconds: 2800)}) {
    _transientResetTimer?.cancel();
    _mascotState = state;
    notifyListeners();

    if (autoResetDuration != null &&
        (state == MascotState.happy || state == MascotState.shocked || state == MascotState.sad)) {
      _transientResetTimer = Timer(autoResetDuration, () {
        if (_mascotState == state) {
          _mascotState = MascotState.idle;
          notifyListeners();
        }
      });
    }
  }

  // --- DRAFT ITINERARY MUTATIONS (BIDIRECTIONAL) ---

  // Add place to draft
  bool addPlaceToDraft(ItineraryPlace place, {bool fromUserPrompt = false, bool notifyChat = true}) {
    if (_draftItinerary.any((p) => p.id == place.id || p.name.toLowerCase() == place.name.toLowerCase())) {
      if (notifyChat) {
        final hasEnough = _draftItinerary.length >= 3;
        final textMsg = hasEnough
            ? "**${place.name}** is already in your draft itinerary! You now have ${_draftItinerary.length} spots in your draft. Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
            : "**${place.name}** is already in your draft itinerary! What other places in Penang would you like to visit next?";
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: textMsg,
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: null,
          ),
        );
      }
      setMascotState(MascotState.happy);
      notifyListeners();
      return false;
    }

    _draftItinerary.add(place);
    _isPlanSavedToProfile = false;
    _isPlanGenerated = false;
    _hasUnplannedChanges = true;

    // If review timeline already exists, re-sync review timeline and trigger AI replan comparison
    if (_timeline.isNotEmpty) {
      _recalculateReviewTimeline();
      _triggerAiReplanForModification();
    }

    final hasEnough = _draftItinerary.length >= 3;

    // Opening hours validation on visit date
    final visitDate = _travelDates?.start ?? DateTime.now();
    final operatingHours = PlacesService.getPlaceOperatingHours(
      place.openingHours ?? place.businessHours,
      visitDate,
    );
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdayName = weekdays[visitDate.weekday - 1];

    if (operatingHours.isClosed) {
      setMascotState(MascotState.shocked);
      if (notifyChat) {
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: "Added ${place.name}! ⚠️ Heads up: **${place.name}** is typically closed on ${weekdayName}s (${operatingHours.formattedHours}). Please verify opening hours to avoid arriving at a closed door! 🚪❌",
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: null,
          ),
        );
      }
    }

    // Conflict detection (Distance / route check)
    final conflictWarning = _checkDistanceConflict(place);
    if (conflictWarning != null) {
      setMascotState(MascotState.shocked);
      if (notifyChat) {
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: "Added ${place.name}! ⚠️ $conflictWarning",
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: null,
          ),
        );
      }
    } else if (!operatingHours.isClosed) {
      setMascotState(MascotState.happy);
      if (notifyChat) {
        final textMsg = hasEnough
            ? "Steady lah! I've added **${place.name}** to your travel plan (${_draftItinerary.length} total stops). 🚲✨ You now have ${_draftItinerary.length} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
            : "Steady lah! I've added **${place.name}** to your travel plan (${_draftItinerary.length} total stops). 🚲✨ What other places in Penang would you like to visit next?";
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: textMsg,
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: null,
            referencedPlaces: [place],
          ),
        );
      }
    }

    notifyListeners();
    return true;
  }

  /// Add a place to the user's plan regardless of whether the trip is locked/active or in draft.
  /// If an active trip is running, slot in the place as the NEXT stop after the current stop.
  bool addPlaceToPlan(ItineraryPlace place, {bool notifyChat = true}) {
    // 1. If trip is currently active (locked), seamlessly slot in as the next stop & recalculate timeline
    if (_hasActiveTrip && _activeTrip != null) {
      if (_activeTrip!.places.any((p) => p.name.toLowerCase() == place.name.toLowerCase())) {
        if (notifyChat) {
          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: "${place.name} is already in your active journey!",
              timestamp: DateTime.now(),
            ),
          );
        }
        notifyListeners();
        return false;
      }

      final updatedPlaces = List<ItineraryPlace>.from(_activeTrip!.places);
      // Slot in as the next stop after the currently active place index
      final insertIndex = (_activePlaceIndex + 1).clamp(0, updatedPlaces.length);
      updatedPlaces.insert(insertIndex, place);

      _draftItinerary = updatedPlaces;
      _recalculateReviewTimeline();

      _activeTrip = ItineraryTrip(
        id: _activeTrip!.id,
        title: 'Penang Journey (${updatedPlaces.length} stops)',
        places: updatedPlaces,
        timeline: List.from(_timeline),
        travelDates: _activeTrip!.travelDates,
        departTime: _activeTrip!.departTime,
        endTripTime: _activeTrip!.endTripTime,
        createdAt: _activeTrip!.createdAt,
        isCompleted: _activeTrip!.isCompleted,
      );

      setMascotState(MascotState.success);
      if (notifyChat) {
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: "Slotted ${place.name} in as your next stop! 🗺️ Updated itinerary now has ${updatedPlaces.length} stops.",
            timestamp: DateTime.now(),
            referencedPlaces: [place],
            timelineItems: _timeline,
          ),
        );
      }
      notifyListeners();
      return true;
    }

    // 2. Otherwise add to draft itinerary
    return addPlaceToDraft(place, notifyChat: notifyChat);
  }

  // Remove place by index (triggered by sliding panel swipe-to-delete)
  void removePlaceFromDraft(int index, {bool notifyChat = true}) {
    if (index < 0 || index >= _draftItinerary.length) return;
    final removed = _draftItinerary.removeAt(index);
    _isPlanSavedToProfile = false;
    _hasUnplannedChanges = true;

    setMascotState(MascotState.sad);

    // If a timeline exists, re-sync review timeline and trigger AI replanning
    if (_timeline.isNotEmpty) {
      _recalculateReviewTimeline();
      _triggerAiReplanForModification();
    }

    if (notifyChat) {
      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: "Removed ${removed.name} from your itinerary. Remaining stops: ${_draftItinerary.length}.",
          timestamp: DateTime.now(),
          showActionChips: _draftItinerary.isNotEmpty,
        ),
      );
    }

    notifyListeners();
  }

  // Remove place by name (triggered by chat command)
  bool removePlaceByName(String nameQuery) {
    final query = nameQuery.toLowerCase().trim();
    final index = _draftItinerary.indexWhere(
      (p) => p.name.toLowerCase().contains(query) || p.area.toLowerCase().contains(query),
    );

    if (index != -1) {
      removePlaceFromDraft(index, notifyChat: true);
      return true;
    }
    return false;
  }

  // Reorder draft places (drag and drop in sliding panel)
  void reorderDraft(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _draftItinerary.removeAt(oldIndex);
    _draftItinerary.insert(newIndex, item);
    _isPlanSavedToProfile = false;
    _hasUnplannedChanges = true;

    // Re-evaluate user's manual sequence and trigger AI replanning comparison
    _recalculateReviewTimeline();
    _triggerAiReplanForModification();

    notifyListeners();
  }

  // Swap two stops directly by index (used for 1-tap smart recommendations)
  void swapStops(int indexA, int indexB) {
    if (indexA < 0 || indexA >= _draftItinerary.length || indexB < 0 || indexB >= _draftItinerary.length) return;
    final temp = _draftItinerary[indexA];
    _draftItinerary[indexA] = _draftItinerary[indexB];
    _draftItinerary[indexB] = temp;
    _isPlanSavedToProfile = false;
    _hasUnplannedChanges = true;

    _recalculateReviewTimeline();
    _triggerAiReplanForModification();
    notifyListeners();
  }

  // Replace draft itinerary and recompute timeline (used for Undo/Redo/Modifications/Hydration)
  void setDraftItinerary(List<ItineraryPlace> places) {
    _draftItinerary = List.from(places);
    final currentKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    if (_plannedPlaceKeys.isNotEmpty &&
        currentKeys.length == _plannedPlaceKeys.length &&
        currentKeys.containsAll(_plannedPlaceKeys)) {
      // Keys are identical (e.g. hydration or in-place update) — plan is still valid and generated!
      _hasUnplannedChanges = false;
    } else if (_isPlanGenerated && _timeline.isNotEmpty) {
      // Plan was already generated; re-sync keys without invalidating generated status
      _plannedPlaceKeys = currentKeys;
      _hasUnplannedChanges = false;
    } else {
      _hasUnplannedChanges = true;
    }
    _recalculateReviewTimeline();
    notifyListeners();
  }

  // Geographic TSP Route Optimizer (Nearest Neighbor + 2-Opt)
  // Prioritizes minimizing travel distance and untangles criss-cross / zig-zag routes
  void optimizeDraftRouteGeographically() {
    if (_draftItinerary.length <= 2) return;

    // Step 1: Nearest-Neighbor starting from the first place (anchor)
    final unvisited = List<ItineraryPlace>.from(_draftItinerary);
    final tour = <ItineraryPlace>[unvisited.removeAt(0)];

    while (unvisited.isNotEmpty) {
      final last = tour.last;
      int bestIdx = 0;
      double minDist = double.infinity;
      for (int i = 0; i < unvisited.length; i++) {
        final d = _calculateDistanceKm(last.lat, last.lng, unvisited[i].lat, unvisited[i].lng);
        if (d < minDist) {
          minDist = d;
          bestIdx = i;
        }
      }
      tour.add(unvisited.removeAt(bestIdx));
    }

    // Step 2: 2-Opt local search to eliminate crossing edges / zig-zags
    bool improved = true;
    int iterations = 0;
    while (improved && iterations < 50) {
      improved = false;
      iterations++;
      for (int i = 1; i < tour.length - 1; i++) {
        for (int k = i + 1; k < tour.length; k++) {
          final dCurrent = _calculateDistanceKm(tour[i - 1].lat, tour[i - 1].lng, tour[i].lat, tour[i].lng) +
              (k + 1 < tour.length ? _calculateDistanceKm(tour[k].lat, tour[k].lng, tour[k + 1].lat, tour[k + 1].lng) : 0.0);
          final dReversed = _calculateDistanceKm(tour[i - 1].lat, tour[i - 1].lng, tour[k].lat, tour[k].lng) +
              (k + 1 < tour.length ? _calculateDistanceKm(tour[i].lat, tour[i].lng, tour[k + 1].lat, tour[k + 1].lng) : 0.0);
          if (dReversed < dCurrent - 0.0001) {
            final sub = tour.sublist(i, k + 1).reversed.toList();
            tour.replaceRange(i, k + 1, sub);
            improved = true;
          }
        }
      }
    }

    _draftItinerary = tour;
    _recalculateReviewTimeline();
    setMascotState(MascotState.happy);
    notifyListeners();
  }

  // Smart re-optimization for Weather Guard
  void reoptimizeWithWeatherGuard() {
    if (_draftItinerary.length < 2) return;

    // Separate into indoor/sheltered vs outdoor places
    final List<ItineraryPlace> outdoor = [];
    final List<ItineraryPlace> indoor = [];

    for (final p in _draftItinerary) {
      final cat = p.category.toLowerCase();
      final desc = p.description.toLowerCase();
      final name = p.name.toLowerCase();

      final isIndoor = cat.contains('museum') ||
          cat.contains('mansion') ||
          cat.contains('indoor') ||
          cat.contains('mall') ||
          desc.contains('indoor') ||
          desc.contains('museum') ||
          desc.contains('air-conditioned') ||
          name.contains('mansion') ||
          name.contains('museum');

      if (isIndoor) {
        indoor.add(p);
      } else {
        outdoor.add(p);
      }
    }

    // Reconstruct sequence: Morning outdoor/heritage, Midday indoor, Afternoon/Evening sheltered or outdoor
    final List<ItineraryPlace> reordered = [];
    
    // First: Morning stop (outdoor/sightseeing)
    if (outdoor.isNotEmpty) {
      reordered.add(outdoor.removeAt(0));
    }
    
    // Midday stops: Indoor / Air-conditioned
    while (indoor.isNotEmpty) {
      reordered.add(indoor.removeAt(0));
    }
    
    // Remaining outdoor stops in afternoon
    while (outdoor.isNotEmpty) {
      reordered.add(outdoor.removeAt(0));
    }

    _draftItinerary = reordered;
    _recalculateReviewTimeline();
    setMascotState(MascotState.success);
    notifyListeners();
  }

  // Checks if a place is closed on the specified visit date based on operating hours
  bool checkIfPlaceClosed(ItineraryPlace place, [DateTime? date]) {
    final visitDate = date ?? (_travelDates?.start ?? DateTime.now());
    final hours = PlacesService.getPlaceOperatingHours(place.openingHours ?? place.businessHours, visitDate);
    return hours.isClosed;
  }

  /// Optimizes draft itinerary sequence so venues with closing deadlines (e.g. 5 PM, 6 PM)
  /// are visited earlier during daytime, and late/24h venues are visited towards evening.
  void optimizeDraftForOpeningHours() {
    if (_draftItinerary.length <= 1) return;
    final visitDate = _travelDates?.start ?? DateTime.now();

    // Categorize stops by operating window
    final List<ItineraryPlace> earlyDaytime = []; // Closes <= 18:30 (6:30 PM)
    final List<ItineraryPlace> flexibleMid = [];   // Closes between 18:30 and 21:30, or unknown
    final List<ItineraryPlace> eveningOr24h = [];  // Closes >= 21:30 or 24 hours, or opens >= 16:00
    final List<ItineraryPlace> closedPlaces = [];  // Closed on visit date

    for (final p in _draftItinerary) {
      final hours = PlacesService.getPlaceOperatingHours(p.openingHours ?? p.businessHours, visitDate);
      if (hours.isClosed) {
        closedPlaces.add(p);
      } else if (hours.isOpen24Hours || (hours.openMinutes != null && hours.openMinutes! >= 16 * 60)) {
        eveningOr24h.add(p);
      } else if (hours.closeMinutes != null && hours.closeMinutes! <= 18 * 60 + 30) {
        earlyDaytime.add(p);
      } else {
        flexibleMid.add(p);
      }
    }

    // Sort early daytime by earliest closing time first
    earlyDaytime.sort((a, b) {
      final ha = PlacesService.getPlaceOperatingHours(a.openingHours ?? a.businessHours, visitDate);
      final hb = PlacesService.getPlaceOperatingHours(b.openingHours ?? b.businessHours, visitDate);
      final ca = ha.closeMinutes ?? 1080;
      final cb = hb.closeMinutes ?? 1080;
      return ca.compareTo(cb);
    });

    // Reconstruct list: early daytime venues first, then flexible, then evening/24h, then closed
    final List<ItineraryPlace> reordered = [];
    reordered.addAll(earlyDaytime);
    reordered.addAll(flexibleMid);
    reordered.addAll(eveningOr24h);
    reordered.addAll(closedPlaces);

    _draftItinerary = reordered;
  }

  // Dynamic recalculation of timeline and warning flags during user review
  void _recalculateReviewTimeline() {
    if (_draftItinerary.isEmpty) {
      _timeline.clear();
      return;
    }

    final List<TimelineItem> newTimeline = [];
    final int departMinutes = _departTime.hour * 60 + _departTime.minute;
    int endMinutes = _endTripTime.hour * 60 + _endTripTime.minute;
    if (endMinutes <= departMinutes) {
      endMinutes = departMinutes + (5 * 60);
    }
    final int totalTripWindow = endMinutes - departMinutes;

    // A Free Time Bridge is ONLY allowed if:
    // 1. Total window is at least 5.5 hours (330 minutes)
    // 2. End time is at least 3:00 PM (15:00)
    // 3. Depart time is in the morning (<= 11:00 AM)
    // 4. Draft has at least 3 stops
    final bool canHaveFreeTime = totalTripWindow >= 330 &&
        _endTripTime.hour >= 15 &&
        _departTime.hour <= 11 &&
        _draftItinerary.length >= 3;

    final int freeTimeMins = canHaveFreeTime ? 90 : 0;

    // Estimate transit times between consecutive stops
    int totalTransitMins = 0;
    final List<int> legTransits = [];
    for (int i = 0; i < _draftItinerary.length - 1; i++) {
      final prev = _draftItinerary[i];
      final next = _draftItinerary[i + 1];
      final transit = PlacesService.calculateTransit(
        fromLat: prev.lat,
        fromLng: prev.lng,
        toLat: next.lat,
        toLng: next.lng,
      );
      final transitMins = transit['transitMins'] as int;
      legTransits.add(transitMins);
      totalTransitMins += transitMins;
    }

    // Available stay minutes across all venues
    final int availableStayMins = max(
      _draftItinerary.length * 20,
      totalTripWindow - totalTransitMins - freeTimeMins,
    );

    // Baseline category weights to proportionally divide time
    final List<double> weights = _draftItinerary.map((p) {
      final c = p.category.toLowerCase();
      final n = p.name.toLowerCase();
      if (n.contains('escape') || n.contains('entopia') || c.contains('theme')) return 1.5;
      if (n.contains('mansion') || n.contains('museum') || c.contains('museum')) return 1.3;
      if (c.contains('food') || c.contains('cafe') || c.contains('hawker')) return 1.0;
      if (n.contains('jetty') || n.contains('art') || c.contains('art')) return 0.7;
      return 1.0;
    }).toList();

    final double totalWeight = weights.fold(0.0, (sum, w) => sum + w);

    // Dynamically budget stay duration per stop, rounded to 5 mins
    final List<int> budgetedStays = [];
    int sumBudgeted = 0;
    for (int i = 0; i < _draftItinerary.length; i++) {
      final ratio = totalWeight > 0 ? (weights[i] / totalWeight) : (1.0 / _draftItinerary.length);
      int stay = ((availableStayMins * ratio) / 5).round() * 5;
      stay = stay.clamp(20, 180);
      budgetedStays.add(stay);
      sumBudgeted += stay;
    }

    // Fine-tune diff on last stop so schedule aligns closely with endTripTime
    if (budgetedStays.isNotEmpty) {
      final diff = availableStayMins - sumBudgeted;
      budgetedStays.last = (budgetedStays.last + diff).clamp(20, 180);
    }

    int currentMinutes = departMinutes;
    bool conflictDetected = false;

    for (int i = 0; i < _draftItinerary.length; i++) {
      final place = _draftItinerary[i];
      final durationMins = budgetedStays[i];

      // Midday free time bridge (between 12:00 PM and 2:00 PM) after morning stops
      final bool alreadyHasFreeTime = newTimeline.any((t) => t is TimelineFreeTimeItem);
      if (canHaveFreeTime && !alreadyHasFreeTime && i >= 1 && currentMinutes >= (12 * 60) && currentMinutes < (14 * 60)) {
        final freeStart = _formatMinutesClock(currentMinutes);
        currentMinutes += freeTimeMins;
        final freeEnd = _formatMinutesClock(currentMinutes);
        newTimeline.add(
          TimelineFreeTimeItem(
            timeSlot: "$freeStart - $freeEnd",
            duration: '1.5 hours',
            options: const FreeTimeOptions(
              optionA: 'Enjoy shaded lunch & rest at nearby air-conditioned cafe or kopitiam.',
              optionB: 'Take a leisurely break or explore shaded walkways.',
              optionC: 'Rest & re-energize during midday peak sun & heat.',
            ),
          ),
        );
      }

      final startFormatted = _formatMinutesClock(currentMinutes);
      final endMinutesStop = currentMinutes + durationMins;
      final endFormatted = _formatMinutesClock(endMinutesStop);
      final timeSlot = "$startFormatted - $endFormatted";

      // Evaluate warning flags dynamically:
      final visitDate = _travelDates?.start ?? DateTime.now();
      final operatingHours = PlacesService.getPlaceOperatingHours(
        place.openingHours ?? place.businessHours,
        visitDate,
      );
      final bool isClosedOnDate = operatingHours.isClosed;
      final bool isOpenDuringVisit = !isClosedOnDate &&
          operatingHours.isOpenDuring(currentMinutes, endMinutesStop);

      String? warning;
      String? warningReason;

      if (isClosedOnDate) {
        warning = 'CLOSED';
        warningReason = 'Venue is closed on visit date (${operatingHours.formattedHours})';
        conflictDetected = true;
      } else if (!isOpenDuringVisit) {
        warning = 'TIME_CONFLICT';
        warningReason = operatingHours.getConflictDescription(currentMinutes, endMinutesStop);
        conflictDetected = true;
      } else {
        // Peak Heat check: 12:00 PM to 02:30 PM for outdoor walking spots
        final hour = currentMinutes ~/ 60;
        final min = currentMinutes % 60;
        final isMidday = (hour == 11 && min >= 45) ||
            (hour >= 12 && hour < 14) ||
            (hour == 14 && min < 30);
        final isOutdoor = place.category.toLowerCase().contains('beach') ||
            place.category.toLowerCase().contains('nature') ||
            place.category.toLowerCase().contains('heritage') ||
            place.category.toLowerCase().contains('art') ||
            place.name.toLowerCase().contains('khoo kongsi') ||
            place.name.toLowerCase().contains('street art') ||
            place.name.toLowerCase().contains('jetty');

        if (isMidday && isOutdoor) {
          warning = 'PEAK_HEAT';
        } else {
          warning = null;
        }
      }

      // 2. Distance conflict check with previous stop
      if (i > 0) {
        final prev = _draftItinerary[i - 1];
        final dist = _calculateDistanceKm(prev.lat, prev.lng, place.lat, place.lng);
        if (dist > 12.0) {
          conflictDetected = true;
        }
      }

      // Update place in draft with new visit time, dynamic stay duration, and warning flag
      _draftItinerary[i] = place.copyWith(
        estimatedStayMinutes: durationMins,
        bestVisitTime: timeSlot,
        warningFlag: warning,
        timeReason: warningReason ?? place.timeReason,
      );

      newTimeline.add(
        TimelineStopItem(
          placeName: place.name,
          area: place.area,
          category: place.category,
          lat: place.lat,
          lng: place.lng,
          timeSlot: timeSlot,
          tip: (warning == 'CLOSED' || warning == 'TIME_CONFLICT')
              ? (warningReason ?? "Double check opening hours as it's listed as closed!")
              : (place.description.isNotEmpty ? place.description : 'Explore ${place.name}'),
          warningFlag: warning,
        ),
      );

      // Advance time for next stop (stay duration + leg transit)
      if (i < _draftItinerary.length - 1) {
        currentMinutes = endMinutesStop + legTransits[i];
      } else {
        currentMinutes = endMinutesStop;
      }
    }

    _timeline = newTimeline;

    if (conflictDetected) {
      setMascotState(MascotState.shocked);
    } else {
      setMascotState(MascotState.happy);
    }
  }


  String _formatMinutesClock(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final hStr = hour12.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  static int? _parseClockTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final numbers = clean.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (numbers.length >= 2) {
        int hour = int.parse(numbers[0]);
        final min = int.parse(numbers[1]);
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return hour * 60 + min;
      }
    } catch (_) {}
    return null;
  }

  // Clear draft
  void clearDraft() {
    _draftItinerary.clear();
    _timeline.clear();
    _plannedPlaceKeys.clear();
    _hasUnplannedChanges = false;
    _backupTimeline = null;
    _weatherAlert = null;
    _heatRecommendations.clear();
    _rainRecommendations.clear();
    _isPlanSavedToProfile = false;
    _hasPendingPlanDecision = false;
    _aiRecomputedTimeline = null;
    _aiRecomputedPlaces = null;
    _userCustomPlaces = null;
    _userCustomTimeline = null;
    _aiOptimizedPlaces = null;
    _aiOptimizedTimeline = null;
    _isUserCustomPlanActive = false;
    setMascotState(MascotState.sad);
    notifyListeners();
  }

  // --- TRIP LOCK & NAVIGATION HANDLERS ---

  // Lock and Start Trip directly
  ItineraryTrip lockAndStartTrip() {
    final trip = ItineraryTrip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Penang Journey (${_draftItinerary.length} stops)',
      places: List.from(_draftItinerary),
      timeline: List.from(_timeline),
      travelDates: _travelDates,
      departTime: _departTime,
      endTripTime: _endTripTime,
      createdAt: DateTime.now(),
    );

    _activeTrip = trip;
    _hasActiveTrip = true;

    setMascotState(MascotState.success);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Trip locked! 🔒 We're ready for takeoff! Opening live navigation on the Map...",
        timestamp: DateTime.now(),
        showActionChips: false,
      ),
    );

    notifyListeners();
    return trip;
  }

  // Apply Rainy-Day Backup Plan
  void applyBackupPlan() {
    if (_backupTimeline == null || _backupTimeline!.isEmpty) return;

    _timeline = List.from(_backupTimeline!);
    final List<ItineraryPlace> backupPlaces = [];
    for (final item in _timeline) {
      if (item is TimelineStopItem) {
        backupPlaces.add(
          ItineraryPlace(
            id: 'backup_${DateTime.now().millisecondsSinceEpoch}_${backupPlaces.length}',
            name: item.placeName,
            area: item.area,
            description: item.tip,
            lat: item.lat,
            lng: item.lng,
            category: item.category,
            bestVisitTime: item.timeSlot,
            timeReason: item.tip,
            warningFlag: item.warningFlag,
            icon: _getCategoryIcon(item.category),
          ),
        );
      }
    }
    _draftItinerary = backupPlaces;
    _weatherAlert = null;

    setMascotState(MascotState.happy);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Switched to your Rainy-Day Indoor Backup Plan! 🌦️✨ All stops are protected from wet weather. Ready when you are!",
        timestamp: DateTime.now(),
        timelineItems: _timeline,
        isTimelinePreviewCard: true,
      ),
    );

    notifyListeners();
  }

  // Keep Original Plan despite Rain Warning
  void keepOriginalPlan() {
    _weatherAlert = null;
    setMascotState(MascotState.happy);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Understood! We'll stick to your curated plan. You can decide dynamically on the travel day based on actual weather conditions! ☀️",
        timestamp: DateTime.now(),
        timelineItems: _timeline,
        isTimelinePreviewCard: true,
      ),
    );

    notifyListeners();
  }

  // --- 🚀 SAVE AND PLAN TRIP FOR ME NOW (Multi-Phase AI Route & Time Optimization) ---
  Future<ItineraryTrip> saveAndPlanTripForMeNow({
    DateTimeRange? customDates, 
    TimeOfDay? customDepartTime,
    TimeOfDay? customEndTime,
  }) async {
    if (_draftItinerary.isEmpty) {
      throw Exception('No places in draft itinerary to plan.');
    }

    if (customDates != null) {
      _travelDates = customDates;
    }
    if (customDepartTime != null) {
      _departTime = customDepartTime;
    }
    if (customEndTime != null) {
      _endTripTime = customEndTime;
    }
    _mascotModificationMessage = null;

    // Phase 2 Date Gatekeeper: Check if travel dates exist
    if (_travelDates == null) {
      setMascotState(MascotState.happy);
      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: "Before I can schedule your itinerary and check venue opening hours, please select your travel dates! [INTENT: REQUIRE_DATES]",
          timestamp: DateTime.now(),
          showActionChips: false,
        ),
      );
      notifyListeners();
      onRequireDatesTriggered?.call();
      throw Exception('REQUIRE_DATES');
    }

    // Align stops with venue opening hours before planning (if not explicitly locked by user)
    if (!_isUserCustomPlanActive) {
      optimizeDraftForOpeningHours();
    }

    try {
      final startDateStr = _travelDates!.start.toIso8601String().split('T').first;
      final endDateStr = _travelDates!.end.toIso8601String().split('T').first;

      // Check if travel date is within 7 days to fetch real weather forecast
      Map<String, dynamic>? weatherPayload;
      final now = DateTime.now();
      final diffDays = _travelDates!.start.difference(DateTime(now.year, now.month, now.day)).inDays;

      if (diffDays >= 0 && diffDays <= 7) {
        try {
          final wService = WeatherService();
          final wData = await wService.fetchWeather();
          weatherPayload = {
            'condition': wData.condition,
            'description': wData.description,
            'temp': wData.temp,
            'precipitation_probability': wData.precipitationProbabilityMax,
          };
        } catch (e) {
          debugPrint("Could not retrieve real-time weather: $e");
        }
      }

      final hourStr = _departTime.hour.toString().padLeft(2, '0');
      final minuteStr = _departTime.minute.toString().padLeft(2, '0');
      final departTimeStr = '$hourStr:$minuteStr';

      final endHourStr = _endTripTime.hour.toString().padLeft(2, '0');
      final endMinuteStr = _endTripTime.minute.toString().padLeft(2, '0');
      final endTimeStr = '$endHourStr:$endMinuteStr';

      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/bird/plan-itinerary');
      final payload = {
        'places': _draftItinerary.map((p) => {
          'id': p.id,
          'name': p.name,
          'area': p.area,
          'category': p.category,
          'estimatedStayMinutes': p.estimatedStayMinutes,
          'lat': p.lat,
          'lng': p.lng,
          'description': p.description,
        }).toList(),
        'travel_dates': {
          'start_date': startDateStr,
          'end_date': endDateStr,
        },
        'depart_time': departTimeStr,
        'end_time': endTimeStr,
        'weather_info': weatherPayload,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));

        if (data['require_dates'] == true || data['action'] == 'REQUIRE_DATES') {
          onRequireDatesTriggered?.call();
          throw Exception('REQUIRE_DATES');
        }

        if (data['success'] == true && data['timeline'] is List) {
          final List<dynamic> rawTimeline = data['timeline'];
          final String mascotMsg = data['mascot_message'] ?? "Here is your AI-optimized Penang itinerary!";
          _mascotPlanMessage = mascotMsg;

          final List<TimelineItem> parsedTimeline = [];
          final List<ItineraryPlace> syncedStops = [];

          for (final item in rawTimeline) {
            final type = item['type']?.toString() ?? 'stop';
            if (type == 'free_time') {
              parsedTimeline.add(TimelineFreeTimeItem.fromJson(item));
            } else {
              final stop = TimelineStopItem.fromJson(item);
              parsedTimeline.add(stop);

              // Calculate dynamic stay duration from timeSlot (e.g. "09:45 AM - 10:25 AM")
              int stayMins = 60;
              final separator = stop.timeSlot.contains('–') ? '–' : '-';
              final parts = stop.timeSlot.split(separator);
              if (parts.length == 2) {
                final s = _parseClockTimeToMinutes(parts[0]);
                final e = _parseClockTimeToMinutes(parts[1]);
                if (s != null && e != null && e > s) {
                  stayMins = e - s;
                }
              }

              final existingMatch = _draftItinerary.firstWhere(
                (p) => p.name.trim().toLowerCase() == stop.placeName.trim().toLowerCase(),
                orElse: () => ItineraryPlace(
                  id: 'stop_${DateTime.now().millisecondsSinceEpoch}_${syncedStops.length}',
                  name: stop.placeName,
                  area: stop.area,
                  description: stop.tip,
                  lat: stop.lat,
                  lng: stop.lng,
                  category: stop.category,
                ),
              );

              syncedStops.add(
                existingMatch.copyWith(
                  estimatedStayMinutes: stayMins,
                  bestVisitTime: stop.timeSlot,
                  timeReason: stop.tip,
                  tip: stop.tip,
                  isAdjusted: stop.isAdjusted,
                  adjustmentReason: stop.adjustmentReason,
                  warningFlag: stop.warningFlag,
                  icon: _getCategoryIcon(stop.category),
                ),
              );
            }
          }

          _timeline = parsedTimeline;
          if (syncedStops.isNotEmpty) {
            _draftItinerary = syncedStops;
          }
          _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
          _hasUnplannedChanges = false;
          _isPlanGenerated = true;

          // Populate Weather Recommendations (Heat & Rain)
          if (data['heat_recommendations'] is List) {
            _heatRecommendations = (data['heat_recommendations'] as List)
                .map((r) => WeatherRecommendation.fromJson(r as Map<String, dynamic>))
                .toList();
          }
          if (data['rain_recommendations'] is List) {
            _rainRecommendations = (data['rain_recommendations'] as List)
                .map((r) => WeatherRecommendation.fromJson(r as Map<String, dynamic>))
                .toList();
          }

          // Parse Weather Alert & Backup Plan
          if (data['weather_alert'] != null && data['backup_plan'] is List) {
            _weatherAlert = WeatherAlertInfo.fromJson(data['weather_alert']);
            final List<TimelineItem> parsedBackup = [];
            for (final bItem in (data['backup_plan'] as List)) {
              if (bItem['type'] == 'free_time') {
                parsedBackup.add(TimelineFreeTimeItem.fromJson(bItem));
              } else {
                parsedBackup.add(TimelineStopItem.fromJson(bItem));
              }
            }
            _backupTimeline = parsedBackup;

            // Emit Interactive Weather Alert & Decision Card Message in Chat
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: _weatherAlert!.message,
                timestamp: DateTime.now(),
                weatherAlert: _weatherAlert,
                timelineItems: _timeline,
                isWeatherDecisionCard: true,
              ),
            );
          } else {
            _weatherAlert = null;
            _backupTimeline = null;
            // Note: Timeline and plan overview are viewed in Your Plan screen (itinerary_plan_screen),
            // so we don't spam the Travel Companion chat history with the timeline schedule or overview bubble.
          }

          // Build generated plan without prematurely marking as ongoing trip (user must Apply Plan)
          final trip = ItineraryTrip(
            id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Penang AI Plan (${_draftItinerary.length} stops)',
            places: List.from(_draftItinerary),
            timeline: List.from(_timeline),
            travelDates: _travelDates,
            departTime: _departTime,
            endTripTime: _endTripTime,
            createdAt: DateTime.now(),
          );

          _activeTrip = null;
          _hasActiveTrip = false;
          setMascotState(MascotState.happy);
          notifyListeners();
          return trip;
        }
      }
    } catch (e) {
      if (e.toString().contains('REQUIRE_DATES')) rethrow;
      debugPrint("AI Itinerary Optimization error: $e");
    }

    // Fallback: recalculate timeline without locking trip
    if (!_isUserCustomPlanActive) {
      optimizeDraftForOpeningHours();
    }
    _recalculateReviewTimeline();
    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _hasUnplannedChanges = false;
    _isPlanGenerated = true;
    _activeTrip = null;
    _hasActiveTrip = false;
    notifyListeners();
    return ItineraryTrip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Penang AI Plan (${_draftItinerary.length} stops)',
      places: List.from(_draftItinerary),
      timeline: List.from(_timeline),
      travelDates: _travelDates,
      departTime: _departTime,
      endTripTime: _endTripTime,
      createdAt: DateTime.now(),
    );
  }

  // --- SAVE & APPLY MODIFIED PLAN (OPTIMIZATION & USER-SEQUENCE PRESERVATION) ---
  Future<bool> applyModifiedPlan({
    required List<ItineraryPlace> places,
    required bool stickToUserPlan,
  }) async {
    _userCustomPlaces = places.map((p) => p.copyWith()).toList();
    try {
      final startDateStr = _travelDates?.start.toIso8601String().split('T').first ?? DateTime.now().toIso8601String().split('T').first;
      final endDateStr = _travelDates?.end.toIso8601String().split('T').first ?? startDateStr;

      final hourStr = _departTime.hour.toString().padLeft(2, '0');
      final minuteStr = _departTime.minute.toString().padLeft(2, '0');
      final departTimeStr = '$hourStr:$minuteStr';

      final endHourStr = _endTripTime.hour.toString().padLeft(2, '0');
      final endMinuteStr = _endTripTime.minute.toString().padLeft(2, '0');
      final endTimeStr = '$endHourStr:$endMinuteStr';

      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/bird/optimize-modified-plan');
      final payload = {
        'places': places.map((p) => {
          'id': p.id,
          'name': p.name,
          'area': p.area,
          'category': p.category,
          'estimatedStayMinutes': p.estimatedStayMinutes,
          'lat': p.lat,
          'lng': p.lng,
          'description': p.description,
          'imageUrl': p.imageUrl,
          'tip': p.tip,
        }).toList(),
        'travel_dates': {
          'start_date': startDateStr,
          'end_date': endDateStr,
        },
        'depart_time': departTimeStr,
        'end_time': endTimeStr,
        'stick_to_user_plan': stickToUserPlan,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 35));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          final List<TimelineItem> newTimeline = [];
          if (data['timeline'] is List) {
            for (final item in data['timeline']) {
              if (item['type'] == 'free_time') {
                newTimeline.add(TimelineFreeTimeItem.fromJson(item));
              } else {
                newTimeline.add(TimelineStopItem.fromJson(item));
              }
            }
          }

          final List<ItineraryPlace> newPlaces = [];
          if (data['places'] is List) {
            for (final pJson in data['places']) {
              final String name = (pJson['name'] ?? '').toString();
              final existing = places.firstWhere(
                (p) => p.name.trim().toLowerCase() == name.trim().toLowerCase(),
                orElse: () => ItineraryPlace(
                  id: (pJson['id'] ?? '').toString(),
                  name: name,
                  area: (pJson['area'] ?? 'Penang').toString(),
                  description: (pJson['description'] ?? '').toString(),
                  lat: (pJson['lat'] as num?)?.toDouble() ?? 5.414,
                  lng: (pJson['lng'] as num?)?.toDouble() ?? 100.328,
                  category: (pJson['category'] ?? 'Attraction').toString(),
                  imageUrl: pJson['imageUrl']?.toString(),
                ),
              );

              newPlaces.add(
                existing.copyWith(
                  bestVisitTime: pJson['suggestedVisitTime']?.toString(),
                  tip: pJson['tip']?.toString(),
                  isAdjusted: pJson['isAdjusted'] == true,
                  adjustmentReason: pJson['adjustmentReason']?.toString(),
                  imageUrl: (pJson['imageUrl'] != null && (pJson['imageUrl'] as String).isNotEmpty) 
                      ? pJson['imageUrl'].toString() 
                      : existing.imageUrl,
                  estimatedStayMinutes: (pJson['estimatedStayMinutes'] as num?)?.toInt() ?? existing.estimatedStayMinutes,
                ),
              );
            }
          }

          if (newTimeline.isNotEmpty) _timeline = newTimeline;
          if (newPlaces.isNotEmpty) _draftItinerary = newPlaces;

          if (stickToUserPlan) {
            _userCustomPlaces = List.from(_draftItinerary);
            _userCustomTimeline = List.from(_timeline);
            _isUserCustomPlanActive = true;
          } else {
            _aiOptimizedPlaces = List.from(_draftItinerary);
            _aiOptimizedTimeline = List.from(_timeline);
            _isUserCustomPlanActive = false;
          }

          _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
          _hasUnplannedChanges = false;
          _isPlanGenerated = true;
          if (data['mascot_message'] != null && data['mascot_message'].toString().trim().isNotEmpty) {
            _mascotModificationMessage = data['mascot_message'].toString();
          } else {
            _mascotModificationMessage = stickToUserPlan
                ? "Sticking to your custom plan! ✍️ Visit times have been scheduled for your exact sequence."
                : "I've re-adjusted your visit sequence and timings to align smoothly with opening hours and reduce travel distance!";
          }

          setMascotState(MascotState.happy);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("Error optimizing modified plan: $e");
    }

    // Fallback: apply directly if network failed
    _draftItinerary = List.from(places);
    _recalculateReviewTimeline();
    if (stickToUserPlan) {
      _userCustomPlaces = List.from(_draftItinerary);
      _userCustomTimeline = List.from(_timeline);
      _isUserCustomPlanActive = true;
    } else {
      _aiOptimizedPlaces = List.from(_draftItinerary);
      _aiOptimizedTimeline = List.from(_timeline);
      _isUserCustomPlanActive = false;
    }
    _plannedPlaceKeys = _draftItinerary.map((p) => p.name.trim().toLowerCase()).toSet();
    _hasUnplannedChanges = false;
    _isPlanGenerated = true;
    _mascotModificationMessage = stickToUserPlan
        ? "Sticking to your custom plan! ✍️ Visit times have been scheduled for your exact sequence."
        : "Applied your updated itinerary!";
    notifyListeners();
    return true;
  }

  // Alias for backward compatibility
  Future<bool> optimizeAndApplyModifiedPlan(List<ItineraryPlace> modifiedPlaces) async {
    return applyModifiedPlan(places: modifiedPlaces, stickToUserPlan: false);
  }

  // Fetch Weather Recommendations from backend if empty
  Future<void> fetchWeatherRecommendationsIfNeeded({bool force = false}) async {
    if (!force && _heatRecommendations.isNotEmpty && _rainRecommendations.isNotEmpty) return;
    try {
      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/bird/weather-recommendations');
      final payload = {
        'places': _draftItinerary.map((p) => {
          'id': p.id,
          'name': p.name,
          'area': p.specificArea,
          'category': p.category,
          'lat': p.lat,
          'lng': p.lng,
        }).toList(),
      };
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          if (data['heat_recommendations'] is List) {
            _heatRecommendations = (data['heat_recommendations'] as List)
                .map((r) => WeatherRecommendation.fromJson(r as Map<String, dynamic>))
                .toList();
          }
          if (data['rain_recommendations'] is List) {
            _rainRecommendations = (data['rain_recommendations'] as List)
                .map((r) => WeatherRecommendation.fromJson(r as Map<String, dynamic>))
                .toList();
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("Could not fetch weather recommendations: $e");
    }
  }

  // Clear / Reset Active Trip status (clears Ongoing Trip state)
  void clearActiveTrip() {
    _hasActiveTrip = false;
    _activeTrip = null;
    notifyListeners();
  }

  // Cancel Active Trip (triggered from Contextual Status Banner)
  void cancelActiveTrip() {
    _hasActiveTrip = false;
    _activeTrip = null;

    // Mascot returns to idle
    setMascotState(MascotState.idle);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Your active journey has been ended. Feel free to draft a new adventure anytime!",
        timestamp: DateTime.now(),
        showActionChips: false,
      ),
    );

    notifyListeners();
  }

  // Plan New Trip (triggered from Contextual Status Banner or reset)
  void planNewTrip() {
    resetForNewTrip();
  }

  // --- CONFLICT & DISTANCE DETECTION ---
  // Calculates Haversine distance in km
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  String? _checkDistanceConflict(ItineraryPlace newPlace) {
    if (_draftItinerary.length <= 1) return null;

    // Check distance from the immediately preceding stop
    final prev = _draftItinerary[_draftItinerary.length - 2];
    final dist = _calculateDistanceKm(prev.lat, prev.lng, newPlace.lat, newPlace.lng);

    // Conflict 1: Crossing between Penang Island and Mainland
    final isPrevMainland = prev.area.toLowerCase().contains('butterworth') ||
        prev.area.toLowerCase().contains('mainland');
    final isNewMainland = newPlace.area.toLowerCase().contains('butterworth') ||
        newPlace.area.toLowerCase().contains('mainland');
    if (isPrevMainland != isNewMainland) {
      return "Notice: ${newPlace.name} crosses between Penang Island and the Mainland! Bridge or ferry transit will require significant travel time.";
    }

    // Conflict 2: If consecutive stops are > 12km apart
    if (dist > 12.0) {
      return "Notice: ${newPlace.name} is ${dist.toStringAsFixed(1)}km away from ${prev.name}. You may experience heavy traffic or long travel times across Penang!";
    }
    return null;
  }

  // --- NATURAL LANGUAGE AI CHAT & LLM INTEGRATION ---

  Future<void> sendUserMessage(String text) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    // Add user message
    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.user,
        text: clean,
        timestamp: DateTime.now(),
      ),
    );

    // Mascot switches to thinking
    setMascotState(MascotState.thinking, autoResetDuration: null);
    notifyListeners();

    // Natural Language Intent Engine
    await _processUserIntent(clean);
  }

  /// Robustly sanitize AI model responses to strip any raw JSON or Markdown fences
  /// and ensure chat bubbles display only the clean conversational text.
  String _sanitizeAiReply(String rawText) {
    String text = rawText.trim();
    if (text.isEmpty) return text;

    // Check if response contains a JSON object or markdown code block
    if (text.startsWith('```') || text.startsWith('{') || text.contains('"message":') || text.contains('"action":')) {
      // 1. Try stripping markdown fence first
      String jsonCandidate = text;
      if (jsonCandidate.startsWith('```json')) {
        jsonCandidate = jsonCandidate.replaceFirst(RegExp(r'^```json\s*', caseSensitive: false), '');
      } else if (jsonCandidate.startsWith('```')) {
        jsonCandidate = jsonCandidate.replaceFirst(RegExp(r'^```\s*'), '');
      }
      jsonCandidate = jsonCandidate.replaceFirst(RegExp(r'\s*```$'), '').trim();

      // 2. Try JSON decode
      try {
        final decoded = json.decode(jsonCandidate);
        if (decoded is Map) {
          final innerMsg = decoded['message'] ?? decoded['reply'];
          if (innerMsg != null && innerMsg.toString().trim().isNotEmpty) {
            return innerMsg.toString().trim();
          }
        }
      } catch (_) {}

      // 3. Fallback regex extraction of "message": "..." (handles truncated JSON)
      final match = RegExp(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)"', dotAll: true).firstMatch(text);
      if (match != null && match.group(1) != null) {
        final extracted = match.group(1)!
            .replaceAll(r'\"', '"')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '')
            .replaceAll(r'\t', '\t')
            .trim();
        if (extracted.isNotEmpty) {
          return extracted;
        }
      }
    }

    // Strip dangling fences if any
    final sanitized = text.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
               .replaceAll(RegExp(r'\s*```$'), '')
               .trim();
    return _condenseOptionBulletDescriptions(sanitized);
  }

  /// Generates an ultra-concise 1-sentence summary of place details to prevent long cluttered text
  String _getConcisePlaceSummary(String? rawText, {int maxLen = 80}) {
    if (rawText == null || rawText.trim().isEmpty) {
      return 'Popular must-visit spot in Penang.';
    }
    String clean = rawText
        .replaceAll(RegExp(r'[\r\n]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Check for first sentence termination
    final match = RegExp(r'[\.\!\?](?:\s|$)').firstMatch(clean);
    if (match != null && match.end > 10 && match.end <= maxLen) {
      return clean.substring(0, match.end).trim();
    }

    if (clean.length <= maxLen) return clean;

    final cut = clean.substring(0, maxLen);
    final lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > 25) {
      return '${cut.substring(0, lastSpace).trim()}...';
    }
    return '${cut.trim()}...';
  }

  /// Ensures bullet points for options in AI responses don't include paragraph-length descriptions
  String _condenseOptionBulletDescriptions(String text) {
    final pattern = RegExp(
      r'((?:•|\*|-)\s*\*\*\[?Option\s*[AB12]\]?:?\s*[^\*]+?\*\*\s*(?:\r?\n\s*)?(?:\([^\)]+?\)\s*)?[—\-:]\s*)([\s\S]+?)(?=(?:\r?\n\s*(?:•|\*|-)\s*\*\*\[?Option|\r?\n\s*👉|\r?\n\s*💡|\r?\n\s*✨|\r?\n\s*📌|$))',
      caseSensitive: false,
    );

    return text.replaceAllMapped(pattern, (match) {
      final prefix = match.group(1) ?? '';
      final rawDesc = match.group(2) ?? '';
      final conciseDesc = _getConcisePlaceSummary(rawDesc, maxLen: 80);
      return '$prefix$conciseDesc\n';
    }).replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  bool _isFactualInquiry(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // 0. Queries seeking information or details ("want to know more about", "tell me about") are factual inquiries!
    final isInfoSeeking = clean.contains('want to know') ||
        clean.contains('wanna know') ||
        clean.contains('know more about') ||
        clean.contains('tell me more about') ||
        clean.contains('more about the') ||
        clean.contains('more about this') ||
        clean.contains('tell me about') ||
        clean.contains('info on') ||
        clean.contains('details of') ||
        clean.contains('我想了解') ||
        clean.contains('我想知道') ||
        clean.contains('了解更多');
    if (isInfoSeeking) {
      return true;
    }

    // 1. Explicit recommendation requests & preference statements are NOT factual inquiries
    final recTriggers = [
      'i want', 'i wish', 'i would like', 'i\'d like', 'i wanna', 'want to', 'wish to', 'wanna',
      'looking for', 'hope to', 'plan to', 'planning to', 'interested in', 'want visit', 'want to visit',
      'want to see', 'want see', 'want to go', 'want go', 'wish to visit', 'wish to see', 'wish to go',
      'clan house', 'clan houses', 'kongsi', 'jetty', 'recommend', 'suggestion', 'suggest',
      'where should i go', 'what should i visit', 'what can i visit', 'what to see', 'where to visit',
      'places to go', 'any place', 'any places', 'any cafe', 'any bakery', 'any restaurant', 'any food',
      'where to eat', 'what to eat', 'good to eat', 'good to visit', 'recommendation', 'options',
      'nearby', 'near', 'around', 'close to', 'what is nearby', 'what are nearby', 'what is near',
      'what to visit', 'to visit', 'nearby to visit', 'near to visit', 'places nearby', 'spots nearby',
      'stamp', 'stamps', 'digital stamp', 'other stamps', 'what other', 'what else', 'anything else',
      '推荐', '建议', '有什么好玩', '有什么好吃', '哪间好吃', '介绍几家', '介绍几个地方',
      '去哪玩', '去哪吃', '什么好玩', '什么好吃', '带我去', '想去', '想看', '我要', '我想', '希望', '打算',
      '附近的', '附近', '周边', '附近有什么', '附近好玩', '附近好吃', '印章'
    ];
    for (final trigger in recTriggers) {
      if (clean.contains(trigger)) {
        return false;
      }
    }

    // 2. Direct factual / informational trigger phrases
    final factualPhrases = [
      'need to pay', 'entrance fee', 'ticket price', 'admission fee', 'is it free',
      'how much to enter', 'ticket cost', 'admission price', 'how much for ticket',
      'opening hours', 'operating hours', 'business hours', 'closing time',
      'what time does it open', 'what time does it close', 'when does it open', 'when does it close',
      'what is the address', 'exact address', 'location of', 'where is it located',
      'which area', 'what area', 'in which area', 'in what area', 'which part', 'what part',
      'where is', 'where are', 'where are they located', 'where are they', 'where are these',
      'can eat', 'cannot eat', 'not suitable', 'precaution', 'side effect', 'contraindication',
      'what people cannot', 'who cannot', 'who should not', 'is it safe', 'health benefit',
      'tell me about', 'history of', 'meaning of', 'origin of', 'what does', 'why does',
      '在哪个区', '在什么区', '在哪个地方', '什么位置', '具体位置', '具体地址',
      '在哪里', '在哪', '在何处', '位于哪里', '属于哪个区', '地址是什么', '地址在哪', '怎么去',
      '营业时间', '开放时间', '开门时间', '关门时间', '几点开', '几点关', '今天有开吗', '明天有开吗',
      '门票', '多少钱', '要门票吗', '需要门票吗', '免费吗', '收费吗',
      '为什么', '禁忌', '不能吃', '不能喝', '什么人不能', '适不适合', '有什么好处', '由来', '历史', '介绍'
    ];

    for (final phrase in factualPhrases) {
      if (clean.contains(phrase)) {
        return true;
      }
    }

    // 3. Informational question sentence starters
    final questionStarters = [
      'what is', 'what are', 'what does', 'why is', 'why are', 'why do', 'why does',
      'how do', 'how does', 'how is', 'how can', 'when is', 'when was', 'who is',
      'is it', 'can i', 'can we', 'should i', 'do i', 'does it', 'what people',
      '什么是', '为何', '如何', '怎么会'
    ];
    for (final starter in questionStarters) {
      if (clean.startsWith(starter) || clean.contains(' $starter')) {
        return true;
      }
    }

    // 4. Ends with question mark without recommendation intent
    if (clean.endsWith('?') || clean.endsWith('？')) {
      return true;
    }

    return false;
  }

  bool isSystemAction(String text) => _isSystemActionText(text);

  bool _isSystemActionText(String text) {
    final clean = text
        .replaceAll(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    const systemKeywords = [
      'save & optimize',
      'save and optimize',
      'save & plan',
      'save and plan',
      'save trip',
      'save plan',
      'save the trip',
      'save and plan trip for me now',
      'keep exploring',
      'keep planning',
      'select dates',
      'lock trip',
      'optimize trip',
      'require dates',
      'i still want to plan',
      'add more places',
      'add more',
      'remove spot',
      'remove stop',
      'delete spot',
      'delete stop',
      'remove a spot',
      'remove a stop',
      'delete a spot',
      'delete a stop',
      'remove spot 1',
      'remove spot 2',
      'remove stop 1',
      'remove stop 2',
      'delete spot 1',
      'delete spot 2',
      'delete stop 1',
      'delete stop 2',
      '删除景点',
      '删除行程',
      '去掉景点',
    ];
    if (systemKeywords.any((k) => clean == k || clean.contains(k) || k.contains(clean))) {
      return true;
    }
    if (RegExp(r'^(?:remove|delete|drop)\s+(?:a\s+)?(?:spot|stop|place|item)(?:\s+\d+)?$', caseSensitive: false).hasMatch(clean)) {
      return true;
    }
    return false;
  }

  /// Checks if prompt is asking to list unlocked / collected stamps
  bool _isUnlockedStampsListInquiry(String lower) {
    final hasUnlockKeyword = lower.contains('unlock') ||
        lower.contains('解锁') ||
        lower.contains('collect') ||
        lower.contains('收集') ||
        lower.contains(' earned') ||
        lower.contains('earned');
    final hasStampKeyword = lower.contains('stamp') ||
        lower.contains('stamps') ||
        lower.contains('印章');
    final hasListKeyword = lower.contains('哪些') ||
        lower.contains('什么') ||
        lower.contains('what') ||
        lower.contains('which') ||
        lower.contains('list') ||
        lower.contains('show') ||
        lower.contains('我有') ||
        lower.contains('my ') ||
        lower.contains('我的') ||
        lower.contains('progress') ||
        lower.contains('进度') ||
        lower.contains('how many') ||
        lower.contains('多少');

    if (hasUnlockKeyword && (hasStampKeyword || hasListKeyword)) return true;
    if (hasStampKeyword &&
        (lower.contains('my stamps') ||
            lower.contains('我的印章') ||
            lower.contains('check stamps') ||
            lower.contains('stamps unlocked') ||
            lower.contains('unlocked stamps') ||
            lower.contains('collected stamps'))) {
      return true;
    }
    return false;
  }

  /// Checks if prompt is asking whether the user has visited a specific place
  bool _isPlaceVisitedInquiry(String lower) {
    final hasEnglishVisitedPattern = RegExp(
      r'\b(?:have\s+i\s+(?:already\s+|ever\s+)?visited|have\s+i\s+(?:already\s+|ever\s+)?been\s+to|did\s+i\s+(?:already\s+)?(?:go\s+to|visit)|did\s+we\s+(?:go\s+to|visit)|have\s+we\s+(?:already\s+)?visited|was\s+i\s+at)\b',
      caseSensitive: false,
    ).hasMatch(lower) ||
        ((lower.contains('visited') || lower.contains('been to') || lower.contains('gone to')) &&
            (lower.contains('before') || lower.contains('already') || lower.contains('yet') || lower.contains('?')));

    final hasChineseVisitedPattern = lower.contains('去过') ||
        lower.contains('到过') ||
        (lower.contains('去了') && (lower.contains('吗') || lower.contains('？') || lower.contains('?'))) ||
        lower.contains('是否去') ||
        lower.contains('有没有去') ||
        lower.contains('是否已经去');

    return hasEnglishVisitedPattern || hasChineseVisitedPattern;
  }

  /// Extracts place name from a visited place inquiry prompt
  String _extractPlaceFromVisitedInquiry(String prompt) {
    final lower = prompt.toLowerCase().trim();

    // Strategy 1: Direct match against 28 digital stamps
    for (final s in kPredefined28DigitalStamps) {
      final sLower = s.title.toLowerCase();
      if (lower.contains(sLower)) return s.title;
      if (sLower.contains('khoo kongsi') && lower.contains('khoo kongsi')) return s.title;
      if (sLower.contains('chew jetty') && lower.contains('chew jetty')) return s.title;
      if (sLower.contains('fire station') && (lower.contains('fire station') || lower.contains('lebuh pantai fire'))) return s.title;
      if (sLower.contains('st george') && (lower.contains('st george') || lower.contains('st. george') || lower.contains('st george church'))) return s.title;
      if (sLower.contains('kapitan keling') && lower.contains('kapitan keling')) return s.title;
      if (sLower.contains('cenotaph') && lower.contains('cenotaph')) return s.title;
      if (sLower.contains('cheong fatt tze') && (lower.contains('cheong fatt tze') || lower.contains('blue mansion'))) return s.title;
      if (sLower.contains('goddess of mercy') && (lower.contains('goddess of mercy') || lower.contains('kuan yin teng') || lower.contains('观音亭'))) return s.title;
      if (sLower.contains('pinang peranakan') && (lower.contains('pinang peranakan') || lower.contains('peranakan mansion') || lower.contains('侨生博物馆'))) return s.title;
      if (sLower.contains('fort cornwallis') && (lower.contains('cornwallis') || lower.contains('康华利斯堡'))) return s.title;
      if (sLower.contains('sun yat sen') && (lower.contains('sun yat sen') || lower.contains('孙中山'))) return s.title;
      if (sLower.contains('clock tower') && (lower.contains('clock tower') || lower.contains('victoria clock') || lower.contains('钟楼'))) return s.title;
    }

    // Strategy 2: Direct match against predefined places
    for (final p in kPenangPredefinedPlaces) {
      final pLower = p.name.toLowerCase();
      if (lower.contains(pLower)) return p.name;
      if (p.id == 'kek_lok_si' && (lower.contains('kek lok si') || lower.contains('极乐寺'))) return p.name;
      if (p.id == 'penang_hill' && (lower.contains('penang hill') || lower.contains('bukit bendera') || lower.contains('升旗山'))) return p.name;
      if (p.id == 'escape_penang' && lower.contains('escape')) return p.name;
      if (p.id == 'entopia' && lower.contains('entopia')) return p.name;
    }

    // Strategy 3: Direct match against places recorded in completed trails
    for (final trail in CompletedTrailsManager.getAllTrails()) {
      for (final stop in trail.stops) {
        if (lower.contains(stop.toLowerCase().trim())) return stop;
      }
      if (trail.stopDetails != null) {
        for (final stop in trail.stopDetails!) {
          if (lower.contains(stop.placeName.toLowerCase().trim())) return stop.placeName;
        }
      }
    }

    // Strategy 4: Clean prompt by regex to isolate the queried place name
    String cleaned = prompt;
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:have\s+i\s+(?:already\s+|ever\s+)?visited|have\s+i\s+(?:already\s+|ever\s+)?been\s+to|did\s+i\s+(?:already\s+)?(?:go\s+to|visit)|did\s+we\s+(?:go\s+to|visit)|have\s+we\s+visited|was\s+i\s+at)\b', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:before|already|yet|previously|in\s+my\s+history|in\s+trip\s+history)\b', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'(?:我(?:是否|有没有|有|已经)?(?:去过|到过|去了)|是否已经去过|是否去过|有没有去过|有去过|我去过|去过了吗|去过吗|去了吗|吗|呢|过吗|过了吗|这个地方|这个景点|之前|以前)', caseSensitive: false), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[?？!！,，.。]+'), ' ').trim();

    return cleaned;
  }

  /// Handles user inquiries regarding Travel History (have I visited xxx?) and unlocked digital stamps
  Future<bool> _handleTravelHistoryAndStampInquiry(String prompt) async {
    final lower = prompt.toLowerCase().trim();

    // 1. Inquiries about unlocked / collected digital stamps (e.g. "我 unlock 了那些", "what stamps have I unlocked?")
    if (_isUnlockedStampsListInquiry(lower)) {
      setMascotState(MascotState.happy);
      var stampList = StampsService.cachedStamps;
      if (stampList.isEmpty) stampList = List.from(kPredefined28DigitalStamps);

      final unlockedStamps = stampList.where((s) =>
        s.isUnlocked || StampsService.isStampUnlocked(s.id) || StampsService.isStampUnlocked(s.title)
      ).toList();

      final buffer = StringBuffer();
      buffer.writeln("🎖️ **Your Digital Stamps Progress: ${unlockedStamps.length} / 28 Collected**");
      buffer.writeln();

      if (unlockedStamps.isNotEmpty) {
        buffer.writeln("Here are the official digital stamps you've unlocked in George Town:");
        for (int i = 0; i < unlockedStamps.length; i++) {
          final s = unlockedStamps[i];
          final dateStr = s.date.isNotEmpty ? s.date : 'Collected';
          buffer.writeln("${i + 1}. **${s.title}** (${s.location}) — *$dateStr* ⭐");
        }
        buffer.writeln();
        final remaining = 28 - unlockedStamps.length;
        if (remaining > 0) {
          buffer.writeln("💡 You still have **$remaining** exciting digital stamps to collect in George Town!");
          buffer.writeln("👉 Tap **🎯 Digital Stamp Hunt** below to prioritize and discover the uncollected spots!");
        } else {
          buffer.writeln("🎉 **Incredible! You have unlocked ALL 28 digital stamps in Penang!** You're a certified Penang Heritage Master Explorer! 🎒🏆");
        }
      } else {
        buffer.writeln("You haven't unlocked any of the 28 official Digital Stamps yet! 🎒");
        buffer.writeln();
        buffer.writeln("When you physically explore official heritage landmarks in George Town with Kia Kia Penang, your digital stamps will unlock automatically!");
        buffer.writeln();
        buffer.writeln("👉 Tap **🎯 Digital Stamp Hunt** below to get personalized recommendations for stamp spots to visit!");
      }

      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: buffer.toString(),
          timestamp: DateTime.now(),
          quickReplies: const ['🎯 Digital Stamp Hunt', 'View Travel History'],
          showActionChips: false,
        ),
      );
      notifyListeners();
      return true;
    }

    // 2. Inquiries about whether user has visited a specific place ("xxx 我是否已经去过了", "have I visited xxx?")
    if (_isPlaceVisitedInquiry(lower)) {
      final placeQuery = _extractPlaceFromVisitedInquiry(prompt);
      if (placeQuery.isNotEmpty) {
        setMascotState(MascotState.thinking);

        // 1. Check in completed trails
        final visitInfo = CompletedTrailsManager.checkPlaceVisited(placeQuery);

        // 2. Also check if it matches one of the 28 digital stamps
        final stampMatch = kPredefined28DigitalStamps.where((s) {
          final sLower = s.title.toLowerCase();
          final qLower = placeQuery.toLowerCase();
          return sLower == qLower || sLower.contains(qLower) || qLower.contains(sLower);
        }).firstOrNull;

        final bool isStampUnlocked = stampMatch != null &&
            (stampMatch.isUnlocked ||
                StampsService.isStampUnlocked(stampMatch.id) ||
                StampsService.isStampUnlocked(stampMatch.title));

        final bool hasVisited = visitInfo.visited || isStampUnlocked;
        final matchedTitle = stampMatch?.title ?? placeQuery;

        final buffer = StringBuffer();
        if (hasVisited) {
          setMascotState(MascotState.happy);
          buffer.writeln("✅ **Yes! You have already visited $matchedTitle!** 🎒✨");
          buffer.writeln();
          if (visitInfo.visited) {
            buffer.writeln("• 📜 **Found in Travel History:** Recorded in your completed trip **'${visitInfo.trailTitle}'**${visitInfo.date != null ? " on ${visitInfo.date}" : ""}.");
          }
          if (stampMatch != null) {
            if (isStampUnlocked) {
              final stampDate = stampMatch.date.isNotEmpty ? " (${stampMatch.date})" : "";
              buffer.writeln("• 🏅 **Digital Stamp:** Unlocked and collected$stampDate ⭐");
            } else {
              buffer.writeln("• 📜 **Digital Stamp:** Location visited, but this digital stamp is not yet unlocked in your collection.");
            }
          }
          buffer.writeln();
          buffer.writeln("Would you like to revisit it, or would you like me to recommend a new Penang spot for you?");
        } else {
          setMascotState(MascotState.idle);
          buffer.writeln("🔍 **According to your Travel History, you haven't visited $matchedTitle yet!** 🗺️");
          buffer.writeln();
          if (stampMatch != null) {
            buffer.writeln("💡 **Good news:** **${stampMatch.title}** is one of the 28 official Digital Stamp locations in George Town, and the stamp is currently **uncollected (🔒)**!");
            buffer.writeln("Visiting this spot will unlock its exclusive digital stamp in your Kia Kia Penang app! 🏅");
            buffer.writeln();
          }
          buffer.writeln("👉 Would you like me to add **$matchedTitle** to your draft itinerary?");
        }

        final quickReplies = hasVisited
            ? const ['🎯 Digital Stamp Hunt', 'Recommend another spot']
            : ['Add $matchedTitle', '🎯 Digital Stamp Hunt'];

        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: buffer.toString(),
            timestamp: DateTime.now(),
            quickReplies: quickReplies,
            showActionChips: false,
          ),
        );
        notifyListeners();
        return true;
      }
    }

    // 3. Inquiries about general visited places history ("我去过哪些地方", "what places have I visited?")
    final isGeneralVisitedQuery = (lower.contains('去过') || lower.contains('visited') || lower.contains('been to')) &&
        (lower.contains('哪些') || lower.contains('哪里') || lower.contains('what') || lower.contains('where') || lower.contains('list') || lower.contains('show') || lower.contains('places') || lower.contains('history') || lower.contains('地方'));
    if (isGeneralVisitedQuery) {
      setMascotState(MascotState.happy);
      final visitedNames = CompletedTrailsManager.getAllVisitedPlaceNames();
      final totalTrails = CompletedTrailsManager.getAllTrails().length;
      final unlockedCount = StampsService.cachedStamps.where((s) =>
        s.isUnlocked || StampsService.isStampUnlocked(s.id) || StampsService.isStampUnlocked(s.title)
      ).length;

      final buffer = StringBuffer();
      buffer.writeln("🗺️ **Your Travel History Summary**");
      buffer.writeln();
      buffer.writeln("You have completed **$totalTrails trail routes** and collected **$unlockedCount / 28 digital stamps**!");
      buffer.writeln();
      if (visitedNames.isNotEmpty) {
        buffer.writeln("Here are places recorded in your visited history:");
        for (int i = 0; i < visitedNames.length && i < 15; i++) {
          buffer.writeln("${i + 1}. **${visitedNames[i]}**");
        }
        if (visitedNames.length > 15) {
          buffer.writeln("*(...and ${visitedNames.length - 15} more in Travel History)*");
        }
      } else {
        buffer.writeln("You haven't completed any recorded trails yet! Start an itinerary to record your visited places.");
      }
      buffer.writeln();
      buffer.writeln("👉 Tap **🎯 Digital Stamp Hunt** to discover new unvisited stamp locations!");

      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: buffer.toString(),
          timestamp: DateTime.now(),
          quickReplies: const ['🎯 Digital Stamp Hunt', 'View Travel History'],
          showActionChips: false,
        ),
      );
      notifyListeners();
      return true;
    }

    return false;
  }

  Future<void> _processUserIntent(String prompt) async {
    final lower = prompt.toLowerCase().trim();
    final cleanPrompt = prompt
        .replaceAll(RegExp(r'[^a-zA-Z0-9\u4e00-\u9fa5\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();

    // 1. CLEAR / REMOVE PLAN & SPECIFIC STOP INTENTS
    if (lower == 'remove plan' ||
        lower == 'delete plan' ||
        lower == 'clear plan' ||
        lower == 'clear draft' ||
        lower == 'remove all' ||
        lower == 'clear all' ||
        lower == 'empty plan' ||
        lower == 'reset plan' ||
        lower == 'remove itinerary' ||
        lower == 'clear itinerary') {
      clearDraft();
      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: "Cleared all stops from your draft itinerary. Let's start fresh!",
          timestamp: DateTime.now(),
        ),
      );
      notifyListeners();
      return;
    }

    // 1.5 DIRECT SAVE & OPTIMIZE INTENT
    if (cleanPrompt == 'save & optimize' ||
        cleanPrompt == 'save and optimize' ||
        cleanPrompt == 'save the trip' ||
        cleanPrompt == 'optimize trip' ||
        cleanPrompt == 'save plan' ||
        cleanPrompt == 'save and plan' ||
        cleanPrompt == 'save and plan trip for me now' ||
        cleanPrompt.contains('save and plan') ||
        cleanPrompt.contains('save trip') ||
        cleanPrompt.contains('save plan') ||
        cleanPrompt.contains('save and optimize') ||
        cleanPrompt == 'option a: save & optimize' ||
        cleanPrompt == 'option a: save and optimize' ||
        cleanPrompt == 'save' ||
        cleanPrompt == 'select dates' ||
        cleanPrompt == 'lock trip' ||
        cleanPrompt.contains('lock plan') ||
        cleanPrompt.contains('lock the plan') ||
        cleanPrompt.contains('lock my plan') ||
        cleanPrompt.contains('how to lock') ||
        cleanPrompt.contains('where to lock') ||
        cleanPrompt.contains('how do i lock') ||
        cleanPrompt.contains('where do i lock') ||
        cleanPrompt.contains('how can i lock') ||
        cleanPrompt.contains('where can i lock') ||
        cleanPrompt.contains('generate plan') ||
        cleanPrompt.contains('how to generate') ||
        cleanPrompt.contains('where to generate') ||
        cleanPrompt.contains('锁定') ||
        cleanPrompt.contains('生成行程')) {
      if (_draftItinerary.isNotEmpty) {
        if (_travelDates == null) {
          final count = _draftItinerary.length;
          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: "To lock and generate your plan, please tap on the checklist icon at the bottom-left corner of your screen (with the badge showing the $count place${count == 1 ? '' : 's'} in your draft plan) and generate your plan there! 📋✨",
              timestamp: DateTime.now(),
              quickReplies: [],
              showActionChips: false,
            ),
          );
        } else {
          lockAndStartTrip();
        }
        notifyListeners();
        return;
      } else {
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: "You haven't added any places to your draft plan yet! Explore Penang or ask me for recommendations to add spots first. Once you have places in your draft, tap on the checklist icon at the bottom-left corner to generate your plan. 🗺️✨",
            timestamp: DateTime.now(),
            quickReplies: [],
            showActionChips: false,
          ),
        );
        notifyListeners();
        return;
      }
    }

    // Check if user is asking to estimate travel time / schedule for drafted stops
    final isTimingEstimatePrompt = (cleanPrompt.contains('estimate') || cleanPrompt.contains('calculate') || cleanPrompt.contains('what is the') || cleanPrompt.contains('how long') || cleanPrompt.contains('预估') || cleanPrompt.contains('计算')) &&
        (cleanPrompt.contains('travel time') || cleanPrompt.contains('travel times') || cleanPrompt.contains('timing') || cleanPrompt.contains('duration') || cleanPrompt.contains('schedule') || cleanPrompt.contains('时间') || cleanPrompt.contains('耗时')) &&
        (cleanPrompt.contains('stop') || cleanPrompt.contains('place') || cleanPrompt.contains('spot') || cleanPrompt.contains('plan') || cleanPrompt.contains('itinerary') || cleanPrompt.contains('景点') || cleanPrompt.contains('行程'));

    if (isTimingEstimatePrompt && _draftItinerary.isNotEmpty && _travelDates == null) {
      final count = _draftItinerary.length;
      _chatMessages.add(
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: "To calculate travel estimates and sequence your itinerary, please tap on the checklist icon at the bottom-left corner of your screen (with the badge showing the $count place${count == 1 ? '' : 's'} in your draft plan) and generate the plan there! 📋✨",
          timestamp: DateTime.now(),
          quickReplies: [],
          showActionChips: false,
        ),
      );
      notifyListeners();
      return;
    }

    // Check if the previous AI message asked which spot to remove
    final lastAiMsg = _chatMessages.reversed.firstWhere(
      (m) => m.sender == MessageSender.ai,
      orElse: () => ChatMessage(id: '', sender: MessageSender.ai, text: '', timestamp: DateTime.now()),
    );
    final lastAiLower = lastAiMsg.text.toLowerCase();
    final isPendingRemovePrompt = lastAiLower.contains('which one should i remove') ||
        lastAiLower.contains('which stop') ||
        lastAiLower.contains('which spot') ||
        (lastAiLower.contains('remove') && (lastAiLower.contains('draft itinerary') || lastAiLower.contains('stops currently')));

    // Remove by sequence number (e.g. "remove spot 2", "delete #1", "remove 3", or "4" when prompted)
    final seqMatch = RegExp(r'^(?:(?:remove|delete|drop)\s+(?:spot\s+|stop\s+|#)?(\d+)|(?:spot\s+|stop\s+|#)?(\d+))$', caseSensitive: false).firstMatch(lower);
    if (seqMatch != null) {
      final rawNum = seqMatch.group(1) ?? (isPendingRemovePrompt ? seqMatch.group(2) : null);
      if (rawNum != null) {
        final seqNum = int.tryParse(rawNum);
        if (seqNum != null && seqNum >= 1 && seqNum <= _draftItinerary.length) {
          final targetPlace = _draftItinerary[seqNum - 1];
          removePlaceFromDraft(seqNum - 1, notifyChat: false);
          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: "Got it! I've removed Stop $seqNum (${targetPlace.name}) from your list. Your plan is now leaner and meaner! 🦜",
              timestamp: DateTime.now(),
              showActionChips: _draftItinerary.isNotEmpty,
            ),
          );
          setMascotState(MascotState.happy);
          notifyListeners();
          return;
        }
      }
    }

    // Remove by name or area keyword
    if (lower.startsWith('remove ') || lower.startsWith('delete ') || lower.startsWith('drop ')) {
      final query = lower.replaceFirst(RegExp(r'^(?:remove|delete|drop)\s+'), '').trim();
      for (var place in List.from(_draftItinerary)) {
        if (place.name.toLowerCase().contains(query) || query.contains(place.name.toLowerCase())) {
          removePlaceByName(place.name);
          return;
        }
      }
    }

    // 2. PRECISE OPTION A / OPTION B / OPTION 1 / OPTION 2 / ADD BOTH SELECTION
    final isOptionBoth = lower == 'add both' ||
        lower == 'add both suggestions' ||
        lower == 'both' ||
        lower == 'add all' ||
        lower == 'both options' ||
        lower.contains('add both') ||
        lower.contains('both suggestions') ||
        lower.contains('both options') ||
        RegExp(r'\b(?:help\s+me\s+)?(?:add|want|insert|put|include|take|pick|choose)\s+(?:both\s+)?(?:option\s*)?a\s*(?:&|and|\+)\s*(?:option\s*)?b\b', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'\b(?:i\s+(?:want|wish|prefer|would\s+like|wanna)\s+)(?:both|a\s*(?:&|and|\+)\s*b)\b', caseSensitive: false).hasMatch(lower) ||
        lower.contains('两个都') ||
        lower.contains('都加') ||
        lower.contains('全部加') ||
        lower.contains('a和b') ||
        lower.contains('a与b');

    final isOptionA = !isOptionBoth && (
        lower == 'a' ||
        lower == '1' ||
        lower == 'option a' ||
        lower == 'option 1' ||
        lower == 'first option' ||
        lower.startsWith('option a:') ||
        lower.startsWith('option 1:') ||
        RegExp(r'^(?:i\s+(?:want|wish|prefer|would\s+like|wanna)\s+)?(?:(?:help\s+me\s+|please\s+)?(?:add|choose|pick|select|take)\s+)?(?:option\s*a|option\s*1|\ba\b|\b1\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'^(?:i\s+(?:want|wish|prefer|would\s+like|wanna)\s+)(?:option\s*a|option\s*1|\ba\b|\b1\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'^(?:(?:help\s+me\s+|please\s+)?(?:add|choose|pick|select|take)\s+)(?:option\s*a|option\s*1|\ba\b|\b1\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        lower == '我要a' ||
        lower == '我要option a' ||
        lower == '选a' ||
        lower == '加a' ||
        lower == '帮我加a' ||
        lower == '第一个'
    );

    final isOptionB = !isOptionBoth && (
        lower == 'b' ||
        lower == '2' ||
        lower == 'option b' ||
        lower == 'option 2' ||
        lower == 'second option' ||
        lower.startsWith('option b:') ||
        lower.startsWith('option 2:') ||
        RegExp(r'^(?:i\s+(?:want|wish|prefer|would\s+like|wanna)\s+)?(?:(?:help\s+me\s+|please\s+)?(?:add|choose|pick|select|take)\s+)?(?:option\s*b|option\s*2|\bb\b|\b2\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'^(?:i\s+(?:want|wish|prefer|would\s+like|wanna)\s+)(?:option\s*b|option\s*2|\bb\b|\b2\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        RegExp(r'^(?:(?:help\s+me\s+|please\s+)?(?:add|choose|pick|select|take)\s+)(?:option\s*b|option\s*2|\bb\b|\b2\b)(?:\s+please)?$', caseSensitive: false).hasMatch(lower) ||
        lower == '我要b' ||
        lower == '我要option b' ||
        lower == '选b' ||
        lower == '加b' ||
        lower == '帮我加b' ||
        lower == '第二个'
    );

    if (isOptionBoth || isOptionA || isOptionB) {
      if (_isSystemActionText(lower)) {
        if (lower.contains('save') || lower.contains('optimize') || lower.contains('date')) {
          if (_draftItinerary.isNotEmpty) {
            if (_travelDates == null) {
              onRequireDatesTriggered?.call();
            } else {
              lockAndStartTrip();
            }
          }
        }
        notifyListeners();
        return;
      }

      // Look for the most recent AI message that provided options or suggested places
      final lastAiMsg = _chatMessages.reversed.where((m) =>
          m.sender == MessageSender.ai &&
          ((m.suggestedPlaces != null && m.suggestedPlaces!.isNotEmpty) ||
           RegExp(r'\[?Option\s*A\]?', caseSensitive: false).hasMatch(m.text))
      ).firstOrNull ?? _chatMessages.reversed.where((m) => m.sender == MessageSender.ai).firstOrNull;

      if (lastAiMsg != null) {
        if (isOptionBoth) {
          final placesToAdd = <ItineraryPlace>[];
          if (lastAiMsg.suggestedPlaces != null && lastAiMsg.suggestedPlaces!.isNotEmpty) {
            for (final p in lastAiMsg.suggestedPlaces!.take(2)) {
              if (!_isSystemActionText(p.name)) {
                placesToAdd.add(p);
              }
            }
          }

          if (placesToAdd.isEmpty) {
            // Fallback: parse Option A and Option B from text
            final text = lastAiMsg.text;
            final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#]+)', caseSensitive: false);
            final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#]+)', caseSensitive: false);
            final matchA = optAPattern.firstMatch(text);
            final matchB = optBPattern.firstMatch(text);
            final sepRegex = RegExp(r'\s+[-–—]{1,2}\s+|\s*[:：]\s+|\s+(?:for|to|offers?|features?|where|is\s+a|is\s+the|is)\s+|[。，]', caseSensitive: false);
            for (final m in [matchA, matchB]) {
              if (m != null && m.group(1) != null) {
                String raw = m.group(1)!.replaceAll(RegExp(r'[\*\_\[\]\.,]'), '').trim();
                if (raw.contains(sepRegex)) {
                  raw = raw.split(sepRegex).first.trim();
                }
                if (raw.isNotEmpty && !_isSystemActionText(raw)) {
                  final pre = kPenangPredefinedPlaces.where((p) => p.name.toLowerCase() == raw.toLowerCase() || raw.toLowerCase().contains(p.name.toLowerCase())).firstOrNull;
                  final stamp = pre == null ? kPredefined28DigitalStamps.where((s) => s.title.toLowerCase() == raw.toLowerCase() || raw.toLowerCase().contains(s.title.toLowerCase()) || s.title.toLowerCase().contains(raw.toLowerCase())).firstOrNull : null;
                  final matchedStampPlace = stamp != null ? ItineraryPlace(
                    id: 'stamp_${stamp.id}',
                    name: stamp.title,
                    area: 'George Town',
                    description: stamp.description,
                    lat: stamp.lat,
                    lng: stamp.lng,
                    category: 'Heritage & Culture',
                    icon: stamp.icon,
                    imageUrl: stamp.imageUrl.isNotEmpty ? stamp.imageUrl : null,
                  ) : null;

                  placesToAdd.add(pre ?? matchedStampPlace ?? ItineraryPlace(
                    id: 'place_${DateTime.now().millisecondsSinceEpoch}_${placesToAdd.length}',
                    name: raw,
                    area: 'George Town',
                    description: 'Popular attraction in Penang',
                    lat: 5.414,
                    lng: 100.328,
                    category: 'Attraction',
                  ));
                }
              }
            }
          }

          if (placesToAdd.isNotEmpty) {
            lastAiMsg.isOptionChosen = true;
            lastAiMsg.selectedOption = 'Both';
            for (final p in placesToAdd) {
              addPlaceToDraft(p, fromUserPrompt: true, notifyChat: false);
            }
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final names = placesToAdd.map((p) => '**${p.name}**').join(' and ');
            final promptSuffix = hasEnough
                ? "You now have ${_draftItinerary.length} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
                : "What other places in Penang would you like to visit next?";
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: "Steady lah! I've added both $names to your travel plan (${_draftItinerary.length} total stops). 🚲✨ $promptSuffix",
                timestamp: DateTime.now(),
                showActionChips: false,
                quickReplies: null,
              ),
            );
            notifyListeners();
            return;
          }
        }

        final targetIndex = isOptionA ? 0 : 1;

        // Strategy 1: Check suggestedPlaces on latest AI message
        if (lastAiMsg.suggestedPlaces != null && lastAiMsg.suggestedPlaces!.isNotEmpty) {
          if (targetIndex < lastAiMsg.suggestedPlaces!.length) {
            final chosenPlace = lastAiMsg.suggestedPlaces![targetIndex];
            if (_isSystemActionText(chosenPlace.name)) {
              notifyListeners();
              return;
            }
            lastAiMsg.isOptionChosen = true;
            lastAiMsg.selectedOption = isOptionA ? 'A' : 'B';
            final added = addPlaceToDraft(chosenPlace, fromUserPrompt: true, notifyChat: false);
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final promptSuffix = hasEnough
                ? "You now have ${_draftItinerary.length} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
                : "What other places in Penang would you like to visit next?";
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: added
                    ? "Steady lah! I've added **${chosenPlace.name}** to your draft itinerary (${_draftItinerary.length} total stops). 🚲✨ $promptSuffix"
                    : "**${chosenPlace.name}** is already in your draft itinerary!",
                timestamp: DateTime.now(),
                showActionChips: false,
                quickReplies: null,
              ),
            );
            notifyListeners();
            return;
          }
        }

        // Strategy 2: Parse Option A / Option B directly from latest AI message text
        final text = lastAiMsg.text;
        final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
        final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);

        final matchA = optAPattern.firstMatch(text);
        final matchB = optBPattern.firstMatch(text);

        final targetMatch = isOptionA ? matchA : matchB;
        if (targetMatch != null && targetMatch.group(1) != null) {
          String rawExtracted = targetMatch.group(1)!.replaceAll(RegExp(r'[\*\_\[\]\.,]'), '').trim();
          final sepRegex = RegExp(r'\s+[-–—]{1,2}\s+|\s*[:：]\s+|\s+(?:for|to|offers?|features?|where|is\s+a|is\s+the|is)\s+|[。，]', caseSensitive: false);
          if (rawExtracted.contains(sepRegex)) {
            rawExtracted = rawExtracted.split(sepRegex).first.trim();
          }
          if (rawExtracted.isNotEmpty && !_isSystemActionText(rawExtracted)) {
            // Find in predefined catalog or stamps pool or create custom place
            final existingPredefined = kPenangPredefinedPlaces.where(
              (p) => p.name.toLowerCase() == rawExtracted.toLowerCase() || rawExtracted.toLowerCase().contains(p.name.toLowerCase()),
            ).firstOrNull;
            final existingStamp = existingPredefined == null ? kPredefined28DigitalStamps.where((s) => s.title.toLowerCase() == rawExtracted.toLowerCase() || rawExtracted.toLowerCase().contains(s.title.toLowerCase()) || s.title.toLowerCase().contains(rawExtracted.toLowerCase())).firstOrNull : null;
            final matchedStampPlace = existingStamp != null ? ItineraryPlace(
              id: 'stamp_${existingStamp.id}',
              name: existingStamp.title,
              area: 'George Town',
              description: existingStamp.description,
              lat: existingStamp.lat,
              lng: existingStamp.lng,
              category: 'Heritage & Culture',
              icon: existingStamp.icon,
              imageUrl: existingStamp.imageUrl.isNotEmpty ? existingStamp.imageUrl : null,
            ) : null;

            final chosenPlace = existingPredefined ?? matchedStampPlace ?? ItineraryPlace(
              id: 'place_${DateTime.now().millisecondsSinceEpoch}',
              name: rawExtracted,
              area: 'George Town',
              description: 'Popular attraction in Penang',
              lat: 5.414,
              lng: 100.328,
              category: 'Attraction',
            );

            lastAiMsg.isOptionChosen = true;
            lastAiMsg.selectedOption = isOptionA ? 'A' : 'B';
            final added = addPlaceToDraft(chosenPlace, fromUserPrompt: true, notifyChat: false);
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final promptSuffix = hasEnough
                ? "You now have ${_draftItinerary.length} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
                : "What other places in Penang would you like to visit next?";
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: added
                    ? "Steady lah! I've added **${chosenPlace.name}** to your draft itinerary (${_draftItinerary.length} total stops). 🚲✨ $promptSuffix"
                    : "**${chosenPlace.name}** is already in your draft itinerary!",
                timestamp: DateTime.now(),
                showActionChips: false,
                quickReplies: null,
              ),
            );
            notifyListeners();
            return;
          }
        }
      }
    }

    // 3. MATCH EXPLICIT "ADD [PLACE NAME]" AGAINST RECENT SUGGESTIONS
    // CRITICAL: If the user is asking a factual inquiry (e.g. "do i need to pay to enter pinang peranakan mansion?"), NEVER intercept as an add command!
    if (!_isFactualInquiry(lower)) {
      for (final msg in _chatMessages.reversed) {
        if (msg.suggestedPlaces != null && msg.suggestedPlaces!.isNotEmpty) {
          for (final sp in msg.suggestedPlaces!) {
            if (_isSystemActionText(sp.name)) continue;
            final spNameLower = sp.name.toLowerCase();
            final isExactMatch = lower == spNameLower;
            final isExplicitAddMatch = (lower.startsWith('add ') ||
                    lower.startsWith('insert ') ||
                    lower.startsWith('put ') ||
                    lower.startsWith('include ') ||
                    lower.startsWith('choose ') ||
                    lower.contains('want to visit') ||
                    lower.contains('want visit') ||
                    lower.contains('wanna visit') ||
                    lower.contains('can we go') ||
                    lower.contains('let\'s go') ||
                    lower.contains('lets go')) &&
                (lower.contains(spNameLower) || spNameLower.contains(lower.replaceFirst(RegExp(r'^(?:add|insert|put|include|choose)\s+'), '')));

            if (isExactMatch || isExplicitAddMatch) {
              msg.isOptionChosen = true;
              msg.selectedOption = sp.name;
              final added = addPlaceToDraft(sp, fromUserPrompt: true, notifyChat: false);
              setMascotState(MascotState.happy);
              final hasEnough = _draftItinerary.length >= 3;
              final promptSuffix = hasEnough
                  ? "You now have ${_draftItinerary.length} spots in your draft! Whenever you're ready, you can view your Draft Plan to generate your customized trip! 📋✨"
                  : "What other places in Penang would you like to visit next?";
              _chatMessages.add(
                ChatMessage(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  sender: MessageSender.ai,
                  text: added
                      ? "Steady lah! I've added **${sp.name}** to your draft itinerary (${_draftItinerary.length} total stops). 🚲✨ $promptSuffix"
                      : "**${sp.name}** is already in your draft itinerary!",
                  timestamp: DateTime.now(),
                  showActionChips: false,
                  quickReplies: null,
                ),
              );
              notifyListeners();
              return;
            }
          }
          break; // Only check the most recent message with suggestions
        }
      }
    }

    // 3.9 TRAVEL HISTORY INQUIRY & UNLOCKED STAMPS INQUIRY:
    // When the user asks "xxx 我是否已经去过了", "have I visited xxx?", "我 unlock 了哪些印章", etc.,
    // evaluate against recorded travel history and official unlocked digital stamps.
    if (await _handleTravelHistoryAndStampInquiry(prompt)) {
      return;
    }

    // 4. EXPLICIT ADD INTENT FOR PREDEFINED PLACES
    final isExplicitAdd = lower.startsWith('add ') ||
        lower.startsWith('insert ') ||
        lower.startsWith('put ') ||
        lower.startsWith('include ') ||
        lower.startsWith('jom go to ') ||
        lower.contains('want to visit') ||
        lower.contains('want visit') ||
        lower.contains('wanna visit') ||
        lower.contains('would like to visit') ||
        lower.contains('want to go') ||
        lower.contains('want go') ||
        lower.contains('wanna go') ||
        lower.contains('can we go') ||
        lower.contains('can we visit') ||
        lower.contains('bring me to') ||
        lower.contains('let\'s go to') ||
        lower.contains('lets go to') ||
        lower.contains('let\'s visit') ||
        lower.contains('lets visit');

    for (var place in kPenangPredefinedPlaces) {
      final nameLower = place.name.toLowerCase();
      bool match = false;
      if (lower == nameLower) {
        match = true;
      } else if (isExplicitAdd) {
        if (lower.contains(nameLower)) {
          match = true;
        } else if (place.id == 'kek_lok_si' && (lower.contains('kek lok') || lower.contains('air itam temple'))) {
          match = true;
        } else if (place.id == 'penang_hill' && (lower.contains('penang hill') || lower.contains('penang hills') || lower.contains('bukit bendera') || lower.contains('hills'))) {
          match = true;
        } else if (place.id == 'george_town_art' && (lower.contains('street art') || lower.contains('mural') || lower.contains('armenian'))) {
          match = true;
        } else if (place.id == 'chew_jetty' && (lower.contains('chew jetty') || lower.contains('clan jetty'))) {
          match = true;
        } else if (place.id == 'escape_penang' && (lower.contains('escape') || lower.contains('theme park'))) {
          match = true;
        } else if (place.id == 'batu_ferringhi' && (lower.contains('batu ferringhi beach') || lower.contains('ferringhi beach'))) {
          match = true;
        } else if (place.id == 'gurney_drive' && (lower.contains('gurney') || lower.contains('hawker'))) {
          match = true;
        } else if (place.id == 'butterworth_art' && (lower.contains('butterworth') || lower.contains('mainland'))) {
          match = true;
        }
      }

      if (match) {
        addPlaceToDraft(place, fromUserPrompt: true);
        return;
      }
    }

    // 4.5 AREA DETECTION & BATCH PREFILL FOR QUICK PLAN SHORTCUT
    final extractedAreaInfo = _extractAreaAndPostcodeFromText(prompt);
    if (extractedAreaInfo != null) {
      _userSpecifiedArea = extractedAreaInfo.area;
      _userSpecifiedPostcode = extractedAreaInfo.postcode;
      _userSpecifiedCatalogKey = extractedAreaInfo.catalogKey;
      debugPrint('📍 [SESSION AREA UPDATED BY USER INPUT]');
      debugPrint('   • Set Target Area    : "$_userSpecifiedArea"');
      debugPrint('   • Set Target Postcode: "$_userSpecifiedPostcode"');
    }

    final isExplicitQuickPlan = RegExp(
      r'^\s*(?:plan\s+(?:a\s+)?trip\s+for\s+me\s+in|quick\s+plan\s+(?:for|by\s+area\s+in|in))\b',
      caseSensitive: false,
    ).hasMatch(lower);

    final List<ItineraryPlace> newlyAddedBatch = [];
    if (isExplicitQuickPlan && extractedAreaInfo != null) {
      final tour = kPenangAreaTourCatalog[extractedAreaInfo.catalogKey];
      if (tour != null) {
        for (final p in tour.places.take(3)) {
          if (!_draftItinerary.any((d) => d.name.toLowerCase() == p.name.toLowerCase())) {
            _draftItinerary.add(p);
            newlyAddedBatch.add(p);
          }
        }
        if (_timeline.isNotEmpty) {
          _recalculateReviewTimeline();
        }
      }
    }

    // 4.6 DIGITAL STAMP HUNT SHORTCUT & EXPLICIT STAMP QUERY:
    // When the user taps the '🎯 Digital Stamp Hunt' shortcut chip or requests stamps,
    // immediately evaluate via _handleAreaTourPlanning so recommendations are strictly
    // drawn from the 28 authentic digital stamps in George Town.
    final isExplicitStampRequest = lower.contains('stamp') ||
        lower.contains('digital stamp') ||
        lower.contains('stamps') ||
        lower.contains('印章');
    if (isExplicitStampRequest && !_isFactualInquiry(prompt)) {
      if (await _handleAreaTourPlanning(prompt)) {
        return;
      }
    }

    // 5. QUERY LLM BACKEND (Ollama + Persona Engine & MongoDB Grounding)
    // All shortcuts (Indoor Discovery, Foodie Guide, Classic Heritage, Quick Plan, etc.)
    // are now processed by Ollama with live Persona Engine & MongoDB RAG!
    await _queryLLMCompanion(
      prompt,
      isQuickPlanBatch: isExplicitQuickPlan,
      newlyAddedBatch: newlyAddedBatch,
    );
  }

  // Helper to extract known Penang area and postcode from user text input
  ({String area, String postcode, String catalogKey})? _extractAreaAndPostcodeFromText(String text) {
    final lower = text.toLowerCase().trim();

    // 1. Postcode match
    final postcodeMatch = RegExp(r'\b(1[0-4]\d{3}|\d{5})\b').firstMatch(lower);
    final code = postcodeMatch?.group(1);
    if (code != null) {
      final codeNum = int.tryParse(code) ?? 0;
      if (codeNum >= 10000 && codeNum <= 10450) {
        return (area: 'George Town', postcode: code, catalogKey: 'george_town');
      } else if (codeNum >= 10470 && codeNum <= 11200) {
        return (area: 'Tanjung Bungah', postcode: code, catalogKey: 'tanjung_bungah');
      } else if (codeNum == 11050) {
        return (area: 'Air Itam', postcode: code, catalogKey: 'air_itam');
      } else if (codeNum == 11100) {
        return (area: 'Batu Ferringhi', postcode: code, catalogKey: 'batu_ferringhi');
      } else if (codeNum == 11000) {
        return (area: 'Balik Pulau', postcode: code, catalogKey: 'balik_pulau');
      } else if (codeNum >= 11010 && codeNum <= 11020) {
        return (area: 'Teluk Bahang', postcode: code, catalogKey: 'teluk_bahang');
      } else if (codeNum >= 11900 && codeNum <= 11960) {
        return (area: 'Bayan Lepas', postcode: code, catalogKey: 'bayan_lepas');
      } else if (codeNum >= 12000 && codeNum <= 13800) {
        return (area: 'Butterworth', postcode: code, catalogKey: 'butterworth');
      }
    }

    // 2. Direct Area Name match
    if (lower.contains('george town') ||
        lower.contains('georgetown') ||
        lower.contains('armenian') ||
        lower.contains('chulia') ||
        lower.contains('unesco')) {
      return (area: 'George Town', postcode: '10200', catalogKey: 'george_town');
    }
    if (lower.contains('air itam') ||
        lower.contains('ayer itam') ||
        lower.contains('penang hill') ||
        lower.contains('bukit bendera') ||
        lower.contains('kek lok si') ||
        lower.contains('kek lok')) {
      return (area: 'Air Itam', postcode: '11050', catalogKey: 'air_itam');
    }
    if (lower.contains('batu ferringhi') ||
        lower.contains('ferringhi') ||
        lower.contains('batu feringghi') ||
        lower.contains('batu ferringi') ||
        lower.contains('beach') ||
        lower.contains('coastal')) {
      return (area: 'Batu Ferringhi', postcode: '11100', catalogKey: 'batu_ferringhi');
    }
    if (lower.contains('teluk bahang') ||
        lower.contains('escape') ||
        lower.contains('entopia') ||
        lower.contains('national park')) {
      return (area: 'Teluk Bahang', postcode: '11010', catalogKey: 'teluk_bahang');
    }
    if (lower.contains('balik pulau') ||
        lower.contains('countryside') ||
        lower.contains('durian') ||
        lower.contains('nutmeg') ||
        lower.contains('audi dream') ||
        lower.contains('audi farm')) {
      return (area: 'Balik Pulau', postcode: '11000', catalogKey: 'balik_pulau');
    }
    if (lower.contains('bayan lepas') ||
        lower.contains('batu maung') ||
        lower.contains('queensbay') ||
        lower.contains('snake temple') ||
        lower.contains('south penang') ||
        lower.contains('southern penang')) {
      return (area: 'Bayan Lepas', postcode: '11900', catalogKey: 'bayan_lepas');
    }
    if (lower.contains('butterworth') ||
        lower.contains('seberang perai') ||
        lower.contains('raja uda') ||
        lower.contains('seberang jaya') ||
        lower.contains('mainland') ||
        lower.contains('bird park')) {
      return (area: 'Butterworth', postcode: '12000', catalogKey: 'butterworth');
    }
    if (lower.contains('tanjung bungah') ||
        lower.contains('tanjung tokong') ||
        lower.contains('straits quay') ||
        lower.contains('floating mosque') ||
        lower.contains('avatar')) {
      return (area: 'Tanjung Bungah', postcode: '11200', catalogKey: 'tanjung_bungah');
    }
    if (lower.contains('gurney') ||
        lower.contains('pulau tikus') ||
        lower.contains('wat chaiya') ||
        lower.contains('dhammikarama')) {
      return (area: 'Gurney Drive', postcode: '10250', catalogKey: 'gurney');
    }

    return null;
  }

  // Resolve user real-time location to nearest Penang area and postcode.
  // Checks GPS first, then user-specified area session state, then falls back strictly to George Town (postcode 10200).
  Future<({String area, String postcode, String catalogKey, double lat, double lng, bool isRealGps})>
      _resolveUserLocationArea() async {
    const centroids = <String, ({double lat, double lng, String postcode, String catalogKey})>{
      'George Town': (lat: 5.4141, lng: 100.3288, postcode: '10200', catalogKey: 'george_town'),
      'Gurney Drive': (lat: 5.4385, lng: 100.3090, postcode: '10250', catalogKey: 'gurney'),
      'Tanjung Bungah': (lat: 5.4600, lng: 100.2850, postcode: '11200', catalogKey: 'tanjung_bungah'),
      'Batu Ferringhi': (lat: 5.4748, lng: 100.2483, postcode: '11100', catalogKey: 'batu_ferringhi'),
      'Teluk Bahang': (lat: 5.4500, lng: 100.2150, postcode: '11010', catalogKey: 'teluk_bahang'),
      'Air Itam': (lat: 5.4000, lng: 100.2750, postcode: '11050', catalogKey: 'air_itam'),
      'Balik Pulau': (lat: 5.3516, lng: 100.2369, postcode: '11000', catalogKey: 'balik_pulau'),
      'Bayan Lepas': (lat: 5.2950, lng: 100.2650, postcode: '11900', catalogKey: 'bayan_lepas'),
      'Butterworth': (lat: 5.3991, lng: 100.3638, postcode: '12000', catalogKey: 'butterworth'),
    };

    double calcDist(double lat1, double lon1, double lat2, double lon2) {
      const p = 0.017453292519943295;
      final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
          cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
      return 12742 * asin(sqrt(a));
    }

    try {
      var pos = LocationService().lastKnownPosition;
      pos ??= await LocationService().getCurrentPosition(timeLimit: const Duration(seconds: 2));

      if (pos != null) {
        String bestArea = 'George Town';
        var bestData = centroids['George Town']!;
        double minDist = double.infinity;

        for (final entry in centroids.entries) {
          final d = calcDist(pos.latitude, pos.longitude, entry.value.lat, entry.value.lng);
          if (d < minDist) {
            minDist = d;
            bestArea = entry.key;
            bestData = entry.value;
          }
        }

        // If within 35 km of Penang
        if (minDist <= 35.0) {
          debugPrint('📍 [REAL-TIME LOCATION RESOLUTION]');
          debugPrint('   • GPS Coordinates : Lat ${pos.latitude.toStringAsFixed(4)}, Lng ${pos.longitude.toStringAsFixed(4)}');
          debugPrint('   • Closest Area    : "$bestArea" (Distance: ${minDist.toStringAsFixed(2)} km, Postcode: ${bestData.postcode})');
          return (
            area: bestArea,
            postcode: bestData.postcode,
            catalogKey: bestData.catalogKey,
            lat: pos.latitude,
            lng: pos.longitude,
            isRealGps: true,
          );
        }
      }
    } catch (e) {
      debugPrint('   • GPS Resolution note: $e');
    }

    // If no real-time GPS is available, check if the user previously specified an area
    if (_userSpecifiedArea != null) {
      final centroidData = centroids[_userSpecifiedArea] ?? centroids['George Town']!;
      debugPrint('📍 [REAL-TIME LOCATION RESOLUTION]');
      debugPrint('   • GPS Coordinates : None (GPS disabled, denied, or timed out)');
      debugPrint('   • Using User-Set Session Area: "$_userSpecifiedArea" (Postcode: $_userSpecifiedPostcode)');
      return (
        area: _userSpecifiedArea!,
        postcode: _userSpecifiedPostcode ?? centroidData.postcode,
        catalogKey: _userSpecifiedCatalogKey ?? centroidData.catalogKey,
        lat: centroidData.lat,
        lng: centroidData.lng,
        isRealGps: false,
      );
    }

    // Fallback strictly to George Town
    debugPrint('📍 [REAL-TIME LOCATION RESOLUTION]');
    debugPrint('   • GPS Coordinates : None (GPS disabled, denied, or timed out)');
    debugPrint('   • Fallback Applied: George Town (Postcode: 10200)');
    return (
      area: 'George Town',
      postcode: '10200',
      catalogKey: 'george_town',
      lat: 5.4141,
      lng: 100.3288,
      isRealGps: false,
    );
  }

  // Handle tour planning requests and recommendation requests.
  // ONLY if the prompt is an explicit quick plan command ("Plan trip for me in [Area]" from the shortcut)
  // does it auto-add the 3 iconic spots to the draft itinerary.
  // For all general recommendation / suggestion queries ("suggest me places near gurney", "I am looking for beaches", etc.),
  // it NEVER modifies the draft itinerary and ALWAYS gives options (Option A & Option B) to the user.
  Future<bool> _handleAreaTourPlanning(String prompt) async {
    final lower = prompt.toLowerCase().trim();

    if (_isFactualInquiry(prompt)) return false;

    // Detect if this is an explicit quick plan request (e.g. triggered via "Quick plan by area" shortcut)
    final isExplicitQuickPlan = RegExp(
      r'^\s*(?:plan\s+(?:a\s+)?trip\s+for\s+me\s+in|quick\s+plan\s+(?:for|by\s+area\s+in|in))\b',
      caseSensitive: false,
    ).hasMatch(lower);

    // Check for tour / short trip / itinerary / visit / explore / recommendation intents
    final isTourRequest = lower.contains('tour') ||
        lower.contains('short trip') ||
        lower.contains('day trip') ||
        lower.contains('half day') ||
        lower.contains('itinerary') ||
        lower.contains('places to visit') ||
        lower.contains('place to visit') ||
        lower.contains('plan a tour') ||
        lower.contains('plan a trip') ||
        lower.contains('what to do in') ||
        lower.contains('what to visit in') ||
        lower.contains('what to see in') ||
        lower.contains('bring me to') ||
        lower.contains('attractions in') ||
        lower.contains('jom jalan') ||
        lower.contains('sightseeing');

    // Extract known Penang area and postcode from prompt (if any)
    final extractedAreaInfo = _extractAreaAndPostcodeFromText(prompt);
    final isExplicitAreaMention = extractedAreaInfo != null;
    if (isExplicitAreaMention) {
      _userSpecifiedArea = extractedAreaInfo.area;
      _userSpecifiedPostcode = extractedAreaInfo.postcode;
      _userSpecifiedCatalogKey = extractedAreaInfo.catalogKey;
      debugPrint('📍 [SESSION AREA UPDATED BY USER INPUT]');
      debugPrint('   • User Input         : "$prompt"');
      debugPrint('   • Set Target Area    : "$_userSpecifiedArea"');
      debugPrint('   • Set Target Postcode: "$_userSpecifiedPostcode"');
      debugPrint('   • Catalog Key        : "$_userSpecifiedCatalogKey"');
      debugPrint('   • Persistence        : Stored in session for subsequent queries & shortcuts');
    }

    final isRecommendationRequest = isExplicitAreaMention ||
        lower.contains('suggest') ||
        lower.contains('recommend') ||
        lower.contains('looking for') ||
        lower.contains('look for') ||
        lower.contains('i want') ||
        lower.contains('i wish') ||
        lower.contains('i would like') ||
        lower.contains('i wanna') ||
        lower.contains('want to') ||
        lower.contains('want visit') ||
        lower.contains('want to visit') ||
        lower.contains('clan house') ||
        lower.contains('clan houses') ||
        lower.contains('kongsi') ||
        lower.contains('jetty') ||
        lower.contains('indoor') ||
        lower.contains('stamp') ||
        lower.contains('heritage') ||
        lower.contains('food') ||
        lower.contains('foodie') ||
        lower.contains('breakfast') ||
        lower.contains('tea') ||
        lower.contains('night market') ||
        lower.contains('bars') ||
        lower.contains('bar') ||
        lower.contains('beach') ||
        lower.contains('coastal') ||
        lower.contains('cafe') ||
        lower.contains('nature') ||
        lower.contains('temple') ||
        lower.contains('shopping') ||
        lower.contains('sunset') ||
        lower.contains('mural') ||
        lower.contains('where to go') ||
        lower.contains('what to see') ||
        lower.contains('what can i visit') ||
        lower.contains('what else') ||
        lower.contains('anything else') ||
        lower.contains('something else') ||
        lower.contains('other place') ||
        lower.contains('other option') ||
        lower.contains('another') ||
        lower.contains('我想') ||
        lower.contains('我要') ||
        lower.contains('想去') ||
        lower.contains('还有什么') ||
        lower.contains('还有别的') ||
        lower.contains('其他推荐') ||
        lower.contains('别的');

    final isClassicHeritage = lower.contains('classic heritage') || lower.contains('1-day classic heritage');
    final wasLastIndoor = _chatMessages.isNotEmpty &&
        _chatMessages.reversed.take(6).any((m) => m.text.toLowerCase().contains('indoor discovery'));
    final wasLastStampHunt = _chatMessages.isNotEmpty &&
        _chatMessages.reversed.take(6).any((m) => m.text.toLowerCase().contains('digital stamp'));

    final isIndoorDiscovery = lower.contains('indoor') ||
        (wasLastIndoor && (lower.contains('what else') || lower.contains('anything else') || lower.contains('other') || lower.contains('another') || lower.contains('还有')));

    final isExplicitStampRequest = lower.contains('stamp') ||
        lower.contains('digital stamp') ||
        lower.contains('stamps') ||
        lower.contains('印章');

    // Digital stamp hunt is triggered when explicitly requested (e.g. shortcut chip or "stamp" query).
    // If the user previously triggered stamp hunt and then asks for "other suggestions" / "what else",
    // isStampHunt remains false so the companion can suggest places out of (outside) the 28 places!
    final isStampHunt = isExplicitStampRequest;

    // 1. EXTRACT POSTCODE (e.g. 10200, 11050, 11100, 11900, etc.)
    final postcodeMatch = RegExp(r'\b(1[0-4]\d{3}|\d{5})\b').firstMatch(prompt);
    String? postcode = postcodeMatch?.group(1) ?? (isExplicitAreaMention ? extractedAreaInfo.postcode : null);

    debugPrint('====================================================');
    debugPrint('🤖 [TRIP CONTROLLER] Processing prompt: "$prompt"');
    debugPrint('🔍 [INTENT EVALUATION]');
    debugPrint('   • isExplicitQuickPlan    : $isExplicitQuickPlan');
    debugPrint('   • isExplicitAreaMention  : $isExplicitAreaMention');
    debugPrint('   • isTourRequest          : $isTourRequest');
    debugPrint('   • isRecommendationRequest: $isRecommendationRequest');
    debugPrint('   • isIndoorDiscovery      : $isIndoorDiscovery');
    debugPrint('   • isStampHunt            : $isStampHunt');
    debugPrint('   • wasLastStampHunt       : $wasLastStampHunt');
    debugPrint('   • isClassicHeritage      : $isClassicHeritage');

    // 2. EXTRACT TARGET AREA & MATCHED TOUR
    PenangAreaTour? matchedTour;
    String targetArea = 'George Town';
    double userLat = 5.4141;
    double userLng = 100.3288;

    if (isClassicHeritage) {
      // Classic Heritage is strictly focused on George Town UNESCO zone
      matchedTour = kPenangAreaTourCatalog['george_town'];
      targetArea = 'George Town';
      postcode ??= '10200';
      debugPrint('🏛️ [CLASSIC HERITAGE] Explicitly locked to George Town UNESCO Heritage Zone.');
    } else if (isStampHunt) {
      // Digital Stamp Hunt is strictly focused on George Town where all 28 digital stamps reside
      matchedTour = kPenangAreaTourCatalog['george_town'];
      targetArea = 'George Town';
      postcode ??= '10200';
      debugPrint('📜 [DIGITAL STAMP HUNT] Explicitly locked to George Town where 28 digital stamps reside.');
    } else if (isExplicitAreaMention) {
      targetArea = extractedAreaInfo.area;
      postcode ??= extractedAreaInfo.postcode;
      matchedTour = kPenangAreaTourCatalog[extractedAreaInfo.catalogKey] ?? kPenangAreaTourCatalog['george_town'];
      debugPrint('📍 [EXPLICIT AREA SELECTION] Using target area: "$targetArea" (Postcode: $postcode)');
    } else {
      // Check for explicit area mentions in prompt
      if (lower.contains('george town') ||
          lower.contains('georgetown') ||
          lower.contains('armenian') ||
          lower.contains('chulia') ||
          lower.contains('unesco')) {
        matchedTour = kPenangAreaTourCatalog['george_town'];
        targetArea = 'George Town';
      } else if (lower.contains('air itam') ||
          lower.contains('ayer itam') ||
          lower.contains('penang hill') ||
          lower.contains('bukit bendera') ||
          lower.contains('kek lok si') ||
          lower.contains('kek lok')) {
        matchedTour = kPenangAreaTourCatalog['air_itam'];
        targetArea = 'Air Itam';
      } else if (lower.contains('batu ferringhi') ||
          lower.contains('ferringhi') ||
          lower.contains('batu feringghi') ||
          lower.contains('batu ferringi') ||
          lower.contains('beach') ||
          lower.contains('coastal')) {
        matchedTour = kPenangAreaTourCatalog['batu_ferringhi'];
        targetArea = 'Batu Ferringhi';
      } else if (lower.contains('teluk bahang') ||
          lower.contains('escape') ||
          lower.contains('entopia') ||
          lower.contains('national park')) {
        matchedTour = kPenangAreaTourCatalog['teluk_bahang'];
        targetArea = 'Teluk Bahang';
      } else if (lower.contains('balik pulau') ||
          lower.contains('countryside') ||
          lower.contains('durian') ||
          lower.contains('nutmeg') ||
          lower.contains('audi dream') ||
          lower.contains('audi farm')) {
        matchedTour = kPenangAreaTourCatalog['balik_pulau'];
        targetArea = 'Balik Pulau';
      } else if (lower.contains('bayan lepas') ||
          lower.contains('batu maung') ||
          lower.contains('queensbay') ||
          lower.contains('snake temple') ||
          lower.contains('south penang') ||
          lower.contains('southern penang')) {
        matchedTour = kPenangAreaTourCatalog['bayan_lepas'];
        targetArea = 'Bayan Lepas';
      } else if (lower.contains('butterworth') ||
          lower.contains('seberang perai') ||
          lower.contains('raja uda') ||
          lower.contains('seberang jaya') ||
          lower.contains('mainland') ||
          lower.contains('bird park')) {
        matchedTour = kPenangAreaTourCatalog['butterworth'];
        targetArea = 'Butterworth';
      } else if (lower.contains('tanjung bungah') ||
          lower.contains('tanjung tokong') ||
          lower.contains('straits quay') ||
          lower.contains('floating mosque') ||
          lower.contains('avatar')) {
        matchedTour = kPenangAreaTourCatalog['tanjung_bungah'];
        targetArea = 'Tanjung Bungah';
      } else if (lower.contains('gurney') ||
          lower.contains('pulau tikus') ||
          lower.contains('wat chaiya') ||
          lower.contains('dhammikarama')) {
        matchedTour = kPenangAreaTourCatalog['gurney'];
        targetArea = 'Gurney Drive';
      }

      // Inferred area from postcode if no direct area keyword was found
      if (matchedTour == null && postcode != null) {
        final codeNum = int.tryParse(postcode) ?? 0;
        if (codeNum >= 10000 && codeNum <= 10450) {
          matchedTour = kPenangAreaTourCatalog['george_town'];
          targetArea = 'George Town';
        } else if (codeNum >= 10470 && codeNum <= 11200) {
          matchedTour = kPenangAreaTourCatalog['tanjung_bungah'];
          targetArea = 'Tanjung Bungah';
        } else if (codeNum == 11050) {
          matchedTour = kPenangAreaTourCatalog['air_itam'];
          targetArea = 'Air Itam';
        } else if (codeNum == 11100) {
          matchedTour = kPenangAreaTourCatalog['batu_ferringhi'];
          targetArea = 'Batu Ferringhi';
        } else if (codeNum == 11000) {
          matchedTour = kPenangAreaTourCatalog['balik_pulau'];
          targetArea = 'Balik Pulau';
        } else if (codeNum >= 11010 && codeNum <= 11020) {
          matchedTour = kPenangAreaTourCatalog['teluk_bahang'];
          targetArea = 'Teluk Bahang';
        } else if (codeNum >= 11900 && codeNum <= 11960) {
          matchedTour = kPenangAreaTourCatalog['bayan_lepas'];
          targetArea = 'Bayan Lepas';
        } else if (codeNum >= 12000 && codeNum <= 13800) {
          matchedTour = kPenangAreaTourCatalog['butterworth'];
          targetArea = 'Butterworth';
        }
      }

      // If no explicit area matched from prompt words:
      // Focus on George Town first, ONLY Indoor Discovery is based on real-time user location!
      if (matchedTour == null) {
        if (isIndoorDiscovery) {
          final locRes = await _resolveUserLocationArea();
          targetArea = locRes.area;
          postcode ??= locRes.postcode;
          userLat = locRes.lat;
          userLng = locRes.lng;
          matchedTour = kPenangAreaTourCatalog[locRes.catalogKey] ?? kPenangAreaTourCatalog['george_town'];
        } else {
          targetArea = 'George Town';
          postcode ??= '10200';
          userLat = 5.4141;
          userLng = 100.3288;
          matchedTour = kPenangAreaTourCatalog['george_town'];
        }
      }
    }

    if (matchedTour == null) return false;

    // GATE: Prompt MUST be a genuine tour, recommendation, area mention, or shortcut intent!
    // For pure conversational feedback (e.g. "Wow interesting", "Okay cool", "Nice", "Thanks"),
    // return false so the model persona responds naturally through the LLM pipeline.
    final bool hasRecommendationOrTourIntent = isExplicitQuickPlan ||
        isTourRequest ||
        isRecommendationRequest ||
        isClassicHeritage ||
        isIndoorDiscovery ||
        isStampHunt ||
        isExplicitAreaMention;

    if (!hasRecommendationOrTourIntent) {
      debugPrint('ℹ️ [INTENT BYPASS] Prompt has no recommendation/tour intent. Forwarding to LLM Companion...');
      return false;
    }

    // 3. USER PREFERENCES PRESET: Cultural & Heritage, Food & Dining
    const defaultUserPreferences = ['Cultural & Heritage', 'Food & Dining'];
    final defaultPreferenceTokens = ['heritage', 'culture', 'museum', 'history', 'food', 'dining', 'cafe', 'restaurant'];

    debugPrint('👤 [USER PREFERENCES PRESET]');
    debugPrint('   • Default Preferences : ${defaultUserPreferences.join(" & ")}');
    debugPrint('   • Query Boost Keywords: ${defaultPreferenceTokens.join(", ")}');

    // 4. EXTRACT THEMATIC KEYWORDS
    final candidateKeywords = [
      'food', 'hawker', 'cafe', 'coffee', 'dessert', 'heritage', 'culture',
      'museum', 'temple', 'worship', 'nature', 'park', 'beach', 'shopping',
      'night market', 'bazaar', 'family', 'art', 'mural', 'seafood', 'laksa',
      'adventure', 'sunset', 'relax', 'indoor', 'breakfast', 'tea', 'stamp', 'bars'
    ];
    final extractedKeywords = candidateKeywords.where((kw) => lower.contains(kw)).toList();

    // 5. RETRIEVE THE PRESET 3 MUST-VISIT PLACES
    final mustVisitPlaces = matchedTour.places.take(3).toList();
    final excludedNames = <String>{};
    for (final p in _draftItinerary) {
      excludedNames.add(p.name.toLowerCase().trim());
    }
    // Also exclude places previously suggested in chat so alternative recommendations (e.g. "what else") offer fresh spots!
    for (final msg in _chatMessages) {
      if (msg.suggestedPlaces != null) {
        for (final sp in msg.suggestedPlaces!) {
          excludedNames.add(sp.name.toLowerCase().trim());
        }
      }
    }

    // Exploration & Quick Plan query detected: Draft itinerary is NOT modified silently.
    debugPrint('💡 [MODE: RECOMMENDATION & OPTIONS]');
    debugPrint('   • Exploration / Quick Plan query: Draft itinerary is NOT modified.');
    debugPrint('   • Current draft stops count: ${_draftItinerary.length}');

    setMascotState(MascotState.thinking);

    // 6. RETRIEVE CANDIDATE PLACES
    final candidateOptions = <ItineraryPlace>[];

    if (isStampHunt) {
      debugPrint('📜 [DIGITAL STAMP HUNT - 28 MY STAMPS POOL]');
      debugPrint('   • Retrieving official check-in stamp places from 28 My Stamps pool for George Town...');
      var stampList = StampsService.cachedStamps;
      if (stampList.isEmpty) {
        stampList = List.from(kPredefined28DigitalStamps);
      }

      final sortedStamps = List<DigitalStamp>.from(stampList);
      sortedStamps.sort((a, b) {
        // RULE: Prioritize landmarks user has NOT unlocked yet (isUnlocked == false)
        final isUnlockedA = a.isUnlocked ||
            StampsService.isStampUnlocked(a.id) ||
            StampsService.isStampUnlocked(a.title);
        final isUnlockedB = b.isUnlocked ||
            StampsService.isStampUnlocked(b.id) ||
            StampsService.isStampUnlocked(b.title);
        if (!isUnlockedA && isUnlockedB) return -1;
        if (isUnlockedA && !isUnlockedB) return 1;

        final distA = StampsService.calculateDistanceKm(userLat, userLng, a.lat, a.lng);
        final distB = StampsService.calculateDistanceKm(userLat, userLng, b.lat, b.lng);
        final distDiff = (distA - distB).abs();
        if (distDiff > 0.05) {
          return distA.compareTo(distB);
        }
        return a.order.compareTo(b.order);
      });

      debugPrint('   • Found ${sortedStamps.length} stamps. Selecting 2 non-excluded stamp places...');
      for (final s in sortedStamps) {
        final sLower = s.title.toLowerCase().trim();
        bool isExcluded = false;
        for (final ex in excludedNames) {
          if (sLower == ex || sLower.contains(ex) || ex.contains(sLower)) {
            isExcluded = true;
            break;
          }
        }
        if (isExcluded) continue;

        final isUnlocked = s.isUnlocked ||
            StampsService.isStampUnlocked(s.id) ||
            StampsService.isStampUnlocked(s.title);
        final statusTag = isUnlocked ? '⭐ [Collected Stamp]' : '🔒 [Uncollected Stamp — Priority Visit]';

        candidateOptions.add(
          ItineraryPlace(
            id: 'stamp_${s.id}',
            name: s.title,
            area: 'George Town',
            description: s.description.isNotEmpty
                ? '$statusTag ${s.description}'
                : '$statusTag Official digital stamp landmark in Penang.',
            lat: s.lat,
            lng: s.lng,
            category: 'Heritage & Culture',
            estimatedStayMinutes: 45,
            icon: s.icon,
            imageUrl: s.imageUrl.isNotEmpty ? s.imageUrl : null,
          ),
        );
        if (candidateOptions.length >= 2) break;
      }
    } else {
      try {
        // Construct search query
        // For indoor discovery: search targetArea and postcode, filtering by has_aircon=true via parameter
        // DO NOT add the literal word "indoor" into the query string, because places don't have "indoor" in their names/addresses.
        final queryComponents = <String>[targetArea];
        if (!isIndoorDiscovery && extractedKeywords.isNotEmpty) {
          queryComponents.add(extractedKeywords.first);
        }
        if (postcode != null) {
          queryComponents.add(postcode);
        }
        final searchQuery = queryComponents.join(' ');

        if (isIndoorDiscovery) {
          debugPrint('❄️ [INDOOR DISCOVERY RAG FILTER]');
          debugPrint('   • Filter applied  : {"features.has_aircon": true}');
          debugPrint('   • Area Scoped     : $targetArea (Postcode: $postcode)');
          debugPrint('   • Query String    : "$searchQuery"');
          debugPrint('   • Preset Themes   : ${defaultUserPreferences.join(" & ")}');
        }

        debugPrint('--> 🔍 [MongoDB Tour Options] Querying MongoDB for: "$searchQuery" (hasAircon: $isIndoorDiscovery)');

        final mongoResults = await PlacesService()
            .searchMultiplePlaces(searchQuery, hasAircon: isIndoorDiscovery)
            .timeout(const Duration(seconds: 4));

        // Prioritize by user preferences (Cultural & Heritage, Food & Dining)
        final scoredResults = mongoResults.map((item) {
          int prefScore = 0;
          final cat = (item['category'] ?? item['primary_category'] ?? '').toLowerCase();
          final title = (item['title'] ?? item['name'] ?? '').toLowerCase();
          final summary = (item['summary'] ?? item['description'] ?? '').toLowerCase();
          final itemArea = (item['area'] ?? '').toLowerCase();
          final combined = '$cat $title $summary';

          // Heavily reward matching the targetArea
          if (itemArea == targetArea.toLowerCase()) {
            prefScore += 100;
          }

          if (combined.contains('heritage') || combined.contains('culture') || combined.contains('museum')) {
            prefScore += 50;
          }
          if (combined.contains('food') || combined.contains('dining') || combined.contains('cafe') || combined.contains('restaurant')) {
            prefScore += 40;
          }
          return MapEntry(item, prefScore);
        }).toList();

        scoredResults.sort((a, b) => b.value.compareTo(a.value));

        for (final entry in scoredResults) {
          final item = entry.key;
          final title = (item['title'] ?? item['name'] ?? '').trim();
          if (title.isEmpty) continue;
          final titleLower = title.toLowerCase();

          // 避开已存在的地点
          bool isExcluded = false;
          for (final ex in excludedNames) {
            if (titleLower == ex || titleLower.contains(ex) || ex.contains(titleLower)) {
              isExcluded = true;
              break;
            }
          }
          if (isExcluded) continue;

          // Double check features.has_aircon if indoor discovery
          if (isIndoorDiscovery && item['features'] != null) {
            try {
              final feats = json.decode(item['features']!);
              if (feats is Map && feats['has_aircon'] == false) continue;
            } catch (_) {}
          }

          double lat = 5.414;
          double lng = 100.328;
          if (item['coordinates'] != null) {
            try {
              final coords = json.decode(item['coordinates']!);
              if (coords is List && coords.length >= 2) {
                lng = (coords[0] as num).toDouble();
                lat = (coords[1] as num).toDouble();
              }
            } catch (_) {}
          }

          final category = item['category'] ?? 'Attraction';
          final rawSummary = (item['summary'] != null && item['summary']!.trim().isNotEmpty)
              ? item['summary']!.trim()
              : (item['place_summary'] != null && item['place_summary']!.trim().isNotEmpty)
                  ? item['place_summary']!.trim()
                  : '';
          final rawDesc = (item['description'] != null && item['description']!.trim().isNotEmpty)
              ? item['description']!.trim()
              : 'Popular $category in $targetArea';
          final chosenText = rawSummary.isNotEmpty ? rawSummary : rawDesc;
          final conciseSummary = _getConcisePlaceSummary(chosenText);

          final place = ItineraryPlace(
            id: item['id'] ?? 'opt_${DateTime.now().millisecondsSinceEpoch}_${candidateOptions.length}',
            name: title,
            area: item['area'] ?? targetArea,
            address: item['address'],
            description: conciseSummary,
            lat: lat,
            lng: lng,
            category: category,
            estimatedStayMinutes: 50,
            icon: _getCategoryIcon(category),
            imageUrl: item['imagePath'],
          );

          if (!candidateOptions.any((p) => p.name.toLowerCase() == place.name.toLowerCase())) {
            candidateOptions.add(place);
            if (candidateOptions.length >= 2) break;
          }
        }
      } catch (e) {
        debugPrint('--> ⚠️ [MongoDB Query Error in Tour Planning]: $e');
      }
    }

    // Fallback: If returned fewer than 2 non-colliding options, fill STRICTLY from places in the same targetArea!
    if (candidateOptions.length < 2) {
      if (isStampHunt) {
        // Fallback: draw directly from 28 predefined digital stamps
        for (final s in kPredefined28DigitalStamps) {
          final sLower = s.title.toLowerCase().trim();
          if (candidateOptions.any((c) => c.name.toLowerCase().trim() == sLower || sLower.contains(c.name.toLowerCase().trim()))) continue;
          bool isExcluded = false;
          for (final ex in excludedNames) {
            if (sLower == ex || sLower.contains(ex) || ex.contains(sLower)) {
              isExcluded = true;
              break;
            }
          }
          if (isExcluded) continue;

          candidateOptions.add(
            ItineraryPlace(
              id: 'stamp_${s.id}',
              name: s.title,
              area: 'George Town',
              description: s.description.isNotEmpty ? s.description : 'Official digital stamp landmark in Penang.',
              lat: s.lat,
              lng: s.lng,
              category: 'Heritage & Culture',
              estimatedStayMinutes: 45,
              icon: s.icon,
              imageUrl: s.imageUrl.isNotEmpty ? s.imageUrl : null,
            ),
          );
          if (candidateOptions.length >= 2) break;
        }
      } else {
        // First try to pick places belonging strictly to the SAME target area from matchedTour!
        final sameAreaPool = matchedTour.places.where((p) => p.area.toLowerCase() == targetArea.toLowerCase()).toList();
        for (final pre in sameAreaPool) {
          final preLower = pre.name.toLowerCase().trim();
          bool isExcluded = false;
          for (final ex in excludedNames) {
            if (preLower == ex || preLower.contains(ex) || ex.contains(preLower)) {
              isExcluded = true;
              break;
            }
          }
          if (isExcluded) continue;
          if (!candidateOptions.any((p) => p.name.toLowerCase() == preLower)) {
            candidateOptions.add(pre);
            if (candidateOptions.length >= 2) break;
          }
        }

        // If still need places, check predefined places in the SAME target area
        if (candidateOptions.length < 2) {
          final sameAreaPredefined = kPenangPredefinedPlaces.where((p) => p.area.toLowerCase() == targetArea.toLowerCase()).toList();
          for (final pre in sameAreaPredefined) {
            final preLower = pre.name.toLowerCase().trim();
            bool isExcluded = false;
            for (final ex in excludedNames) {
              if (preLower == ex || preLower.contains(ex) || ex.contains(preLower)) {
                isExcluded = true;
                break;
              }
            }
            if (isExcluded) continue;
            if (!candidateOptions.any((p) => p.name.toLowerCase() == preLower)) {
              candidateOptions.add(pre);
              if (candidateOptions.length >= 2) break;
            }
          }
        }

        // Only as a final resort if the targetArea has literally no places in catalog, pick from predefined
        if (candidateOptions.length < 2) {
          for (final pre in kPenangPredefinedPlaces) {
            final preLower = pre.name.toLowerCase().trim();
            bool isExcluded = false;
            for (final ex in excludedNames) {
              if (preLower == ex || preLower.contains(ex) || ex.contains(preLower)) {
                isExcluded = true;
                break;
              }
            }
            if (isExcluded) continue;
            if (!candidateOptions.any((p) => p.name.toLowerCase() == preLower)) {
              candidateOptions.add(pre);
              if (candidateOptions.length >= 2) break;
            }
          }
        }
      }
    }

    // Default emergency options if needed
    if (candidateOptions.isEmpty) {
      if (isStampHunt) {
        final s = kPredefined28DigitalStamps[0];
        candidateOptions.add(
          ItineraryPlace(
            id: 'stamp_${s.id}',
            name: s.title,
            area: 'George Town',
            description: s.description.isNotEmpty ? s.description : 'Official digital stamp landmark in Penang.',
            lat: s.lat,
            lng: s.lng,
            category: 'Heritage & Culture',
            estimatedStayMinutes: 45,
            icon: s.icon,
            imageUrl: s.imageUrl.isNotEmpty ? s.imageUrl : null,
          ),
        );
      } else {
        candidateOptions.add(
          ItineraryPlace(
            id: 'opt_default_1',
            name: 'ChinaHouse Cafe & Arts',
            area: targetArea,
            description: 'Air-conditioned traditional shophouse cafe with artisan desserts and art.',
            lat: 5.4148,
            lng: 100.3385,
            category: 'Cafes',
            estimatedStayMinutes: 60,
            icon: Icons.coffee,
          ),
        );
      }
    }
    if (candidateOptions.length < 2) {
      if (isStampHunt) {
        final s = kPredefined28DigitalStamps.firstWhere(
          (stamp) => stamp.title.toLowerCase() != candidateOptions[0].name.toLowerCase(),
          orElse: () => kPredefined28DigitalStamps[1],
        );
        candidateOptions.add(
          ItineraryPlace(
            id: 'stamp_${s.id}',
            name: s.title,
            area: 'George Town',
            description: s.description.isNotEmpty ? s.description : 'Official digital stamp landmark in Penang.',
            lat: s.lat,
            lng: s.lng,
            category: 'Heritage & Culture',
            estimatedStayMinutes: 45,
            icon: s.icon,
            imageUrl: s.imageUrl.isNotEmpty ? s.imageUrl : null,
          ),
        );
      } else {
        candidateOptions.add(
          ItineraryPlace(
            id: 'opt_default_2',
            name: 'Wonderfood Museum',
            area: targetArea,
            description: 'Air-conditioned indoor heritage culinary museum celebrating Penang food culture.',
            lat: 5.4162,
            lng: 100.3411,
            category: 'Heritage & Culture',
            estimatedStayMinutes: 60,
            icon: Icons.museum,
          ),
        );
      }
    }

    final optionA = candidateOptions[0];
    final optionB = candidateOptions[1];

    setMascotState(MascotState.happy);

    // 7. BUILD RICH MESSAGE
    final buffer = StringBuffer();
    if (isExplicitQuickPlan) {
      buffer.writeln("${matchedTour.emoji} I've planned your tour for **${matchedTour.displayName}**!");
      if (extractedKeywords.isNotEmpty || postcode != null) {
        final criteria = [
          if (extractedKeywords.isNotEmpty) "Theme: ${extractedKeywords.join(', ')}",
          if (postcode != null) "Postcode: $postcode",
        ].join(' | ');
        buffer.writeln("*($criteria)*");
      }
      buffer.writeln();
      buffer.writeln("✨ **Here are iconic must-visit highlights for $targetArea:**");
      for (int i = 0; i < mustVisitPlaces.length; i++) {
        final p = mustVisitPlaces[i];
        buffer.writeln("${i + 1}. **${p.name}** (${p.area}) — ${_getConcisePlaceSummary(p.description)}");
      }
      buffer.writeln();
      buffer.writeln("🎯 **Which of these top options would you like to start with?**");
      buffer.writeln("• **Option A: ${optionA.name}** (${optionA.category}) — ${_getConcisePlaceSummary(optionA.description)}");
      buffer.writeln("• **Option B: ${optionB.name}** (${optionB.category}) — ${_getConcisePlaceSummary(optionB.description)}");
      buffer.writeln();
      buffer.writeln("👉 Tap **Option A** or **Option B** below to add to your plan!");
    } else if (isStampHunt) {
      final totalUnlocked = StampsService.cachedStamps.where((s) =>
        s.isUnlocked || StampsService.isStampUnlocked(s.id) || StampsService.isStampUnlocked(s.title)
      ).length;
      final remainingCount = 28 - totalUnlocked;

      if (wasLastStampHunt) {
        buffer.writeln("📜 **Digital Stamp Hunt: More Stamp Locations!**");
        buffer.writeln();
        if (remainingCount > 0) {
          buffer.writeln("Here are two more official check-in spots in **George Town** (prioritizing your **$remainingCount uncollected** stamps) where you can visit and collect digital stamps in your Kia Kia Penang app:");
        } else {
          buffer.writeln("Here are two more official check-in spots in **George Town** where you can visit and collect digital stamps in your Kia Kia Penang app:");
        }
      } else {
        buffer.writeln("📜 **Digital Stamp Hunt: Collect Stamps in App!**");
        buffer.writeln();
        if (remainingCount > 0) {
          buffer.writeln("You've unlocked **$totalUnlocked / 28** digital stamps! Prioritizing your **$remainingCount uncollected** landmarks, here are two official check-in spots in **George Town** for you to visit and unlock:");
        } else {
          buffer.writeln("Congratulations, you have unlocked all **28 / 28** digital stamps! Here are two official check-in spots in **George Town** to explore:");
        }
      }
      buffer.writeln();
      buffer.writeln("• **Option A: ${optionA.name}** (${optionA.area}) — ${_getConcisePlaceSummary(optionA.description)}");
      buffer.writeln("• **Option B: ${optionB.name}** (${optionB.area}) — ${_getConcisePlaceSummary(optionB.description)}");
      buffer.writeln();
      buffer.writeln("👉 Tap **Option A** or **Option B** below to add to your plan and collect this stamp!");
    } else if (isIndoorDiscovery) {
      buffer.writeln("🌧️ **Indoor Discovery in $targetArea (Air-Conditioned)**");
      buffer.writeln();
      buffer.writeln("Rain detected! Here are two air-conditioned indoor places matching your preferences (Cultural & Heritage, Food & Dining):");
      buffer.writeln();
      buffer.writeln("• **Option A: ${optionA.name}** (${optionA.category}) — ${_getConcisePlaceSummary(optionA.description)}");
      buffer.writeln("• **Option B: ${optionB.name}** (${optionB.category}) — ${_getConcisePlaceSummary(optionB.description)}");
      buffer.writeln();
      buffer.writeln("👉 Tap **Option A** or **Option B** below to stay dry and enjoy your indoor visit!");
    } else {
      final topicTitle = extractedKeywords.isNotEmpty
          ? "${extractedKeywords.join(' & ')} in $targetArea"
          : targetArea;

      if (wasLastStampHunt) {
        buffer.writeln("✨ **Here are two other great Penang highlights beyond the stamp collection spots:**");
      } else if (isExplicitAreaMention && !isTourRequest && extractedKeywords.isEmpty) {
        buffer.writeln("📍 **Got it! I've updated your target area to $targetArea ($postcode).**");
        buffer.writeln();
        buffer.writeln("${matchedTour.emoji} Here are two great options I recommend for **$targetArea**:");
      } else {
        buffer.writeln("${matchedTour.emoji} **Here are two great options I recommend for $topicTitle:**");
      }
      buffer.writeln();
      buffer.writeln("• **Option A: ${optionA.name}** (${optionA.category}) — ${_getConcisePlaceSummary(optionA.description)}");
      buffer.writeln("• **Option B: ${optionB.name}** (${optionB.category}) — ${_getConcisePlaceSummary(optionB.description)}");
      buffer.writeln();
      buffer.writeln("👉 Tap **Option A** or **Option B** below to add to your plan, or tap **Add both suggestions**!");
      buffer.writeln("💡 *Tip: If you'd like me to build a complete ready-made day trip for this area, tap the **Quick plan by area** shortcut!*");
    }

    debugPrint('🎯 [CANDIDATE OPTIONS RETRIEVED]');
    debugPrint('   • Option A: "${optionA.name}" (${optionA.category} - ${optionA.area})');
    debugPrint('   • Option B: "${optionB.name}" (${optionB.category} - ${optionB.area})');
    debugPrint('📨 [DISPATCH] Emitting AI message with option buttons: ["Option A: ${optionA.name}", "Option B: ${optionB.name}"]');
    debugPrint('====================================================');

    final quickReplies = [
      'Option A: ${optionA.name}',
      'Option B: ${optionB.name}',
    ];
    final suggestedPlaces = [optionA, optionB];

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: buffer.toString().trim(),
        timestamp: DateTime.now(),
        showActionChips: false,
        referencedPlaces: isExplicitQuickPlan ? mustVisitPlaces : null,
        suggestedPlaces: suggestedPlaces,
        quickReplies: quickReplies,
      ),
    );

    notifyListeners();
    return true;
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('cafe') || cat.contains('coffee') || cat.contains('dessert')) return Icons.coffee;
    if (cat.contains('food') || cat.contains('restaurant') || cat.contains('hawker')) return Icons.restaurant;
    if (cat.contains('beach')) return Icons.beach_access;
    if (cat.contains('hotel') || cat.contains('stay') || cat.contains('resort')) return Icons.hotel;
    if (cat.contains('museum') || cat.contains('gallery')) return Icons.museum;
    if (cat.contains('temple') || cat.contains('worship')) return Icons.temple_buddhist;
    if (cat.contains('park') || cat.contains('nature')) return Icons.eco;
    return Icons.place;
  }

  Future<void> _queryLLMCompanion(
    String prompt, {
    bool isQuickPlanBatch = false,
    List<ItineraryPlace> newlyAddedBatch = const [],
  }) async {
    // 1. Determine Mode for Dynamic Dispatcher
    String mode = 'global_explorer';
    if (_hasActiveTrip) {
      mode = 'in_trip_assistant';
    } else if (isQuickPlanBatch) {
      // Quick plan batch uses global_explorer to introduce the foundational highlights without triggering draft save nudge
      mode = 'global_explorer';
    } else if (_draftItinerary.isNotEmpty) {
      mode = 'draft_modifier';
    }

    // 2. Format Conversation History (excluding the current latest user message to avoid duplication)
    final historyPayload = _chatMessages.length > 1
        ? _chatMessages
            .sublist(0, _chatMessages.length - 1)
            .map((m) => {
                  'role': m.sender == MessageSender.user ? 'user' : 'assistant',
                  'content': m.text,
                  'quickReplies': m.quickReplies ?? [],
                  'suggestedPlaces': m.suggestedPlaces?.map((p) => p.name).toList() ?? [],
                })
            .toList()
        : <Map<String, dynamic>>[];

    // 3. Construct Context Payload
    final lowerPrompt = prompt.toLowerCase();
    final wasLastIndoor = _chatMessages.isNotEmpty &&
        _chatMessages.reversed.take(3).any((m) => m.text.toLowerCase().contains('indoor discovery'));
    final isIndoorDiscovery = lowerPrompt.contains('indoor') ||
        (wasLastIndoor && (lowerPrompt.contains('what else') || lowerPrompt.contains('anything else') || lowerPrompt.contains('other') || lowerPrompt.contains('another') || lowerPrompt.contains('还有')));

    final resolvedLoc = await _resolveUserLocationArea();
    final String effectiveArea;
    final String effectivePostcode;
    if (_userSpecifiedArea != null) {
      effectiveArea = _userSpecifiedArea!;
      effectivePostcode = _userSpecifiedPostcode ?? '10200';
    } else if (isIndoorDiscovery) {
      // ONLY Indoor Discovery uses user real-time location (with fallback to George Town)
      effectiveArea = resolvedLoc.area;
      effectivePostcode = resolvedLoc.postcode;
    } else {
      // General user queries without mentioning area focus on George Town first!
      effectiveArea = 'George Town';
      effectivePostcode = '10200';
    }

    final contextPayload = <String, dynamic>{
      'targetArea': effectiveArea,
      'targetPostcode': effectivePostcode,
      'isIndoorDiscovery': isIndoorDiscovery,
      'isQuickPlanBatch': isQuickPlanBatch,
      'newlyAddedBatch': newlyAddedBatch.map((p) => {
        'name': p.name,
        'area': p.area,
        'category': p.category,
        'summary': _getConcisePlaceSummary(p.description, maxLen: 65),
      }).toList(),
      'userLocation': {
        'area': resolvedLoc.area,
        'postcode': resolvedLoc.postcode,
        'lat': resolvedLoc.lat,
        'lng': resolvedLoc.lng,
        'isRealGps': resolvedLoc.isRealGps,
      },
      'draftSpotCount': _draftItinerary.length,
      'existingTripDates': _travelDates != null ? [
        {
          'startDate': _travelDates!.start.toIso8601String(),
          'endDate': _travelDates!.end.toIso8601String(),
          'title': 'Penang Vacation',
        }
      ] : [],
      'draftPlan': {
        'scheduleDate': _travelDates?.start.toIso8601String() ?? '',
        'stops': _draftItinerary.asMap().entries.map((e) => {
          'sequence': e.key + 1,
          'placeName': e.value.name,
          'area': e.value.area,
          'category': e.value.category,
          'suggestedArrivalWindow': e.value.bestVisitTime ?? 'Flexible',
          'durationMinutes': e.value.estimatedStayMinutes,
          'weatherTag': e.value.warningFlag ?? 'None',
        }).toList(),
      },
      'travelHistory': {
        'totalCompletedTrails': CompletedTrailsManager.getAllTrails().length,
        'visitedPlaces': CompletedTrailsManager.getAllVisitedPlaceNames(),
        'unlockedDigitalStamps': StampsService.cachedStamps
            .where((s) => s.isUnlocked || StampsService.isStampUnlocked(s.id) || StampsService.isStampUnlocked(s.title))
            .map((s) => s.title)
            .toList(),
      },
    };

    if (_hasActiveTrip) {
      contextPayload['activeTrip'] = {
        'tripId': 'active_trip_${DateTime.now().millisecondsSinceEpoch}',
        'currentStopIndex': 0,
        'remainingStops': _timeline.whereType<TimelineStopItem>().map((s) => {
          'sequence': 1,
          'placeName': s.placeName,
          'area': s.area,
          'isIndoor': !s.isPeakHeat,
        }).toList(),
      };
    }

    // 4. Try Bird Backend (Node.js API endpoint /api/bird/chat which uses Persona Engine & multi-turn memory)
    try {
      final birdBackendUrl = Uri.parse('${AppConfig.backendBaseUrl}/api/bird/chat');
      debugPrint('--> 🚀 [Bird Chat] Sending POST request to: $birdBackendUrl');
      final response = await http
          .post(
            birdBackendUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'mode': mode,
              'message': prompt,
              'history': historyPayload,
              'context': contextPayload,
              'hasActiveTrip': _hasActiveTrip,
            }),
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('--> 📥 [Bird Chat] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && (data['reply'] != null || data['message'] != null)) {
          final String reply = _sanitizeAiReply((data['reply'] ?? data['message'] ?? '').toString().trim());
          final String action = data['action']?.toString() ?? 'none';
          final String emotion = data['emotion']?.toString() ?? 'happy';

          // Extract quickReplies (e.g. Option A, Option B) - MAX 2
          List<String>? quickReplies;
          if (data['quickReplies'] is List && (data['quickReplies'] as List).isNotEmpty) {
            quickReplies = (data['quickReplies'] as List).map((e) => e.toString()).take(2).toList();
          } else if (data['payload'] != null && data['payload']['quickReplies'] is List) {
            quickReplies = (data['payload']['quickReplies'] as List).map((e) => e.toString()).take(2).toList();
          }

          if (quickReplies != null) {
            quickReplies = quickReplies.map((qr) {
              return qr.replaceAll(RegExp(r'(Option\s*[AB12]:\s*)(?:Add|Visit)\s+', caseSensitive: false), r'$1')
                       .replaceAll(RegExp(r'^(?:Add|Visit)\s+', caseSensitive: false), '')
                       .replaceAll('"', '')
                       .trim();
            }).toList();
          }

          final hasOptionStructureInReply = RegExp(r'\[?Option\s*[AB12]\]?|Option\s*[AB12]:', caseSensitive: false).hasMatch(reply);
          final isFactual = !hasOptionStructureInReply && ((data['isFactualInquiry'] == true) || _isFactualInquiry(prompt));

          // Parse suggested places from MongoDB if returned - MAX 2 (filter out places already in draft itinerary)
          List<ItineraryPlace>? suggestedPlaces;
          final rawPlaces = (data['suggestedPlaces'] is List)
              ? data['suggestedPlaces']
              : (data['options'] is List
                  ? data['options']
                  : (data['payload'] != null && data['payload']['suggestedPlaces'] is List
                      ? data['payload']['suggestedPlaces']
                      : null));
          if (rawPlaces is List && !isFactual) {
            suggestedPlaces = rawPlaces.map((p) {
              String name = p is String ? p : (p['name']?.toString() ?? p['placeName']?.toString() ?? 'Penang Place');
              name = name.replaceAll(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '')
                         .replaceAll(RegExp(r'^(?:add|visit|choose|pick)\s+', caseSensitive: false), '')
                         .replaceAll(RegExp(r'[\*\_\[\]\.,"]'), '')
                         .trim();
              final category = (p is Map ? p['category']?.toString() : null) ?? 'Attraction';
              final rawArea = (p is Map ? p['area']?.toString() : null);
              final rawDesc = (p is Map ? (p['summary']?.toString() ?? p['place_summary']?.toString() ?? p['description']?.toString() ?? p['reason']?.toString()) : null) ?? '';
              final desc = _getConcisePlaceSummary(rawDesc);
              final address = (p is Map ? p['address']?.toString() : null);
              final specificArea = resolveSpecificPenangArea(
                placeName: name,
                area: rawArea,
                address: address,
                description: desc,
              );
              final stayMins = calculateDynamicStayDuration(
                name: name,
                category: category,
                description: desc,
                currentStayMinutes: (p is Map && p['estimatedStayMinutes'] is int) ? p['estimatedStayMinutes'] : null,
              );
              return ItineraryPlace(
                id: (p is Map ? p['id']?.toString() : null) ?? 'mongo_${DateTime.now().millisecondsSinceEpoch}',
                name: name.isNotEmpty ? name : 'Penang Place',
                area: specificArea,
                address: address,
                description: desc,
                lat: (p is Map && p['lat'] is num) ? (p['lat'] as num).toDouble() : 5.414,
                lng: (p is Map && p['lng'] is num) ? (p['lng'] as num).toDouble() : 100.328,
                category: category,
                estimatedStayMinutes: stayMins,
                icon: _getCategoryIcon(category),
                primaryCategory: (p is Map ? (p['primary_category']?.toString() ?? p['primaryCategory']?.toString()) : null) ?? category,
                subCategories: (p is Map && p['sub_categories'] is List)
                    ? (p['sub_categories'] as List).map((e) => e.toString()).toList()
                    : (p is Map && p['subCategories'] is List)
                        ? (p['subCategories'] as List).map((e) => e.toString()).toList()
                        : [],
                features: (p is Map && p['features'] is Map)
                    ? (p['features'] as Map).map((k, v) => MapEntry(k.toString(), v == true))
                    : {},
                openingHours: (p is Map ? (p['place_business_hours'] ?? p['opening_hours'] ?? p['businessHours']) : null),
                businessHours: (p is Map ? p['businessHours']?.toString() : null),
              );
            }).where((p) {
              if (_isSystemActionText(p.name)) return false;
              // Exclude if already in draft itinerary!
              return !_draftItinerary.any((d) => d.name.toLowerCase().trim() == p.name.toLowerCase().trim());
            }).take(2).toList();

            final promptLower = prompt.toLowerCase();
            final isStampRequestInLLM = promptLower.contains('stamp') ||
                promptLower.contains('digital stamp') ||
                promptLower.contains('stamps') ||
                promptLower.contains('印章');
            if (isStampRequestInLLM && suggestedPlaces.isNotEmpty) {
              // Strictly ensure that any suggested places belong to the 28 predefined stamps
              suggestedPlaces = suggestedPlaces.where((p) {
                final pName = p.name.toLowerCase().trim();
                return kPredefined28DigitalStamps.any((s) {
                  final sTitle = s.title.toLowerCase().trim();
                  return pName == sTitle || pName.contains(sTitle) || sTitle.contains(pName);
                });
              }).toList();
            }
          }

          final isRemoveAction = action == 'remove_spots' || action == 'remove_spot' ||
              RegExp(r'\b(?:remove|delete|drop)\s+(?:a\s+)?(?:spot|stop|place|item|plan)\b', caseSensitive: false).hasMatch(prompt) ||
              RegExp(r'\b(?:remove|delete|drop)\s+(?:stop\s+|spot\s+|#)?\d+\b', caseSensitive: false).hasMatch(prompt) ||
              RegExp(r'\b(?:want|wish|like|wanna)\s+to\s+(?:remove|delete|drop)\b', caseSensitive: false).hasMatch(prompt) ||
              prompt.toLowerCase().contains('remove spot') ||
              prompt.toLowerCase().contains('remove stop') ||
              prompt.toLowerCase().contains('delete spot') ||
              prompt.toLowerCase().contains('delete stop') ||
              prompt.toLowerCase().contains('remove a spot') ||
              prompt.toLowerCase().contains('remove a stop') ||
              prompt.toLowerCase().contains('delete a spot') ||
              prompt.toLowerCase().contains('delete a stop');

          if (isFactual || isRemoveAction) {
            suggestedPlaces = [];
            quickReplies = [];
          }

          // Client-side Alignment & Fallback: Ensure quickReplies and suggestedPlaces match Option A / Option B in reply text
          if (!isFactual && !isRemoveAction) {
            final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
            final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);

            final matchA = optAPattern.firstMatch(reply);
            final matchB = optBPattern.firstMatch(reply);
            final sepRegex = RegExp(r'\s+[-–—]{1,2}\s+|\s*[:：]\s+|\s+(?:for|to|offers?|features?|where|is\s+a|is\s+the|is)\s+|[。，]', caseSensitive: false);

            String? textPlaceA;
            String? textPlaceB;

            if (matchA != null && matchA.group(1) != null) {
              String rawA = matchA.group(1)!.replaceAll(RegExp(r'[\*\_\[\]]'), '').replaceAll(RegExp(r'[,.]$'), '').trim();
              if (rawA.contains(sepRegex)) {
                rawA = rawA.split(sepRegex).first.trim();
              }
              if (rawA.isNotEmpty && !_isSystemActionText(rawA)) {
                textPlaceA = rawA;
              }
            }

            if (matchB != null && matchB.group(1) != null) {
              String rawB = matchB.group(1)!.replaceAll(RegExp(r'[\*\_\[\]]'), '').replaceAll(RegExp(r'[,.]$'), '').trim();
              if (rawB.contains(sepRegex)) {
                rawB = rawB.split(sepRegex).first.trim();
              }
              if (rawB.isNotEmpty && !_isSystemActionText(rawB)) {
                textPlaceB = rawB;
              }
            }

            final isFoodIntent = RegExp(
              r'laksa|char koay teow|char kway teow|cendol|curry mee|hokkien mee|nasi kandar|roti canai|hawker|food court|dim sum|bakery|cafe|makan|food|restaurant|noodle|eats|ho chiak|美食|小吃|叻沙|炒粿条',
              caseSensitive: false,
            ).hasMatch(reply);

            // If the model explicitly introduced Option A and Option B in reply text, reconcile suggestedPlaces and quickReplies!
            if (textPlaceA != null && textPlaceB != null) {
              final cleanA = textPlaceA.toLowerCase().trim();
              final cleanB = textPlaceB.toLowerCase().trim();

              // Check if backend's suggestedPlaces already accurately align with textPlaceA and textPlaceB
              final isAligned = (suggestedPlaces != null && suggestedPlaces.length >= 2) &&
                  suggestedPlaces.any((p) =>
                      p.name.toLowerCase().contains(cleanA) ||
                      cleanA.contains(p.name.toLowerCase())) &&
                  suggestedPlaces.any((p) =>
                      p.name.toLowerCase().contains(cleanB) ||
                      cleanB.contains(p.name.toLowerCase()));

              if (!isAligned) {
                quickReplies = [
                  'Option A: $textPlaceA',
                  'Option B: $textPlaceB',
                ];

                // Reconcile suggestedPlaces so they strictly match textPlaceA and textPlaceB
                final reconciled = <ItineraryPlace>[];
                for (final targetName in [textPlaceA, textPlaceB]) {
                  final existingMatch = suggestedPlaces?.where((p) =>
                    p.name.toLowerCase() == targetName.toLowerCase() ||
                    p.name.toLowerCase().contains(targetName.toLowerCase()) ||
                    targetName.toLowerCase().contains(p.name.toLowerCase())
                  ).firstOrNull;

                  if (existingMatch != null) {
                    reconciled.add(existingMatch);
                  } else {
                    final predefined = kPenangPredefinedPlaces.where((p) {
                      if (isFoodIntent && (p.category != 'Food' && p.category != 'Hawker Centres & Food Courts' && p.category != 'Cafes')) {
                        return false;
                      }
                      final pName = p.name.toLowerCase();
                      final tName = targetName.toLowerCase();
                      return pName == tName || (tName.startsWith(pName) && tName.length < pName.length + 10);
                    }).firstOrNull;

                    // Infer area from reply text if present
                    String inferredArea = 'Penang';
                    for (final a in ['Balik Pulau', 'Bayan Lepas', 'George Town', 'Air Itam', 'Batu Ferringhi', 'Gurney', 'Tanjung Tokong', 'Butterworth', 'Bukit Mertajam']) {
                      if (reply.toLowerCase().contains(a.toLowerCase())) {
                        inferredArea = a;
                        break;
                      }
                    }

                    reconciled.add(
                      predefined ??
                      ItineraryPlace(
                        id: 'opt_${DateTime.now().millisecondsSinceEpoch}_${targetName.hashCode}',
                        name: targetName,
                        area: inferredArea,
                        description: 'Recommended spot in $inferredArea',
                        lat: inferredArea == 'Balik Pulau' ? 5.352 : 5.414,
                        lng: inferredArea == 'Balik Pulau' ? 100.237 : 100.328,
                        category: isFoodIntent ? 'Cafes' : 'Attraction',
                      ),
                    );
                  }
                }
                suggestedPlaces = reconciled;
              } else if (quickReplies == null || quickReplies.isEmpty || quickReplies.length < 2) {
                quickReplies = [
                  'Option A: ${suggestedPlaces[0].name}',
                  'Option B: ${suggestedPlaces[1].name}',
                ];
              }
            } else if ((quickReplies == null || quickReplies.isEmpty) || (suggestedPlaces == null || suggestedPlaces.isEmpty)) {
              final tPlaceA = textPlaceA;
              if (tPlaceA != null && !_draftItinerary.any((d) => d.name.toLowerCase().trim() == tPlaceA.toLowerCase().trim())) {
                suggestedPlaces ??= [];
                if (!suggestedPlaces.any((p) => p.name.toLowerCase() == tPlaceA.toLowerCase())) {
                  final predefined = kPenangPredefinedPlaces.where((p) {
                    if (isFoodIntent && (p.category != 'Food' && p.category != 'Hawker Centres & Food Courts' && p.category != 'Cafes')) {
                      return false;
                    }
                    final pName = p.name.toLowerCase();
                    final tName = tPlaceA.toLowerCase();
                    return pName == tName || (tName.startsWith(pName) && tName.length < pName.length + 10);
                  }).firstOrNull;

                  suggestedPlaces.add(
                    predefined ??
                    ItineraryPlace(
                      id: 'optionA_${DateTime.now().millisecondsSinceEpoch}',
                      name: tPlaceA,
                      area: 'Penang',
                      description: 'Recommended place in Penang',
                      lat: 5.414,
                      lng: 100.328,
                      category: isFoodIntent ? 'Hawker Centres & Food Courts' : 'Attraction',
                    ),
                  );
                }
              }

              final tPlaceB = textPlaceB;
              if (tPlaceB != null && !_draftItinerary.any((d) => d.name.toLowerCase().trim() == tPlaceB.toLowerCase().trim())) {
                suggestedPlaces ??= [];
                if (!suggestedPlaces.any((p) => p.name.toLowerCase() == tPlaceB.toLowerCase())) {
                  final predefined = kPenangPredefinedPlaces.where((p) {
                    if (isFoodIntent && (p.category != 'Food' && p.category != 'Hawker Centres & Food Courts' && p.category != 'Cafes')) {
                      return false;
                    }
                    final pName = p.name.toLowerCase();
                    final tName = tPlaceB.toLowerCase();
                    return pName == tName || (tName.startsWith(pName) && tName.length < pName.length + 10);
                  }).firstOrNull;

                  suggestedPlaces.add(
                    predefined ??
                    ItineraryPlace(
                      id: 'optionB_${DateTime.now().millisecondsSinceEpoch}',
                      name: tPlaceB,
                      area: 'Penang',
                      description: 'Recommended place in Penang',
                      lat: 5.414,
                      lng: 100.328,
                      category: isFoodIntent ? 'Hawker Centres & Food Courts' : 'Attraction',
                    ),
                  );
                }
              }

              if ((quickReplies == null || quickReplies.isEmpty) && suggestedPlaces != null && suggestedPlaces.length >= 2) {
                quickReplies = [
                  'Option A: ${suggestedPlaces[0].name}',
                  'Option B: ${suggestedPlaces[1].name}',
                ];
              }
            }

            // Safety Net: If quickReplies provides 2 options (Option A & Option B),
            // ensure BOTH Option A and Option B places exist in suggestedPlaces
            // so the user sees BOTH Option 1 and Option 2 cards AND option buttons!
            // BUT: Strictly SKIP if either option is a system action (e.g. Save and Plan, Add More Places)!
            if (quickReplies != null && quickReplies.length >= 2 && (suggestedPlaces == null || suggestedPlaces.length < 2)) {
              final rawNameA = quickReplies[0].replaceFirst(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '').trim();
              final rawNameB = quickReplies[1].replaceFirst(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '').trim();

              if (!_isSystemActionText(rawNameA) && !_isSystemActionText(rawNameB)) {
                suggestedPlaces ??= [];
                final inferredArea = suggestedPlaces.isNotEmpty ? suggestedPlaces.first.area : 'George Town';
                final defaultLat = suggestedPlaces.isNotEmpty ? suggestedPlaces.first.lat : 5.414;
                final defaultLng = suggestedPlaces.isNotEmpty ? suggestedPlaces.first.lng : 100.328;

                final hasA = suggestedPlaces.any((p) =>
                  p.name.toLowerCase().contains(rawNameA.toLowerCase()) ||
                  rawNameA.toLowerCase().contains(p.name.toLowerCase())
                );
                final hasB = suggestedPlaces.any((p) =>
                  p.name.toLowerCase().contains(rawNameB.toLowerCase()) ||
                  rawNameB.toLowerCase().contains(p.name.toLowerCase())
                );

                if (!hasA && rawNameA.isNotEmpty) {
                  suggestedPlaces.insert(
                    0,
                    ItineraryPlace(
                      id: 'optA_${DateTime.now().millisecondsSinceEpoch}',
                      name: rawNameA,
                      area: inferredArea,
                      description: 'Recommended landmark in $inferredArea',
                      lat: defaultLat,
                      lng: defaultLng,
                      category: isFoodIntent ? 'Cafes' : 'Attraction',
                    ),
                  );
                }

                if (!hasB && rawNameB.isNotEmpty) {
                  suggestedPlaces.add(
                    ItineraryPlace(
                      id: 'optB_${DateTime.now().millisecondsSinceEpoch}',
                      name: rawNameB,
                      area: inferredArea,
                      description: 'Recommended landmark in $inferredArea',
                      lat: defaultLat,
                      lng: defaultLng,
                      category: isFoodIntent ? 'Cafes' : 'Attraction',
                    ),
                  );
                }
              }
            }
          }

          // Execute actions - Add spot(s)
          final String lowerReply = reply.toLowerCase();
          final bool isOfferingOptions = (lowerReply.contains('option a') && lowerReply.contains('option b')) ||
              (suggestedPlaces != null && suggestedPlaces.length >= 2 &&
                  (lowerReply.contains('which one') ||
                      lowerReply.contains('would you prefer') ||
                      lowerReply.contains('choose your favorite') ||
                      lowerReply.contains('4th stop') ||
                      lowerReply.contains('fourth stop') ||
                      lowerReply.contains('备选地点') ||
                      lowerReply.contains('哪一个')));

          final bool isAddIntentFromText = !isQuickPlanBatch &&
              !isOfferingOptions &&
              (lowerReply.contains("i've added") ||
                  lowerReply.contains("i have added") ||
                  lowerReply.contains("added to your travel plan") ||
                  lowerReply.contains("added to your plan") ||
                  lowerReply.contains("added to your draft") ||
                  lowerReply.contains("added to your list") ||
                  lowerReply.contains("i've put") ||
                  lowerReply.contains("i have put") ||
                  lowerReply.contains("has been added") ||
                  lowerReply.contains("have been added"));

          final lowerPrompt = prompt.toLowerCase();
          final bool userExplicitlyRequestedAdd = lowerPrompt.contains('add') ||
              lowerPrompt.contains('insert') ||
              lowerPrompt.contains('put') ||
              lowerPrompt.contains('include') ||
              lowerPrompt.contains('choose') ||
              lowerPrompt.contains('pick') ||
              lowerPrompt.contains('select') ||
              lowerPrompt.contains('take') ||
              lowerPrompt.contains('want to visit') ||
              lowerPrompt.contains('want visit') ||
              lowerPrompt.contains('wanna visit') ||
              lowerPrompt.contains('option a') ||
              lowerPrompt.contains('option b') ||
              lowerPrompt.contains('both');

          // NEVER auto-add suggested options during quick plan batch or when offering choices to user!
          final bool shouldExecuteAdd = !isQuickPlanBatch && (
              ((action == 'add_spot' || action == 'add_spots') && !isOfferingOptions) ||
              isAddIntentFromText ||
              (userExplicitlyRequestedAdd && suggestedPlaces != null && suggestedPlaces.isNotEmpty)
          );

          if (shouldExecuteAdd) {
            final placesToAdd = <ItineraryPlace>[];

            // 1. If payload contains suggestedPlaces / target spots
            if (data['payload'] != null &&
                data['payload']['suggestedPlaces'] is List &&
                (data['payload']['suggestedPlaces'] as List).isNotEmpty) {
              final payloadList = data['payload']['suggestedPlaces'] as List;
              for (final pItem in payloadList) {
                final targetName = (pItem is Map ? (pItem['placeName'] ?? pItem['name']) : pItem).toString().toLowerCase().trim();
                if (targetName.isNotEmpty && suggestedPlaces != null) {
                  final match = suggestedPlaces.firstWhere(
                    (p) => p.name.toLowerCase().contains(targetName) || targetName.contains(p.name.toLowerCase()),
                    orElse: () => suggestedPlaces!.first,
                  );
                  if (!placesToAdd.contains(match)) placesToAdd.add(match);
                }
              }
            }

            // 2. If placesToAdd is still empty, and suggestedPlaces exists
            // ONLY pick from suggestedPlaces if user explicitly selected or prompt targeted them
            if (placesToAdd.isEmpty && suggestedPlaces != null && suggestedPlaces.isNotEmpty && !isOfferingOptions) {
              if (lowerPrompt.contains('both') || lowerReply.contains('both')) {
                placesToAdd.addAll(suggestedPlaces.take(2));
              } else if (lowerPrompt.contains('option b') || lowerPrompt.contains('second') || lowerReply.contains('option b')) {
                placesToAdd.add(suggestedPlaces.length > 1 ? suggestedPlaces[1] : suggestedPlaces.first);
              } else if (userExplicitlyRequestedAdd) {
                placesToAdd.add(suggestedPlaces.first);
              }
            }

            // 3. Fallback: extract place name from bold markdown e.g. **Cheong Fatt Tze - The Blue Mansion**
            if (placesToAdd.isEmpty && !isOfferingOptions && userExplicitlyRequestedAdd) {
              final boldMatches = RegExp(r'\*\*([^*]+)\*\*').allMatches(reply);
              for (final match in boldMatches) {
                final rawName = match.group(1)!.trim();
                if (!_isSystemActionText(rawName) &&
                    !rawName.toLowerCase().startsWith('option ') &&
                    !rawName.toLowerCase().startsWith('stop ') &&
                    rawName.length > 2) {
                  final cleanName = rawName.split(RegExp(r'\s+[-–—]{1,2}\s+|\s*[:：]\s+')).first.trim();
                  final existing = kPenangPredefinedPlaces.where(
                    (p) => p.name.toLowerCase() == cleanName.toLowerCase() || cleanName.toLowerCase().contains(p.name.toLowerCase())
                  ).firstOrNull;

                  placesToAdd.add(
                    existing ??
                    ItineraryPlace(
                      id: 'spot_${DateTime.now().millisecondsSinceEpoch}_${placesToAdd.length}',
                      name: cleanName,
                      area: effectiveArea,
                      description: 'Added from chat',
                      lat: 5.414,
                      lng: 100.328,
                      category: 'Attraction',
                    ),
                  );
                  if (!lowerPrompt.contains('both') && !lowerReply.contains('both')) {
                    break;
                  }
                }
              }
            }

            for (final targetPlace in placesToAdd) {
              if (!_isSystemActionText(targetPlace.name) &&
                  !_draftItinerary.any((p) => p.name.toLowerCase() == targetPlace.name.toLowerCase())) {
                _draftItinerary.add(targetPlace);
              }
            }
          } else {
            bool didRemove = false;
            if ((action == 'remove_spots' || action == 'remove_spot') &&
                data['payload'] != null &&
                data['payload']['targetSequences'] is List) {
              final targetSeqs = (data['payload']['targetSequences'] as List)
                  .map((e) => int.tryParse(e.toString()))
                  .whereType<int>()
                  .toList();
              // Sort descending to remove safely by index
              targetSeqs.sort((a, b) => b.compareTo(a));
              for (final seq in targetSeqs) {
                final idx = seq - 1;
                if (idx >= 0 && idx < _draftItinerary.length) {
                  _draftItinerary.removeAt(idx);
                  didRemove = true;
                }
              }
            }

            // Fallback 1: Extract sequence number directly from reply text (e.g. "removed Stop 4", "removed Spot 4", "removed #4")
            if (!didRemove && reply.isNotEmpty) {
              final removeRegex = RegExp(r'removed\s+(?:stop\s+|spot\s+|#)?(\d+)', caseSensitive: false);
              final match = removeRegex.firstMatch(reply);
              if (match != null) {
                final seq = int.tryParse(match.group(1) ?? '');
                if (seq != null && seq >= 1 && seq <= _draftItinerary.length) {
                  _draftItinerary.removeAt(seq - 1);
                  didRemove = true;
                }
              }
            }

            // Fallback 2: Match by place name in parentheses e.g. "removed Stop 4 (Balik Pulau International Art Village ARTOPIA)"
            if (!didRemove && reply.isNotEmpty) {
              final parenMatch = RegExp(r'removed\s+[^(]*\(([^)]+)\)', caseSensitive: false).firstMatch(reply);
              if (parenMatch != null) {
                final nameInParen = parenMatch.group(1)?.trim().toLowerCase() ?? '';
                final foundIdx = _draftItinerary.indexWhere(
                  (p) => p.name.toLowerCase().contains(nameInParen) || nameInParen.contains(p.name.toLowerCase()),
                );
                if (foundIdx != -1) {
                  _draftItinerary.removeAt(foundIdx);
                  didRemove = true;
                }
              }
            }

            if (didRemove && _timeline.isNotEmpty) {
              _recalculateReviewTimeline();
              _triggerAiReplanForModification();
            }
          }

          // Set mascot emotion
          if (emotion == 'success') {
            setMascotState(MascotState.success);
          } else if (emotion == 'sad') {
            setMascotState(MascotState.sad);
          } else {
            setMascotState(MascotState.happy);
          }

          // Handle trip control actions
          if (action == 'REQUIRE_DATES') {
            onRequireDatesTriggered?.call();
          } else if (action == 'LOCK_TRIP' && _draftItinerary.isNotEmpty && !_hasActiveTrip) {
            lockAndStartTrip();
            return;
          } else if (action == 'CANCEL_TRIP' && _hasActiveTrip) {
            cancelActiveTrip();
            return;
          }

          // If removal intent or action, strictly ensure no suggested places or quick reply buttons are shown
          if (isRemoveAction || action == 'remove_spots' || action == 'remove_spot') {
            suggestedPlaces = null;
            quickReplies = null;
          }

          // Ensure suggestedPlaces never contains any system action items
          if (suggestedPlaces != null) {
            suggestedPlaces.removeWhere((p) => _isSystemActionText(p.name));
            if (suggestedPlaces.isEmpty) suggestedPlaces = null;
          }

          // Format quickReplies: completely remove all system actions (e.g. Save and Plan)
          if (quickReplies != null) {
            quickReplies.removeWhere((qr) => _isSystemActionText(qr));
            if (quickReplies.isEmpty) quickReplies = null;
          }

          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: reply,
              timestamp: DateTime.now(),
              showActionChips: _draftItinerary.isNotEmpty,
              suggestedPlaces: suggestedPlaces,
              quickReplies: quickReplies,
              action: action,
            ),
          );
          notifyListeners();
          return;
        }
      }
    } catch (e) {
      debugPrint('Bird backend chat error: $e');
    }

    // 2. Direct Ollama API (using gemma4:cloud from AppConfig.ollamaModel)
    try {
      final ollamaUrl = Uri.parse('${AppConfig.ollamaBaseUrl}/api/generate');
      final systemInstruction =
          "You are 'Penny' (a pink bird mascot, 潘妮), a cheerful, knowledgeable local travel bird companion for Penang, Malaysia. "
          "When the user asks for a tour or short trip in an area (e.g. George Town, Air Itam, Batu Ferringhi, etc.), recommend 3 must-visit places for that area, and then offer Option A and Option B from other places in Penang (avoiding the 3 must-visit places) for the user to choose their 4th stop. Keep responses friendly, energetic, and under 150 words.";

      final response = await http
          .post(
            ollamaUrl,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'model': AppConfig.ollamaModel,
              'system': systemInstruction,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final text = _sanitizeAiReply(data['response']?.toString().trim() ?? '');
        if (text.isNotEmpty) {
          setMascotState(MascotState.happy);
          List<String>? quickReplies;
          final isRemovePrompt = RegExp(r'\b(?:remove|delete|drop)\b', caseSensitive: false).hasMatch(prompt);
          if (!_isFactualInquiry(prompt) && !isRemovePrompt) {
            final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
            final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
            final matchA = optAPattern.firstMatch(text);
            final matchB = optBPattern.firstMatch(text);
            if (matchA != null && matchB != null) {
              final nameA = matchA.group(1)?.replaceAll(RegExp(r'[\*\_\[\]]'), '').trim() ?? '';
              final nameB = matchB.group(1)?.replaceAll(RegExp(r'[\*\_\[\]]'), '').trim() ?? '';
              quickReplies = [
                nameA.isNotEmpty ? 'Option A: $nameA' : 'Option A',
                nameB.isNotEmpty ? 'Option B: $nameB' : 'Option B',
              ];
            }
          }

          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: text,
              timestamp: DateTime.now(),
              quickReplies: quickReplies,
              showActionChips: _draftItinerary.isNotEmpty,
            ),
          );
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // 3. Fallback Gemini API (if configured)
    try {
      if (AppConfig.geminiApiKey.isNotEmpty && AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent?key=${AppConfig.geminiApiKey}',
        );

        final systemInstruction =
            "You are 'Penny' (a pink bird mascot, 潘妮), a cheerful, knowledgeable local travel bird companion for Penang, Malaysia. "
            "When the user asks for a tour or short trip in an area (e.g. George Town, Air Itam, Batu Ferringhi, etc.), recommend 3 must-visit places for that area, and then offer Option A and Option B from other places in Penang (avoiding the 3 must-visit places) for the user to choose their 4th stop. Keep responses friendly, energetic, and under 150 words.";

        final response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'contents': [
                  {
                    'parts': [
                      {'text': '$systemInstruction\n\nUser Question: $prompt'}
                    ]
                  }
                ],
              }),
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final text = _sanitizeAiReply(data['candidates'][0]['content']['parts'][0]['text'].toString().trim());

          setMascotState(MascotState.happy);
          List<String>? quickReplies;
          final isRemovePrompt = RegExp(r'\b(?:remove|delete|drop)\b', caseSensitive: false).hasMatch(prompt);
          if (!_isFactualInquiry(prompt) && !isRemovePrompt) {
            final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
            final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#\.]+)', caseSensitive: false);
            final matchA = optAPattern.firstMatch(text);
            final matchB = optBPattern.firstMatch(text);
            if (matchA != null && matchB != null) {
              final nameA = matchA.group(1)?.replaceAll(RegExp(r'[\*\_\[\]]'), '').trim() ?? '';
              final nameB = matchB.group(1)?.replaceAll(RegExp(r'[\*\_\[\]]'), '').trim() ?? '';
              quickReplies = [
                nameA.isNotEmpty ? 'Option A: $nameA' : 'Option A',
                nameB.isNotEmpty ? 'Option B: $nameB' : 'Option B',
              ];
            }
          }

          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: text,
              timestamp: DateTime.now(),
              quickReplies: quickReplies,
              showActionChips: _draftItinerary.isNotEmpty,
            ),
          );
          notifyListeners();
          return;
        }
      }
    } catch (_) {}

    // 4. Local fallback: If tour/shortcut request, use client generator as graceful offline fallback
    if (await _handleAreaTourPlanning(prompt)) return;

    setMascotState(MascotState.happy);
    String reply = "Penang is full of wonders! For food, you can't miss George Town's Char Kway Teow and Air Itam's Laksa. If you'd like me to plan a short trip in any area like George Town, Air Itam, Batu Ferringhi, or Balik Pulau, just ask me!";
    
    if (prompt.toLowerCase().contains('laksa') || prompt.toLowerCase().contains('food')) {
      reply = "Oh, Penang food is heaven! 🍜 You must try the Ayer Itam Assam Laksa right next to Kek Lok Si Market, and Siam Road Char Kway Teow. Should I add them to your travel plan?";
    } else if (prompt.toLowerCase().contains('time') || prompt.toLowerCase().contains('weather')) {
      reply = "The best visiting hours for outdoor murals and Penang Hill are morning (8:00 AM - 11:00 AM) or late afternoon to avoid the mid-day heat. Remember to bring an umbrella!";
    }

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: reply,
        timestamp: DateTime.now(),
        showActionChips: _draftItinerary.isNotEmpty,
      ),
    );
    notifyListeners();
  }
}
