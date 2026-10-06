import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import '../screens/detail_screen.dart';
import '../services/places_service.dart';
import '../theme.dart';
import '../widgets/app_image_widget.dart';

class NearbyItem {
  final String title;
  final String category; // 'Cafe & Kopitiam', 'Casual Dining & Food', 'Shaded Rest & Breeze', 'Indoor Air-Con Rest'
  final String area;
  final String businessHours;
  final String description;
  final String imagePath;
  final double lat;
  final double lng;
  final List<String> tags;

  const NearbyItem({
    required this.title,
    required this.category,
    required this.area,
    required this.businessHours,
    required this.description,
    required this.imagePath,
    required this.lat,
    required this.lng,
    required this.tags,
  });
}

class NearbySuggestionsScreen extends StatefulWidget {
  final String previousPlaceName;
  final String previousPlaceArea;
  final double? lat;
  final double? lng;
  final String? timeSlot;

  const NearbySuggestionsScreen({
    super.key,
    required this.previousPlaceName,
    required this.previousPlaceArea,
    this.lat,
    this.lng,
    this.timeSlot,
  });

  factory NearbySuggestionsScreen.fromItineraryPlace({
    required ItineraryPlace? place,
    String? timeSlot,
  }) {
    return NearbySuggestionsScreen(
      previousPlaceName: place?.name ?? 'Previous Stop',
      previousPlaceArea: place?.specificArea ?? place?.area ?? 'Penang',
      lat: (place?.lat != null && place!.lat != 0.0) ? place.lat : null,
      lng: (place?.lng != null && place!.lng != 0.0) ? place.lng : null,
      timeSlot: timeSlot,
    );
  }

  @override
  State<NearbySuggestionsScreen> createState() => _NearbySuggestionsScreenState();
}

class _NearbySuggestionsScreenState extends State<NearbySuggestionsScreen> {
  // Maximum radius in kilometers for Free Time Bridge leisure suggestions
  static const double _maxRadiusKm = 3.0;

  List<NearbyItem> _liveMongoSpots = [];

  @override
  void initState() {
    super.initState();
    _fetchLiveMongoPlaces();
  }

  // Fetch real-time places from MongoDB places_new collection
  Future<void> _fetchLiveMongoPlaces() async {
    final area = widget.previousPlaceArea.trim();
    if (area.isEmpty) return;

    try {
      final results = await PlacesService().searchMultiplePlaces(area);
      if (results.isNotEmpty && mounted) {
        final List<NearbyItem> parsed = [];
        for (final r in results) {
          final cat = (r['primary_category'] ?? r['category'] ?? 'Dining').toString();
          final catLower = cat.toLowerCase();
          // Strictly exclude Heritage & Sightseeing/museum/temple attractions
          if (catLower.contains('heritage') ||
              catLower.contains('sight') ||
              catLower.contains('museum') ||
              catLower.contains('worship') ||
              catLower.contains('monument') ||
              catLower.contains('temple')) {
            continue;
          }

          // Parse coordinates from MongoDB: [lng, lat]
          double lat = 0.0;
          double lng = 0.0;
          if (r['coordinates'] != null) {
            try {
              final c = json.decode(r['coordinates']!);
              if (c is List && c.length >= 2) {
                lng = (c[0] as num).toDouble();
                lat = (c[1] as num).toDouble();
              }
            } catch (_) {}
          }

          // Parse tags from MongoDB features
          List<String> tags = [];
          if (r['features'] != null) {
            try {
              final f = json.decode(r['features']!);
              if (f is Map) {
                if (f['has_aircon'] == true) tags.add('Air-Conditioned');
                if (f['has_parking'] == true) tags.add('Parking Available');
                if (f['is_wheelchair_accessible'] == true) tags.add('Wheelchair Accessible');
                if (f['is_halal'] == true) tags.add('Halal Friendly');
                if (f['free_entry'] == true) tags.add('Free Entry');
              }
            } catch (_) {}
          }
          if (tags.isEmpty) {
            tags.add('Local Spot');
            tags.add(area);
          }

          parsed.add(NearbyItem(
            title: r['title'] ?? 'Penang Spot',
            category: catLower.contains('cafe') || catLower.contains('coffee')
                ? 'Cafe & Kopitiam'
                : (catLower.contains('food') || catLower.contains('dining') || catLower.contains('restaurant')
                    ? 'Casual Dining & Food'
                    : 'Shaded Rest & Breeze'),
            area: r['area'] ?? area,
            businessHours: PlacesService.formatConciseSummary(r['businessHours'] ?? r['openingHours']),
            description: r['description'] ?? 'Located in $area, Penang.',
            imagePath: r['imagePath'] ?? '',
            lat: lat,
            lng: lng,
            tags: tags,
          ));
        }

        if (parsed.isNotEmpty && mounted) {
          setState(() {
            _liveMongoSpots = parsed;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching nearby spots from MongoDB places_new: $e');
    }
  }

  // Curated spots strictly focused on:
  // 1. Cafes & Kopitiams
  // 2. Casual Dining & Refreshments
  // 3. Shaded Rest & Relaxing Breezy Pavilions
  // (Heritage & Sightseeing attractions excluded as requested)
  static const List<NearbyItem> _allNearbySpots = [
    // --- TELUK BAHANG ---
    NearbyItem(
      title: 'End of the World Seafood & Kopitiam',
      category: 'Cafe & Kopitiam',
      area: 'Teluk Bahang',
      businessHours: '11:30 AM - 8:30 PM',
      description: 'Breezy coastal kopitiam located right at the Teluk Bahang jetty. Perfect for cold fresh coconuts, iced local coffee, and relaxing shaded lunch by the water.',
      imagePath: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
      lat: 5.4590,
      lng: 100.2095,
      tags: ['Local Kopitiam', 'Coastal Breeze', 'Shaded Seating'],
    ),
    NearbyItem(
      title: 'ESCAPE Play Canopy Forest Cafe',
      category: 'Cafe & Kopitiam',
      area: 'Teluk Bahang',
      businessHours: '10:00 AM - 6:00 PM',
      description: 'Shaded open-air cafe nestled beneath tall forest trees. Great for iced coffee, fresh tropical smoothies, and light lunch snacks.',
      imagePath: 'https://images.unsplash.com/photo-1564507592333-c60657eea523?auto=format&fit=crop&q=80&w=600',
      lat: 5.4490,
      lng: 100.2150,
      tags: ['Forest Shade', 'Chilled Drinks', 'Rest Area'],
    ),
    NearbyItem(
      title: 'Teluk Bahang Forest Park Shaded Stream & Gazebos',
      category: 'Shaded Rest & Breeze',
      area: 'Teluk Bahang',
      businessHours: '8:30 AM - 5:30 PM',
      description: 'Covered gazebos and shaded walking boardwalks along natural stream pools, completely shielded from direct midday heat.',
      imagePath: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&q=80&w=600',
      lat: 5.4510,
      lng: 100.2170,
      tags: ['Canopy Shade', 'Natural Breeze', 'Relaxation'],
    ),
    NearbyItem(
      title: 'Penang Batik Artisan Tea & Crafts Pavilion',
      category: 'Indoor Air-Con Rest',
      area: 'Teluk Bahang',
      businessHours: '9:00 AM - 5:30 PM',
      description: 'Air-conditioned and sheltered pavilion with cool indoor lounge seating, traditional herbal tea, and artisanal crafts showcase.',
      imagePath: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&q=80&w=600',
      lat: 5.4540,
      lng: 100.2230,
      tags: ['Air-Conditioned', 'Tea Lounge', 'Sheltered'],
    ),

    // --- BATU FERRINGHI ---
    NearbyItem(
      title: 'BoraBora by Sunset Beachside Cafe',
      category: 'Cafe & Kopitiam',
      area: 'Batu Ferringhi',
      businessHours: '12:00 PM - 11:00 PM',
      description: 'Laid-back beachfront cafe with shaded canopy seating, fresh fruit smoothies, pizzas, and gentle ocean breezes.',
      imagePath: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&q=80&w=600',
      lat: 5.4740,
      lng: 100.2480,
      tags: ['Beachfront', 'Seaside Breeze', 'Chilled Drinks'],
    ),
    NearbyItem(
      title: 'Ferringhi Garden Botanical Cafe & Nursery',
      category: 'Casual Dining & Food',
      area: 'Batu Ferringhi',
      businessHours: '4:00 PM - 10:30 PM',
      description: 'An indoor botanical garden oasis filled with live orchids, cascading fountains, and peaceful shaded dining atmosphere.',
      imagePath: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
      lat: 5.4720,
      lng: 100.2460,
      tags: ['Botanical Cafe', 'Shaded Oasis', 'Relaxing'],
    ),
    NearbyItem(
      title: 'Long Beach Food Court & Fresh Juice Stalls',
      category: 'Casual Dining & Food',
      area: 'Batu Ferringhi',
      businessHours: '4:00 PM - 11:00 PM',
      description: 'Covered open-air dining center offering fresh sugar cane juice, local satay, and comforting Penang noodles.',
      imagePath: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=600',
      lat: 5.4715,
      lng: 100.2470,
      tags: ['Covered Food Court', 'Fresh Juices', 'Local Bites'],
    ),
    NearbyItem(
      title: 'Tropical Spice Garden Bamboo Tree Terrace Cafe',
      category: 'Cafe & Kopitiam',
      area: 'Batu Ferringhi',
      businessHours: '9:00 AM - 5:30 PM',
      description: 'Elevated open terrace cafe shaded by lush bamboo groves overlooking the sea. Enjoy spiced iced teas and cake.',
      imagePath: 'https://images.unsplash.com/photo-1466692476868-aef1dfb1e735?auto=format&fit=crop&q=80&w=600',
      lat: 5.4632,
      lng: 100.2291,
      tags: ['Bamboo Canopy', 'Spiced Teas', 'Quiet Retreat'],
    ),

    // --- GEORGE TOWN ---
    NearbyItem(
      title: 'Toh Soon Cafe Charcoal Toast & Kopi',
      category: 'Cafe & Kopitiam',
      area: 'George Town',
      businessHours: '8:00 AM - 5:00 PM',
      description: 'Famous sheltered alley kopitiam known for charcoal-toasted Hainanese bread, runny half-boiled eggs, and aromatic iced kopi.',
      imagePath: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=600',
      lat: 5.4187,
      lng: 100.3325,
      tags: ['Hainanese Kopi', 'Charcoal Toast', 'Heritage Stall'],
    ),
    NearbyItem(
      title: 'ChinaHouse Cafe & Bakery Courtyard',
      category: 'Cafe & Kopitiam',
      area: 'George Town',
      businessHours: '9:00 AM - 11:00 PM',
      description: 'Long shophouse cafe with an air-conditioned library room, open courtyard, and a legendary table of 30+ artisan cakes.',
      imagePath: 'https://images.unsplash.com/photo-1554118811-1e0d58224f24?auto=format&fit=crop&q=80&w=600',
      lat: 5.4149,
      lng: 100.3385,
      tags: ['Air-Conditioned', 'Artisanal Cakes', 'Cool Courtyard'],
    ),
    NearbyItem(
      title: 'Penang Road Famous Teochew Chendul',
      category: 'Casual Dining & Food',
      area: 'George Town',
      businessHours: '10:30 AM - 7:00 PM',
      description: 'Classic shaved ice dessert stand serving rich santan, gula melaka, and pandan jelly to quickly beat the midday heat.',
      imagePath: 'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&q=80&w=600',
      lat: 5.4172,
      lng: 100.3308,
      tags: ['Shaved Ice Chendul', 'Fast Treat', 'Iconic'],
    ),
    NearbyItem(
      title: 'Yin\'s Sourdough Bakery & Pastry Cafe',
      category: 'Cafe & Kopitiam',
      area: 'George Town',
      businessHours: '8:30 AM - 5:00 PM',
      description: 'Cozy air-conditioned bakery offering naturally fermented sourdough breads, croissants, and specialty pour-over coffee.',
      imagePath: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&q=80&w=600',
      lat: 5.4135,
      lng: 100.3390,
      tags: ['Air-Conditioned', 'Sourdough', 'Specialty Coffee'],
    ),
    NearbyItem(
      title: 'Hameediyah Restaurant & Teh Tarik Lounge',
      category: 'Casual Dining & Food',
      area: 'George Town',
      businessHours: '10:00 AM - 10:00 PM',
      description: 'Air-conditioned dining hall serving legendary spiced dishes and frothy pulled teh tarik in comfort.',
      imagePath: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&q=80&w=600',
      lat: 5.4175,
      lng: 100.3315,
      tags: ['Air-Conditioned', 'Teh Tarik', 'Comfort Dining'],
    ),

    // --- AIR ITAM ---
    NearbyItem(
      title: 'Air Itam Sister Curry Mee Stall',
      category: 'Cafe & Kopitiam',
      area: 'Air Itam',
      businessHours: '7:30 AM - 1:00 PM',
      description: 'Sheltered roadside stall famous for charcoal-boiled curry soup and refreshing iced herbal barley drinks.',
      imagePath: 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?auto=format&fit=crop&q=80&w=600',
      lat: 5.4015,
      lng: 100.2782,
      tags: ['Charcoal Broth', 'Iced Barley', 'Fast Bite'],
    ),
    NearbyItem(
      title: 'Air Itam Market Food Court & Assam Laksa',
      category: 'Casual Dining & Food',
      area: 'Air Itam',
      businessHours: '10:30 AM - 7:00 PM',
      description: 'Covered food court with fresh sugarcane juice and renowned sour tamarind fish laksa broth.',
      imagePath: 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?auto=format&fit=crop&q=80&w=600',
      lat: 5.4019,
      lng: 100.2773,
      tags: ['Covered Food Court', 'Sugarcane Juice', 'Assam Laksa'],
    ),
    NearbyItem(
      title: 'Penang Hill Lower Station Air-Con Cafe',
      category: 'Indoor Air-Con Rest',
      area: 'Air Itam',
      businessHours: '7:00 AM - 9:00 PM',
      description: 'Cool air-conditioned indoor lounge at the base station with comfortable seating, iced teas, and light pastries.',
      imagePath: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=600',
      lat: 5.4085,
      lng: 100.2770,
      tags: ['Air-Conditioned', 'Cold Drinks', 'Rest Station'],
    ),
    NearbyItem(
      title: 'Hill Gate Shaded Garden Pavilion',
      category: 'Shaded Rest & Breeze',
      area: 'Air Itam',
      businessHours: '8:00 AM - 6:00 PM',
      description: 'Quiet tree-lined garden path and benches at the base of the hill offering mountain shade and fresh air.',
      imagePath: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?auto=format&fit=crop&q=80&w=600',
      lat: 5.4030,
      lng: 100.2760,
      tags: ['Tree Shade', 'Quiet Bench', 'Fresh Breeze'],
    ),

    // --- BAYAN LEPAS ---
    NearbyItem(
      title: 'Queensbay Waterfront Promenade & Cafes',
      category: 'Indoor Air-Con Rest',
      area: 'Bayan Lepas',
      businessHours: '10:30 AM - 10:00 PM',
      description: 'Fully air-conditioned seaside mall atrium with waterfront bakeries, bubble tea cafes, and comfortable rest lounges.',
      imagePath: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&q=80&w=600',
      lat: 5.3328,
      lng: 100.3066,
      tags: ['Air-Conditioned', 'Waterfront', 'Bakeries'],
    ),
    NearbyItem(
      title: 'Teluk Tempoyak Seaside Jetty Drinks & Grill',
      category: 'Casual Dining & Food',
      area: 'Bayan Lepas',
      businessHours: '4:00 PM - 10:00 PM',
      description: 'Covered wooden seaside jetty with panoramic sea breeze, fresh coconut water, and local seafood bites.',
      imagePath: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=600',
      lat: 5.2780,
      lng: 100.2860,
      tags: ['Sea Breeze', 'Fresh Coconut', 'Wooden Jetty'],
    ),

    // --- BALIK PULAU ---
    NearbyItem(
      title: 'Kim Laksa Balik Pulau & Chilled Nutmeg Juice',
      category: 'Cafe & Kopitiam',
      area: 'Balik Pulau',
      businessHours: '10:00 AM - 5:00 PM',
      description: 'Celebrated open-air countryside coffee shop famous for creamy Siam laksa and iced local nutmeg juice.',
      imagePath: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=600',
      lat: 5.3524,
      lng: 100.2372,
      tags: ['Nutmeg Juice', 'Countryside Kopi', 'Covered'],
    ),
    NearbyItem(
      title: 'Audi Dream Farm Shaded Countryside Cafe',
      category: 'Shaded Rest & Breeze',
      area: 'Balik Pulau',
      businessHours: '9:00 AM - 6:00 PM',
      description: 'Sheltered eco-farm cafe serving fresh garden herbal teas, seasonal fruit platters, and quiet country breezes.',
      imagePath: 'https://images.unsplash.com/photo-1470240731273-7821a6eeb6bd?auto=format&fit=crop&q=80&w=600',
      lat: 5.3420,
      lng: 100.2215,
      tags: ['Fresh Herbal Tea', 'Farm Shade', 'Quiet Countryside'],
    ),

    // --- TANJUNG TOKONG & TANJUNG BUNGAH ---
    NearbyItem(
      title: 'Straits Quay Marina Promenade & Gelato',
      category: 'Indoor Air-Con Rest',
      area: 'Tanjung Tokong',
      businessHours: '10:00 AM - 10:00 PM',
      description: 'Sheltered oceanfront promenade with air-conditioned cafes, artisanal gelato, and peaceful harbor views.',
      imagePath: 'https://images.unsplash.com/photo-1519046904884-53103b34b206?auto=format&fit=crop&q=80&w=600',
      lat: 5.4583,
      lng: 100.3133,
      tags: ['Air-Conditioned', 'Gelato & Coffee', 'Marina View'],
    ),
    NearbyItem(
      title: 'Viva Local Food Haven Seaside Court',
      category: 'Casual Dining & Food',
      area: 'Tanjung Bungah',
      businessHours: '11:00 AM - 11:00 PM',
      description: 'Covered airy food court right next to the beach, perfect for fresh fruit juices and local comfort food.',
      imagePath: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
      lat: 5.4610,
      lng: 100.3080,
      tags: ['Covered Food Court', 'Fresh Juices', 'Seaside Air'],
    ),
  ];

  static double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double p = 0.017453292519943295; // Pi / 180
    final double a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  List<MapEntry<NearbyItem, double?>> _getRankedSuggestions() {
    final prevName = widget.previousPlaceName.trim().toLowerCase();
    final prevArea = widget.previousPlaceArea.trim().toLowerCase();
    final hasCoords = widget.lat != null && widget.lng != null && widget.lat != 0.0 && widget.lng != 0.0;

    // Combine live MongoDB places_new items with local pool, avoiding duplicate titles
    final Map<String, NearbyItem> merged = {};
    for (final item in _liveMongoSpots) {
      merged[item.title.trim().toLowerCase()] = item;
    }
    for (final item in _allNearbySpots) {
      final k = item.title.trim().toLowerCase();
      if (!merged.containsKey(k)) {
        merged[k] = item;
      }
    }

    // Filter out items matching previous stop name
    final candidates = merged.values.where((item) {
      if (item.title.trim().toLowerCase() == prevName) return false;
      return true;
    }).toList();

    // Map each item with its calculated geographic distance
    final mapped = candidates.map((item) {
      double? dist;
      if (hasCoords && item.lat != 0.0 && item.lng != 0.0) {
        dist = _calculateDistanceKm(widget.lat!, widget.lng!, item.lat, item.lng);
      }
      return MapEntry(item, dist);
    }).toList();

    // STRICT FILTER: Only show suggestions strictly within 3 km
    final filtered = mapped.where((entry) {
      final dist = entry.value;
      if (dist != null) {
        return dist <= _maxRadiusKm;
      }
      // If coordinates are missing on the previous stop, check if same micro-area
      final itemArea = entry.key.area.toLowerCase();
      return itemArea.contains(prevArea) || prevArea.contains(itemArea);
    }).toList();

    // Sort by real geographic distance ascending
    filtered.sort((a, b) {
      if (a.value != null && b.value != null) {
        return a.value!.compareTo(b.value!);
      }
      if (a.value != null) return -1;
      if (b.value != null) return 1;
      return a.key.title.compareTo(b.key.title);
    });

    return filtered;
  }

  String _formatDistanceInfo(double? distanceKm) {
    if (distanceKm == null) {
      return 'Within 3 km of ${widget.previousPlaceArea}';
    }
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      final walkMin = (meters / 80).clamp(1, 15).round();
      return '$meters m away • ~$walkMin min walk';
    } else {
      final kmStr = distanceKm.toStringAsFixed(1);
      final driveMin = ((distanceKm / 30) * 60).clamp(2, 10).round();
      return '$kmStr km away • ~$driveMin min drive';
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _getRankedSuggestions();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "What's Nearby",
          style: TextStyle(
            color: Color(0xFF19244E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Contextual info header
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.explore_outlined, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Suggestions Near ${widget.previousPlaceName}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                          fontFamily: 'SF Pro',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.timeSlot != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '⏰ ${widget.timeSlot}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF047857),
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  'Relaxing dining, cafes, and shaded spots within 3 km of your stop to enjoy during your Free Time Bridge. (No selection needed — explore freely!)',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade700,
                    height: 1.35,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ],
            ),
          ),

          // Suggestions list
          Expanded(
            child: suggestions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 10),
                          Text(
                            'No spots within 3 km of ${widget.previousPlaceName}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                              fontFamily: 'SF Pro',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Take this window to relax or enjoy your current location.',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontFamily: 'SF Pro'),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: suggestions.length,
                    itemBuilder: (context, index) {
                      final entry = suggestions[index];
                      final item = entry.key;
                      final distanceKm = entry.value;

                      return _buildSuggestionCard(item, distanceKm);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(NearbyItem item, double? distanceKm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetailScreen(
                title: item.title,
                area: item.area,
                businessHours: PlacesService.formatConciseSummary(item.businessHours),
                description: item.description,
                imagePath: item.imagePath,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImageWidget(
                      imagePath: item.imagePath,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Distance Badge (<= 3 km)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me, size: 10, color: Color(0xFF047857)),
                              const SizedBox(width: 3),
                              Text(
                                _formatDistanceInfo(distanceKm),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF19244E),
                            fontFamily: 'SF Pro',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 11, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                PlacesService.formatConciseSummary(item.businessHours),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontFamily: 'SF Pro',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  height: 1.35,
                  fontFamily: 'SF Pro',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Feature Tags & View Detail button
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: item.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey.shade300, width: 0.5),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade800,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Details ›',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
