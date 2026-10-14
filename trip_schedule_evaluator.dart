import 'dart:convert';
import 'dart:math';
import 'saved_trip_plans_manager.dart';
import 'places_service.dart';
import 'live_journey_service.dart';
import 'stamps_service.dart';
import '../screens/category_screen.dart';

/// Represents a single recommended alternative venue within 2km of the conflicted stop
class NearbyAlternative {
  final String name;
  final String category;
  final String area;
  final String businessHours;
  final String description;
  final String imagePath;
  final double lat;
  final double lng;
  final double distanceKm;
  final int distanceMeters;
  final int travelMinutes;
  final PlaceOperatingHours operatingHours;
  final String reason;

  const NearbyAlternative({
    required this.name,
    required this.category,
    required this.area,
    required this.businessHours,
    required this.description,
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    required this.distanceMeters,
    required this.travelMinutes,
    required this.operatingHours,
    required this.reason,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '$distanceMeters m away • ~$travelMinutes min travel';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km away • ~$travelMinutes min travel';
    }
  }
}

/// Represents an opening hours conflict detected for a stop upon estimated arrival
class ScheduleConflict {
  final SavedPlanStop stop;
  final int stopIndex;
  final DateTime estimatedArrival;
  final DateTime estimatedDeparture;
  final PlaceOperatingHours operatingHours;
  final String conflictType; // 'closed_today' | 'not_open_yet' | 'closed_before_arrival' | 'closes_during_visit'
  final String explanation;
  final List<NearbyAlternative> alternatives;

  const ScheduleConflict({
    required this.stop,
    required this.stopIndex,
    required this.estimatedArrival,
    required this.estimatedDeparture,
    required this.operatingHours,
    required this.conflictType,
    required this.explanation,
    required this.alternatives,
  });
}

/// Evaluation result containing proposed start time, conflict flags, and computed stop times
class ScheduleEvaluationResult {
  final DateTime proposedStartTime;
  final bool hasConflicts;
  final List<ScheduleConflict> conflicts;
  final Map<int, (DateTime arrival, DateTime departure)> stopTimes;

  const ScheduleEvaluationResult({
    required this.proposedStartTime,
    required this.hasConflicts,
    required this.conflicts,
    required this.stopTimes,
  });
}

/// Service that evaluates a travel itinerary against a custom trip start time,
/// checking each venue's opening hours on the scheduled visit day and providing
/// 2-3 same-category nearby alternatives within 2km if venues are closed.
class TripScheduleEvaluator {
  static const double maxNearbyRadiusKm = 2.0; // Strictly within 2km

  /// Evaluates all stops in the plan starting from [startDateTime].
  /// Detects any stops that will be closed or not open yet upon arrival.
  static Future<ScheduleEvaluationResult> evaluatePlanSchedule({
    required SavedTripPlan plan,
    required DateTime startDateTime,
    double? startLat,
    double? startLng,
    bool useMockLocation = true,
  }) async {
    final Map<int, (DateTime, DateTime)> stopTimes = {};
    final List<ScheduleConflict> conflicts = [];

    if (plan.stops.isEmpty) {
      return ScheduleEvaluationResult(
        proposedStartTime: startDateTime,
        hasConflicts: false,
        conflicts: [],
        stopTimes: {},
      );
    }

    DateTime currentClock = startDateTime;

    // 1. Initial transit to Stop 0
    final firstStop = plan.stops.first;
    int initialTransitMins = 10;
    if (startLat != null && startLng != null) {
      final transit = PlacesService.calculateTransit(
        fromLat: startLat,
        fromLng: startLng,
        toLat: firstStop.lat,
        toLng: firstStop.lng,
      );
      initialTransitMins = (transit['transitMins'] as num?)?.toInt() ?? 10;
    } else if (useMockLocation) {
      final hotel = MockHotelRegistry.findForArea(firstStop.area);
      final transit = PlacesService.calculateTransit(
        fromLat: hotel.lat,
        fromLng: hotel.lng,
        toLat: firstStop.lat,
        toLng: firstStop.lng,
      );
      initialTransitMins = (transit['transitMins'] as num?)?.toInt() ?? 10;
    }

    // 2. Iterate each stop and calculate arrival & departure
    for (int i = 0; i < plan.stops.length; i++) {
      final stop = plan.stops[i];
      final DateTime arrival;

      if (i == 0) {
        arrival = currentClock.add(Duration(minutes: initialTransitMins));
      } else {
        final prevStop = plan.stops[i - 1];
        final transit = PlacesService.calculateTransit(
          fromLat: prevStop.lat,
          fromLng: prevStop.lng,
          toLat: stop.lat,
          toLng: stop.lng,
        );
        final transitMins = (transit['transitMins'] as num?)?.toInt() ?? 12;
        arrival = currentClock.add(Duration(minutes: transitMins));
      }

      final stayMins = _parseStayDurationMinutes(stop.stayDuration);
      final departure = arrival.add(Duration(minutes: stayMins));
      stopTimes[i] = (arrival, departure);
      currentClock = departure;

      // 3. Retrieve operating hours for the venue on the visit day
      final rawHours = await _resolvePlaceOpeningHours(stop);
      final operatingHours = PlacesService.getPlaceOperatingHours(rawHours, arrival);

      final arrivalMins = arrival.hour * 60 + arrival.minute;
      final departMins = departure.hour * 60 + departure.minute;

      // 4. Verify against opening hours
      final conflict = _checkStopConflict(
        stop: stop,
        stopIndex: i,
        arrival: arrival,
        departure: departure,
        arrivalMins: arrivalMins,
        departMins: departMins,
        operatingHours: operatingHours,
      );

      if (conflict != null) {
        // Find 2 to 3 same-category nearby suggestions within 2km
        final alternatives = await findNearbySameCategoryAlternatives(
          stop: stop,
          visitDate: arrival,
          arrivalMinutes: arrivalMins,
          departureMinutes: departMins,
          maxDistanceKm: maxNearbyRadiusKm,
        );

        conflicts.add(
          ScheduleConflict(
            stop: stop,
            stopIndex: i,
            estimatedArrival: arrival,
            estimatedDeparture: departure,
            operatingHours: operatingHours,
            conflictType: conflict.$1,
            explanation: conflict.$2,
            alternatives: alternatives,
          ),
        );
      }
    }

    return ScheduleEvaluationResult(
      proposedStartTime: startDateTime,
      hasConflicts: conflicts.isNotEmpty,
      conflicts: conflicts,
      stopTimes: stopTimes,
    );
  }

  /// Evaluates whether a stop has an opening hours conflict
  static (String conflictType, String explanation)? _checkStopConflict({
    required SavedPlanStop stop,
    required int stopIndex,
    required DateTime arrival,
    required DateTime departure,
    required int arrivalMins,
    required int departMins,
    required PlaceOperatingHours operatingHours,
  }) {
    if (operatingHours.isOpen24Hours) return null;

    final weekdayName = _getWeekdayName(arrival.weekday);
    final formattedArrival = PlacesService.formatClockMinutes(arrivalMins);

    // 1. Closed on this day
    if (operatingHours.isClosed) {
      return (
        'closed_today',
        '${stop.placeName} is closed on $weekdayName.',
      );
    }

    final openM = operatingHours.openMinutes;
    final closeM = operatingHours.closeMinutes;

    if (openM != null && closeM != null) {
      final effectiveClose = closeM < openM ? closeM + 1440 : closeM;

      // 2. Arrives before opening time
      if (arrivalMins < openM) {
        final formattedOpen = PlacesService.formatClockMinutes(openM);
        return (
          'not_open_yet',
          '${stop.placeName} has not opened yet upon arrival. Opens at $formattedOpen, but estimated arrival is $formattedArrival.',
        );
      }

      // 3. Arrives after closing time
      if (arrivalMins >= effectiveClose) {
        final formattedClose = PlacesService.formatClockMinutes(closeM);
        return (
          'closed_before_arrival',
          '${stop.placeName} will already be closed when you arrive. Closes at $formattedClose, but estimated arrival is $formattedArrival.',
        );
      }

      // 4. Closes during the visit (leaving less than 15 mins)
      if (departMins > effectiveClose + 10) {
        final formattedClose = PlacesService.formatClockMinutes(closeM);
        return (
          'closes_during_visit',
          '${stop.placeName} closes at $formattedClose, which overlaps your planned stay.',
        );
      }
    }

    return null;
  }

  /// Searches for 2 to 3 same-category nearby alternatives within [maxDistanceKm] (default 2km)
  /// that are verified to be open during the visit window on [visitDate].
  static Future<List<NearbyAlternative>> findNearbySameCategoryAlternatives({
    required SavedPlanStop stop,
    required DateTime visitDate,
    required int arrivalMinutes,
    required int departureMinutes,
    double maxDistanceKm = 2.0,
  }) async {
    final List<NearbyAlternative> candidates = [];
    final targetCategory = _normalizeCategory(stop.category);
    final targetLat = stop.lat;
    final targetLng = stop.lng;
    final stopNameLower = stop.placeName.trim().toLowerCase();

    // Set of seen names to avoid duplicates
    final Set<String> seenNames = {stopNameLower};

    // 1. Check local predefined stamps (high quality GPS and images)
    for (final stamp in kPredefined28DigitalStamps) {
      final nameLower = stamp.title.trim().toLowerCase();
      if (seenNames.contains(nameLower)) continue;

      final stampCategory = _inferCategoryFromNameAndDesc(stamp.title, stamp.description);
      final isCompatible = _isCategoryCompatible(targetCategory, stampCategory);
      if (!isCompatible) continue;

      final distKm = _calculateHaversineDistanceKm(targetLat, targetLng, stamp.lat, stamp.lng);
      if (distKm <= maxDistanceKm) {
        final hoursStr = _inferBusinessHours(stamp.title);
        final opHours = PlacesService.parseOperatingHours(hoursStr);
        if (_isVenueOpen(opHours, arrivalMinutes, departureMinutes)) {
          seenNames.add(nameLower);
          final transit = PlacesService.calculateTransit(
            fromLat: targetLat,
            fromLng: targetLng,
            toLat: stamp.lat,
            toLng: stamp.lng,
          );
          candidates.add(
            NearbyAlternative(
              name: stamp.title,
              category: stampCategory,
              area: stamp.location,
              businessHours: hoursStr,
              description: stamp.description,
              imagePath: stamp.imageUrl,
              lat: stamp.lat,
              lng: stamp.lng,
              distanceKm: distKm,
              distanceMeters: (distKm * 1000).round(),
              travelMinutes: (transit['transitMins'] as num?)?.toInt() ?? max(2, (distKm * 3).round()),
              operatingHours: opHours,
              reason: 'Open & only ${(distKm * 1000).round()}m from ${stop.placeName} in the same $targetCategory category.',
            ),
          );
        }
      }
    }

    // 2. Check local allDestinations
    for (final dest in allDestinations) {
      final nameLower = dest.title.trim().toLowerCase();
      if (seenNames.contains(nameLower)) continue;

      final destCategory = _normalizeCategory(dest.category);
      if (!_isCategoryCompatible(targetCategory, destCategory)) continue;

      final (lat, lng) = _resolveCoordsForTitle(dest.title, dest.area);
      final distKm = _calculateHaversineDistanceKm(targetLat, targetLng, lat, lng);

      if (distKm <= maxDistanceKm) {
        final opHours = PlacesService.getPlaceOperatingHours(dest.businessHours, visitDate);
        if (_isVenueOpen(opHours, arrivalMinutes, departureMinutes)) {
          seenNames.add(nameLower);
          final transit = PlacesService.calculateTransit(
            fromLat: targetLat,
            fromLng: targetLng,
            toLat: lat,
            toLng: lng,
          );
          candidates.add(
            NearbyAlternative(
              name: dest.title,
              category: dest.category,
              area: dest.area,
              businessHours: dest.businessHours,
              description: dest.description,
              imagePath: dest.imagePath,
              lat: lat,
              lng: lng,
              distanceKm: distKm,
              distanceMeters: (distKm * 1000).round(),
              travelMinutes: (transit['transitMins'] as num?)?.toInt() ?? max(2, (distKm * 3).round()),
              operatingHours: opHours,
              reason: 'Open $targetCategory attraction within ${(distKm * 1000).round()}m of your stop.',
            ),
          );
        }
      }
    }

    // 3. If we still need more suggestions (fewer than 3), query MongoDB backend
    if (candidates.length < 3) {
      try {
        final backendPlaces = await PlacesService().searchMultiplePlaces(stop.area);
        for (final item in backendPlaces) {
          final title = (item['title'] ?? item['name'] ?? '').toString().trim();
          final nameLower = title.toLowerCase();
          if (title.isEmpty || seenNames.contains(nameLower)) continue;

          final cat = _normalizeCategory(item['category'] ?? item['primary_category'] ?? 'Attraction');
          if (!_isCategoryCompatible(targetCategory, cat)) continue;

          double lat = 0.0;
          double lng = 0.0;
          if (item['coordinates'] != null) {
            try {
              final c = json.decode(item['coordinates']!);
              if (c is List && c.length >= 2) {
                lng = (c[0] as num).toDouble();
                lat = (c[1] as num).toDouble();
              }
            } catch (_) {}
          }
          if (lat == 0.0 || lng == 0.0) {
            final coords = _resolveCoordsForTitle(title, item['area'] ?? stop.area);
            lat = coords.$1;
            lng = coords.$2;
          }

          final distKm = _calculateHaversineDistanceKm(targetLat, targetLng, lat, lng);
          if (distKm <= maxDistanceKm) {
            final rawHours = item['placeBusinessHours'] ?? item['businessHours'] ?? item['openingHours'];
            final opHours = PlacesService.getPlaceOperatingHours(rawHours, visitDate);

            if (_isVenueOpen(opHours, arrivalMinutes, departureMinutes)) {
              seenNames.add(nameLower);
              final transit = PlacesService.calculateTransit(
                fromLat: targetLat,
                fromLng: targetLng,
                toLat: lat,
                toLng: lng,
              );
              candidates.add(
                NearbyAlternative(
                  name: title,
                  category: item['category'] ?? cat,
                  area: item['area'] ?? stop.area,
                  businessHours: PlacesService.formatConciseSummary(rawHours, visitDate),
                  description: item['description'] ?? 'Verified local $cat destination in Penang.',
                  imagePath: item['imagePath'] ?? '',
                  lat: lat,
                  lng: lng,
                  distanceKm: distKm,
                  distanceMeters: (distKm * 1000).round(),
                  travelMinutes: (transit['transitMins'] as num?)?.toInt() ?? max(2, (distKm * 3).round()),
                  operatingHours: opHours,
                  reason: 'Local $targetCategory spot open at your travel time, ${(distKm * 1000).round()}m away.',
                ),
              );
            }
          }
          if (candidates.length >= 6) break;
        }
      } catch (_) {}
    }

    // Sort by distance ascending
    candidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // Return top 2 to 3 alternatives
    if (candidates.length > 3) {
      return candidates.sublist(0, 3);
    }
    return candidates;
  }

  /// Checks if venue is open during the user's estimated visit window
  static bool _isVenueOpen(PlaceOperatingHours opHours, int arrivalMins, int departMins) {
    if (opHours.isClosed) return false;
    if (opHours.isOpen24Hours) return true;
    if (opHours.openMinutes == null || opHours.closeMinutes == null) return true;

    final openM = opHours.openMinutes!;
    final closeM = opHours.closeMinutes!;
    final effectiveClose = closeM < openM ? closeM + 1440 : closeM;

    // Must be after open time and before close time
    if (arrivalMins < openM) return false;
    if (arrivalMins >= effectiveClose) return false;

    return true;
  }

  /// Resolves raw operating hours for a SavedPlanStop
  /// Resolves business hours for a stop using known landmarks, predefined stamps,
  /// allDestinations, or backend API search
  static Future<dynamic> _resolvePlaceOpeningHours(SavedPlanStop stop) async {
    // 1. Check prominent Penang landmarks directly (instant resolution)
    final knownHours = _inferBusinessHours(stop.placeName);
    if (knownHours.isNotEmpty && knownHours != '9:00 AM - 6:00 PM') {
      return knownHours;
    }

    // 2. Search in allDestinations
    final dest = allDestinations.where((d) =>
        d.title.toLowerCase().contains(stop.placeName.toLowerCase()) ||
        stop.placeName.toLowerCase().contains(d.title.toLowerCase())).firstOrNull;
    if (dest != null && dest.businessHours.isNotEmpty) {
      return dest.businessHours;
    }

    // 3. Search predefined stamps
    final stamp = kPredefined28DigitalStamps.where((s) =>
        s.title.toLowerCase().contains(stop.placeName.toLowerCase()) ||
        stop.placeName.toLowerCase().contains(s.title.toLowerCase())).firstOrNull;
    if (stamp != null) {
      return _inferBusinessHours(stamp.title);
    }

    // 4. Search via PlacesService with quick timeout
    try {
      final results = await PlacesService()
          .searchMultiplePlaces(stop.placeName)
          .timeout(const Duration(milliseconds: 1500));
      if (results.isNotEmpty) {
        final first = results.first;
        final h = first['placeBusinessHours'] ?? first['businessHours'] ?? first['openingHours'];
        if (h != null) return h;
      }
    } catch (_) {}

    return knownHours; // Fall back to standard 9:00 AM - 6:00 PM
  }

  /// Categorization normalization
  static String _normalizeCategory(String? raw) {
    if (raw == null || raw.trim().isEmpty) return 'Attraction';
    final lower = raw.toLowerCase().trim();

    if (lower.contains('heritage') || lower.contains('clan') || lower.contains('historic') || lower.contains('culture')) {
      return 'Heritage';
    }
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant') || lower.contains('cafe') || lower.contains('hawker')) {
      return 'Food';
    }
    if (lower.contains('nature') || lower.contains('park') || lower.contains('garden') || lower.contains('beach') || lower.contains('hill')) {
      return 'Nature';
    }
    if (lower.contains('outdoor') || lower.contains('adventure') || lower.contains('theme')) {
      return 'Outdoors';
    }
    if (lower.contains('temple') || lower.contains('worship') || lower.contains('church') || lower.contains('mosque')) {
      return 'Places of Worship';
    }
    if (lower.contains('museum') || lower.contains('gallery')) {
      return 'Museum';
    }
    return 'Attraction';
  }

  /// Checks if two categories are compatible (e.g. Heritage & Worship & Museum all fit cultural attractions)
  static bool _isCategoryCompatible(String cat1, String cat2) {
    if (cat1 == cat2) return true;
    final c1 = _normalizeCategory(cat1);
    final c2 = _normalizeCategory(cat2);
    if (c1 == c2) return true;

    // Cultural / Heritage / Worship / Museum compatibility
    const cultural = {'Heritage', 'Places of Worship', 'Museum', 'Attraction'};
    if (cultural.contains(c1) && cultural.contains(c2)) return true;

    // Nature / Outdoors compatibility
    const nature = {'Nature', 'Outdoors', 'Attraction'};
    if (nature.contains(c1) && nature.contains(c2)) return true;

    return false;
  }

  static String _inferCategoryFromNameAndDesc(String name, String desc) {
    final lower = '$name $desc'.toLowerCase();
    if (lower.contains('temple') || lower.contains('mosque') || lower.contains('church') || lower.contains('worship')) {
      return 'Places of Worship';
    }
    if (lower.contains('mansion') || lower.contains('clan') || lower.contains('jetty') || lower.contains('heritage') || lower.contains('fort') || lower.contains('street art')) {
      return 'Heritage';
    }
    if (lower.contains('food') || lower.contains('hawker') || lower.contains('laksa') || lower.contains('chendul') || lower.contains('curry') || lower.contains('kway teow')) {
      return 'Food';
    }
    if (lower.contains('hill') || lower.contains('park') || lower.contains('garden') || lower.contains('nature')) {
      return 'Nature';
    }
    if (lower.contains('museum') || lower.contains('gallery')) {
      return 'Museum';
    }
    return 'Heritage';
  }

  static String _inferBusinessHours(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('street art') || lower.contains('mural')) return 'Open 24 Hours';
    if (lower.contains('fort cornwallis')) return '9:00 AM - 10:00 PM';
    if (lower.contains('clan jetty') || lower.contains('chew jetty')) return '9:00 AM - 9:00 PM';
    if (lower.contains('khoo kongsi')) return '9:00 AM - 5:00 PM';
    if (lower.contains('cheong fatt tze') || lower.contains('blue mansion')) return '11:00 AM - 5:00 PM';
    if (lower.contains('peranakan')) return '9:30 AM - 5:00 PM';
    if (lower.contains('kek lok si')) return '8:30 AM - 5:30 PM';
    if (lower.contains('penang hill')) return '6:30 AM - 10:00 PM';
    if (lower.contains('escape')) return '10:00 AM - 6:00 PM';
    if (lower.contains('entopia')) return '9:00 AM - 5:00 PM';
    if (lower.contains('chulia')) return '6:00 PM - 11:30 PM';
    if (lower.contains('gurney')) return '4:30 PM - 11:00 PM';
    if (lower.contains('new lane')) return '4:00 PM - 11:00 PM';
    return '9:00 AM - 6:00 PM';
  }

  static (double, double) _resolveCoordsForTitle(String title, String area) {
    final lower = '$title $area'.toLowerCase();
    for (final s in kPredefined28DigitalStamps) {
      if (lower.contains(s.title.toLowerCase()) || s.title.toLowerCase().contains(title.toLowerCase())) {
        return (s.lat, s.lng);
      }
    }
    if (lower.contains('chew jetty') || lower.contains('clan jetty')) return (5.4126, 100.3396);
    if (lower.contains('penang hill')) return (5.4084, 100.2687);
    if (lower.contains('kek lok si')) return (5.3995, 100.2736);
    if (lower.contains('fort cornwallis')) return (5.4206, 100.3440);
    if (lower.contains('khoo kongsi')) return (5.4151, 100.3364);
    if (lower.contains('peranakan')) return (5.4180, 100.3409);
    if (lower.contains('cheong fatt tze') || lower.contains('blue mansion')) return (5.4216, 100.3344);
    if (lower.contains('chulia')) return (5.4182, 100.3364);
    if (lower.contains('new lane')) return (5.4149, 100.3262);
    if (lower.contains('street art')) return (5.4150, 100.3370);
    if (lower.contains('escape')) return (5.4492, 100.2154);
    if (lower.contains('entopia')) return (5.4470, 100.2185);
    if (lower.contains('botanic')) return (5.4379, 100.2907);
    return (5.4141, 100.3288); // Default George Town
  }

  static double _calculateHaversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  static int _parseStayDurationMinutes(String stayDuration) {
    final match = RegExp(r'\d+').firstMatch(stayDuration);
    if (match != null) {
      final val = int.tryParse(match.group(0)!);
      if (val != null && val > 0) return val;
    }
    return 45; // Default 45 mins stay
  }

  static String _getWeekdayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
