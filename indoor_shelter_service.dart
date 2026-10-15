import 'dart:math';

/// Model representing an indoor shelter or air-conditioned alternative in Penang
class IndoorShelter {
  final String id;
  final String name;
  final String nameEn;
  final String area;
  final double lat;
  final double lng;
  final String category;
  final String description;
  final String highlight;
  final String imageUrl;
  final double distanceMeters;
  final int durationMinutes;

  IndoorShelter({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.area,
    required this.lat,
    required this.lng,
    required this.category,
    required this.description,
    required this.highlight,
    required this.imageUrl,
    this.distanceMeters = 0.0,
    this.durationMinutes = 0,
  });

  double get distanceKm => distanceMeters / 1000.0;

  String get distanceString {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()}m';
    }
    return '${distanceKm.toStringAsFixed(2)} km';
  }

  IndoorShelter copyWithDistance({
    required double distanceMeters,
    required int durationMinutes,
  }) {
    return IndoorShelter(
      id: id,
      name: name,
      nameEn: nameEn,
      area: area,
      lat: lat,
      lng: lng,
      category: category,
      description: description,
      highlight: highlight,
      imageUrl: imageUrl,
      distanceMeters: distanceMeters,
      durationMinutes: durationMinutes,
    );
  }
}

/// Service that cross-references the user's current GPS position with
/// the Penang POI database to locate the closest and most suitable indoor shelters.
class IndoorShelterService {
  static final IndoorShelterService instance = IndoorShelterService._internal();
  IndoorShelterService._internal();

  /// Curated master database of indoor shelters across all Penang regions
  static final List<IndoorShelter> _penangIndoorDatabase = [
    // George Town Central Malls & Shelters
    IndoorShelter(
      id: 'shelter_1st_avenue',
      name: '1st Avenue Mall',
      nameEn: '1st Avenue Mall',
      area: 'George Town',
      lat: 5.41320,
      lng: 100.33120,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'Modern 7-storey air-conditioned shopping complex with covered basement drop-off, cafes, cinema, and dining options.',
      highlight: 'Full indoor climate control, spacious food court & Grab pick-up lounge.',
      imageUrl: 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&q=80&w=600',
    ),
    IndoorShelter(
      id: 'shelter_komtar_ict',
      name: 'Komtar ICT Mall & The TOP',
      nameEn: 'Komtar ICT Mall & The TOP',
      area: 'George Town',
      lat: 5.41430,
      lng: 100.32980,
      category: 'Indoor Complex / Landmark',
      description: 'Penang iconic 68-storey indoor tower with massive indoor theme parks, tech digital mall, and fully sheltered concourses.',
      highlight: 'Directly connected via covered walkways to Prangin and 1st Avenue.',
      imageUrl: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&q=80&w=600',
    ),
    IndoorShelter(
      id: 'shelter_prangin_mall',
      name: 'Prangin Mall',
      nameEn: 'Prangin Mall',
      area: 'George Town',
      lat: 5.41450,
      lng: 100.33150,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'Established indoor retail mall with over 400 specialty shops, electronic stores, and diverse local food spots.',
      highlight: 'Extensive underground and elevated covered pedestrian linkages.',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
    ),

    // Gurney Drive Air-Conditioned Havens
    IndoorShelter(
      id: 'shelter_gurney_plaza',
      name: 'Gurney Plaza',
      nameEn: 'Gurney Plaza',
      area: 'Gurney Drive',
      lat: 5.43770,
      lng: 100.30970,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'Premier seaside indoor shopping destination with nine floors of flagship retail, gourmet restaurants, and sheltered parking.',
      highlight: 'Excellent coastal refuge during storms with hundreds of indoor venues.',
      imageUrl: 'https://images.unsplash.com/photo-1567449303078-57ad995bd301?auto=format&fit=crop&q=80&w=600',
    ),
    IndoorShelter(
      id: 'shelter_gurney_paragon',
      name: 'Gurney Paragon Mall',
      nameEn: 'Gurney Paragon Mall',
      area: 'Gurney Drive',
      lat: 5.43580,
      lng: 100.31150,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'Luxury lifestyle complex built around the historic St. Joseph chapel, featuring vast indoor atriums and bookshops.',
      highlight: 'Modern indoor architecture with multi-level covered parking.',
      imageUrl: 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&q=80&w=600',
    ),

    // South Island / Bayan Lepas
    IndoorShelter(
      id: 'shelter_queensbay',
      name: 'Queensbay Mall',
      nameEn: 'Queensbay Mall',
      area: 'Bayan Lepas',
      lat: 5.33320,
      lng: 100.30680,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'The largest shopping mall in Penang featuring over 400 stores, indoor entertainment zones, and waterfront dining.',
      highlight: 'Massive indoor footprint with complete weather shielding.',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
    ),

    // Central & Air Itam
    IndoorShelter(
      id: 'shelter_sunshine_farlim',
      name: 'Sunshine Farlim Mall',
      nameEn: 'Sunshine Farlim Mall',
      area: 'Air Itam',
      lat: 5.39450,
      lng: 100.28650,
      category: 'Shopping Mall / Indoor Shelter',
      description: 'Community-oriented indoor shopping center close to Kek Lok Si and Penang Hill foothills.',
      highlight: 'Reliable indoor shelter with covered market stalls and cafes.',
      imageUrl: 'https://images.unsplash.com/photo-1596402184320-417e7178b2cd?auto=format&fit=crop&q=80&w=600',
    ),

    // North Coast / Batu Ferringhi
    IndoorShelter(
      id: 'shelter_eden_parade',
      name: 'Eden Parade Mall',
      nameEn: 'Eden Parade Batu Ferringhi',
      area: 'Batu Ferringhi',
      lat: 5.47150,
      lng: 100.24600,
      category: 'Shopping Complex / Indoor Shelter',
      description: 'Beachfront indoor commercial center providing shelter from northern coastal rainstorms.',
      highlight: 'Quick indoor retreat along the Batu Ferringhi hotel strip.',
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=600',
    ),

    // West Coast / Balik Pulau
    IndoorShelter(
      id: 'shelter_botanica_centre',
      name: 'Botanica Centre Balik Pulau',
      nameEn: 'Botanica Centre Balik Pulau',
      area: 'Balik Pulau',
      lat: 5.36200,
      lng: 100.22200,
      category: 'Commercial Centre / Indoor Shelter',
      description: 'Sheltered western district complex with supermarkets, cafes, and indoor rest areas.',
      highlight: 'Safe inland shelter for rural and fruit farm travelers.',
      imageUrl: 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?auto=format&fit=crop&q=80&w=600',
    ),

    // Cultural & Heritage Indoor Havens
    IndoorShelter(
      id: 'shelter_peranakan_mansion',
      name: 'Pinang Peranakan Mansion',
      nameEn: 'Pinang Peranakan Mansion',
      area: 'George Town',
      lat: 5.41840,
      lng: 100.34130,
      category: 'Air-Conditioned Heritage Museum',
      description: 'Opulent historic courtyard mansion filled with thousands of antique Peranakan artifacts and sheltered inner courtyards.',
      highlight: 'UNESCO heritage exploration completely shielded from heavy downpours.',
      imageUrl: 'https://images.unsplash.com/photo-1582719508461-905c673771fd?auto=format&fit=crop&q=80&w=600',
    ),
    IndoorShelter(
      id: 'shelter_wonderfood',
      name: 'Wonderfood Museum Penang',
      nameEn: 'Wonderfood Museum Penang',
      area: 'George Town',
      lat: 5.41620,
      lng: 100.34110,
      category: 'Indoor Museum / Family Fun',
      description: 'Colonial-era building housing giant, hyper-realistic Malaysian food replicas with full air-conditioning throughout.',
      highlight: 'Interactive indoor photography paradise while waiting out the rain.',
      imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80&w=600',
    ),
    IndoorShelter(
      id: 'shelter_chinahouse',
      name: 'ChinaHouse Complex & Cafe',
      nameEn: 'ChinaHouse Arts & Cafe',
      area: 'George Town',
      lat: 5.41480,
      lng: 100.33920,
      category: 'Indoor Cafe & Art Complex',
      description: 'Long traditional compound linking Beach Street and Victoria Street, comprising galleries, bakeries, and live acoustic spaces.',
      highlight: 'Historic covered shelter serving famous cakes, coffee, and indoor arts.',
      imageUrl: 'https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&q=80&w=600',
    ),
  ];

  /// Cross-references current mock GPS location with the POI database,
  /// calculates realistic road distance & Grab ETA, and returns sorted nearby shelters.
  List<IndoorShelter> getNearbyShelters({
    required double userLat,
    required double userLng,
    int limit = 5,
  }) {
    final List<IndoorShelter> list = [];

    for (final shelter in _penangIndoorDatabase) {
      final straightDist = _calculateHaversineMeters(
        userLat,
        userLng,
        shelter.lat,
        shelter.lng,
      );
      // Realistic Penang urban road factor (~1.25x detour)
      final roadDistMeters = max(100.0, straightDist * 1.25);
      final roadKm = roadDistMeters / 1000.0;

      // Grab / car transit speed in urban traffic (~28 km/h + 2 min buffer)
      final durationMins = max(2, (roadKm / 28.0 * 60).round() + 2);

      list.add(shelter.copyWithDistance(
        distanceMeters: roadDistMeters,
        durationMinutes: durationMins,
      ));
    }

    // Sort by proximity ascending
    list.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

    return list.take(limit).toList();
  }

  /// Returns the single closest indoor shelter to the user
  IndoorShelter getClosestShelter({
    required double userLat,
    required double userLng,
  }) {
    final shelters = getNearbyShelters(userLat: userLat, userLng: userLng, limit: 1);
    if (shelters.isNotEmpty) return shelters.first;
    return _penangIndoorDatabase.first;
  }

  /// Haversine formula calculating great-circle distance in meters
  static double _calculateHaversineMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // pi / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000.0 * asin(sqrt(a)); // 2 * R (R = 6371000 meters)
  }
}
