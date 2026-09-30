import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../services/weather_service.dart';

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

  const TimelineStopItem({
    required this.placeName,
    required this.area,
    required this.category,
    required this.lat,
    required this.lng,
    required super.timeSlot,
    required this.tip,
    this.warningFlag,
  }) : super(type: 'stop');

  bool get isPeakHeat => warningFlag == 'PEAK_HEAT';
  bool get isClosed => warningFlag == 'CLOSED';

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
  };
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
  if (combined.contains('teluk bahang') ||
      combined.contains('escape') ||
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

  // 3. Fallback to existing area if it's already specific (not 'Penang' / 'Pulau Pinang')
  if (area != null &&
      area.isNotEmpty &&
      area.toLowerCase() != 'penang' &&
      area.toLowerCase() != 'pulau pinang' &&
      area.toLowerCase() != 'malaysia') {
    if (area.toLowerCase() == 'georgetown') return 'George Town';
    if (area.toLowerCase() == 'ayer itam') return 'Air Itam';
    return area;
  }

  // 4. Default to George Town
  return 'George Town';
}

/// Dynamically calculates recommended stay duration (minutes) for a Penang place.
int calculateDynamicStayDuration({
  required String name,
  required String category,
  String? description,
  int? currentStayMinutes,
}) {
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
  });

  /// Specific Penang area resolved dynamically via postcodes, keywords, and known districts.
  String get specificArea => resolveSpecificPenangArea(
    placeName: name,
    area: area,
    address: address,
    description: description,
  );

  /// Dynamically calculated stay duration in minutes based on category and place type.
  int get dynamicStayMinutes => calculateDynamicStayDuration(
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
  final bool isCompleted;

  ItineraryTrip({
    required this.id,
    required this.title,
    required this.places,
    this.timeline = const [],
    required this.createdAt,
    this.travelDates,
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
      ItineraryPlace(
        id: 'gt_khoo_kongsi',
        name: 'Leong San Tong Khoo Kongsi',
        area: 'George Town',
        description: 'Elaborately carved Chinese clanhouse showcasing sublime Hokkien architectural mastery.',
        lat: 5.4151,
        lng: 100.3364,
        category: 'Heritage',
        estimatedStayMinutes: 120,
        icon: Icons.temple_buddhist,
      ),
      ItineraryPlace(
        id: 'gt_fort_cornwallis',
        name: 'Fort Cornwallis',
        area: 'George Town',
        description: 'Historic 18th-century star-shaped bastion fortress built by the British East India Company.',
        lat: 5.4206,
        lng: 100.3440,
        category: 'Historic',
        estimatedStayMinutes: 120,
        icon: Icons.fort,
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
      ItineraryPlace(
        id: 'ai_habitat',
        name: 'The Habitat Penang Hill',
        area: 'Air Itam',
        description: 'World-class rainforest discovery centre with canopy walkway and Curtis Crest tree-top views.',
        lat: 5.4095,
        lng: 100.2675,
        category: 'Nature',
        estimatedStayMinutes: 75,
        icon: Icons.eco,
      ),
    ],
  ),
  'batu_ferringhi': const PenangAreaTour(
    areaKey: 'batu_ferringhi',
    displayName: 'Batu Ferringhi Beach & Coast',
    emoji: '🌊',
    summary: 'Golden sandy beaches, aromatic tropical spice reserves, local art galleries, and vibrant seaside evening shopping.',
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
        id: 'bf_art_gallery',
        name: 'Yahong Art Gallery',
        area: 'Batu Ferringhi',
        description: 'Celebrated cultural art center showcasing batik paintings, Chinese antique arts, and craft jewelry.',
        lat: 5.4735,
        lng: 100.2458,
        category: 'Art',
        estimatedStayMinutes: 45,
        icon: Icons.palette,
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
      ItineraryPlace(
        id: 'tb_dam_forest',
        name: 'Teluk Bahang Dam & Forest Park',
        area: 'Teluk Bahang',
        description: 'Tranquil reservoir views and fresh mountain stream pools ideal for nature relaxation.',
        lat: 5.4445,
        lng: 100.2160,
        category: 'Nature',
        estimatedStayMinutes: 45,
        icon: Icons.water,
      ),
    ],
  ),
  'balik_pulau': const PenangAreaTour(
    areaKey: 'balik_pulau',
    displayName: 'Balik Pulau Countryside & Orchards',
    emoji: '🌾',
    summary: 'Pristine countryside cycling lanes, interactive family farms, authentic Siamese Laksa, and nutmeg plantations.',
    places: [
      ItineraryPlace(
        id: 'bp_countryside',
        name: 'Balik Pulau Countryside & Paddy Fields',
        area: 'Balik Pulau',
        description: 'Peaceful western valleys, cycling pathways, and picturesque rural landscapes.',
        lat: 5.3516,
        lng: 100.2369,
        category: 'Country',
        estimatedStayMinutes: 75,
        icon: Icons.agriculture,
      ),
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
      ItineraryPlace(
        id: 'bl_aquarium',
        name: 'Fisheries Research Institute Aquarium',
        area: 'Bayan Lepas',
        description: 'Marine conservation discovery center showcasing tropical reef fish, moray eels, and corals.',
        lat: 5.2851,
        lng: 100.2870,
        category: 'Nature',
        estimatedStayMinutes: 45,
        icon: Icons.water_drop,
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
      ItineraryPlace(
        id: 'bw_robina_park',
        name: 'Pantai Robina Eco Park',
        area: 'Butterworth',
        description: 'Coastline eco-park offering sea breezes and picturesque sunset views over Penang Island.',
        lat: 5.4678,
        lng: 100.3789,
        category: 'Nature',
        estimatedStayMinutes: 45,
        icon: Icons.beach_access,
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
      ItineraryPlace(
        id: 'tb_beach',
        name: 'Tanjung Bungah Beach',
        area: 'Tanjung Bungah',
        description: 'Quiet sandy bay ideal for water sport rentals and relaxing sea breeze walks.',
        lat: 5.4642,
        lng: 100.2812,
        category: 'Beach',
        estimatedStayMinutes: 45,
        icon: Icons.beach_access,
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
      ),
      ItineraryPlace(
        id: 'gu_wat_chaiya',
        name: 'Wat Chaiyamangkalaram (Reclining Buddha)',
        area: 'Pulau Tikus',
        description: 'Historic Thai Buddhist temple housing one of the world\'s largest gold-plated reclining Buddhas.',
        lat: 5.4316,
        lng: 100.3142,
        category: 'Worship',
        estimatedStayMinutes: 45,
        icon: Icons.temple_buddhist,
      ),
    ],
  ),
  'penang_general': const PenangAreaTour(
    areaKey: 'penang_general',
    displayName: 'Penang Island Highlights',
    emoji: '🌟',
    summary: 'A complete short trip combining George Town heritage street art, Kek Lok Si, Penang Hill, and Batu Ferringhi.',
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
      ItineraryPlace(
        id: 'pg_penang_hill',
        name: 'Penang Hill (Bukit Bendera)',
        area: 'Air Itam',
        description: 'Historic funicular railway ascent to panoramic views over George Town and mainland.',
        lat: 5.4084,
        lng: 100.2687,
        category: 'Nature',
        estimatedStayMinutes: 90,
        icon: Icons.landscape,
      ),
      ItineraryPlace(
        id: 'pg_batu_ferringhi',
        name: 'Batu Ferringhi Beach',
        area: 'Batu Ferringhi',
        description: 'Golden sand strip famous for watersports, beach dining, and sunset sea views.',
        lat: 5.4748,
        lng: 100.2483,
        category: 'Beach',
        estimatedStayMinutes: 75,
        icon: Icons.beach_access,
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
  ItineraryTrip? _activeTrip;
  List<ItineraryPlace> _draftItinerary = [];
  final List<ChatMessage> _chatMessages = [];

  // Travel Dates & AI Timeline State
  DateTimeRange? _travelDates;
  List<TimelineItem> _timeline = [];
  List<TimelineItem>? _backupTimeline;
  WeatherAlertInfo? _weatherAlert;
  VoidCallback? onRequireDatesTriggered;
  VoidCallback? onPromptSaveTrip;

  // Plan Modification & Decision State
  bool _hasPendingPlanDecision = false;
  bool _isRecomputingAiPlan = false;
  List<TimelineItem>? _aiRecomputedTimeline;
  List<ItineraryPlace>? _aiRecomputedPlaces;

  // Getters
  MascotState get mascotState => _mascotState;
  bool get hasActiveTrip => _hasActiveTrip;
  ItineraryTrip? get activeTrip => _activeTrip;
  List<ItineraryPlace> get draftItinerary => List.unmodifiable(_draftItinerary);
  List<ChatMessage> get chatMessages => List.unmodifiable(_chatMessages);
  DateTimeRange? get travelDates => _travelDates;
  List<TimelineItem> get timeline => List.unmodifiable(_timeline);
  List<TimelineItem>? get backupTimeline => _backupTimeline;
  WeatherAlertInfo? get weatherAlert => _weatherAlert;
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
            ? "**${place.name}** is already in your draft itinerary! Would you like to save and optimize your trip now?"
            : "**${place.name}** is already in your draft itinerary! What other places in Penang would you like to visit next?";
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: textMsg,
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
          ),
        );
      }
      setMascotState(MascotState.happy);
      notifyListeners();
      return false;
    }

    _draftItinerary.add(place);

    // If review timeline already exists, re-sync review timeline and trigger AI replan comparison
    if (_timeline.isNotEmpty) {
      _recalculateReviewTimeline();
      _triggerAiReplanForModification();
    }

    final hasEnough = _draftItinerary.length >= 3;

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
            quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
          ),
        );
      }
    } else {
      setMascotState(MascotState.happy);
      if (notifyChat) {
        final textMsg = hasEnough
            ? "Steady lah! I've added **${place.name}** to your travel plan (${_draftItinerary.length} total stops). 🚲✨ You now have enough places to plan an awesome trip!"
            : "Steady lah! I've added **${place.name}** to your travel plan (${_draftItinerary.length} total stops). 🚲✨ What other places in Penang would you like to visit next?";
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: textMsg,
            timestamp: DateTime.now(),
            showActionChips: false,
            quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
            referencedPlaces: [place],
          ),
        );
      }
    }

    notifyListeners();
    return true;
  }

  /// Add a place to the user's plan regardless of whether the trip is locked/active or in draft
  bool addPlaceToPlan(ItineraryPlace place, {bool notifyChat = true}) {
    // 1. If trip is currently active (locked), seamlessly add to active trip & recalculate timeline
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

      final updatedPlaces = List<ItineraryPlace>.from(_activeTrip!.places)..add(place);
      _draftItinerary = updatedPlaces;
      _recalculateReviewTimeline();

      _activeTrip = ItineraryTrip(
        id: _activeTrip!.id,
        title: 'Penang Journey (${updatedPlaces.length} stops)',
        places: updatedPlaces,
        timeline: List.from(_timeline),
        travelDates: _activeTrip!.travelDates,
        createdAt: _activeTrip!.createdAt,
        isCompleted: _activeTrip!.isCompleted,
      );

      setMascotState(MascotState.success);
      if (notifyChat) {
        _chatMessages.add(
          ChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            sender: MessageSender.ai,
            text: "Added ${place.name} to your ongoing journey! 🗺️ Updated itinerary now has ${updatedPlaces.length} stops.",
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

    _recalculateReviewTimeline();
    _triggerAiReplanForModification();
    notifyListeners();
  }

  // Replace draft itinerary and recompute timeline (used for Undo/Redo/Modifications)
  void setDraftItinerary(List<ItineraryPlace> places) {
    _draftItinerary = List.from(places);
    _recalculateReviewTimeline();
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

  // Dynamic recalculation of timeline and warning flags during user review
  void _recalculateReviewTimeline() {
    if (_draftItinerary.isEmpty) {
      _timeline.clear();
      return;
    }

    final List<TimelineItem> newTimeline = [];
    DateTime currentTime = DateTime(2026, 1, 1, 9, 0); // Start day at 9:00 AM
    bool conflictDetected = false;

    // Check if any indoor places exist in the plan
    final hasIndoorPlaces = _draftItinerary.any((p) {
      final cat = p.category.toLowerCase();
      final desc = p.description.toLowerCase();
      final name = p.name.toLowerCase();
      return cat.contains('museum') || cat.contains('mansion') || cat.contains('indoor') ||
          desc.contains('indoor') || desc.contains('air-conditioned') || name.contains('mansion');
    });

    for (int i = 0; i < _draftItinerary.length; i++) {
      final place = _draftItinerary[i];

      // If all stops are outdoor and we reach midday (>= 11:45 AM) after at least 1-2 stops,
      // insert midday free time/shaded break before continuing with outdoor stops after 02:30 PM
      if (!hasIndoorPlaces && i >= 2 && currentTime.hour >= 11 && currentTime.hour < 14) {
        final freeStart = _formatTimeOfDay(currentTime);
        final freeEndTime = DateTime(2026, 1, 1, 14, 30); // Resume at 2:30 PM
        final freeEnd = _formatTimeOfDay(freeEndTime);
        newTimeline.add(
          TimelineFreeTimeItem(
            timeSlot: "$freeStart - $freeEnd",
            duration: '2.0 hours',
            options: const FreeTimeOptions(
              optionA: 'Enjoy shaded lunch & rest at nearby air-conditioned cafe.',
              optionB: 'Take a leisurely break or visit nearby shaded walkways.',
              optionC: 'Rest at accommodation during peak sun exposure (UV 9).',
            ),
          ),
        );
        currentTime = freeEndTime;
      }

      final startFormatted = _formatTimeOfDay(currentTime);
      final durationMins = place.estimatedStayMinutes;
      final endTime = currentTime.add(Duration(minutes: durationMins));
      final endFormatted = _formatTimeOfDay(endTime);
      final timeSlot = "$startFormatted - $endFormatted";

      // Evaluate warning flags dynamically:
      String? warning = place.warningFlag;

      // 1. Peak Heat check: 12:00 PM to 02:30 PM for outdoor walking spots
      final hour = currentTime.hour;
      final isMidday = (hour == 11 && currentTime.minute >= 45) ||
          (hour >= 12 && hour < 14) ||
          (hour == 14 && currentTime.minute < 30);
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

      // 2. Distance conflict check with previous stop
      if (i > 0) {
        final prev = _draftItinerary[i - 1];
        final dist = _calculateDistanceKm(prev.lat, prev.lng, place.lat, place.lng);
        if (dist > 12.0) {
          conflictDetected = true;
        }
      }

      // Update place in draft with new visit time and warning flag
      _draftItinerary[i] = place.copyWith(
        bestVisitTime: timeSlot,
        warningFlag: warning,
      );

      newTimeline.add(
        TimelineStopItem(
          placeName: place.name,
          area: place.area,
          category: place.category,
          lat: place.lat,
          lng: place.lng,
          timeSlot: timeSlot,
          tip: place.description.isNotEmpty ? place.description : 'Explore ${place.name}',
          warningFlag: warning,
        ),
      );

      // Advance time for next stop (stay duration + 20 min travel time)
      currentTime = endTime.add(const Duration(minutes: 20));
    }

    _timeline = newTimeline;

    if (conflictDetected) {
      setMascotState(MascotState.shocked);
    } else {
      setMascotState(MascotState.happy);
    }
  }

  String _formatTimeOfDay(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return "${displayHour.toString().padLeft(2, '0')}:$minute $period";
  }

  // Clear draft
  void clearDraft() {
    _draftItinerary.clear();
    _timeline.clear();
    _backupTimeline = null;
    _weatherAlert = null;
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
  Future<ItineraryTrip> saveAndPlanTripForMeNow({DateTimeRange? customDates}) async {
    if (_draftItinerary.isEmpty) {
      throw Exception('No places in draft itinerary to plan.');
    }

    if (customDates != null) {
      _travelDates = customDates;
    }

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

    // Set mascot to thinking while AI computes optimal route and times
    setMascotState(MascotState.thinking, autoResetDuration: null);

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

          final List<TimelineItem> parsedTimeline = [];
          final List<ItineraryPlace> syncedStops = [];

          for (final item in rawTimeline) {
            final type = item['type']?.toString() ?? 'stop';
            if (type == 'free_time') {
              parsedTimeline.add(TimelineFreeTimeItem.fromJson(item));
            } else {
              final stop = TimelineStopItem.fromJson(item);
              parsedTimeline.add(stop);

              syncedStops.add(
                ItineraryPlace(
                  id: 'stop_${DateTime.now().millisecondsSinceEpoch}_${syncedStops.length}',
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

          _timeline = parsedTimeline;
          if (syncedStops.isNotEmpty) {
            _draftItinerary = syncedStops;
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

            // Format standard AI timeline card in chat
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: mascotMsg,
                timestamp: DateTime.now(),
                timelineItems: _timeline,
                isTimelinePreviewCard: true,
              ),
            );
          }

          // Save as active trip
          final trip = ItineraryTrip(
            id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
            title: 'Penang AI Plan (${_draftItinerary.length} stops)',
            places: List.from(_draftItinerary),
            timeline: List.from(_timeline),
            travelDates: _travelDates,
            createdAt: DateTime.now(),
          );

          _activeTrip = trip;
          _hasActiveTrip = true;
          setMascotState(MascotState.success);
          notifyListeners();
          return trip;
        }
      }
    } catch (e) {
      if (e.toString().contains('REQUIRE_DATES')) rethrow;
      debugPrint("AI Itinerary Optimization error: $e");
    }

    // Fallback
    return lockAndStartTrip();
  }

  // Cancel Active Trip (triggered from Contextual Status Banner)
  void cancelActiveTrip() {
    _hasActiveTrip = false;
    _activeTrip = null;

    // Mascot becomes sad when user cancels active trip
    setMascotState(MascotState.sad);

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

  // Plan New Trip (triggered from Contextual Status Banner)
  void planNewTrip() {
    // Reset draft without altering active trip
    _draftItinerary = [];
    setMascotState(MascotState.happy);

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: "Fresh draft initialized! 📝 Let's plan another trip while your active journey is recorded.",
        timestamp: DateTime.now(),
        showActionChips: false,
      ),
    );

    notifyListeners();
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
    return text.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
               .replaceAll(RegExp(r'\s*```$'), '')
               .trim();
  }

  bool _isFactualInquiry(String text) {
    final clean = text.trim().toLowerCase();
    if (clean.isEmpty) return false;

    // 1. Explicit recommendation requests are NOT factual inquiries
    final recTriggers = [
      'recommend', 'suggestion', 'suggest', 'where should i go', 'what should i visit',
      'what can i visit', 'what to see', 'where to visit', 'places to go', 'any place',
      'any places', 'any cafe', 'any bakery', 'any restaurant', 'any food', 'where to eat',
      'what to eat', 'good to eat', 'good to visit', 'recommendation', 'options',
      'nearby', 'near', 'around', 'close to', 'what is nearby', 'what are nearby', 'what is near',
      'what to visit', 'to visit', 'nearby to visit', 'near to visit', 'places nearby', 'spots nearby',
      'food nearby', 'attractions nearby', 'restaurants nearby', 'cafes nearby', 'what to see nearby',
      '推荐', '建议', '有什么好玩', '有什么好吃', '哪间好吃', '介绍几家', '介绍几个地方',
      '去哪玩', '去哪吃', '什么好玩', '什么好吃', '带我去', '想去',
      '附近的', '附近', '周边', '附近有什么', '附近好玩', '附近好吃'
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

  bool _isSystemActionText(String text) {
    final clean = text
        .replaceAll(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'[\*\_\[\]\.,]'), '')
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
    ];
    return systemKeywords.any((k) => clean == k || clean.startsWith(k) || k.startsWith(clean));
  }

  Future<void> _processUserIntent(String prompt) async {
    final lower = prompt.toLowerCase().trim();

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
    if (lower == 'save & optimize' ||
        lower == 'save and optimize' ||
        lower == 'save the trip' ||
        lower == 'optimize trip' ||
        lower == 'save plan' ||
        lower == 'save and plan' ||
        lower == 'save and plan trip for me now' ||
        lower == 'option a: save & optimize' ||
        lower == 'option a: save and optimize' ||
        lower == 'save' ||
        lower == 'select dates' ||
        lower == 'select dates 📅') {
      if (_draftItinerary.isNotEmpty) {
        if (_travelDates == null) {
          onRequireDatesTriggered?.call();
          _chatMessages.add(
            ChatMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: MessageSender.ai,
              text: "Jom lock in your travel dates! Once your dates are set, Weather Guard will automatically optimize your route sequence for sun, rain, and opening hours. 📅✨",
              timestamp: DateTime.now(),
              quickReplies: ['Select Dates 📅', 'Keep Planning 🗺️'],
              showActionChips: true,
            ),
          );
        } else {
          lockAndStartTrip();
        }
        notifyListeners();
        return;
      }
    }

    // Remove by sequence number (e.g. "remove spot 2", "delete #1", "remove 3")
    final seqMatch = RegExp(r'(?:remove|delete|drop)\s+(?:spot\s+|#)?(\d+)').firstMatch(lower);
    if (seqMatch != null) {
      final seqNum = int.tryParse(seqMatch.group(1) ?? '');
      if (seqNum != null && seqNum >= 1 && seqNum <= _draftItinerary.length) {
        removePlaceFromDraft(seqNum - 1, notifyChat: true);
        return;
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
        lower.contains('add both') ||
        lower.contains('add both suggestions');

    final isOptionA = !isOptionBoth && (lower == 'option a' ||
        lower == 'a' ||
        lower == 'option 1' ||
        lower == '1' ||
        lower == 'add option 1' ||
        lower == 'add option a' ||
        lower == 'add 1' ||
        lower.startsWith('option a:') ||
        lower.startsWith('option 1:') ||
        lower.contains('first option'));

    final isOptionB = !isOptionBoth && (lower == 'option b' ||
        lower == 'b' ||
        lower == 'option 2' ||
        lower == '2' ||
        lower == 'add option 2' ||
        lower == 'add option b' ||
        lower == 'add 2' ||
        lower.startsWith('option b:') ||
        lower.startsWith('option 2:') ||
        lower.contains('second option'));

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

      // Look ONLY at the most recent AI message
      final lastAiMsg = _chatMessages.reversed.where((m) => m.sender == MessageSender.ai).firstOrNull;
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
            // Fallback: parse text
            final text = lastAiMsg.text;
            final optAPattern = RegExp(r'(?:###\s*\[?Option\s*A\]?\s*:\s*|\*\*\[?Option\s*A\]?\s*:\*\*\s*|\[?Option\s*A\]?\s*:\s*)([^\n\r#]+)', caseSensitive: false);
            final optBPattern = RegExp(r'(?:###\s*\[?Option\s*B\]?\s*:\s*|\*\*\[?Option\s*B\]?\s*:\*\*\s*|\[?Option\s*B\]?\s*:\s*)([^\n\r#]+)', caseSensitive: false);
            final matchA = optAPattern.firstMatch(text);
            final matchB = optBPattern.firstMatch(text);
            for (final m in [matchA, matchB]) {
              if (m != null && m.group(1) != null) {
                final raw = m.group(1)!.replaceAll(RegExp(r'[\*\_\[\]\.,]'), '').trim();
                if (raw.isNotEmpty && !_isSystemActionText(raw)) {
                  final pre = kPenangPredefinedPlaces.where((p) => p.name.toLowerCase() == raw.toLowerCase() || raw.toLowerCase().contains(p.name.toLowerCase())).firstOrNull;
                  placesToAdd.add(pre ?? ItineraryPlace(
                    id: 'place_${DateTime.now().millisecondsSinceEpoch}_${placesToAdd.length}',
                    name: raw,
                    area: 'Penang',
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
            for (final p in placesToAdd) {
              addPlaceToDraft(p, fromUserPrompt: true, notifyChat: false);
            }
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final names = placesToAdd.map((p) => '**${p.name}**').join(' and ');
            final promptSuffix = hasEnough
                ? "You now have enough places to plan an awesome trip!"
                : "What other places in Penang would you like to visit next?";
            _chatMessages.add(
              ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                sender: MessageSender.ai,
                text: "Steady lah! I've added both $names to your travel plan (${_draftItinerary.length} total stops). 🚲✨ $promptSuffix",
                timestamp: DateTime.now(),
                showActionChips: false,
                quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
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
            final added = addPlaceToDraft(chosenPlace, fromUserPrompt: true, notifyChat: false);
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final promptSuffix = hasEnough
                ? "You now have enough places to plan an awesome trip!"
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
                quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
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
          final rawExtracted = targetMatch.group(1)!.replaceAll(RegExp(r'[\*\_\[\]\.,]'), '').trim();
          if (rawExtracted.isNotEmpty && !_isSystemActionText(rawExtracted)) {
            // Find in predefined catalog or create custom place
            final existingPredefined = kPenangPredefinedPlaces.where(
              (p) => p.name.toLowerCase() == rawExtracted.toLowerCase() || rawExtracted.toLowerCase().contains(p.name.toLowerCase()),
            ).firstOrNull;

            final chosenPlace = existingPredefined ?? ItineraryPlace(
              id: 'place_${DateTime.now().millisecondsSinceEpoch}',
              name: rawExtracted,
              area: 'Penang',
              description: 'Popular attraction in Penang',
              lat: 5.414,
              lng: 100.328,
              category: 'Attraction',
            );

            final added = addPlaceToDraft(chosenPlace, fromUserPrompt: true, notifyChat: false);
            setMascotState(MascotState.happy);
            final hasEnough = _draftItinerary.length >= 3;
            final promptSuffix = hasEnough
                ? "You now have enough places to plan an awesome trip!"
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
                quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
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
              final added = addPlaceToDraft(sp, fromUserPrompt: true, notifyChat: false);
              setMascotState(MascotState.happy);
              final hasEnough = _draftItinerary.length >= 3;
              final promptSuffix = hasEnough
                  ? "You now have enough places to plan an awesome trip!"
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
                  quickReplies: hasEnough ? ['🚀 Save and Plan Trip for Me Now'] : null,
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

    // 4.5 TOUR AND SHORT TRIP DIRECT PLANNING
    if (!_isFactualInquiry(prompt) && _handleAreaTourPlanning(prompt)) return;

    // 5. QUERY LLM BACKEND (Dynamic Mode Dispatcher with Persona Engine & MongoDB Grounding)
    await _queryLLMCompanion(prompt);
  }

  // Handle tour and short trip planning requests by area/location (plans 3 to 5 places directly)
  bool _handleAreaTourPlanning(String prompt) {
    final lower = prompt.toLowerCase().trim();

    // Check for tour / short trip / itinerary / visit / explore intents
    final isTourRequest = lower.contains('tour') ||
        lower.contains('short trip') ||
        lower.contains('day trip') ||
        lower.contains('half day') ||
        lower.contains('places to visit') ||
        lower.contains('place to visit') ||
        lower.contains('plan a tour') ||
        lower.contains('what to do in') ||
        lower.contains('what to visit in') ||
        lower.contains('what to see in') ||
        lower.contains('bring me to') ||
        lower.contains('attractions in') ||
        lower.contains('jom jalan') ||
        lower.contains('sightseeing');

    if (!isTourRequest) return false;

    // Detect target area
    PenangAreaTour? matchedTour;

    if (lower.contains('george town') ||
        lower.contains('georgetown') ||
        lower.contains('armenian') ||
        lower.contains('chulia') ||
        lower.contains('unesco') ||
        lower.contains('heritage')) {
      matchedTour = kPenangAreaTourCatalog['george_town'];
    } else if (lower.contains('air itam') ||
        lower.contains('ayer itam') ||
        lower.contains('penang hill') ||
        lower.contains('bukit bendera') ||
        lower.contains('kek lok si') ||
        lower.contains('kek lok')) {
      matchedTour = kPenangAreaTourCatalog['air_itam'];
    } else if (lower.contains('batu ferringhi') ||
        lower.contains('ferringhi') ||
        lower.contains('batu feringghi') ||
        lower.contains('batu ferringi') ||
        lower.contains('beach') ||
        lower.contains('coastal')) {
      matchedTour = kPenangAreaTourCatalog['batu_ferringhi'];
    } else if (lower.contains('teluk bahang') ||
        lower.contains('escape') ||
        lower.contains('entopia') ||
        lower.contains('national park')) {
      matchedTour = kPenangAreaTourCatalog['teluk_bahang'];
    } else if (lower.contains('balik pulau') ||
        lower.contains('countryside') ||
        lower.contains('durian') ||
        lower.contains('nutmeg') ||
        lower.contains('audi dream') ||
        lower.contains('audi farm')) {
      matchedTour = kPenangAreaTourCatalog['balik_pulau'];
    } else if (lower.contains('bayan lepas') ||
        lower.contains('batu maung') ||
        lower.contains('queensbay') ||
        lower.contains('snake temple') ||
        lower.contains('south penang') ||
        lower.contains('southern penang')) {
      matchedTour = kPenangAreaTourCatalog['bayan_lepas'];
    } else if (lower.contains('butterworth') ||
        lower.contains('seberang perai') ||
        lower.contains('raja uda') ||
        lower.contains('seberang jaya') ||
        lower.contains('mainland') ||
        lower.contains('bird park')) {
      matchedTour = kPenangAreaTourCatalog['butterworth'];
    } else if (lower.contains('tanjung bungah') ||
        lower.contains('tanjung tokong') ||
        lower.contains('straits quay') ||
        lower.contains('floating mosque') ||
        lower.contains('avatar')) {
      matchedTour = kPenangAreaTourCatalog['tanjung_bungah'];
    } else if (lower.contains('gurney') ||
        lower.contains('pulau tikus') ||
        lower.contains('wat chaiya') ||
        lower.contains('dhammikarama')) {
      matchedTour = kPenangAreaTourCatalog['gurney'];
    }

    if (matchedTour == null) return false;

    // Add curated 3 to 5 places to draft itinerary
    final placesToAdd = matchedTour.places;
    int newlyAdded = 0;
    for (final place in placesToAdd) {
      if (!_draftItinerary.any((p) => p.name.toLowerCase() == place.name.toLowerCase())) {
        _draftItinerary.add(place);
        newlyAdded++;
      }
    }

    // Re-evaluate review timeline if exists
    if (_timeline.isNotEmpty) {
      _recalculateReviewTimeline();
    }

    setMascotState(MascotState.happy);

    // Build rich, structured itinerary text for user (3 to 5 places)
    final buffer = StringBuffer();
    buffer.writeln("${matchedTour.emoji} I've planned a ${placesToAdd.length}-stop short trip for **${matchedTour.displayName}**!");
    buffer.writeln();
    buffer.writeln(matchedTour.summary);
    buffer.writeln();

    for (int i = 0; i < placesToAdd.length; i++) {
      final p = placesToAdd[i];
      buffer.writeln("${i + 1}. **${p.name}** (${p.area}) — ${p.description}");
    }

    buffer.writeln();
    if (newlyAdded > 0) {
      buffer.writeln("✨ All ${placesToAdd.length} places are added directly to your travel plan (${_draftItinerary.length} total stops). Tap the 🗺️ icon in the top right to view the timeline, or tap **Save and Plan Trip for Me Now** below to lock your trip!");
    } else {
      buffer.writeln("✨ These ${placesToAdd.length} places are ready in your travel plan. Tap **Save and Plan Trip for Me Now** below to optimize opening hours and weather!");
    }

    _chatMessages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: buffer.toString().trim(),
        timestamp: DateTime.now(),
        showActionChips: true,
        referencedPlaces: placesToAdd,
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

  Future<void> _queryLLMCompanion(String prompt) async {
    // 1. Determine Mode for Dynamic Dispatcher
    String mode = 'global_explorer';
    if (_hasActiveTrip) {
      mode = 'in_trip_assistant';
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
    final contextPayload = <String, dynamic>{
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

          final isFactual = (data['isFactualInquiry'] == true) || _isFactualInquiry(prompt);

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
              final desc = (p is Map ? (p['description']?.toString() ?? p['reason']?.toString()) : null) ?? '';
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
          }

          if (isFactual) {
            suggestedPlaces = [];
            quickReplies = [];
          }

          // Client-side Alignment & Fallback: Ensure quickReplies and suggestedPlaces match Option A / Option B in reply text
          if (!isFactual) {
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
            // but suggestedPlaces only resolved 1 place, ensure Option B is synthesized
            // so the user sees BOTH Option 1 and Option 2 cards!
            if (quickReplies != null && quickReplies.length >= 2 && (suggestedPlaces == null || suggestedPlaces.length < 2)) {
              final rawNameB = quickReplies[1].replaceFirst(RegExp(r'^(?:Option\s*[AB12]|\[Option\s*[AB12]\])\s*:\s*', caseSensitive: false), '').trim();
              if (rawNameB.isNotEmpty && !_isSystemActionText(rawNameB)) {
                suggestedPlaces ??= [];
                final alreadyPresent = suggestedPlaces.any((p) =>
                  p.name.toLowerCase().contains(rawNameB.toLowerCase()) ||
                  rawNameB.toLowerCase().contains(p.name.toLowerCase())
                );
                if (!alreadyPresent) {
                  final inferredArea = suggestedPlaces.isNotEmpty ? suggestedPlaces.first.area : 'Bayan Lepas';
                  suggestedPlaces.add(
                    ItineraryPlace(
                      id: 'optB_${DateTime.now().millisecondsSinceEpoch}',
                      name: rawNameB,
                      area: inferredArea,
                      description: 'Recommended place in $inferredArea',
                      lat: suggestedPlaces.isNotEmpty ? suggestedPlaces.first.lat : 5.295,
                      lng: suggestedPlaces.isNotEmpty ? suggestedPlaces.first.lng : 100.265,
                      category: isFoodIntent ? 'Cafes' : 'Attraction',
                    ),
                  );
                }
              }
            }
          }

          // Execute actions - Add ONLY the single target spot
          final String lowerReply = reply.toLowerCase();
          final bool isAddIntentFromText = lowerReply.contains("i've added") ||
              lowerReply.contains("i have added") ||
              lowerReply.contains("added to your travel plan") ||
              lowerReply.contains("added to your plan") ||
              lowerReply.contains("added to your list");

          if (action == 'add_spot' || isAddIntentFromText) {
            ItineraryPlace? targetPlace;
            if (suggestedPlaces != null && suggestedPlaces.isNotEmpty) {
              if (data['payload'] != null &&
                  data['payload']['suggestedPlaces'] is List &&
                  (data['payload']['suggestedPlaces'] as List).isNotEmpty) {
                final targetName = (data['payload']['suggestedPlaces'][0]['placeName'] ?? '').toString().toLowerCase();
                if (targetName.isNotEmpty) {
                  targetPlace = suggestedPlaces.firstWhere(
                    (p) => p.name.toLowerCase().contains(targetName) || targetName.contains(p.name.toLowerCase()),
                    orElse: () => suggestedPlaces!.first,
                  );
                }
              }
              targetPlace ??= suggestedPlaces.first;
            } else {
              // Fallback: extract place name from bold markdown e.g. **Cheong Fatt Tze - The Blue Mansion**
              final boldMatch = RegExp(r'\*\*([^*]+)\*\*').firstMatch(reply);
              if (boldMatch != null && boldMatch.group(1) != null) {
                final extractedName = boldMatch.group(1)!.trim();
                if (!_isSystemActionText(extractedName) && extractedName.length > 2) {
                  targetPlace = ItineraryPlace(
                    id: 'spot_${DateTime.now().millisecondsSinceEpoch}',
                    name: extractedName,
                    area: 'Penang',
                    description: 'Added from chat',
                    lat: 5.414,
                    lng: 100.328,
                    category: 'Attraction',
                  );
                }
              }
            }

            if (targetPlace != null &&
                !_isSystemActionText(targetPlace.name) &&
                !_draftItinerary.any((p) => p.name.toLowerCase() == targetPlace!.name.toLowerCase())) {
              _draftItinerary.add(targetPlace);
            }
          } else if (action == 'remove_spots' && data['payload'] != null && data['payload']['targetSequences'] is List) {
            final targetSeqs = (data['payload']['targetSequences'] as List).map((e) => int.tryParse(e.toString())).whereType<int>().toList();
            // Sort descending to remove safely by index
            targetSeqs.sort((a, b) => b.compareTo(a));
            for (final seq in targetSeqs) {
              final idx = seq - 1;
              if (idx >= 0 && idx < _draftItinerary.length) {
                _draftItinerary.removeAt(idx);
              }
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

          // If draft itinerary has fewer than 3 places, do not show Save Trip button in chat quickReplies
          if (_draftItinerary.length < 3 && quickReplies != null) {
            quickReplies.removeWhere((qr) => qr.contains('Save and Plan Trip'));
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
          "You are 'Kia-Kia Penang Pink Bird', a cheerful, knowledgeable local travel bird companion for Penang, Malaysia. "
          "When the user asks for a tour or a short trip at a specific area or location in Penang (e.g. George Town, Air Itam, Batu Ferringhi, Teluk Bahang, Bayan Lepas, Balik Pulau, Butterworth, etc.), DO NOT provide options to choose from (do not ask which option they prefer). Instead, directly help the user plan a 3 to 5 places itinerary in that area in logical visit sequence with highlights and practical tips. Keep responses friendly, energetic, and under 150 words.";

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
          if (!_isFactualInquiry(prompt)) {
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
            "You are 'Kia-Kia Penang Pink Bird', a cheerful, knowledgeable local travel bird companion for Penang, Malaysia. "
            "When the user asks for a tour or a short trip at a specific area or location in Penang (e.g. George Town, Air Itam, Batu Ferringhi, Teluk Bahang, Bayan Lepas, Balik Pulau, Butterworth, etc.), DO NOT provide options to choose from (do not ask which option they prefer). Instead, directly help the user plan a 3 to 5 places itinerary in that area in logical visit sequence with highlights and practical tips. Keep responses friendly, energetic, and under 150 words.";

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

    // 4. Local fallback intelligent response
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
