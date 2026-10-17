import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'ollama_service.dart';
import '../screens/category_screen.dart';
import 'stamps_service.dart';

class PlacesService {
  final OllamaService _ollamaService = OllamaService();

  // In-memory photo cache to avoid redundant API requests
  static final Map<String, String> _photoCache = {};

  /// Haversine straight-line distance in kilometres between two coordinates
  static double calculateDistanceKm(double lat1, double lng1, double lat2, double lng2) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  /// Calculates realistic road transit distance and travel times across Penang.
  /// Uses Penang road detour factor (1.25x straight-line) and urban traffic speed (28 km/h).
  static Map<String, dynamic> calculateTransit({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 - cos((toLat - fromLat) * p) / 2 +
        cos(fromLat * p) * cos(toLat * p) * (1 - cos((toLng - fromLng) * p)) / 2;
    final straightKm = 12742 * asin(sqrt(a)); // Haversine formula (2 * R, R = 6371 km)

    // Real-world Penang road detour factor (~1.25x straight-line, min 0.3km)
    final roadKm = straightKm > 0 ? max(0.3, straightKm * 1.25) : 0.8;

    // Average urban/suburban driving speed in Penang is ~28 km/h + traffic/parking buffer
    final carMins = max(3, (roadKm / 28.0 * 60).round() + (roadKm > 1.0 ? 3 : 1));

    // Walking speed ~4.5 km/h on road network (~1.25x detour)
    final walkMins = ((roadKm / 4.5) * 60).round().clamp(1, 300);

    // Public Bus (Rapid Penang) ~16 km/h + 5m stop/wait buffer
    final busMins = (((roadKm / 16.0) * 60) + 5).round().clamp(5, 240);

    return {
      'straightKm': straightKm,
      'roadKm': roadKm,
      'transitMins': carMins,
      'carMins': carMins,
      'walkMins': walkMins,
      'busMins': busMins,
    };
  }

  String _formatBusinessHours(dynamic hours) {
    if (hours == null) return 'Check online';
    if (hours is String) return hours;
    if (hours is Map) {
      if (hours.isEmpty) return 'Check online';
      final values = hours.values.toSet();
      if (values.length == 1) {
        return values.first.toString();
      }
      final now = DateTime.now();
      final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      final todayName = weekdays[now.weekday - 1];
      if (hours.containsKey(todayName)) {
        return 'Today: ${hours[todayName]}';
      }
      return hours.entries
          .map((e) => '${e.key.toString()[0].toUpperCase()}${e.key.toString().substring(1, 3)}: ${e.value}')
          .join(', ');
    }
    return 'Check online';
  }

  static String formatTimeString(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return '';
    if (RegExp(r'(am|pm)', caseSensitive: false).hasMatch(trimmed)) {
      return trimmed;
    }
    final parts = trimmed.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) {
        final ampm = h >= 12 ? 'PM' : 'AM';
        final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        final minStr = m.toString().padLeft(2, '0');
        return minStr == '00' ? '$hour12:00 $ampm' : '$hour12:$minStr $ampm';
      }
    }
    return trimmed;
  }

  /// Extracts human-readable hours string from a day value (which may be Map, String, or JSON)
  static String formatDayOpeningHours(dynamic val) {
    if (val == null) return 'Check online';
    if (val is Map) {
      final isClosed = val['is_closed'] == true || val['closed'] == true;
      if (isClosed) return 'Closed';
      final open = val['open']?.toString();
      final close = val['close']?.toString();
      if (open != null && close != null && open.isNotEmpty && close.isNotEmpty) {
        if ((open == '00:00' || open == '0:00') && (close == '00:00' || close == '24:00' || close == '23:59')) {
          return 'Open 24 Hours';
        }
        return '${formatTimeString(open)} – ${formatTimeString(close)}';
      }
      if (val['hours'] != null) {
        return formatDayOpeningHours(val['hours']);
      }
      return 'Check online';
    }
    final str = val.toString().trim();
    if (str.toLowerCase() == 'closed' || str.toLowerCase() == 'tutup') return 'Closed';

    // Parse ranges like "5–10 PM", "5:00 PM – 10:00 PM", "11 AM – 8 PM"
    final rangeMatch = RegExp(r'(\d+(?::\d+)?)\s*(am|pm)?\s*[-–—]\s*(\d+(?::\d+)?)\s*(am|pm)', caseSensitive: false).firstMatch(str);
    if (rangeMatch != null) {
      final startNum = rangeMatch.group(1)!;
      final startAmPm = (rangeMatch.group(2) ?? rangeMatch.group(4) ?? '').toUpperCase();
      final endNum = rangeMatch.group(3)!;
      final endAmPm = (rangeMatch.group(4) ?? '').toUpperCase();

      final formattedStart = formatTimeString('$startNum $startAmPm');
      final formattedEnd = formatTimeString('$endNum $endAmPm');
      return '$formattedStart – $formattedEnd';
    }

    if (str.startsWith('{') && str.endsWith('}')) {
      try {
        final decoded = json.decode(str);
        return formatDayOpeningHours(decoded);
      } catch (_) {}

      // Fallback parser for Dart map toString() like "{is_closed: false, open: 09:00, close: 18:00}"
      final isClosedMatch = RegExp(r'is_closed\s*:\s*(true|false)', caseSensitive: false).firstMatch(str);
      if (isClosedMatch != null && isClosedMatch.group(1)?.toLowerCase() == 'true') {
        return 'Closed';
      }
      final openMatch = RegExp(r'open\s*:\s*([^,}\s]+)', caseSensitive: false).firstMatch(str);
      final closeMatch = RegExp(r'close\s*:\s*([^,}\s]+)', caseSensitive: false).firstMatch(str);
      if (openMatch != null && closeMatch != null) {
        final open = openMatch.group(1)!;
        final close = closeMatch.group(1)!;
        if ((open == '00:00' || open == '0:00') && (close == '00:00' || close == '24:00' || close == '23:59')) {
          return 'Open 24 Hours';
        }
        return '${formatTimeString(open)} – ${formatTimeString(close)}';
      }
    }
    if (str.contains('{') || str.contains('}')) {
      return 'Check online';
    }
    return str;
  }

  /// Formats opening hours for a specific date (e.g. "Tuesday: 9:00 AM – 6:00 PM" or "Tuesday: Closed")
  static String formatOpeningHoursForDay(dynamic rawHours, DateTime date) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdayName = weekdays[date.weekday - 1];
    final dayKey = weekdayName.toLowerCase();

    if (rawHours == null) return '$weekdayName: Check online';

    dynamic mapOrVal = rawHours;
    if (mapOrVal is String && mapOrVal.trim().startsWith('{')) {
      try {
        mapOrVal = json.decode(mapOrVal);
      } catch (_) {}
    }

    if (mapOrVal is Map) {
      if (mapOrVal.containsKey(dayKey)) {
        final formatted = formatDayOpeningHours(mapOrVal[dayKey]);
        return '$weekdayName: $formatted';
      }
      // Check 3-letter abbreviation (mon, tue, wed...)
      final shortKey = dayKey.substring(0, 3);
      for (final entry in mapOrVal.entries) {
        final k = entry.key.toString().toLowerCase();
        if (k == dayKey || k == shortKey || k.startsWith(shortKey)) {
          final formatted = formatDayOpeningHours(entry.value);
          return '$weekdayName: $formatted';
        }
      }
      if (mapOrVal.containsKey('open') && mapOrVal.containsKey('close')) {
        return '$weekdayName: ${formatDayOpeningHours(mapOrVal)}';
      }
      if (mapOrVal.containsKey('hours')) {
        return '$weekdayName: ${formatDayOpeningHours(mapOrVal['hours'])}';
      }
    }

    if (mapOrVal is String && mapOrVal.trim().isNotEmpty) {
      final trimmed = mapOrVal.trim();
      if (trimmed.contains('{') || trimmed.contains('}')) {
        final formatted = formatDayOpeningHours(trimmed);
        if (!formatted.contains('{')) {
          return '$weekdayName: $formatted';
        }
        return '$weekdayName: Check online';
      }
      return '$weekdayName: $trimmed';
    }

    return '$weekdayName: Check online';
  }

  /// Checks whether a place is closed on a specific date based on raw opening hours
  static bool isPlaceClosedOnDate(dynamic rawHours, DateTime date) {
    if (rawHours == null) return false;
    final hours = getPlaceOperatingHours(rawHours, date);
    return hours.isClosed;
  }

  /// Extracts structured operating hours (with openMinutes and closeMinutes) for a visit date
  static PlaceOperatingHours getPlaceOperatingHours(dynamic rawHours, DateTime date) {
    if (rawHours == null) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final weekdayName = weekdays[date.weekday - 1];
      return PlaceOperatingHours(
        isClosed: false,
        isOpen24Hours: false,
        formattedHours: '$weekdayName: Check online',
      );
    }
    final formatted = formatOpeningHoursForDay(rawHours, date);
    return parseOperatingHours(formatted);
  }

  /// Parses human-readable opening hours string into PlaceOperatingHours
  static PlaceOperatingHours parseOperatingHours(String text) {
    final clean = text.trim();
    // Strip day prefix like "Saturday: "
    final hoursPart = clean.contains(':') && !clean.startsWith('http')
        ? clean.substring(clean.indexOf(':') + 1).trim()
        : clean;

    final lower = hoursPart.toLowerCase();
    if (lower == 'closed' ||
        lower == 'tutup' ||
        lower == 'off' ||
        RegExp(r'^(closed|tutup|off)\b', caseSensitive: false).hasMatch(lower)) {
      return PlaceOperatingHours(
        isClosed: true,
        isOpen24Hours: false,
        formattedHours: 'Closed',
        statusReason: 'Closed on visit day',
      );
    }

    if (lower.contains('24 hours') || lower.contains('24 jam') || lower == 'open 24 hours') {
      return const PlaceOperatingHours(
        isClosed: false,
        isOpen24Hours: true,
        openMinutes: 0,
        closeMinutes: 1440,
        formattedHours: 'Open 24 Hours',
      );
    }

    // Range matching "9:00 AM – 6:00 PM", "09:00 - 18:00", "9am - 10pm", "11:00 AM - 10:30 PM", etc.
    final rangeMatch = RegExp(
      r'(\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)?)\s*[-–—至到]\s*(\d{1,2}(?:[:.]\d{2})?\s*(?:am|pm)?)',
      caseSensitive: false,
    ).firstMatch(hoursPart);

    if (rangeMatch != null) {
      String startStr = rangeMatch.group(1)!.trim();
      String endStr = rangeMatch.group(2)!.trim();

      // If start has no AM/PM but end has PM/AM (e.g. "9 - 6 PM"), infer start
      if (!startStr.toLowerCase().contains('am') && !startStr.toLowerCase().contains('pm')) {
        if (endStr.toLowerCase().contains('pm')) {
          final numPart = int.tryParse(startStr.replaceAll(RegExp(r'\D'), '')) ?? 9;
          if (numPart >= 7 && numPart <= 11) {
            startStr = '$startStr AM';
          } else {
            startStr = '$startStr PM';
          }
        } else if (endStr.toLowerCase().contains('am')) {
          startStr = '$startStr AM';
        }
      }

      final startM = parseTimeStringToMinutes(startStr);
      final endM = parseTimeStringToMinutes(endStr);

      if (startM != null && endM != null) {
        return PlaceOperatingHours(
          isClosed: false,
          isOpen24Hours: false,
          openMinutes: startM,
          closeMinutes: endM,
          formattedHours: hoursPart,
        );
      }
    }

    return PlaceOperatingHours(
      isClosed: false,
      isOpen24Hours: false,
      formattedHours: hoursPart.isNotEmpty ? hoursPart : 'Check online',
    );
  }

  /// Parses a clock time string like "9:00 AM", "6:00 PM", "18:00" to minutes from 00:00
  static int? parseTimeStringToMinutes(String timeStr) {
    final clean = timeStr.trim().toLowerCase();
    if (clean.isEmpty) return null;
    if (clean == '00:00' || clean == '0:00' || clean == '24:00') return 0;
    if (clean == '23:59') return 23 * 60 + 59;

    // 12-hour format: "9:00 AM", "6:00 PM", "9am", "6pm", "9.00pm"
    final match12 = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)$').firstMatch(clean);
    if (match12 != null) {
      int hour = int.parse(match12.group(1)!);
      final minute = match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final isPm = match12.group(3) == 'pm';
      if (isPm && hour < 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return hour * 60 + minute;
    }

    // 24-hour format: "18:00", "09:00", "9:00"
    final match24 = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(clean);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      return hour * 60 + minute;
    }

    return null;
  }

  /// Formats minutes into human-readable clock string like "6:00 PM"
  static String formatClockMinutes(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final mStr = minute.toString().padLeft(2, '0');
    return '$hour12:$mStr $period';
  }

  /// Formats opening hours as a clean concise single-line string (e.g. "10:00 AM – 5:00 PM" or "Open 24 Hours")
  static String formatConciseSummary(dynamic rawHours, [DateTime? date]) {
    if (rawHours == null) return 'Check online';
    final targetDate = date ?? DateTime.now();
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayKey = weekdays[targetDate.weekday - 1];

    dynamic mapOrVal = rawHours;
    if (mapOrVal is String && mapOrVal.trim().startsWith('{')) {
      try {
        mapOrVal = json.decode(mapOrVal);
      } catch (_) {
        final formattedDay = formatDayOpeningHours(mapOrVal);
        if (formattedDay != 'Check online' && !formattedDay.contains('{')) {
          return formattedDay;
        }
      }
    }

    if (mapOrVal is Map) {
      if (mapOrVal.containsKey(todayKey)) {
        final res = formatDayOpeningHours(mapOrVal[todayKey]);
        if (res != 'Check online') return res;
      }
      final shortKey = todayKey.substring(0, 3);
      for (final entry in mapOrVal.entries) {
        final k = entry.key.toString().toLowerCase();
        if (k == todayKey || k == shortKey || k.startsWith(shortKey)) {
          final res = formatDayOpeningHours(entry.value);
          if (res != 'Check online') return res;
        }
      }
      final validEntries = mapOrVal.values
          .map(formatDayOpeningHours)
          .where((v) => v != 'Check online' && !v.startsWith('{'))
          .toSet();
      if (validEntries.length == 1) {
        return validEntries.first;
      }
      for (final v in mapOrVal.values) {
        final f = formatDayOpeningHours(v);
        if (f != 'Check online' && !f.startsWith('{')) return f;
      }
      return 'Check online';
    }

    if (mapOrVal is String) {
      final trimmed = mapOrVal.trim();
      if (trimmed.startsWith('{')) return 'Check online';
      return trimmed;
    }

    return 'Check online';
  }

  String _normalizeOpeningHours(dynamic rawHours) {
    if (rawHours == null) return 'Check online';
    if (rawHours is String) return rawHours;
    if (rawHours is Map && rawHours.isNotEmpty) {
      final Map<String, String> normalized = {};
      final bool is24Hours = rawHours['is_24_hours'] == true;
      final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
      for (final day in weekdays) {
        if (rawHours.containsKey(day)) {
          final v = rawHours[day];
          if (v is String) {
            normalized[day] = v;
          } else if (v is Map) {
            if (is24Hours || (v['open'] == '00:00' && v['close'] == '00:00' && v['is_closed'] != true)) {
              normalized[day] = 'Open 24 Hours';
            } else if (v['is_closed'] == true) {
              normalized[day] = 'Closed';
            } else if (v['open'] != null && v['close'] != null) {
              normalized[day] = '${formatTimeString(v['open'].toString())} – ${formatTimeString(v['close'].toString())}';
            }
          }
        }
      }
      if (normalized.isEmpty) {
        rawHours.forEach((k, v) {
          final keyStr = k.toString().toLowerCase();
          if (keyStr == 'is_24_hours') return;
          if (v is String) {
            normalized[keyStr] = v;
          } else if (v is Map) {
            if (is24Hours || (v['open'] == '00:00' && v['close'] == '00:00' && v['is_closed'] != true)) {
              normalized[keyStr] = 'Open 24 Hours';
            } else if (v['is_closed'] == true) {
              normalized[keyStr] = 'Closed';
            } else if (v['open'] != null && v['close'] != null) {
              normalized[keyStr] = '${formatTimeString(v['open'].toString())} – ${formatTimeString(v['close'].toString())}';
            }
          }
        });
      }
      if (normalized.isNotEmpty) {
        return json.encode(normalized);
      }
      return json.encode(rawHours);
    }
    return _formatBusinessHours(rawHours);
  }

  static String resolveBackendImageUrl(String? rawThumb, {String? baseUrl}) {
    if (rawThumb == null || rawThumb.isEmpty || rawThumb == 'no_image_found') {
      return 'no_image_found';
    }
    final trimmed = rawThumb.trim();
    // 1. Base64
    if (trimmed.startsWith('data:image/') ||
        trimmed.startsWith('data:application/') ||
        (trimmed.length > 200 && !trimmed.startsWith('http') && !trimmed.startsWith('/') && !trimmed.startsWith('assets/'))) {
      return trimmed;
    }
    // 2. Google imgres URL -> extract imgurl
    if (trimmed.contains('google.com/imgres')) {
      try {
        final uri = Uri.parse(trimmed);
        final real = uri.queryParameters['imgurl'];
        if (real != null && real.isNotEmpty) {
          return real;
        }
      } catch (_) {}
    }
    // 3. HTTP / HTTPS
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    // 4. Local asset
    if (trimmed.startsWith('assets/')) {
      return trimmed;
    }
    // 5. Backend relative path
    if (baseUrl != null && baseUrl.isNotEmpty) {
      final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      return '$baseUrl$path';
    }
    return trimmed;
  }

  static String? _workingBackendUrl;

  // 1. Query MongoDB Backend Places API (With Smart Multi-Host Discovery)

  Future<List<Map<String, String>>?> _queryBackendPlaces(String query, {bool hasAircon = false}) async {
    final candidateUrls = {
      if (_workingBackendUrl != null) _workingBackendUrl!,
      AppConfig.backendBaseUrl,
      'http://10.0.2.2:3000', // Android Emulator Host Loopback
      'http://localhost:3000',
      'http://127.0.0.1:3000',
    }.toList();

    for (final baseUrl in candidateUrls) {
      final airconParam = hasAircon ? '&has_aircon=true' : '';
      final url = Uri.parse('$baseUrl/api/places/search?q=${Uri.encodeComponent(query)}$airconParam');
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          _workingBackendUrl = baseUrl;
          final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
          final List results = data['data'] ?? [];
          final List<Map<String, String>> list = [];
          
          for (var item in results) {
            final title = item['name']?.toString() ?? item['place_name']?.toString() ?? '';
            if (title.isEmpty) continue;
            
            final address = item['address']?.toString() ?? item['place_address']?.toString() ?? '';
            final rawArea = item['area']?.toString();
            final area = _extractAreaFromAddress(address, rawArea);
            final category = item['primary_category']?.toString() ?? item['place_category']?.toString() ?? 'Attraction';
            
            final rawDesc = item['description'] != null ? item['description'].toString().trim() : '';
            final rawSummary = item['summary'] != null
                ? item['summary'].toString().trim()
                : (item['place_summary'] != null ? item['place_summary'].toString().trim() : '');
            final description = rawDesc.isNotEmpty
                ? rawDesc
                : (rawSummary.isNotEmpty ? rawSummary : 'A popular $category located in $area, Penang.');
            
            final thumbnail = item['place_media']?['thumbnail']?.toString() ?? item['cover_image']?.toString() ?? '';
            final String imagePath = resolveBackendImageUrl(thumbnail, baseUrl: baseUrl);

            final bool hasPlaceBusinessHours = item['place_business_hours'] != null &&
                item['place_business_hours'] is Map &&
                (item['place_business_hours'] as Map).isNotEmpty;
            final rawHours = hasPlaceBusinessHours
                ? item['place_business_hours']
                : (item['opening_hours'] ?? item['raw_hours_text']);
            final String businessHours = _normalizeOpeningHours(rawHours);
            
            final placeInformation = item['place_information'];
            final placeLocation = item['location'] ?? item['place_location'];
            final hasStreetView = item['hasStreetView'] == true || item['has_street_view'] == true;
            final isPano = item['isPano'] == true;
            final mapillaryImageId = item['mapillaryImageId']?.toString() ?? item['mapillary_image_id']?.toString();
            final streetViewUpdatedAt = item['streetViewUpdatedAt']?.toString();
            final placeId = item['_id']?.toString() ?? item['id']?.toString() ?? '';
            final externalPlaceId = item['external_place_id']?.toString() ?? '';
            
            final phone = placeInformation is Map ? placeInformation['phone']?.toString() : null;
            final website = placeInformation is Map ? placeInformation['website']?.toString() : null;
            final rating = item['rating']?.toString() ?? (placeInformation is Map ? placeInformation['rating']?.toString() : null);
            final reviewsCount = item['review_count']?.toString() ?? (placeInformation is Map ? placeInformation['reviews_count']?.toString() : null);
            final priceLevel = placeInformation is Map ? placeInformation['price_level']?.toString() : null;
            
            list.add({
              'title': title,
              'area': area,
              'address': address,
              'businessHours': businessHours,
              'openingHours': rawHours,
              if (item['place_business_hours'] != null) 'placeBusinessHours': item['place_business_hours'],
              'description': description,
              if (item['description_zh'] != null) 'description_zh': item['description_zh'].toString(),
              if (item['descriptionZh'] != null) 'descriptionZh': item['descriptionZh'].toString(),
              if (rawSummary.isNotEmpty) 'summary': rawSummary,
              'imagePath': imagePath,
              'category': category,
              'hasStreetView': hasStreetView.toString(),
              'isPano': isPano.toString(),
              if (placeId.isNotEmpty) 'id': placeId,
              if (externalPlaceId.isNotEmpty) 'externalPlaceId': externalPlaceId,
              if (mapillaryImageId != null && mapillaryImageId.isNotEmpty) 'mapillaryImageId': mapillaryImageId,
              if (streetViewUpdatedAt != null) 'streetViewUpdatedAt': streetViewUpdatedAt,
              if (phone != null && phone.isNotEmpty) 'phone': phone,
              if (website != null && website.isNotEmpty) 'website': website,
              if (rating != null) 'rating': rating,
              if (reviewsCount != null) 'reviewsCount': reviewsCount,
              if (priceLevel != null) 'priceLevel': priceLevel,
              if (placeInformation != null) 'placeInformation': json.encode(placeInformation),
              if (placeLocation != null && placeLocation['coordinates'] != null)
                'coordinates': json.encode(placeLocation['coordinates']),
              if (item['primary_category'] != null) 'primary_category': item['primary_category'].toString(),
              if (item['sub_categories'] != null) 'sub_categories': json.encode(item['sub_categories']),
              if (item['raw_hours_text'] != null) 'rawHoursText': item['raw_hours_text'].toString(),
              if (item['search_keywords'] != null)
                'searchKeywords': item['search_keywords'] is List
                    ? json.encode(item['search_keywords'])
                    : item['search_keywords'].toString(),
              if (item['features'] != null) 'features': json.encode(item['features']),
              if (item['ticket_fee'] != null) 'ticketFee': json.encode(item['ticket_fee']),
            });
          }
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (e) {
        // Try next candidate URL
      }
    }
    return null;
  }

  // Helper: Format raw places_new document into normalized Map
  Map<String, dynamic> _extractMongoPlaceDetails(dynamic item, String baseUrl, String fallbackTitle) {
    final thumbnail = item['place_media']?['thumbnail']?.toString() ??
        item['cover_image']?.toString() ??
        '';
    final String? imagePath = thumbnail.isNotEmpty
        ? resolveBackendImageUrl(thumbnail, baseUrl: baseUrl)
        : null;

    final placeInfo = item['place_information'];
    final coords = item['location']?['coordinates'] ?? item['place_location']?['coordinates'];

    final rawDesc = item['description'] != null ? item['description'].toString().trim() : '';
    final rawDescZh = item['description_zh'] != null
        ? item['description_zh'].toString().trim()
        : (item['descriptionZh'] != null ? item['descriptionZh'].toString().trim() : '');
    final rawSummary = item['summary'] != null
        ? item['summary'].toString().trim()
        : (item['place_summary'] != null ? item['place_summary'].toString().trim() : '');
    final address = item['address']?.toString() ?? item['place_address']?.toString() ?? '';
    final rawArea = item['area']?.toString();
    final area = _extractAreaFromAddress(address, rawArea);
    final category = item['primary_category']?.toString() ?? item['place_category']?.toString() ?? 'Attraction';
    final description = rawDesc.isNotEmpty
        ? rawDesc
        : (rawSummary.isNotEmpty ? rawSummary : 'A popular $category located in $area, Penang.');

    final bool hasPlaceBusinessHours = item['place_business_hours'] != null &&
        item['place_business_hours'] is Map &&
        (item['place_business_hours'] as Map).isNotEmpty;
    final rawHours = hasPlaceBusinessHours
        ? item['place_business_hours']
        : (item['opening_hours'] ?? item['raw_hours_text']);
    final String businessHours = _normalizeOpeningHours(rawHours);

    final rawHoursText = item['raw_hours_text']?.toString() ?? '';
    List<String> searchKeywords = [];
    if (item['search_keywords'] is List) {
      searchKeywords = (item['search_keywords'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (item['search_keywords'] is String && item['search_keywords'].toString().trim().isNotEmpty) {
      searchKeywords = item['search_keywords']
          .toString()
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final primaryCategory = item['primary_category']?.toString() ?? item['place_category']?.toString() ?? '';
    List<String> subCategories = [];
    if (item['sub_categories'] is List) {
      subCategories = (item['sub_categories'] as List).map((e) => e.toString()).toList();
    }

    final phone = placeInfo is Map ? placeInfo['phone']?.toString() : null;
    final website = placeInfo is Map ? placeInfo['website']?.toString() : null;
    final rating = item['rating']?.toString() ?? (placeInfo is Map ? placeInfo['rating']?.toString() : null);
    final reviewsCount = item['review_count']?.toString() ?? (placeInfo is Map ? placeInfo['reviews_count']?.toString() : null);
    final priceLevel = (placeInfo is Map && placeInfo['price_level'] != null && placeInfo['price_level'].toString().isNotEmpty)
        ? placeInfo['price_level']?.toString()
        : item['price_level']?.toString();

    final id = item['_id']?.toString() ?? item['id']?.toString() ?? '';

    return {
      'id': id,
      'title': item['name']?.toString() ?? item['place_name']?.toString() ?? fallbackTitle,
      'imagePath': imagePath,
      'hasStreetView': item['hasStreetView'] == true || item['has_street_view'] == true,
      'isPano': item['isPano'] == true,
      'mapillaryImageId': item['mapillaryImageId']?.toString() ?? item['mapillary_image_id']?.toString(),
      'streetViewUpdatedAt': item['streetViewUpdatedAt']?.toString(),
      'externalPlaceId': item['external_place_id']?.toString() ?? '',
      'coordinates': coords,
      'coordinatesJson': coords != null ? json.encode(coords) : null,
      'address': address,
      'area': area,
      'category': category,
      'primaryCategory': primaryCategory,
      'subCategories': subCategories,
      'description': description,
      if (rawDescZh.isNotEmpty) 'description_zh': rawDescZh,
      if (rawDescZh.isNotEmpty) 'descriptionZh': rawDescZh,
      if (rawSummary.isNotEmpty) 'summary': rawSummary,
      'businessHours': businessHours,
      'openingHours': rawHours,
      if (item['place_business_hours'] != null) 'placeBusinessHours': item['place_business_hours'],
      'rawHoursText': rawHoursText,
      'searchKeywords': searchKeywords,
      'information': placeInfo,
      'placeInformationJson': placeInfo != null ? json.encode(placeInfo) : null,
      'phone': phone,
      'website': website,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'priceLevel': priceLevel,
      'features': item['features'],
      'ticketFee': item['ticket_fee'],
    };
  }

  // Fetch full place details directly from MongoDB places_new collection
  Future<Map<String, dynamic>?> fetchPlaceDetails(String placeName, {String? placeId}) async {
    final cleanName = placeName.trim();
    if (cleanName.isEmpty && (placeId == null || placeId.isEmpty)) return null;

    final candidateUrls = {
      if (_workingBackendUrl != null) _workingBackendUrl!,
      AppConfig.backendBaseUrl,
      'http://10.0.2.2:3000',
      'http://localhost:3000',
      'http://127.0.0.1:3000',
    }.toList();

    for (final baseUrl in candidateUrls) {
      // 1. Prioritize direct MongoDB places_new ID lookup (only 24-hex ObjectIds)
      if (placeId != null && placeId.isNotEmpty && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(placeId)) {
        try {
          final idUrl = Uri.parse('$baseUrl/api/v2/places/$placeId');
          final response = await http.get(idUrl).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            _workingBackendUrl = baseUrl;
            final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
            final item = data['data'];
            if (item != null && item is Map) {
              return _extractMongoPlaceDetails(item, baseUrl, cleanName);
            }
          }
        } catch (_) {}
      }

      // 2. Query places_new via /api/places/search or /api/v2/places/search
      if (cleanName.isNotEmpty) {
        final candidateQueries = <String>{
          cleanName,
          cleanName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim(),
        };
        final noParen = cleanName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
        final noStopWords = noParen
            .replaceAll(RegExp(r'\b(buddhist|hall|promenade|centre|center|walkways?)\b', caseSensitive: false), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (noStopWords.isNotEmpty && noStopWords != noParen) {
          candidateQueries.add(noStopWords);
        }
        final words = noParen.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
        if (words.length >= 3) {
          candidateQueries.add('${words[0]} ${words[1]}');
        }

        for (final qStr in candidateQueries) {
          if (qStr.isEmpty) continue;
          final searchUrls = [
            Uri.parse('$baseUrl/api/places/search?q=${Uri.encodeComponent(qStr)}'),
            Uri.parse('$baseUrl/api/v2/places/search?q=${Uri.encodeComponent(qStr)}'),
          ];

          for (final url in searchUrls) {
            try {
              final response = await http.get(url).timeout(const Duration(seconds: 3));
              if (response.statusCode == 200) {
                _workingBackendUrl = baseUrl;
                final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
                final List results = data['data'] ?? [];
                if (results.isNotEmpty) {
                  final cleanLower = cleanName.toLowerCase();
                  final cleanTokens = cleanLower.split(RegExp(r'[^a-zA-Z0-9]+')).where((s) => s.length >= 2).toSet();

                  dynamic bestItem;
                  int bestScore = -1;

                  for (final doc in results) {
                    if (doc is! Map) continue;
                    final docName = (doc['name'] ?? doc['place_name'] ?? '').toString().toLowerCase();
                    int score = 0;
                    if (docName == cleanLower) {
                      score = 1000;
                    } else if (docName.contains(cleanLower) || cleanLower.contains(docName)) {
                      score = 500;
                    } else {
                      final docTokens = docName.split(RegExp(r'[^a-zA-Z0-9]+')).where((s) => s.length >= 2).toSet();
                      final overlap = cleanTokens.intersection(docTokens).length;
                      score = overlap * 100;
                    }
                    if (doc['opening_hours'] != null || doc['raw_hours_text'] != null) {
                      score += 50;
                    }
                    // Weight by review count and popularity so famous canonical spots (e.g. Leong San Tong Khoo Kongsi with 2000+ reviews) beat obscure sub-clans
                    final reviews = int.tryParse(doc['review_count']?.toString() ?? doc['place_information']?['reviews_count']?.toString() ?? '0') ?? 0;
                    final popularity = int.tryParse(doc['popularity_score']?.toString() ?? '0') ?? 0;
                    score += (reviews.clamp(0, 5000) ~/ 10);
                    score += popularity;

                    if (score > bestScore) {
                      bestScore = score;
                      bestItem = doc;
                    }
                  }

                  bestItem ??= results.first;

                  if (bestItem != null && bestItem is Map) {
                    return _extractMongoPlaceDetails(bestItem, baseUrl, cleanName);
                  }
                }
              }
            } catch (_) {}
          }
        }
      }
    }
    return null;
  }

  // 2. Query Mapbox Geocoding & POI Search (Scoped strictly to Penang, Malaysia)
  Future<List<Map<String, String>>> _queryMapboxPlaces(String query) async {
    if (AppConfig.mapboxAccessToken.isEmpty) return [];

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
      '?access_token=${AppConfig.mapboxAccessToken}'
      '&proximity=100.3288,5.4141'
      '&bbox=100.17,5.12,100.55,5.55'
      '&country=MY'
      '&types=poi,address'
      '&limit=8'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List features = data['features'] ?? [];
        final List<Map<String, String>> results = [];

        for (var feature in features) {
          final text = feature['text']?.toString() ?? '';
          final placeName = feature['place_name']?.toString() ?? '';
          if (text.isEmpty && placeName.isEmpty) continue;

          final title = text.isNotEmpty ? text : placeName.split(',')[0].trim();
          final address = placeName;
          final area = _extractAreaFromAddress(address);

          // Infer category from Mapbox properties
          final properties = feature['properties'] ?? {};
          final categoryRaw = properties['category']?.toString() ?? '';
          final category = _mapRawCategory(categoryRaw.isNotEmpty ? categoryRaw : title);

          // GeoJSON coordinates [lng, lat]
          final geometry = feature['geometry'];
          final coords = geometry != null ? geometry['coordinates'] : null;

          final item = {
            'title': title,
            'area': area,
            'address': address,
            'businessHours': '9:00 AM - 10:00 PM',
            'description': 'A recognized venue located in $area, Penang.',
            'imagePath': 'no_image_found',
            'category': category,
            if (coords != null) 'coordinates': json.encode(coords),
          };
          if (!isStrictlyPenang(item, query: query)) continue;
          results.add(item);
        }
        return results;
      }
    } catch (e) {
      debugPrint('Mapbox search error: $e');
    }
    return [];
  }

  // 3. Query OpenStreetMap Nominatim API (Fallback)
  Future<List<Map<String, String>>> _queryOpenStreetMapList(String query) async {
    final searchPrompt = query.toLowerCase().contains('penang') ? query : '$query, Penang, Malaysia';
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(searchPrompt)}'
      '&format=json'
      '&addressdetails=1'
      '&limit=4'
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': AppConfig.appUserAgent},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List items = json.decode(utf8.decode(response.bodyBytes));
        final List<Map<String, String>> results = [];

        for (var place in items) {
          final address = place['address'] ?? {};
          final title = place['display_name']?.toString().split(',')[0] ?? query;
          final area = address['suburb'] ??
              address['neighbourhood'] ??
              address['city'] ??
              address['town'] ??
              'Penang';

          final lat = double.tryParse(place['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(place['lon']?.toString() ?? '0') ?? 0.0;

          final item = {
            'title': title,
            'area': area.toString(),
            'address': place['display_name']?.toString() ?? '',
            'businessHours': '9:00 AM - 6:00 PM',
            'description': 'A landmark in $area, Penang.',
            'imagePath': 'no_image_found',
            'category': 'Attraction',
            'coordinates': json.encode([lon, lat]),
          };
          if (!isStrictlyPenang(item, query: query)) continue;
          results.add(item);
        }
        return results;
      }
    } catch (e) {
      debugPrint('OSM Nominatim error: $e');
    }
    return [];
  }

  // 4. Robust Photo Fetcher for Places (Foursquare -> Wikipedia/Wikimedia -> SerpAPI -> Curated Unsplash)
  Future<String> fetchPhotoForPlace(String placeName, {String? category, String? area}) async {
    final cacheKey = placeName.toLowerCase().trim();
    if (_photoCache.containsKey(cacheKey)) {
      return _photoCache[cacheKey]!;
    }

    // Step 0: Check MongoDB backend place_media thumbnail first
    try {
      final details = await fetchPlaceDetails(placeName);
      if (details != null && details['imagePath'] != null && details['imagePath'].toString().isNotEmpty) {
        final img = details['imagePath'].toString();
        if (img != 'no_image_found') {
          _photoCache[cacheKey] = img;
          return img;
        }
      }
    } catch (_) {}

    // Step A: Try Foursquare API
    if (AppConfig.foursquareApiKey.isNotEmpty) {
      try {
        final fsqUrl = Uri.parse(
          'https://api.foursquare.com/v3/places/search'
          '?query=${Uri.encodeComponent(placeName)}'
          '&near=Penang,Malaysia'
          '&fields=photos,name'
          '&limit=1'
        );
        final fsqResp = await http.get(
          fsqUrl,
          headers: {
            'Authorization': AppConfig.foursquareApiKey,
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 4));

        if (fsqResp.statusCode == 200) {
          final data = json.decode(fsqResp.body);
          final List results = data['results'] ?? [];
          if (results.isNotEmpty) {
            final List photos = results[0]['photos'] ?? [];
            if (photos.isNotEmpty) {
              final p = photos[0];
              final photoUrl = '${p['prefix']}800x600${p['suffix']}';
              _photoCache[cacheKey] = photoUrl;
              return photoUrl;
            }
          }
        }
      } catch (_) {}
    }

    // Step B: Try Wikipedia / Wikimedia Commons API (Great for landmarks, heritage, temples, parks)
    try {
      final wikiTitle = placeName.replaceAll(RegExp(r'\b(Penang|Malaysia|Island)\b', caseSensitive: false), '').trim();
      final wikiUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php'
        '?action=query'
        '&prop=pageimages'
        '&format=json'
        '&pithumbsize=800'
        '&titles=${Uri.encodeComponent(wikiTitle)}'
      );
      final wikiResp = await http.get(wikiUrl).timeout(const Duration(seconds: 3));
      if (wikiResp.statusCode == 200) {
        final data = json.decode(wikiResp.body);
        final Map? pages = data['query']?['pages'];
        if (pages != null && pages.isNotEmpty) {
          final firstPage = pages.values.first;
          final String? source = firstPage?['thumbnail']?['source'];
          if (source != null && source.isNotEmpty) {
            _photoCache[cacheKey] = source;
            return source;
          }
        }
      }
    } catch (_) {}

    // Step B2: Try Serper API (Fast Google Places & Google Images exact photos)
    if (AppConfig.serperApiKey.isNotEmpty && AppConfig.serperApiKey != 'YOUR_SERPER_API_KEY_HERE') {
      try {
        final cleanName = placeName.replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5]'), ' ').trim();
        final serperPlacesUrl = Uri.parse('https://google.serper.dev/places');
        final serperResp = await http.post(
          serperPlacesUrl,
          headers: {
            'X-API-KEY': AppConfig.serperApiKey,
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'q': '$cleanName, Penang',
            'location': 'Penang, Malaysia',
          }),
        ).timeout(const Duration(seconds: 3));

        if (serperResp.statusCode == 200) {
          final data = json.decode(serperResp.body);
          final List places = data['places'] ?? [];
          if (places.isNotEmpty && places[0]['thumbnailUrl'] != null) {
            final thumb = places[0]['thumbnailUrl'].toString();
            if (thumb.startsWith('http')) {
              _photoCache[cacheKey] = thumb;
              return thumb;
            }
          }
        }

        // Fallback to Serper Google Images
        final serperImagesUrl = Uri.parse('https://google.serper.dev/images');
        final imgResp = await http.post(
          serperImagesUrl,
          headers: {
            'X-API-KEY': AppConfig.serperApiKey,
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'q': '$cleanName Penang',
          }),
        ).timeout(const Duration(seconds: 3));

        if (imgResp.statusCode == 200) {
          final data = json.decode(imgResp.body);
          final List images = data['images'] ?? [];
          if (images.isNotEmpty && images[0]['imageUrl'] != null) {
            final img = images[0]['imageUrl'].toString();
            if (img.startsWith('http')) {
              _photoCache[cacheKey] = img;
              return img;
            }
          }
        }
      } catch (_) {}
    }

    // Step C: Try SerpAPI Google Maps thumbnail
    if (AppConfig.serpApiKey.isNotEmpty && AppConfig.serpApiKey != 'YOUR_SERP_API_KEY_HERE') {
      try {
        final serpUrl = Uri.parse(
          'https://serpapi.com/search.json'
          '?engine=google_maps'
          '&q=${Uri.encodeComponent('$placeName, Penang')}'
          '&type=search'
          '&api_key=${AppConfig.serpApiKey}'
        );
        final serpResp = await http.get(serpUrl).timeout(const Duration(seconds: 4));
        if (serpResp.statusCode == 200) {
          final data = json.decode(serpResp.body);
          final List results = data['local_results'] ?? [];
          if (results.isNotEmpty) {
            final thumb = results[0]['thumbnail']?.toString();
            if (thumb != null && thumb.isNotEmpty && thumb.startsWith('http')) {
              _photoCache[cacheKey] = thumb;
              return thumb;
            }
          }
        }
      } catch (_) {}
    }

    // Step D: When no authentic photo is found from DB or APIs, return 'no_image_found'
    // This allows the UI to display "No photo provided" instead of mismatched images.
    _photoCache[cacheKey] = 'no_image_found';
    return 'no_image_found';
  }



  String _mapRawCategory(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('food') || lower.contains('restaurant') || lower.contains('bakery') || lower.contains('cafe')) return 'Food';
    if (lower.contains('temple') || lower.contains('worship') || lower.contains('church') || lower.contains('mosque')) return 'Places of Worship';
    if (lower.contains('park') || lower.contains('nature') || lower.contains('beach') || lower.contains('garden')) return 'Nature & Parks';
    if (lower.contains('historic') || lower.contains('museum') || lower.contains('heritage') || lower.contains('clan')) return 'Heritage';
    return 'Attraction';
  }

  // 5. Strict Penang Location Filter
  /// Ensures results strictly belong to Penang and filters out neighbouring states/localities (e.g. Kedah, Padang Serai)
  bool isStrictlyPenang(Map<String, dynamic> place, {String? query}) {
    final lowerTitle = (place['title'] ?? place['name'] ?? place['place_name'] ?? '').toString().toLowerCase().trim();
    final lowerArea = (place['area'] ?? '').toString().toLowerCase();
    final lowerAddress = (place['address'] ?? place['place_address'] ?? '').toString().toLowerCase();
    final combined = '$lowerTitle $lowerArea $lowerAddress';

    // Neighboring states or outside towns
    const nonPenangKeywords = [
      'kedah', 'perak', 'perlis', 'padang serai', 'kulim', 'sungai petani',
      'alor setar', 'taiping', 'ipoh', 'kuala lumpur', 'selangor', 'parit buntar',
      'bagan serai', 'kampar'
    ];
    for (final kw in nonPenangKeywords) {
      if (combined.contains(kw)) return false;
    }

    final cleanQuery = query?.toLowerCase().trim() ?? '';

    // Filter broad administrative regions/state names unless user explicitly queried that specific term
    const broadRegions = [
      'pulau pinang', 'penang', 'penang island', 'state of penang',
      'perai', 'penaga', 'permatang pauh', 'seberang perai'
    ];
    if (broadRegions.contains(lowerTitle) && cleanQuery != lowerTitle) {
      return false;
    }

    // Verify geographical coordinates bounds (Penang Island & Seberang Perai)
    dynamic coords = place['coordinates'];
    if (coords is String) {
      try {
        coords = json.decode(coords);
      } catch (_) {}
    }

    double? lat;
    double? lng;
    if (coords is List && coords.length >= 2) {
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else if (coords is Map) {
      lat = (coords['latitude'] ?? coords['lat'] as num?)?.toDouble();
      lng = (coords['longitude'] ?? coords['lng'] as num?)?.toDouble();
    }

    if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
      if (lat < 5.11 || lat > 5.58 || lng < 100.16 || lng > 100.56) {
        return false;
      }
    }

    return true;
  }

  // Common Penang aliases, nicknames, and multilingual equivalents
  static final Map<String, List<String>> _penangAliases = {
    'penang hill': ['bukit bendera', 'bendera', 'penang hill funicular', 'penang hill (bukit bendera)', 'flagstaff hill'],
    'kek lok si': ['kek lok si temple', 'kek lok', 'air itam temple', 'ji le si', '极乐寺'],
    'cheong fatt tze': ['the blue mansion', 'blue mansion', 'zhang bi shi', 'cheong fatt tze - the blue mansion'],
    'pinang peranakan mansion': ['peranakan mansion', 'baba nyonya museum', 'green mansion', 'nyonya mansion'],
    'entopia': ['entopia by penang butterfly farm', 'penang butterfly farm', 'butterfly farm', 'butterfly park'],
    'penang national park': ['taman negara pulau pinang', 'taman negara', 'national park'],
    'penang botanic gardens': ['waterfall gardens', 'botanic garden', 'botanical gardens', 'taman botani'],
    'youth park': ['taman perbandaran', 'municipal park', 'youth park penang'],
    'gurney bay park': ['gurney bay', 'gurney wharf', 'gurney park'],
    'escape penang': ['escape', 'escape theme park', 'escape adventure park', 'escape park'],
    'clan jetties': ['clan jetties of penang', 'chew jetty', 'tan jetty', 'lim jetty', 'lee jetty', 'yeoh jetty'],
    'fort cornwallis': ['kota cornwallis', 'cornwallis'],
    'the top': ['the top penang', 'komtar the top', 'komtar top', 'rainbow skywalk', 'komtar'],
    'wonderfood museum': ['wonderfood', 'food museum penang', 'food museum'],
    'batu ferringhi': ['ferringhi beach', 'batu feringghi', 'batu ferringhi beach'],
    'bukit mertajam recreational forest': ['cherok tokun', 'cherok to’kun', 'tokun', 'bm hill'],
  };

  // Known accurate coordinates for Penang landmarks
  static final Map<String, List<double>> _knownPenangCoordinates = {
    'penang hill': [100.2770, 5.4085],
    'bukit bendera': [100.2770, 5.4085],
    'penang national park': [100.1983, 5.4593],
    'penang botanic gardens': [100.2905, 5.4385],
    'youth park': [100.3006, 5.4287],
    'taman perbandaran': [100.3006, 5.4287],
    'teluk bahang forest park': [100.2167, 5.4500],
    'gurney bay park': [100.3150, 5.4380],
    'escape penang': [100.2152, 5.4492],
    'escape': [100.2152, 5.4492],
    'entopia': [100.2173, 5.4475],
    'the habitat': [100.2675, 5.4150],
    'kek lok si': [100.2736, 5.3995],
    'cheong fatt tze': [100.3347, 5.4216],
    'pinang peranakan mansion': [100.3411, 5.4180],
    'fort cornwallis': [100.3439, 5.4204],
    'leong san tong khoo kongsi': [100.3371, 5.4149],
    'clan jetties': [100.3400, 5.4132],
    'gurney drive': [100.3090, 5.4398],
    'chulia street': [100.3380, 5.4182],
    'air itam': [100.2776, 5.4011],
    'the top': [100.3300, 5.4143],
    'komtar': [100.3300, 5.4143],
    'wonderfood museum': [100.3412, 5.4164],
    'city park': [100.3006, 5.4287],
    'bukit mertajam recreational forest': [100.4900, 5.3600],
    'cherok tokun': [100.4900, 5.3600],
    'batu ferringhi': [100.2450, 5.4740],
  };

  static List<double>? getCoordinatesForPlace(String title, [String? area]) {
    final lower = title.toLowerCase();
    for (final entry in _knownPenangCoordinates.entries) {
      if (lower.contains(entry.key) || entry.key.contains(lower)) {
        return entry.value;
      }
    }
    if (area != null && area.isNotEmpty) {
      final lowerArea = area.toLowerCase();
      for (final entry in _knownPenangCoordinates.entries) {
        if (lowerArea.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    return null;
  }

  // 6. Multi-Token Metadata & Alias Fuzzy Match Scoring Algorithm
  int calculateFuzzyMatchScore(String query, Map<String, dynamic> place) {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return 0;

    final qTokens = cleanQuery
        .split(RegExp(r'[\s,\-_]+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (qTokens.isEmpty) return 0;

    final title = (place['title'] ?? place['place_name'] ?? '').toLowerCase();
    final area = (place['area'] ?? '').toLowerCase();
    final address = (place['address'] ?? place['place_address'] ?? '').toLowerCase();
    final category = (place['category'] ?? place['place_category'] ?? '').toLowerCase();
    final description = (place['description'] ?? place['place_summary'] ?? '').toLowerCase();
    final combinedMetadata = '$title $area $address $category $description';

    int score = 0;
    int matchedTokens = 0;

    // A. Direct exact title or substring match
    if (title == cleanQuery) score += 600;
    if (title.contains(cleanQuery)) score += 350;

    // B. Alias Matching (e.g. "bukit bendera" -> Penang Hill, "blue mansion" -> Cheong Fatt Tze)
    for (final entry in _penangAliases.entries) {
      final canonical = entry.key;
      final aliases = entry.value;

      final bool queryMatchesEntry = cleanQuery == canonical ||
          cleanQuery.contains(canonical) ||
          aliases.any((a) => cleanQuery == a || cleanQuery.contains(a));

      if (queryMatchesEntry) {
        final bool placeMatchesEntry = title.contains(canonical) ||
            aliases.any((a) => title.contains(a));
        if (placeMatchesEntry) {
          score += 500;
        }
      }
    }

    // C. Generic category & intent keywords (e.g. "park", "garden", "beach", "temple", "museum", "food", "cafe", "forest", "hill")
    const genericTypes = ['park', 'garden', 'beach', 'temple', 'museum', 'food', 'cafe', 'forest', 'hill'];
    for (final gType in genericTypes) {
      if (cleanQuery.contains(gType)) {
        if (title.contains(gType)) {
          score += 250;
        }
        if (category.contains(gType) ||
            (gType == 'park' && (category.contains('nature') || category.contains('outdoors'))) ||
            (gType == 'garden' && (category.contains('nature') || category.contains('outdoors'))) ||
            (gType == 'beach' && (category.contains('nature') || category.contains('outdoors')))) {
          score += 180;
        }
        if (description.contains(gType)) {
          score += 100;
        }
      }
    }

    // D. Token-by-token matching across metadata
    for (final token in qTokens) {
      bool tokenMatched = false;

      if (title.contains(token)) {
        score += 120;
        tokenMatched = true;
      } else if (area.contains(token) || address.contains(token)) {
        score += 80;
        tokenMatched = true;
      } else if (category.contains(token)) {
        score += 60;
        tokenMatched = true;
      } else if (description.contains(token)) {
        score += 35;
        tokenMatched = true;
      } else if (_fuzzyTokenCheck(token, combinedMetadata)) {
        score += 30;
        tokenMatched = true;
      }

      if (tokenMatched) {
        matchedTokens++;
      }
    }

    // Multiplier if all tokens in the user's query matched
    if (matchedTokens == qTokens.length) {
      score += 250;
    } else if (matchedTokens > 0) {
      score += (matchedTokens * 40);
    }

    return score;
  }

  bool _fuzzyTokenCheck(String token, String target) {
    if (token.length < 3) return false;
    // Common aliases in Penang
    if ((token == 'air' && target.contains('ayer')) || (token == 'ayer' && target.contains('air'))) return true;
    if ((token == 'george' || token == 'georgetown') && target.contains('george town')) return true;
    if (token == 'jetty' && target.contains('jetties')) return true;
    if (token == 'penang' && target.contains('pinang')) return true;

    // Substring or prefix check
    for (final word in target.split(RegExp(r'\s+'))) {
      if (word.startsWith(token) || token.startsWith(word)) return true;
    }
    return false;
  }

  // 7. Primary Unified Search: Local Destinations + MongoDB Backend -> Mapbox POIs -> OSM Fallback
  /// Can sort returns from nearest to furthest based on user plan area or existing plan stops
  Future<List<Map<String, String>>> searchMultiplePlaces(
    String query, {
    bool hasAircon = false,
    double? planLat,
    double? planLng,
    String? planArea,
    List<dynamic>? planPlaces,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    // Determine user plan reference location and existing stop coordinates
    final List<List<double>> planStopCoords = [];
    if (planPlaces != null && planPlaces.isNotEmpty) {
      for (final p in planPlaces) {
        double? pLat;
        double? pLng;
        if (p is Map) {
          pLat = (p['lat'] as num?)?.toDouble() ?? (p['latitude'] as num?)?.toDouble();
          pLng = (p['lng'] as num?)?.toDouble() ?? (p['longitude'] as num?)?.toDouble();
        } else {
          try {
            pLat = (p.lat as num).toDouble();
            pLng = (p.lng as num).toDouble();
          } catch (_) {}
        }
        if (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0) {
          planStopCoords.add([pLng, pLat]);
        }
      }
    }

    double? refPlanLat = planLat;
    double? refPlanLng = planLng;

    if ((refPlanLat == null || refPlanLng == null) && planStopCoords.isNotEmpty) {
      double sumLat = 0;
      double sumLng = 0;
      for (final c in planStopCoords) {
        sumLng += c[0];
        sumLat += c[1];
      }
      refPlanLat = sumLat / planStopCoords.length;
      refPlanLng = sumLng / planStopCoords.length;
    } else if ((refPlanLat == null || refPlanLng == null) && planArea != null && planArea.trim().isNotEmpty) {
      final areaCoords = getCoordinatesForPlace(planArea);
      if (areaCoords != null) {
        refPlanLng = areaCoords[0];
        refPlanLat = areaCoords[1];
      }
    }

    final bool hasPlanLocation = (refPlanLat != null && refPlanLng != null) || planStopCoords.isNotEmpty;

    final Map<String, Map<String, String>> combinedCandidates = {};

    // 1. Immediately evaluate local curated Penang destinations dataset
    for (var d in allDestinations) {
      final coords = getCoordinatesForPlace(d.title, d.area);
      final itemMap = {
        'title': d.title,
        'area': d.area,
        'businessHours': d.businessHours,
        'description': d.description,
        'imagePath': d.imagePath,
        'category': d.category,
        if (coords != null) 'coordinates': json.encode(coords),
      };
      if (!isStrictlyPenang(itemMap, query: cleanQuery)) continue;

      final score = calculateFuzzyMatchScore(cleanQuery, itemMap);
      if (score >= 45) {
        final key = d.title.toLowerCase().trim();
        combinedCandidates[key] = itemMap;
      }
    }

    // 2. Query Backend MongoDB (Parallel with Mapbox)
    final Future<List<Map<String, String>>?> backendFuture = _queryBackendPlaces(cleanQuery, hasAircon: hasAircon);
    final Future<List<Map<String, String>>> mapboxFuture = (combinedCandidates.length < 4)
        ? _queryMapboxPlaces(cleanQuery)
        : Future.value(<Map<String, String>>[]);

    final backendResults = await backendFuture;
    if (backendResults != null && backendResults.isNotEmpty) {
      for (var item in backendResults) {
        if (!isStrictlyPenang(item, query: cleanQuery)) continue;
        if (hasAircon && item['features'] != null) {
          try {
            final feats = json.decode(item['features']!);
            if (feats is Map && feats['has_aircon'] == false) continue;
          } catch (_) {}
        }
        if (item['coordinates'] == null) {
          final knownCoords = getCoordinatesForPlace(item['title'] ?? '', item['area']);
          if (knownCoords != null) {
            item['coordinates'] = json.encode(knownCoords);
          }
        }
        final key = (item['title'] ?? '').toLowerCase().trim();
        if (key.isNotEmpty && !combinedCandidates.containsKey(key)) {
          combinedCandidates[key] = item;
        }
      }
    }

    // 3. Include Mapbox Geocoding & POIs only if high-quality candidates count is still low
    if (combinedCandidates.length < 4) {
      final mapboxResults = await mapboxFuture;
      for (var item in mapboxResults) {
        if (!isStrictlyPenang(item, query: cleanQuery)) continue;
        final key = (item['title'] ?? '').toLowerCase().trim();
        if (key.isNotEmpty && !combinedCandidates.containsKey(key)) {
          combinedCandidates[key] = item;
        }
      }
    }

    // 4. Fallback: If nothing was found yet, query OpenStreetMap Nominatim
    if (combinedCandidates.isEmpty) {
      final osmResults = await _queryOpenStreetMapList(cleanQuery);
      for (var item in osmResults) {
        if (!isStrictlyPenang(item, query: cleanQuery)) continue;
        final key = (item['title'] ?? '').toLowerCase().trim();
        if (key.isNotEmpty && !combinedCandidates.containsKey(key)) {
          combinedCandidates[key] = item;
        }
      }
    }

    // 5. Final fallback to AI generation if completely empty
    if (combinedCandidates.isEmpty) {
      try {
        final aiResult = await _ollamaService.queryDestination(cleanQuery);
        final title = aiResult['title'] ?? cleanQuery;
        final photo = await fetchPhotoForPlace(title, category: 'Attraction', area: aiResult['area']);
        final coords = getCoordinatesForPlace(title, aiResult['area']) ?? [100.3288, 5.4141];
        return [{
          'title': title,
          'area': aiResult['area'] ?? 'Penang',
          'businessHours': aiResult['businessHours'] ?? 'Check online',
          'description': aiResult['description'] ?? 'A popular place in Penang.',
          'imagePath': photo,
          'category': 'Attraction',
          'coordinates': json.encode(coords),
        }];
      } catch (_) {
        return [];
      }
    }

    // Convert candidates to list
    List<Map<String, String>> candidateList = combinedCandidates.values.toList();

    // 6. Proactive Photo Fetching and Distance Calculation relative to User's Plan Area
    for (int i = 0; i < candidateList.length; i++) {
      var item = candidateList[i];
      final currentImage = item['imagePath'] ?? '';
      if (currentImage.isEmpty || currentImage == 'no_image_found') {
        final resolvedPhoto = await fetchPhotoForPlace(
          item['title'] ?? cleanQuery,
          category: item['category'],
          area: item['area'],
        );
        candidateList[i]['imagePath'] = resolvedPhoto;
      }

      // Ensure coordinates are populated
      double? placeLat;
      double? placeLng;
      if (item['coordinates'] != null) {
        try {
          final c = json.decode(item['coordinates']!);
          if (c is List && c.length >= 2) {
            placeLng = (c[0] as num).toDouble();
            placeLat = (c[1] as num).toDouble();
          }
        } catch (_) {}
      }
      if (placeLat == null || placeLng == null) {
        final known = getCoordinatesForPlace(item['title'] ?? '', item['area']);
        if (known != null) {
          placeLng = known[0];
          placeLat = known[1];
          candidateList[i]['coordinates'] = json.encode(known);
        }
      }

      // Calculate distance from user's current plan area (minimum distance to any plan stop or centroid)
      if (hasPlanLocation && placeLat != null && placeLng != null) {
        double minDistance = 9999.0;
        if (planStopCoords.isNotEmpty) {
          for (final stopCoord in planStopCoords) {
            final dist = calculateDistanceKm(placeLat, placeLng, stopCoord[1], stopCoord[0]);
            if (dist < minDistance) {
              minDistance = dist;
            }
          }
        } else if (refPlanLat != null && refPlanLng != null) {
          minDistance = calculateDistanceKm(placeLat, placeLng, refPlanLat, refPlanLng);
        }
        candidateList[i]['distanceKm'] = minDistance.toStringAsFixed(1);
        candidateList[i]['distanceText'] = '${minDistance.toStringAsFixed(1)} km';
      }
    }

    // 7. Sort candidate list:
    // If a plan area/location is specified, sort results from NEAREST to MOST FAR!
    // Exact full query / direct alias matches (score >= 600) are reserved at the top.
    candidateList.sort((a, b) {
      final scoreA = calculateFuzzyMatchScore(cleanQuery, a);
      final scoreB = calculateFuzzyMatchScore(cleanQuery, b);

      // Priority A: Exact full title or direct alias match (e.g. "bukit bendera" -> Penang Hill)
      final bool exactA = scoreA >= 600;
      final bool exactB = scoreB >= 600;
      if (exactA != exactB) {
        return exactB ? 1 : -1;
      }

      // Priority B: Proximity to user plan area (from nearest to furthest)
      if (hasPlanLocation) {
        final distA = double.tryParse(a['distanceKm'] ?? '') ?? 999.0;
        final distB = double.tryParse(b['distanceKm'] ?? '') ?? 999.0;
        final diff = distA.compareTo(distB);
        if (diff != 0) {
          return diff; // Nearest first!
        }
      }

      // Priority C: Multi-token relevancy score and review count
      if (scoreB != scoreA) {
        return scoreB.compareTo(scoreA);
      }
      final revB = int.tryParse(b['reviewCount'] ?? b['review_count'] ?? '0') ?? 0;
      final revA = int.tryParse(a['reviewCount'] ?? a['review_count'] ?? '0') ?? 0;
      return revB.compareTo(revA);
    });

    return candidateList;
  }

  /// Public helper: Resolves the canonical Penang area name based on address
  String resolveAreaFromAddress(String address, [String? fallbackArea]) {
    return _extractAreaFromAddress(address, fallbackArea);
  }

  // Extract a readable area name from an address string based on postcode and district keywords
  String _extractAreaFromAddress(String address, [String? fallbackArea]) {
    final lower = address.toLowerCase();

    // 1. Check known Penang district / town names in address
    if (lower.contains('tanjung bungah') || lower.contains('tanjong bungah')) {
      return 'Tanjung Bungah';
    }
    if (lower.contains('batu ferringhi') || lower.contains('batu feringghi') || lower.contains('ferringhi')) {
      return 'Batu Ferringhi';
    }
    if (lower.contains('teluk bahang') || lower.contains('telok bahang')) {
      return 'Teluk Bahang';
    }
    if (lower.contains('tanjung tokong') || lower.contains('tanjong tokong')) {
      return 'Tanjung Tokong';
    }
    if (lower.contains('pulau tikus')) {
      return 'Pulau Tikus';
    }
    if (lower.contains('air itam') || lower.contains('ayer itam')) {
      return 'Air Itam';
    }
    if (lower.contains('balik pulau')) {
      return 'Balik Pulau';
    }
    if (lower.contains('bayan lepas')) {
      return 'Bayan Lepas';
    }
    if (lower.contains('bayan baru')) {
      return 'Bayan Baru';
    }
    if (lower.contains('gelugor')) {
      return 'Gelugor';
    }
    if (lower.contains('jelutong')) {
      return 'Jelutong';
    }
    if (lower.contains('george town') || lower.contains('georgetown')) {
      return 'George Town';
    }
    if (lower.contains('butterworth')) {
      return 'Butterworth';
    }
    if (lower.contains('bukit mertajam')) {
      return 'Bukit Mertajam';
    }
    if (lower.contains('simpang ampat')) {
      return 'Simpang Ampat';
    }
    if (lower.contains('seberang jaya')) {
      return 'Seberang Jaya';
    }
    if (lower.contains('nibong tebal')) {
      return 'Nibong Tebal';
    }

    // 2. Check 5-digit Penang Postcode in address
    final postcodeMatch = RegExp(r'\b(1\d{4})\b').firstMatch(address);
    if (postcodeMatch != null) {
      final code = int.tryParse(postcodeMatch.group(1)!);
      if (code != null) {
        if (code == 11200) return 'Tanjung Bungah';
        if (code == 11100) return 'Batu Ferringhi';
        if (code == 11050) return 'Teluk Bahang';
        if (code == 10470) return 'Tanjung Tokong';
        if (code == 10250 || code == 10350) return 'Pulau Tikus';
        if (code >= 10000 && code <= 10200) return 'George Town';
        if (code == 10400 || code == 10450) return 'George Town';
        if (code == 11300 || code == 11400 || code == 11500) return 'Air Itam';
        if (code == 11600) return 'Jelutong';
        if (code == 11700) return 'Gelugor';
        if (code == 11900 || code == 11920) return 'Bayan Lepas';
        if (code == 11950) return 'Bayan Baru';
        if (code == 11000 || code == 11010 || code == 11020) return 'Balik Pulau';
        if (code >= 12000 && code <= 13800) return 'Butterworth';
        if (code >= 14000 && code <= 14400) return 'Bukit Mertajam';
      }
    }

    // 3. Fallback to existing fallbackArea if valid
    if (fallbackArea != null &&
        fallbackArea.trim().isNotEmpty &&
        fallbackArea.trim() != 'Other' &&
        fallbackArea.trim() != 'Penang') {
      return fallbackArea.trim();
    }

    if (address.isEmpty) return 'Penang';

    final cleanAddress = address
        .replaceAll(RegExp(r'\bpulau pinang\b', caseSensitive: false), 'Penang')
        .replaceAll(RegExp(r'\bmalaysia\b', caseSensitive: false), '')
        .trim();

    final parts = cleanAddress.split(',');

    for (int i = parts.length - 1; i >= 0; i--) {
      String part = parts[i].trim();
      final lowerPart = part.toLowerCase();

      if (lowerPart == 'penang' || lowerPart.isEmpty) {
        continue;
      }

      var cleanedPart = part
          .replaceAll(RegExp(r'\b\d{5}\b'), '')
          .replaceAll(RegExp(r'邮政编码|postcode|postal\s*code', caseSensitive: false), '')
          .trim();

      if (cleanedPart.startsWith(':') || cleanedPart.endsWith(':')) {
        cleanedPart = cleanedPart.replaceAll(':', '').trim();
      }

      final lowerCleaned = cleanedPart.toLowerCase();
      if (lowerCleaned.startsWith('jln') ||
          lowerCleaned.startsWith('jalan') ||
          lowerCleaned.startsWith('lebuh') ||
          lowerCleaned.startsWith('lorong') ||
          lowerCleaned.startsWith('road') ||
          lowerCleaned.startsWith('street') ||
          lowerCleaned.startsWith('solok') ||
          RegExp(r'^\d+').hasMatch(lowerCleaned)) {
        if (i > 0) continue;
      }

      if (cleanedPart.isNotEmpty) {
        return cleanedPart;
      }
    }
    return parts[0].trim();
  }

  // Fetch stay/transport service records from MongoDB
  Future<List<Map<String, dynamic>>> fetchServiceData(String route) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/api/$route');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List results = data['data'] ?? [];
        return List<Map<String, dynamic>>.from(results);
      }
    } catch (e) {
      debugPrint('Error fetching service data for $route: $e');
    }
    return [];
  }
}

/// Represents structured operating hours of a place on a given day
class PlaceOperatingHours {
  final bool isClosed;
  final bool isOpen24Hours;
  final int? openMinutes;
  final int? closeMinutes;
  final String formattedHours;
  final String? statusReason;

  const PlaceOperatingHours({
    required this.isClosed,
    required this.isOpen24Hours,
    this.openMinutes,
    this.closeMinutes,
    required this.formattedHours,
    this.statusReason,
  });

  /// Checks if the venue is open during the scheduled visit window [startMins, endMins]
  bool isOpenDuring(int startMins, int endMins) {
    if (isClosed) return false;
    if (isOpen24Hours) return true;
    if (openMinutes == null || closeMinutes == null) return true;

    final effectiveClose = closeMinutes! < openMinutes! ? closeMinutes! + (24 * 60) : closeMinutes!;

    // Visit starts at or after closing time
    if (startMins >= effectiveClose) return false;
    // Visit starts before opening time
    if (startMins < openMinutes!) return false;
    // Visit stays past closing time by more than 10 mins
    if (endMins > effectiveClose + 10) return false;

    return true;
  }

  /// Returns clear reason why a visit time conflicts with operating hours
  String getConflictDescription(int startMins, int endMins) {
    if (isClosed) return 'Venue is closed all day on this date';
    if (openMinutes != null && closeMinutes != null) {
      final effectiveClose = closeMinutes! < openMinutes! ? closeMinutes! + (24 * 60) : closeMinutes!;
      if (startMins >= effectiveClose) {
        return 'Arrives after closing time (Closes at ${PlacesService.formatClockMinutes(closeMinutes!)})';
      }
      if (startMins < openMinutes!) {
        return 'Arrives before opening time (Opens at ${PlacesService.formatClockMinutes(openMinutes!)})';
      }
      if (endMins > effectiveClose) {
        return 'Visit extends past closing time (${PlacesService.formatClockMinutes(closeMinutes!)})';
      }
    }
    return 'Outside operating hours';
  }
}

