import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import '../services/places_service.dart';

/// Full-screen search and place picker for Draft Plan.
/// Allows users to search Penang destinations / MongoDB places, filter by category,
/// and directly tap to add them to their draft plan.
class SearchPlacesScreen extends StatefulWidget {
  final TripController controller;

  const SearchPlacesScreen({super.key, required this.controller});

  @override
  State<SearchPlacesScreen> createState() => _SearchPlacesScreenState();
}

class _SearchPlacesScreenState extends State<SearchPlacesScreen> {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounceTimer;
  bool _isSearching = false;
  String _selectedCategory = 'All';
  String _selectedArea = 'All';
  List<Map<String, dynamic>> _searchResults = [];

  static const List<String> _penangAreas = [
    'All',
    'George Town',
    'Air Itam',
    'Batu Ferringhi',
    'Gurney Drive',
    'Tanjung Tokong',
    'Tanjung Bungah',
    'Pulau Tikus',
    'Teluk Bahang',
    'Balik Pulau',
    'Bayan Lepas',
    'Bayan Baru',
    'Jelutong',
    'Gelugor',
    'Butterworth',
    'Seberang Perai',
  ];

  // ── Category Color Palette (Light Backgrounds) ───────────────────────────
  static const Map<String, Color> _categoryBgColors = {
    'Cafes': Color(0xFFFFF3E0),
    'Food & Dining': Color(0xFFE8F5E9),
    'Nightlife & Speakeasies': Color(0xFFF3E5F5),
    'Heritage & Culture': Color(0xFFE3F2FD),
    'Arts & Workshops': Color(0xFFFCE4EC),
    'Religious Sites': Color(0xFFF9FBE7),
    'Nature & Parks': Color(0xFFE0F2F1),
    'Family & Adventure': Color(0xFFFFF8E1),
    'Shopping & Markets': Color(0xFFE8EAF6),
    'Local Souvenirs': Color(0xFFFBE9E7),
    'Boutique Stays': Color(0xFFEDE7F6),
    'Wellness & Spa': Color(0xFFE0F7FA),
    'Entertainment': Color(0xFFF1F8E9),
    'Others': Color(0xFFF5F5F5),
  };

  static const Map<String, Color> _categoryTextColors = {
    'Cafes': Color(0xFFE65100),
    'Food & Dining': Color(0xFF1B5E20),
    'Nightlife & Speakeasies': Color(0xFF4A148C),
    'Heritage & Culture': Color(0xFF0D47A1),
    'Arts & Workshops': Color(0xFF880E4F),
    'Religious Sites': Color(0xFF827717),
    'Nature & Parks': Color(0xFF004D40),
    'Family & Adventure': Color(0xFFF57F17),
    'Shopping & Markets': Color(0xFF1A237E),
    'Local Souvenirs': Color(0xFFBF360C),
    'Boutique Stays': Color(0xFF311B92),
    'Wellness & Spa': Color(0xFF006064),
    'Entertainment': Color(0xFF33691E),
    'Others': Color(0xFF424242),
  };

  static const List<String> _categoryFilters = [
    'All',
    'Heritage & Culture',
    'Food & Dining',
    'Cafes',
    'Nature & Parks',
    'Religious Sites',
    'Family & Adventure',
    'Shopping & Markets',
    'Arts & Workshops',
    'Entertainment',
  ];

  // ── Curated Popular Penang Spots Across All 15 Areas ─────────────────────
  static const List<Map<String, dynamic>> _popularSuggestions = [
    // ── George Town ────────────────────────────────────────────────────────
    {
      'name': 'George Town Street Art',
      'area': 'George Town',
      'category': 'Arts & Workshops',
      'lat': 5.4140,
      'lng': 100.3380,
      'desc': 'World-famous interactive murals by Ernest Zacharevic and steel rod caricatures.',
      'features': {'is_wheelchair_accessible': true},
    },
    {
      'name': 'Pinang Peranakan Mansion',
      'area': 'George Town',
      'category': 'Heritage & Culture',
      'lat': 5.4180,
      'lng': 100.3411,
      'desc': 'Opulent 19th-century Baba Nyonya ancestral home showcasing over 1,000 antique artifacts.',
      'features': {'has_aircon': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Cheong Fatt Tze (The Blue Mansion)',
      'area': 'George Town',
      'category': 'Heritage & Culture',
      'lat': 5.4215,
      'lng': 100.3347,
      'desc': 'Iconic UNESCO-awarded indigo heritage mansion featured in Crazy Rich Asians.',
      'features': {'has_aircon': true, 'has_parking': true},
    },
    {
      'name': 'Khoo Kongsi Clan House',
      'area': 'George Town',
      'category': 'Heritage & Culture',
      'lat': 5.4150,
      'lng': 100.3370,
      'desc': 'Spectacular Chinese clan temple featuring intricate stone carvings and gilded woodwork.',
      'features': {'is_wheelchair_accessible': true},
    },
    {
      'name': 'Chew Jetty Heritage Village',
      'area': 'George Town',
      'category': 'Heritage & Culture',
      'lat': 5.4132,
      'lng': 100.3400,
      'desc': 'Historic 19th-century wooden waterfront stilt house community on Weld Quay.',
      'features': {'is_wheelchair_accessible': true},
    },
    {
      'name': 'Fort Cornwallis',
      'area': 'George Town',
      'category': 'Heritage & Culture',
      'lat': 5.4208,
      'lng': 100.3440,
      'desc': 'Malaysia’s largest standing 18th-century British fort built by Captain Francis Light.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'The TOP Penang @ Komtar',
      'area': 'George Town',
      'category': 'Entertainment',
      'lat': 5.4147,
      'lng': 100.3300,
      'desc': 'Rainbow Skywalk glass observatory bridge and indoor theme attractions on the 68th floor.',
      'features': {'has_aircon': true, 'is_wheelchair_accessible': true, 'has_parking': true},
    },
    {
      'name': 'Penang Road Famous Teochew Chendul',
      'area': 'George Town',
      'category': 'Food & Dining',
      'lat': 5.4172,
      'lng': 100.3307,
      'desc': 'Legendary shaved ice dessert with green rice flour jelly, coconut milk, and palm sugar since 1936.',
      'features': {'is_halal': false},
    },
    {
      'name': 'New Lane Hawker Centre',
      'area': 'George Town',
      'category': 'Food & Dining',
      'lat': 5.4147,
      'lng': 100.3262,
      'desc': 'Vibrant evening street hawker lane for Char Koay Teow, Hokkien Mee, and Fried Oyster.',
      'features': {'is_halal': false},
    },
    {
      'name': 'ChinaHouse Cafe & Bakery',
      'area': 'George Town',
      'category': 'Cafes',
      'lat': 5.4144,
      'lng': 100.3394,
      'desc': 'Longest heritage shophouse cafe in Penang famous for 30+ daily artisanal cakes and coffee.',
      'features': {'wifi_available': true, 'has_aircon': true, 'specialty_coffee': true},
    },
    {
      'name': 'Hin Bus Depot',
      'area': 'George Town',
      'category': 'Arts & Workshops',
      'lat': 5.4121,
      'lng': 100.3283,
      'desc': 'Vibrant creative arts hub, artisan weekend market, galleries, and open community lawns.',
      'features': {'wifi_available': true, 'has_parking': true},
    },

    // ── Air Itam ───────────────────────────────────────────────────────────
    {
      'name': 'Kek Lok Si Temple',
      'area': 'Air Itam',
      'category': 'Religious Sites',
      'lat': 5.3995,
      'lng': 100.2736,
      'desc': 'Magnificent Buddhist temple complex featuring the 7-tier pagoda and giant Guanyin statue.',
      'features': {'is_vegetarian_friendly': true, 'has_parking': true},
    },
    {
      'name': 'Penang Hill Funicular',
      'area': 'Air Itam',
      'category': 'Nature & Parks',
      'lat': 5.4085,
      'lng': 100.2770,
      'desc': 'Historic funicular railway ascent to the refreshing panoramic summit of Penang Hill.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'The Habitat Penang Hill',
      'area': 'Air Itam',
      'category': 'Nature & Parks',
      'lat': 5.4246,
      'lng': 100.2690,
      'desc': 'Canopy walk and Curtis Crest 360-degree viewing platform in a 130-million-year-old rainforest.',
      'features': {'is_wheelchair_accessible': true},
    },
    {
      'name': 'Air Itam Dam',
      'area': 'Air Itam',
      'category': 'Nature & Parks',
      'lat': 5.3970,
      'lng': 100.2678,
      'desc': 'Scenic mountain reservoir popular for morning jogs, cycling, and panoramic hill views.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Penang Air Itam Laksa',
      'area': 'Air Itam',
      'category': 'Food & Dining',
      'lat': 5.4012,
      'lng': 100.2780,
      'desc': 'Iconic sour spicy fish-broth noodle soup with prawn paste beside the Air Itam market.',
      'features': {'is_halal': false},
    },
    {
      'name': 'MonkeyCup@PenangHill',
      'area': 'Air Itam',
      'category': 'Cafes',
      'lat': 5.4260,
      'lng': 100.2650,
      'desc': 'High-altitude botanical cafe surrounded by rare pitcher plants and lush greenery.',
      'features': {'wifi_available': true, 'specialty_coffee': true},
    },

    // ── Batu Ferringhi ─────────────────────────────────────────────────────
    {
      'name': 'Batu Ferringhi Public Beach',
      'area': 'Batu Ferringhi',
      'category': 'Nature & Parks',
      'lat': 5.4745,
      'lng': 100.2475,
      'desc': 'Golden sand coastline famous for parasailing, jet-skiing, and stunning sunset views.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Batu Ferringhi Night Market',
      'area': 'Batu Ferringhi',
      'category': 'Shopping & Markets',
      'lat': 5.4715,
      'lng': 100.2458,
      'desc': 'Lively evening beachfront market selling clothing, handicrafts, souvenirs, and gifts.',
      'features': {'is_wheelchair_accessible': true},
    },
    {
      'name': 'Biru Biru On The Island',
      'area': 'Batu Ferringhi',
      'category': 'Food & Dining',
      'lat': 5.4705,
      'lng': 100.2440,
      'desc': 'Beachfront bar and dining hotspot with refreshing cocktails and sunset sea views.',
      'features': {'wifi_available': true, 'has_parking': true},
    },
    {
      'name': 'Shangri-La Golden Sands Resort',
      'area': 'Batu Ferringhi',
      'category': 'Boutique Stays',
      'lat': 5.4728,
      'lng': 100.2467,
      'desc': 'Family-friendly beachfront resort featuring lagoon pools, water park, and lush tropical gardens.',
      'features': {'has_aircon': true, 'has_parking': true, 'wifi_available': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Sigi\'s Bar and Grill on the Beach',
      'area': 'Batu Ferringhi',
      'category': 'Food & Dining',
      'lat': 5.4727,
      'lng': 100.2464,
      'desc': 'Beachfront Italian grill dining facing the sea waves at Golden Sands Resort.',
      'features': {'wifi_available': true, 'has_parking': true},
    },

    // ── Gurney Drive ───────────────────────────────────────────────────────
    {
      'name': 'Gurney Plaza',
      'area': 'Gurney Drive',
      'category': 'Shopping & Markets',
      'lat': 5.4373,
      'lng': 100.3097,
      'desc': 'Premier beachfront retail mall in Penang with international luxury brands and dining.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'Gurney Paragon Mall',
      'area': 'Gurney Drive',
      'category': 'Shopping & Markets',
      'lat': 5.4357,
      'lng': 100.3115,
      'desc': 'Modern waterfront retail mall integrated around the heritage St. Joseph’s Novitiate.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'Gurney Drive Hawker Centre',
      'area': 'Gurney Drive',
      'category': 'Food & Dining',
      'lat': 5.4398,
      'lng': 100.3090,
      'desc': 'One of Penang’s largest seaside open-air hawker centres for Char Koay Teow and Pasembur.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Gurney Bay',
      'area': 'Gurney Drive',
      'category': 'Nature & Parks',
      'lat': 5.4385,
      'lng': 100.3120,
      'desc': 'New green seafront public park with promenade walkways, play areas, and coastal sea breezes.',
      'features': {'is_wheelchair_accessible': true, 'has_parking': true},
    },

    // ── Tanjung Tokong ─────────────────────────────────────────────────────
    {
      'name': 'Straits Quay Marina Mall',
      'area': 'Tanjung Tokong',
      'category': 'Shopping & Markets',
      'lat': 5.4580,
      'lng': 100.3135,
      'desc': 'Penang’s only waterfront marina retail mall with berthed yachts and seaside promenade dining.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'Penang Avatar Secret Garden',
      'area': 'Tanjung Tokong',
      'category': 'Nature & Parks',
      'lat': 5.4635,
      'lng': 100.3080,
      'desc': 'Enchanting illuminated fantasy forest behind Thai Pak Koong Temple, lit up with neon colors at night.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Hompton by the Beach Penang',
      'area': 'Tanjung Tokong',
      'category': 'Boutique Stays',
      'lat': 5.4640,
      'lng': 100.3065,
      'desc': 'Modern beachfront hotel offering panoramic sea-facing infinity pool and sunset lounge.',
      'features': {'has_aircon': true, 'has_parking': true, 'wifi_available': true},
    },
    {
      'name': 'Anjoelogy Cafe',
      'area': 'Tanjung Tokong',
      'category': 'Cafes',
      'lat': 5.4520,
      'lng': 100.3060,
      'desc': 'Aesthetic specialty cafe serving artisanal coffee, brunch, and homemade bakery items.',
      'features': {'wifi_available': true, 'has_aircon': true, 'specialty_coffee': true},
    },
    {
      'name': 'Cafe No.12 十二號冰廳',
      'area': 'Tanjung Tokong',
      'category': 'Cafes',
      'lat': 5.4505,
      'lng': 100.3050,
      'desc': 'Popular nostalgic Hong Kong-style cafe known for milk tea, polo buns, and roast meats.',
      'features': {'has_aircon': true, 'wifi_available': true},
    },

    // ── Tanjung Bungah ─────────────────────────────────────────────────────
    {
      'name': 'Tanjung Bungah Floating Mosque',
      'area': 'Tanjung Bungah',
      'category': 'Religious Sites',
      'lat': 5.4688,
      'lng': 100.2798,
      'desc': 'Stunning mosque built on stilts extending into the sea, featuring Middle Eastern & Malay architecture.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Tanjung Bungah Public Beach',
      'area': 'Tanjung Bungah',
      'category': 'Nature & Parks',
      'lat': 5.4665,
      'lng': 100.2820,
      'desc': 'Relaxed beach bay favored by locals for kayaking, windsurfing, and evening coastal walks.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Penang Toy Museum Heritage House',
      'area': 'Tanjung Bungah',
      'category': 'Entertainment',
      'lat': 5.4650,
      'lng': 100.2880,
      'desc': 'Nostalgic museum housing over 100,000 toys, pop culture figurines, and comic memorabilia.',
      'features': {'has_aircon': true, 'has_parking': true},
    },
    {
      'name': 'Rainbow Paradise Beach Resort',
      'area': 'Tanjung Bungah',
      'category': 'Boutique Stays',
      'lat': 5.4620,
      'lng': 100.2980,
      'desc': 'Seaside resort with direct beach access, outdoor pool, and tennis courts.',
      'features': {'has_aircon': true, 'has_parking': true, 'wifi_available': true},
    },

    // ── Pulau Tikus ────────────────────────────────────────────────────────
    {
      'name': 'Wat Chayamangkalaram (Reclining Buddha)',
      'area': 'Pulau Tikus',
      'category': 'Religious Sites',
      'lat': 5.4317,
      'lng': 100.3138,
      'desc': 'Historic Thai Buddhist temple housing a 33-meter gold-plated Reclining Buddha statue.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Dhammikarama Burmese Buddhist Temple',
      'area': 'Pulau Tikus',
      'category': 'Religious Sites',
      'lat': 5.4312,
      'lng': 100.3142,
      'desc': 'Oldest Burmese Buddhist temple in Penang, featuring the Arahant shrine and wishing well.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Penang Waterfall Hill Temple',
      'area': 'Pulau Tikus',
      'category': 'Religious Sites',
      'lat': 5.4335,
      'lng': 100.2980,
      'desc': 'Grand hilltop Hindu Murugan temple with over 500 steps, epicentre of annual Thaipusam celebrations.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Pulau Tikus Wet Market & Hawkers',
      'area': 'Pulau Tikus',
      'category': 'Food & Dining',
      'lat': 5.4300,
      'lng': 100.3120,
      'desc': 'Bustling morning wet market and evening hawker food center famous for Apom and Lok-Lok.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Penang Youth Park (Taman Perbandaran)',
      'area': 'Pulau Tikus',
      'category': 'Nature & Parks',
      'lat': 5.4310,
      'lng': 100.2980,
      'desc': 'Sprawling public park with outdoor splash pools, skate park, archery range, and shaded trails.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },

    // ── Teluk Bahang ───────────────────────────────────────────────────────
    {
      'name': 'ESCAPE Penang',
      'area': 'Teluk Bahang',
      'category': 'Family & Adventure',
      'lat': 5.4485,
      'lng': 100.2155,
      'desc': 'Guinness record-holding outdoor eco-adventure theme park with 1,111m water slide and zip coaster.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Entopia by Penang Butterfly Farm',
      'area': 'Teluk Bahang',
      'category': 'Nature & Parks',
      'lat': 5.4462,
      'lng': 100.2227,
      'desc': 'Massive glasshouse sanctuary with 15,000+ free-flying butterflies, insects, and reptile discovery zones.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Penang National Park (Taman Negara)',
      'area': 'Teluk Bahang',
      'category': 'Nature & Parks',
      'lat': 5.4590,
      'lng': 100.1980,
      'desc': 'Malaysia’s smallest national park with scenic jungle trails to Monkey Beach and turtle sanctuary.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Tropical Spice Garden',
      'area': 'Teluk Bahang',
      'category': 'Heritage & Culture',
      'lat': 5.4635,
      'lng': 100.2295,
      'desc': 'Award-winning bio-reserve featuring 500+ species of tropical spices, giant swings, and cooking classes.',
      'features': {'has_parking': true, 'wifi_available': true},
    },
    {
      'name': 'Penang Tropical Fruit Farm',
      'area': 'Teluk Bahang',
      'category': 'Heritage & Culture',
      'lat': 5.4170,
      'lng': 100.2200,
      'desc': '25-acre hillside eco-orchard featuring 250+ varieties of exotic tropical and subtropical fruit trees.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Monkey Beach',
      'area': 'Teluk Bahang',
      'category': 'Nature & Parks',
      'lat': 5.4740,
      'lng': 100.1970,
      'desc': 'Secluded white sandy beach inside Penang National Park accessible by boat or jungle hike.',
      'features': {'is_wheelchair_accessible': false},
    },

    // ── Balik Pulau ────────────────────────────────────────────────────────
    {
      'name': 'Balik Pulau Countryside & Paddy Fields',
      'area': 'Balik Pulau',
      'category': 'Nature & Parks',
      'lat': 5.3520,
      'lng': 100.2350,
      'desc': 'Tranquil countryside surrounded by rural paddy fields, scenic cycling paths, and mountain sunsets.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Countryside Stables Penang',
      'area': 'Balik Pulau',
      'category': 'Family & Adventure',
      'lat': 5.3450,
      'lng': 100.2070,
      'desc': 'Charming equestrian park offering horse rides, miniature pony petting, and carriage rides.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Audi Dream Farm',
      'area': 'Balik Pulau',
      'category': 'Family & Adventure',
      'lat': 5.3620,
      'lng': 100.2050,
      'desc': 'Interactive agro-tourism family farm with animal petting, vegetable plots, and traditional dining.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Penang TCL ATV Extreme',
      'area': 'Balik Pulau',
      'category': 'Family & Adventure',
      'lat': 5.3480,
      'lng': 100.2240,
      'desc': 'Thrilling off-road quad biking tours through rugged jungle trails, streams, and fruit orchards.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Ghee Hup Nutmeg Factory (义合豆蔻场)',
      'area': 'Balik Pulau',
      'category': 'Local Souvenirs',
      'lat': 5.3550,
      'lng': 100.2370,
      'desc': 'Traditional heritage nutmeg factory producing fresh nutmeg drinks, preserved snacks, and therapeutic oils.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Kim\'s Laksa Balik Pulau',
      'area': 'Balik Pulau',
      'category': 'Food & Dining',
      'lat': 5.3515,
      'lng': 100.2365,
      'desc': 'Famous coffee shop stall known for authentic creamy Siam Laksa and spicy Asam Laksa.',
      'features': {'is_halal': false},
    },

    // ── Bayan Lepas ────────────────────────────────────────────────────────
    {
      'name': 'Queensbay Mall',
      'area': 'Bayan Lepas',
      'category': 'Shopping & Markets',
      'lat': 5.3328,
      'lng': 100.3067,
      'desc': 'Largest waterfront shopping mall on Penang Island with 400+ stores facing Jerejak Island.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'Penang Snake Temple',
      'area': 'Bayan Lepas',
      'category': 'Religious Sites',
      'lat': 5.3135,
      'lng': 100.2810,
      'desc': 'Built in 1850 in honor of Chor Soo Kong, famous for harmless resident pit vipers on altar tables.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Penang War Museum',
      'area': 'Bayan Lepas',
      'category': 'Heritage & Culture',
      'lat': 5.2815,
      'lng': 100.2885,
      'desc': 'Restored British WWII military fortress on Batu Maung hill with underground bunkers and tunnels.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Setia SPICE Canopy & Arena',
      'area': 'Bayan Lepas',
      'category': 'Entertainment',
      'lat': 5.3288,
      'lng': 100.2825,
      'desc': 'World’s first hybrid solar convention complex with open rooftop green gardens and trendy dining.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'SBK Coffee 新文记咖啡体验馆',
      'area': 'Bayan Lepas',
      'category': 'Food & Dining',
      'lat': 5.3340,
      'lng': 100.2780,
      'desc': 'Certified halal traditional Penang coffee experience centre, cafe, and cultural gift shop.',
      'features': {'is_halal': true, 'has_aircon': true, 'specialty_coffee': true},
    },

    // ── Bayan Baru ─────────────────────────────────────────────────────────
    {
      'name': 'Bayan Baru Market Food Court',
      'area': 'Bayan Baru',
      'category': 'Food & Dining',
      'lat': 5.3255,
      'lng': 100.2865,
      'desc': 'Bustling neighbourhood food centre known for Mee Jawa, Nasi Kandar, economy rice, and rojak.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Sunshine Square Mall',
      'area': 'Bayan Baru',
      'category': 'Shopping & Markets',
      'lat': 5.3250,
      'lng': 100.2875,
      'desc': 'Long-standing commercial department store and supermarket serving the Bayan Baru community.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Arena Curve Dining',
      'area': 'Bayan Baru',
      'category': 'Food & Dining',
      'lat': 5.3275,
      'lng': 100.2820,
      'desc': 'Modern commercial hub featuring trendy Korean BBQ, hotpot, western bistros, and bubble tea.',
      'features': {'has_aircon': true, 'wifi_available': true},
    },
    {
      'name': 'Daily Coffee Bayan Baru',
      'area': 'Bayan Baru',
      'category': 'Cafes',
      'lat': 5.3260,
      'lng': 100.2850,
      'desc': 'Cozy neighbourhood specialty cafe serving fresh coffee, pastries, and breakfast platters.',
      'features': {'has_aircon': true, 'wifi_available': true, 'specialty_coffee': true},
    },

    // ── Jelutong ───────────────────────────────────────────────────────────
    {
      'name': 'Pasar Awam & Balai Rakyat Batu Lanchang',
      'area': 'Jelutong',
      'category': 'Food & Dining',
      'lat': 5.3900,
      'lng': 100.3060,
      'desc': 'Famous food court renowned for crispy Chinese Pasir, fresh Nyonya kuih, and curry noodles.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Jelutong Street Market',
      'area': 'Jelutong',
      'category': 'Shopping & Markets',
      'lat': 5.3980,
      'lng': 100.3130,
      'desc': 'Vibrant local morning street market packed with fresh local tropical fruits, snacks, and street food.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Astaka Sungai Pinang',
      'area': 'Jelutong',
      'category': 'Food & Dining',
      'lat': 5.4050,
      'lng': 100.3200,
      'desc': 'Sprawling hawker centre celebrated for grilled seafood, satay, fried noodles, and chicken wings.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Bukit Dumbar Park',
      'area': 'Jelutong',
      'category': 'Nature & Parks',
      'lat': 5.3850,
      'lng': 100.3110,
      'desc': 'Lush hilltop reservoir park with walking tracks offering panoramic vistas of George Town and Penang Bridge.',
      'features': {'has_parking': true},
    },

    // ── Gelugor ────────────────────────────────────────────────────────────
    {
      'name': 'Muzium & Galeri Tuanku Fauziah (USM)',
      'area': 'Gelugor',
      'category': 'Heritage & Culture',
      'lat': 5.3570,
      'lng': 100.3015,
      'desc': 'University campus museum showcasing Southeast Asian ethnographic heritage and contemporary fine art.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Pasar Malam Taman Tun Sardon',
      'area': 'Gelugor',
      'category': 'Food & Dining',
      'lat': 5.3690,
      'lng': 100.3050,
      'desc': 'Legendary evening market celebrated for authentic Malay street dishes, Roti Canai, and Kuih Melayu.',
      'features': {'is_halal': true, 'has_parking': true},
    },
    {
      'name': 'Jaya Restaurant (Gelugor)',
      'area': 'Gelugor',
      'category': 'Food & Dining',
      'lat': 5.3650,
      'lng': 100.3080,
      'desc': 'Popular banana leaf and Indian-Muslim restaurant famous for fish head curry and briyani.',
      'features': {'is_halal': true, 'has_parking': true},
    },
    {
      'name': 'Sungai Dua Night Market',
      'area': 'Gelugor',
      'category': 'Shopping & Markets',
      'lat': 5.3520,
      'lng': 100.2980,
      'desc': 'Bustling student night market near USM filled with local snacks, fried chicken, and drinks.',
      'features': {'has_parking': true},
    },

    // ── Butterworth ────────────────────────────────────────────────────────
    {
      'name': 'Penang Sentral & Ferry Terminal',
      'area': 'Butterworth',
      'category': 'Entertainment',
      'lat': 5.3970,
      'lng': 100.3660,
      'desc': 'Main integrated northern transit hub connecting trains, express buses, and the iconic Penang cross-strait ferry.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Tow Boo Kong Temple (北海斗母宫)',
      'area': 'Butterworth',
      'category': 'Religious Sites',
      'lat': 5.4320,
      'lng': 100.3855,
      'desc': 'One of Southeast Asia’s grandest Nine Emperor Gods temple complexes featuring carved stone dragon pillars.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Pantai Bersih & Robina Eco Park',
      'area': 'Butterworth',
      'category': 'Nature & Parks',
      'lat': 5.4410,
      'lng': 100.3800,
      'desc': 'Scenic coastal beachfront promenade popular for evening walks and seaside fresh seafood dining.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Khunthai Restaurant @ Butterworth',
      'area': 'Butterworth',
      'category': 'Food & Dining',
      'lat': 5.4420,
      'lng': 100.3790,
      'desc': 'Famous beachside authentic Thai restaurant known for spicy Tom Yam, steamed fish, and green curry.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Pasar Awam Apollo',
      'area': 'Butterworth',
      'category': 'Shopping & Markets',
      'lat': 5.4380,
      'lng': 100.3860,
      'desc': 'Lively Raja Uda morning market offering authentic mainland street food, kuih, and local delicacies.',
      'features': {'has_parking': true},
    },

    // ── Seberang Perai ─────────────────────────────────────────────────────
    {
      'name': 'Minor Basilica of St. Anne, Bukit Mertajam',
      'area': 'Seberang Perai',
      'category': 'Religious Sites',
      'lat': 5.3530,
      'lng': 100.4770,
      'desc': 'Globally renowned Roman Catholic pilgrimage basilica attracting hundreds of thousands during the annual feast.',
      'features': {'has_parking': true, 'is_wheelchair_accessible': true},
    },
    {
      'name': 'Cherok Tokun Nature Reserve',
      'area': 'Seberang Perai',
      'category': 'Nature & Parks',
      'lat': 5.3580,
      'lng': 100.4890,
      'desc': 'Verdant forest park featuring giant trees, natural streams, and hiking trails up Bukit Mertajam Peak.',
      'features': {'has_parking': true},
    },
    {
      'name': 'Design Village Outlet Mall',
      'area': 'Seberang Perai',
      'category': 'Shopping & Markets',
      'lat': 5.2420,
      'lng': 100.4360,
      'desc': 'Malaysia’s largest open-air green outlet shopping mall with discounted premium designer fashion brands.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'IKEA Batu Kawan',
      'area': 'Seberang Perai',
      'category': 'Shopping & Markets',
      'lat': 5.2340,
      'lng': 100.4390,
      'desc': 'Northern Malaysia flagship home furnishing store with family restaurant serving Swedish meatballs.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true, 'wifi_available': true},
    },
    {
      'name': 'AEON Mall Bukit Mertajam',
      'area': 'Seberang Perai',
      'category': 'Shopping & Markets',
      'lat': 5.3210,
      'lng': 100.4780,
      'desc': 'Major retail and entertainment complex in Bukit Mertajam with cinema, supermarket, and family dining.',
      'features': {'has_aircon': true, 'has_parking': true, 'is_wheelchair_accessible': true},
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    _debounceTimer?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    try {
      final res = await _placesService.searchMultiplePlaces(query);
      if (!mounted) return;

      final mapped = res.map((p) {
        // Parse coordinates
        double lat = 5.4140;
        double lng = 100.3280;
        if (p['coordinates'] != null) {
          try {
            final coords = json.decode(p['coordinates']!);
            if (coords is List && coords.length >= 2) {
              lng = (coords[0] as num).toDouble();
              lat = (coords[1] as num).toDouble();
            }
          } catch (_) {}
        }

        // Parse features
        Map<String, bool> feats = {};
        if (p['features'] != null) {
          try {
            final decoded = json.decode(p['features']!);
            if (decoded is Map) {
              feats = decoded.map((k, v) => MapEntry(k.toString(), v == true));
            }
          } catch (_) {}
        }

        // Parse sub-categories
        List<String> subCats = [];
        if (p['sub_categories'] != null) {
          try {
            final decoded = json.decode(p['sub_categories']!);
            if (decoded is List) {
              subCats = decoded.map((e) => e.toString()).toList();
            }
          } catch (_) {}
        }

        final primaryCat = p['primary_category'] ?? p['category'] ?? 'Others';

        return {
          'name': p['title'] ?? 'Penang Place',
          'area': p['area'] ?? 'Penang',
          'address': p['address'] ?? '',
          'category': primaryCat,
          'primaryCategory': primaryCat,
          'subCategories': subCats,
          'features': feats,
          'businessHours': p['businessHours'],
          'openingHours': p['opening_hours'] ?? p['businessHours'],
          'lat': lat,
          'lng': lng,
          'desc': p['description'] ?? '',
        };
      }).toList();

      setState(() {
        _searchResults = mapped;
        _isSearching = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  // ── Filtered List ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _currentItems {
    var list = _searchController.text.trim().isNotEmpty
        ? _searchResults
        : _popularSuggestions;

    // 1. Filter by Category
    if (_selectedCategory != 'All') {
      list = list.where((item) {
        final cat = (item['category'] ?? '').toString();
        final primary = (item['primaryCategory'] ?? '').toString();
        return cat.toLowerCase().contains(_selectedCategory.toLowerCase()) ||
            primary.toLowerCase().contains(_selectedCategory.toLowerCase());
      }).toList();
    }

    // 2. Filter by Penang Area
    if (_selectedArea != 'All') {
      final target = _selectedArea.toLowerCase();
      list = list.where((item) {
        final area = (item['area'] ?? '').toString().toLowerCase();
        final address = (item['address'] ?? '').toString().toLowerCase();
        final name = (item['name'] ?? '').toString().toLowerCase();
        final desc = (item['desc'] ?? '').toString().toLowerCase();
        return area.contains(target) ||
            address.contains(target) ||
            name.contains(target) ||
            desc.contains(target);
      }).toList();
    }

    return list;
  }

  bool _isPlaceInDraft(String placeName) {
    return widget.controller.draftItinerary.any(
      (p) => p.name.trim().toLowerCase() == placeName.trim().toLowerCase(),
    );
  }

  void _addPlace(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? 'Penang Place';
    final area = item['area']?.toString() ?? 'Penang';
    final address = item['address']?.toString() ?? '';
    final category = item['category']?.toString() ?? 'Others';
    final primaryCat = item['primaryCategory']?.toString() ?? category;
    final desc = item['desc']?.toString() ?? '';
    final lat = (item['lat'] as num?)?.toDouble() ?? 5.4140;
    final lng = (item['lng'] as num?)?.toDouble() ?? 100.3280;

    List<String> subCats = [];
    if (item['subCategories'] is List) {
      subCats = List<String>.from(item['subCategories'] as List);
    }

    Map<String, bool> features = {};
    if (item['features'] is Map) {
      (item['features'] as Map).forEach((k, v) {
        features[k.toString()] = v == true;
      });
    }

    final newPlace = ItineraryPlace(
      id: 'search_add_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      area: area,
      address: address,
      description: desc,
      category: category,
      primaryCategory: primaryCat,
      subCategories: subCats,
      features: features,
      openingHours: item['openingHours'] ?? item['businessHours'],
      businessHours: item['businessHours']?.toString(),
      imageUrl: item['imagePath']?.toString() ?? item['imageUrl']?.toString() ?? item['thumbnail']?.toString(),
      lat: lat,
      lng: lng,
      estimatedStayMinutes: 60,
    );

    final success = widget.controller.addPlaceToDraft(newPlace, notifyChat: false);

    if (success && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Added "$name" to draft plan! (${widget.controller.draftItinerary.length} places)',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'SF Pro'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E293B),
          duration: const Duration(milliseconds: 1600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _openAreaFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.70,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Color(0xFF304FFE), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Filter by Penang Area',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF19244E),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                  if (_selectedArea != 'All')
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedArea = 'All');
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'Reset Filter',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a Penang district to narrow down places:',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontFamily: 'SF Pro'),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: _penangAreas.length,
                  separatorBuilder: (context, i) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, idx) {
                    final area = _penangAreas[idx];
                    final isSelected = _selectedArea == area;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF304FFE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          area == 'All' ? Icons.map_outlined : Icons.place_rounded,
                          size: 18,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                      title: Text(
                        area == 'All' ? 'All Areas in Penang' : area,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF304FFE) : const Color(0xFF1E293B),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF304FFE), size: 20)
                          : null,
                      onTap: () {
                        setState(() => _selectedArea = area);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── UI Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final draftCount = widget.controller.draftItinerary.length;
    final items = _currentItems;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF19244E)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search & Add Places',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF19244E),
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
        actions: [
          // Done button showing current draft count
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF304FFE),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$draftCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto Mono',
                ),
              ),
            ),
            label: const Text(
              'Done',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF304FFE),
                fontFamily: 'SF Pro',
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: Column(
        children: [
          // ── Search Input Box & Area Filter Button (Same Row) ───────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // Search Input Box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (q) => _performSearch(q.trim()),
                      decoration: InputDecoration(
                        hintText: 'Search Penang places, cafes...',
                        hintStyle: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF94A3B8),
                          fontFamily: 'SF Pro',
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchResults = [];
                                    _isSearching = false;
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Area Filter Button
                InkWell(
                  onTap: () => _openAreaFilterDialog(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedArea != 'All'
                          ? const Color(0xFF304FFE)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _selectedArea != 'All'
                            ? const Color(0xFF304FFE)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 20,
                          color: _selectedArea != 'All'
                              ? Colors.white
                              : const Color(0xFF19244E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _selectedArea == 'All' ? 'Area' : _selectedArea,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _selectedArea != 'All'
                                ? Colors.white
                                : const Color(0xFF19244E),
                            fontFamily: 'SF Pro',
                          ),
                        ),
                        if (_selectedArea != 'All') ...[
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedArea = 'All');
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Category Filter Chips ───────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categoryFilters.length,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cat = _categoryFilters[idx];
                final isSelected = _selectedCategory == cat;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF304FFE) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF304FFE) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 10),

          // ── Section Title ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _searchController.text.trim().isNotEmpty
                      ? Icons.search_rounded
                      : Icons.local_fire_department_rounded,
                  size: 16,
                  color: _searchController.text.trim().isNotEmpty
                      ? const Color(0xFF304FFE)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Text(
                  _searchController.text.trim().isNotEmpty
                      ? 'Search Results${_selectedArea != 'All' ? ' in $_selectedArea' : ''} (${items.length})'
                      : 'Popular Spots${_selectedArea != 'All' ? ' in $_selectedArea' : ''} (${items.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'SF Pro',
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 12, color: Color(0xFFF1F5F9)),

          // ── Place List ──────────────────────────────────────────────────
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF304FFE)),
                  )
                : items.isEmpty
                    ? _buildNoResultsState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: items.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final name = item['name']?.toString() ?? '';
                          final area = item['area']?.toString() ?? 'Penang';
                          final category = item['category']?.toString() ?? 'Others';
                          final desc = item['desc']?.toString() ?? '';
                          final isAdded = _isPlaceInDraft(name);

                          final catBg = _categoryBgColors[category] ?? const Color(0xFFF1F5F9);
                          final catText = _categoryTextColors[category] ?? const Color(0xFF475569);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isAdded ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x05000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Place Information
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category Tag on TOP of Place Name
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: catBg,
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          category,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: catText,
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Place Name
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1E293B),
                                          fontFamily: 'SF Pro',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),

                                      // Area
                                      if (area.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_on_outlined,
                                                size: 12, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 3),
                                            Text(
                                              area,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Color(0xFF94A3B8),
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      // Short Description
                                      if (desc.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          desc,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.grey.shade600,
                                            fontFamily: 'SF Pro',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                // Add Button
                                isAdded
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                color: Color(0xFF16A34A), size: 15),
                                            SizedBox(width: 4),
                                            Text(
                                              'Added',
                                              style: TextStyle(
                                                color: Color(0xFF16A34A),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF304FFE),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          elevation: 0,
                                        ),
                                        icon: const Icon(Icons.add, size: 15),
                                        label: const Text(
                                          'Add',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                        onPressed: () => _addPlace(item),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 54, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedArea != 'All'
                  ? 'No places found in $_selectedArea'
                  : 'No places found',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                fontFamily: 'SF Pro',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _selectedArea != 'All'
                  ? 'Try selecting a different area or reset the area filter.'
                  : 'Try searching with a different keyword or browse popular spots above.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Colors.grey, fontFamily: 'SF Pro'),
            ),
            if (_selectedArea != 'All') ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF304FFE),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _selectedArea = 'All'),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text('Reset Area Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
