import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'ollama_service.dart';
import '../screens/category_screen.dart';

class PlacesService {
  final OllamaService _ollamaService = OllamaService();

  // In-memory photo cache to avoid redundant API requests
  static final Map<String, String> _photoCache = {};

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
        return minStr == '00' ? '$hour12 $ampm' : '$hour12:$minStr $ampm';
      }
    }
    return trimmed;
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
      ?_workingBackendUrl,
      AppConfig.backendBaseUrl,
      'http://192.168.1.15:3000',
      'http://10.3.225.167:3000',
      'http://10.3.241.207:3000',
      'http://10.0.2.2:3000', // Android Emulator Host Loopback
      'http://localhost:3000', // Local Desktop/Web
    }.toList();

    for (final baseUrl in candidateUrls) {
      final airconParam = hasAircon ? '&has_aircon=true' : '';
      final url = Uri.parse('$baseUrl/api/places/search?q=${Uri.encodeComponent(query)}$airconParam');
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 3));
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

            final rawHours = item['opening_hours'] ?? item['place_business_hours'];
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
              'description': description,
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

    final rawHours = item['opening_hours'] ?? item['place_business_hours'];
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
      if (rawSummary.isNotEmpty) 'summary': rawSummary,
      'businessHours': businessHours,
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
      ?_workingBackendUrl,
      AppConfig.backendBaseUrl,
      'http://192.168.1.15:3000',
      'http://10.3.225.167:3000',
      'http://10.3.241.207:3000',
      'http://10.0.2.2:3000',
      'http://localhost:3000',
    }.toList();

    for (final baseUrl in candidateUrls) {
      // 1. Prioritize direct MongoDB places_new ID lookup
      if (placeId != null && placeId.isNotEmpty && placeId.length >= 12) {
        try {
          final idUrl = Uri.parse('$baseUrl/api/v2/places/$placeId');
          final response = await http.get(idUrl).timeout(const Duration(seconds: 3));
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
        final searchUrls = [
          Uri.parse('$baseUrl/api/places/search?q=${Uri.encodeComponent(cleanName)}'),
          Uri.parse('$baseUrl/api/v2/places/search?q=${Uri.encodeComponent(cleanName)}'),
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
                dynamic bestItem;
                try {
                  bestItem = results.firstWhere(
                    (doc) {
                      final n = (doc['name'] ?? doc['place_name'] ?? '').toString().toLowerCase();
                      return n == cleanLower;
                    },
                  );
                } catch (_) {
                  try {
                    bestItem = results.firstWhere(
                      (doc) {
                        final n = (doc['name'] ?? doc['place_name'] ?? '').toString().toLowerCase();
                        return n.contains(cleanLower) || cleanLower.contains(n);
                      },
                    );
                  } catch (_) {
                    bestItem = results.first;
                  }
                }

                if (bestItem != null && bestItem is Map) {
                  return _extractMongoPlaceDetails(bestItem, baseUrl, cleanName);
                }
              }
            }
          } catch (_) {}
        }
      }
    }
    return null;
  }

  // 2. Query Mapbox Geocoding & POI Search (Scoped to Penang, Malaysia)
  Future<List<Map<String, String>>> _queryMapboxPlaces(String query) async {
    if (AppConfig.mapboxAccessToken.isEmpty) return [];

    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
      '?access_token=${AppConfig.mapboxAccessToken}'
      '&proximity=100.25,5.41'
      '&bbox=100.0,5.1,100.6,5.6'
      '&country=MY'
      '&types=poi,address,neighborhood,locality,place'
      '&limit=6'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
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

          results.add({
            'title': title,
            'area': area,
            'address': address,
            'businessHours': '9:00 AM - 10:00 PM',
            'description': 'A recognized venue located in $area, Penang.',
            'imagePath': 'no_image_found',
            'category': category,
            if (coords != null) 'coordinates': json.encode(coords),
          });
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

          results.add({
            'title': title,
            'area': area.toString(),
            'address': place['display_name']?.toString() ?? '',
            'businessHours': '9:00 AM - 6:00 PM',
            'description': 'A landmark in $area, Penang.',
            'imagePath': 'no_image_found',
            'category': 'Attraction',
            'coordinates': json.encode([lon, lat]),
          });
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

  // 5. Multi-Token Metadata Fuzzy Match Scoring Algorithm
  // Satisfies queries like "Air Itam Temple" -> matches "Kek Lok Si Temple" in "Air Itam"
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

    // Exact full query match gets top priority
    if (title == cleanQuery) score += 500;
    if (title.contains(cleanQuery)) score += 300;

    for (final token in qTokens) {
      bool tokenMatched = false;

      if (title.contains(token)) {
        score += 120;
        tokenMatched = true;
      } else if (area.contains(token) || address.contains(token)) {
        score += 80;
        tokenMatched = true;
      } else if (category.contains(token)) {
        score += 50;
        tokenMatched = true;
      } else if (description.contains(token)) {
        score += 30;
        tokenMatched = true;
      } else if (_fuzzyTokenCheck(token, combinedMetadata)) {
        score += 25;
        tokenMatched = true;
      }

      if (tokenMatched) {
        matchedTokens++;
      }
    }

    // Huge multiplier if ALL tokens in the user's query are satisfied across the metadata
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

  // 6. Primary Unified Search: MongoDB + Mapbox -> OSM Fallback + AI Enrichment + Photo Pipeline
  Future<List<Map<String, String>>> searchMultiplePlaces(String query, {bool hasAircon = false}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final Map<String, Map<String, String>> combinedCandidates = {};

    // 1. Query Backend MongoDB (Parallel with Mapbox)
    final Future<List<Map<String, String>>?> backendFuture = _queryBackendPlaces(cleanQuery, hasAircon: hasAircon);
    final Future<List<Map<String, String>>> mapboxFuture = _queryMapboxPlaces(cleanQuery);

    final backendResults = await backendFuture;
    if (backendResults != null && backendResults.isNotEmpty) {
      for (var item in backendResults) {
        if (hasAircon && item['features'] != null) {
          try {
            final feats = json.decode(item['features']!);
            if (feats is Map && feats['has_aircon'] == false) continue;
          } catch (_) {}
        }
        final key = (item['title'] ?? '').toLowerCase().trim();
        if (key.isNotEmpty && !combinedCandidates.containsKey(key)) {
          combinedCandidates[key] = item;
        }
      }
    }

    // 2. Query Mapbox Geocoding & POIs
    final mapboxResults = await mapboxFuture;
    for (var item in mapboxResults) {
      final key = (item['title'] ?? '').toLowerCase().trim();
      if (key.isNotEmpty && !combinedCandidates.containsKey(key)) {
        combinedCandidates[key] = item;
      }
    }

    // 3. Search local destination dataset with fuzzy matching
    for (var d in allDestinations) {
      final itemMap = {
        'title': d.title,
        'area': d.area,
        'businessHours': d.businessHours,
        'description': d.description,
        'imagePath': d.imagePath,
        'category': d.category,
      };
      final score = calculateFuzzyMatchScore(cleanQuery, itemMap);
      if (score > 60) {
        final key = d.title.toLowerCase().trim();
        if (!combinedCandidates.containsKey(key)) {
          combinedCandidates[key] = itemMap;
        }
      }
    }

    // 4. Fallback: If nothing was found yet, query OpenStreetMap Nominatim
    if (combinedCandidates.isEmpty) {
      final osmResults = await _queryOpenStreetMapList(cleanQuery);
      for (var item in osmResults) {
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
        return [{
          'title': title,
          'area': aiResult['area'] ?? 'Penang',
          'businessHours': aiResult['businessHours'] ?? 'Check online',
          'description': aiResult['description'] ?? 'A popular place in Penang.',
          'imagePath': photo,
          'category': 'Attraction',
        }];
      } catch (_) {
        return [];
      }
    }

    // Convert candidates to list
    List<Map<String, String>> candidateList = combinedCandidates.values.toList();

    // 6. Proactive Photo Fetching for items with missing or placeholder images
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
    }

    // 7. Sort candidate list by multi-token fuzzy relevancy score
    candidateList.sort((a, b) {
      final scoreB = calculateFuzzyMatchScore(cleanQuery, b);
      final scoreA = calculateFuzzyMatchScore(cleanQuery, a);
      return scoreB.compareTo(scoreA);
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
