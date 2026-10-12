import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankRequirement {
  final String title;
  final String description;
  final double target;
  final String unit;
  final IconData icon;

  const RankRequirement({
    required this.title,
    required this.description,
    required this.target,
    required this.unit,
    required this.icon,
  });
}

enum UserRank {
  tourist,
  traveler,
  explorer,
  adventurer,
  legend;

  String get displayName {
    switch (this) {
      case UserRank.tourist:
        return 'Tourist';
      case UserRank.traveler:
        return 'Traveler';
      case UserRank.explorer:
        return 'Explorer';
      case UserRank.adventurer:
        return 'Adventurer';
      case UserRank.legend:
        return 'Legend';
    }
  }

  String get badgeTitle {
    switch (this) {
      case UserRank.tourist:
        return 'Tourist Badge';
      case UserRank.traveler:
        return 'Traveler Badge';
      case UserRank.explorer:
        return 'Explorer Badge';
      case UserRank.adventurer:
        return 'Adventurer Badge';
      case UserRank.legend:
        return 'Legend Badge';
    }
  }

  String get theme {
    switch (this) {
      case UserRank.tourist:
        return 'Heritage landmarks, heritage transport, and local treats.';
      case UserRank.traveler:
        return 'Outstation/island exploration, tropical fruits, and local produce.';
      case UserRank.explorer:
        return 'Nature trails, outdoor adventure, and eco-heritage.';
      case UserRank.adventurer:
        return 'Infrastructure, coastal routes, and iconic bridges/ferries.';
      case UserRank.legend:
        return 'Mastery tier combining heritage architecture, skyline views, and culinary icons.';
    }
  }

  String get badgeAssetPath {
    switch (this) {
      case UserRank.tourist:
        return 'assets/badges/tourist-badge.jpg';
      case UserRank.traveler:
        return 'assets/badges/traveller-badge.jpg';
      case UserRank.explorer:
        return 'assets/badges/explorer-badge.jpg';
      case UserRank.adventurer:
        return 'assets/badges/adventure-badge.jpg';
      case UserRank.legend:
        return 'assets/badges/legend-badge.jpg';
    }
  }

  String get description {
    switch (this) {
      case UserRank.tourist:
        return 'Welcome to Penang! Start exploring UNESCO heritage landmarks and iconic foods to level up.';
      case UserRank.traveler:
        return 'You are on your way! Actively exploring outside George Town, tropical produce, and attractions.';
      case UserRank.explorer:
        return 'Eco-heritage pioneer! Completing nature trails and tracking active mobility across Penang.';
      case UserRank.adventurer:
        return 'A seasoned adventurer! Crossing iconic Penang bridges and discovering coastal landmarks.';
      case UserRank.legend:
        return 'The ultimate Penang master! Complete the 25+ stamps collection and Penny itineraries.';
    }
  }

  int get requiredRoutes {
    switch (this) {
      case UserRank.tourist: return 0;
      case UserRank.traveler: return 2;
      case UserRank.explorer: return 5;
      case UserRank.adventurer: return 10;
      case UserRank.legend: return 20;
    }
  }

  IconData get icon {
    switch (this) {
      case UserRank.tourist:
        return Icons.hiking_rounded;
      case UserRank.traveler:
        return Icons.explore_rounded;
      case UserRank.explorer:
        return Icons.star_border_rounded;
      case UserRank.adventurer:
        return Icons.emoji_events_outlined;
      case UserRank.legend:
        return Icons.diamond_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRank.tourist:
        return const Color(0xFF26A69A);
      case UserRank.traveler:
        return const Color(0xFF1E88E5);
      case UserRank.explorer:
        return const Color(0xFFFFA000);
      case UserRank.adventurer:
        return const Color(0xFFFF5722);
      case UserRank.legend:
        return const Color(0xFF8E24AA);
    }
  }

  UserRank? get nextRank {
    switch (this) {
      case UserRank.tourist:
        return UserRank.traveler;
      case UserRank.traveler:
        return UserRank.explorer;
      case UserRank.explorer:
        return UserRank.adventurer;
      case UserRank.adventurer:
        return UserRank.legend;
      case UserRank.legend:
        return null;
    }
  }

  List<RankRequirement> get requirements {
    switch (this) {
      case UserRank.tourist:
        return const [
          RankRequirement(
            title: 'Check-ins',
            description: 'Visit and check in to 3 different UNESCO Heritage Zone landmarks (e.g., Fort Cornwallis, Cheong Fatt Tze Mansion, Pinang Peranakan Mansion).',
            target: 3.0,
            unit: 'landmarks',
            icon: Icons.account_balance_rounded,
          ),
          RankRequirement(
            title: 'Food/Culture',
            description: 'Scan and log 2 iconic Penang street foods (e.g., Ais Kacang, Char Kway Teow, or Penang Laksa).',
            target: 2.0,
            unit: 'foods',
            icon: Icons.restaurant_rounded,
          ),
        ];

      case UserRank.traveler:
        return const [
          RankRequirement(
            title: 'Geofenced Check-ins',
            description: 'Check in to 2 different districts outside George Town (e.g., Balik Pulau, Tanjung Bungah, or Teluk Bahang).',
            target: 2.0,
            unit: 'districts',
            icon: Icons.map_rounded,
          ),
          RankRequirement(
            title: 'Local Harvest OR Attractions',
            description: 'Visit a designated agricultural spot or orchard and log 2 local seasonal produce items (e.g., Balik Pulau Durian, Nutmeg / Buah Pala, or Clove) OR explore and check into 2 nature or cultural attractions (e.g., Kek Lok Si Temple, Entopia, or The Habitat).',
            target: 2.0,
            unit: 'spots / items',
            icon: Icons.eco_rounded,
          ),
        ];

      case UserRank.explorer:
        return const [
          RankRequirement(
            title: 'Trail Discovery',
            description: 'Complete at least 2 distinct nature trails or hiking routes (e.g., Penang Hill trails, Monkey Beach trail, or Botanical Gardens paths).',
            target: 2.0,
            unit: 'trails',
            icon: Icons.hiking_rounded,
          ),
          RankRequirement(
            title: 'Active Mobility',
            description: 'Log a cumulative total of 10 km of walking or cycling tracked via the app within any heritage or park zone.',
            target: 10.0,
            unit: 'km',
            icon: Icons.directions_walk_rounded,
          ),
        ];

      case UserRank.adventurer:
        return const [
          RankRequirement(
            title: 'Bridge Crossings',
            description: 'Log travel across Penang Bridge (First Bridge) at least twice.',
            target: 2.0,
            unit: 'crossings',
            icon: Icons.directions_car_rounded,
          ),
          RankRequirement(
            title: 'Coastal Check-ins',
            description: 'Check in to 3 coastal or seafront landmarks (e.g., Gurney Bay, Esplanade sea wall, or Straits Quay).',
            target: 3.0,
            unit: 'landmarks',
            icon: Icons.waves_rounded,
          ),
          RankRequirement(
            title: 'Seaside Food Stop',
            description: 'Check in and log 1 meal or drink at a coastal/seafront food spot (e.g., enjoying fresh seafood at Gurney Drive Hawker Centre, coconut shake by the beach, or café hopping along Straits Quay).',
            target: 1.0,
            unit: 'stop',
            icon: Icons.local_cafe_rounded,
          ),
        ];

      case UserRank.legend:
        return const [
          RankRequirement(
            title: 'Complete Collection',
            description: 'Unlock at least 25 individual check-in stamps across George Town and the mainland.',
            target: 25.0,
            unit: 'stamps',
            icon: Icons.stars_rounded,
          ),
          RankRequirement(
            title: 'Itinerary Milestone',
            description: 'Complete 3 Penny Generated itineraries curated by the Kia-Kia Penang app.',
            target: 3.0,
            unit: 'itineraries',
            icon: Icons.auto_awesome_rounded,
          ),
        ];
    }
  }

  double getCurrentValue(UserProfile profile, int reqIndex) {
    switch (this) {
      case UserRank.tourist:
        if (reqIndex == 0) return profile.heritageCheckIns.toDouble();
        return profile.streetFoodsLogged.toDouble();
      case UserRank.traveler:
        if (reqIndex == 0) return profile.outstationCheckIns.toDouble();
        return profile.localAttractionsOrHarvest.toDouble();
      case UserRank.explorer:
        if (reqIndex == 0) return profile.natureTrailsCompleted.toDouble();
        return profile.activeMobilityKm;
      case UserRank.adventurer:
        if (reqIndex == 0) return profile.bridgeCrossings.toDouble();
        if (reqIndex == 1) return profile.coastalCheckIns.toDouble();
        return profile.seasideFoodStops.toDouble();
      case UserRank.legend:
        if (reqIndex == 0) return profile.unlockedStampsCount.toDouble();
        return profile.pennyItinerariesCompleted.toDouble();
    }
  }

  double getProgressRatio(UserProfile profile) {
    final reqs = requirements;
    if (reqs.isEmpty) return 1.0;
    double sumRatio = 0.0;
    for (int i = 0; i < reqs.length; i++) {
      final cur = getCurrentValue(profile, i);
      final target = reqs[i].target;
      sumRatio += (cur / target).clamp(0.0, 1.0);
    }
    return sumRatio / reqs.length;
  }

  bool isCompleted(UserProfile profile) {
    final reqs = requirements;
    for (int i = 0; i < reqs.length; i++) {
      final cur = getCurrentValue(profile, i);
      final target = reqs[i].target;
      if (cur < target) return false;
    }
    return true;
  }

  String getProgressSummary(UserProfile profile) {
    switch (this) {
      case UserRank.tourist:
        return '${profile.heritageCheckIns}/3 Landmarks · ${profile.streetFoodsLogged}/2 Foods';
      case UserRank.traveler:
        return '${profile.outstationCheckIns}/2 Districts · ${profile.localAttractionsOrHarvest}/2 Attractions';
      case UserRank.explorer:
        return '${profile.natureTrailsCompleted}/2 Trails · ${profile.activeMobilityKm.toStringAsFixed(1)}/10.0 km';
      case UserRank.adventurer:
        return '${profile.bridgeCrossings}/2 Bridges · ${profile.coastalCheckIns}/3 Coastal · ${profile.seasideFoodStops}/1 Seaside';
      case UserRank.legend:
        return '${profile.unlockedStampsCount}/25 Stamps · ${profile.pennyItinerariesCompleted}/3 Itineraries';
    }
  }
}

class UserProfile {
  final String name;
  final String email;
  final String phone;
  final String joinedDate;
  final UserRank rank;
  final int completedRoutes;
  final double distanceTravelled; // in km
  final List<String> travelStyles;
  final String nationality;
  final int? nationalityLastUpdatedYear;
  final DateTime? nameLastUpdatedDate;
  final List<String> dietaryPreferences;
  final bool isEmailVerified;
  final bool isPhoneVerified;

  // Granular milestone counters for badge unlock requirements
  final int heritageCheckIns;
  final int streetFoodsLogged;
  final int outstationCheckIns;
  final int localAttractionsOrHarvest;
  final int natureTrailsCompleted;
  final double activeMobilityKm;
  final int bridgeCrossings;
  final int coastalCheckIns;
  final int seasideFoodStops;
  final int unlockedStampsCount;
  final int pennyItinerariesCompleted;

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.joinedDate,
    required this.rank,
    required this.completedRoutes,
    required this.distanceTravelled,
    required this.travelStyles,
    this.nationality = 'Malaysia 🇲🇾',
    this.nationalityLastUpdatedYear,
    this.nameLastUpdatedDate,
    this.dietaryPreferences = const ['Halal', 'Pork-Free'],
    this.isEmailVerified = false,
    this.isPhoneVerified = false,
    this.heritageCheckIns = 1,
    this.streetFoodsLogged = 1,
    this.outstationCheckIns = 0,
    this.localAttractionsOrHarvest = 0,
    this.natureTrailsCompleted = 0,
    this.activeMobilityKm = 2.5,
    this.bridgeCrossings = 0,
    this.coastalCheckIns = 0,
    this.seasideFoodStops = 0,
    this.unlockedStampsCount = 1,
    this.pennyItinerariesCompleted = 1,
  });

  /// The active badge goal the user is currently working towards
  UserRank get activeBadgeGoal {
    if (rank == UserRank.legend) return UserRank.legend;
    if (rank == UserRank.adventurer) return UserRank.legend;
    if (rank == UserRank.explorer) return UserRank.adventurer;
    if (rank == UserRank.traveler) return UserRank.explorer;
    
    // For tourist rank: if tourist badge requirements are not yet complete, goal is tourist
    if (heritageCheckIns < 3 || streetFoodsLogged < 2) {
      return UserRank.tourist;
    }
    return UserRank.traveler;
  }

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? joinedDate,
    UserRank? rank,
    int? completedRoutes,
    double? distanceTravelled,
    List<String>? travelStyles,
    String? nationality,
    int? nationalityLastUpdatedYear,
    DateTime? nameLastUpdatedDate,
    List<String>? dietaryPreferences,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    int? heritageCheckIns,
    int? streetFoodsLogged,
    int? outstationCheckIns,
    int? localAttractionsOrHarvest,
    int? natureTrailsCompleted,
    double? activeMobilityKm,
    int? bridgeCrossings,
    int? coastalCheckIns,
    int? seasideFoodStops,
    int? unlockedStampsCount,
    int? pennyItinerariesCompleted,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      joinedDate: joinedDate ?? this.joinedDate,
      rank: rank ?? this.rank,
      completedRoutes: completedRoutes ?? this.completedRoutes,
      distanceTravelled: distanceTravelled ?? this.distanceTravelled,
      travelStyles: travelStyles ?? this.travelStyles,
      nationality: nationality ?? this.nationality,
      nationalityLastUpdatedYear: nationalityLastUpdatedYear ?? this.nationalityLastUpdatedYear,
      nameLastUpdatedDate: nameLastUpdatedDate ?? this.nameLastUpdatedDate,
      dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      heritageCheckIns: heritageCheckIns ?? this.heritageCheckIns,
      streetFoodsLogged: streetFoodsLogged ?? this.streetFoodsLogged,
      outstationCheckIns: outstationCheckIns ?? this.outstationCheckIns,
      localAttractionsOrHarvest: localAttractionsOrHarvest ?? this.localAttractionsOrHarvest,
      natureTrailsCompleted: natureTrailsCompleted ?? this.natureTrailsCompleted,
      activeMobilityKm: activeMobilityKm ?? this.activeMobilityKm,
      bridgeCrossings: bridgeCrossings ?? this.bridgeCrossings,
      coastalCheckIns: coastalCheckIns ?? this.coastalCheckIns,
      seasideFoodStops: seasideFoodStops ?? this.seasideFoodStops,
      unlockedStampsCount: unlockedStampsCount ?? this.unlockedStampsCount,
      pennyItinerariesCompleted: pennyItinerariesCompleted ?? this.pennyItinerariesCompleted,
    );
  }
}

class UserProfileManager {
  static final UserProfile _defaultProfile = UserProfile(
    name: 'vennis',
    email: 'venniscc04@gmail.com',
    phone: '',
    joinedDate: 'August 2026',
    rank: UserRank.tourist,
    completedRoutes: 1,
    distanceTravelled: 2.5,
    travelStyles: ['Foodie', 'Nature Lover', 'Adventure'],
    nationality: 'Malaysia 🇲🇾',
    dietaryPreferences: ['Halal', 'Pork-Free'],
    isEmailVerified: false,
    isPhoneVerified: false,
    heritageCheckIns: 1,
    streetFoodsLogged: 1,
    outstationCheckIns: 0,
    localAttractionsOrHarvest: 0,
    natureTrailsCompleted: 0,
    activeMobilityKm: 2.5,
    bridgeCrossings: 0,
    coastalCheckIns: 0,
    seasideFoodStops: 0,
    unlockedStampsCount: 1,
    pennyItinerariesCompleted: 1,
  );

  static final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(_defaultProfile);

  // Initialize and load saved state from Firestore or local cache
  static Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // Sync unlocked stamps count from local cache if available
    final localStamps = prefs.getStringList('local_unlocked_stamps') ?? [];
    final stampsCount = localStamps.length;

    // 1. Fetch from Firestore if Firebase user is logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          final rankVal = (data['rank'] as num?)?.toInt() ?? 0;
          final userProfile = UserProfile(
            name: (data['name'] as String?)?.isNotEmpty == true
                ? data['name']
                : (user.displayName ?? 'vennis'),
            email: user.email ?? (data['email'] as String?) ?? '',
            phone: (data['phone'] as String?) ?? user.phoneNumber ?? '',
            joinedDate: (data['joinedDate'] as String?) ?? 'August 2026',
            rank: (rankVal >= 0 && rankVal < UserRank.values.length)
                ? UserRank.values[rankVal]
                : UserRank.tourist,
            completedRoutes: (data['completedRoutes'] as num?)?.toInt() ?? 1,
            distanceTravelled: (data['distanceTravelled'] as num?)?.toDouble() ?? 2.5,
            travelStyles: List<String>.from(data['travelStyles'] ?? []),
            nationality: (data['nationality'] as String?)?.isNotEmpty == true
                ? data['nationality']
                : 'Malaysia 🇲🇾',
            nationalityLastUpdatedYear: (data['nationalityLastUpdatedYear'] as num?)?.toInt(),
            nameLastUpdatedDate: data['nameLastUpdatedDate'] != null
                ? (data['nameLastUpdatedDate'] is Timestamp
                    ? (data['nameLastUpdatedDate'] as Timestamp).toDate()
                    : DateTime.tryParse(data['nameLastUpdatedDate'].toString()))
                : null,
            dietaryPreferences: List<String>.from(data['dietaryPreferences'] ?? ['Halal', 'Pork-Free']),
            isEmailVerified: data['isEmailVerified'] as bool? ?? false,
            heritageCheckIns: (data['heritageCheckIns'] as num?)?.toInt() ?? 1,
            streetFoodsLogged: (data['streetFoodsLogged'] as num?)?.toInt() ?? 1,
            outstationCheckIns: (data['outstationCheckIns'] as num?)?.toInt() ?? 0,
            localAttractionsOrHarvest: (data['localAttractionsOrHarvest'] as num?)?.toInt() ?? 0,
            natureTrailsCompleted: (data['natureTrailsCompleted'] as num?)?.toInt() ?? 0,
            activeMobilityKm: (data['activeMobilityKm'] as num?)?.toDouble() ?? (data['distanceTravelled'] as num?)?.toDouble() ?? 2.5,
            bridgeCrossings: (data['bridgeCrossings'] as num?)?.toInt() ?? 0,
            coastalCheckIns: (data['coastalCheckIns'] as num?)?.toInt() ?? 0,
            seasideFoodStops: (data['seasideFoodStops'] as num?)?.toInt() ?? 0,
            unlockedStampsCount: (data['unlockedStampsCount'] as num?)?.toInt() ?? (stampsCount > 0 ? stampsCount : 1),
            pennyItinerariesCompleted: (data['pennyItinerariesCompleted'] as num?)?.toInt() ?? (data['completedRoutes'] as num?)?.toInt() ?? 1,
          );

          profileNotifier.value = userProfile;

          // Cache locally
          await prefs.setString('user_name', userProfile.name);
          await prefs.setString('user_email', userProfile.email);
          await prefs.setString('user_phone', userProfile.phone);
          await prefs.setString('user_joined', userProfile.joinedDate);
          await prefs.setString('user_nationality', userProfile.nationality);
          if (userProfile.nationalityLastUpdatedYear != null) {
            await prefs.setInt('user_nationality_last_updated_year', userProfile.nationalityLastUpdatedYear!);
          }
          if (userProfile.nameLastUpdatedDate != null) {
            await prefs.setString('user_name_last_updated_date', userProfile.nameLastUpdatedDate!.toIso8601String());
          }
          await prefs.setStringList('user_dietary_preferences', userProfile.dietaryPreferences);
          await prefs.setBool('user_email_verified', userProfile.isEmailVerified);
          await prefs.setInt('user_rank', userProfile.rank.index);
          await prefs.setInt('user_routes', userProfile.completedRoutes);
          await prefs.setDouble('user_distance', userProfile.distanceTravelled);
          await prefs.setStringList('user_styles', userProfile.travelStyles);
          await prefs.setInt('user_heritage_checkins', userProfile.heritageCheckIns);
          await prefs.setInt('user_street_foods', userProfile.streetFoodsLogged);
          await prefs.setInt('user_outstation_checkins', userProfile.outstationCheckIns);
          await prefs.setInt('user_harvest_attractions', userProfile.localAttractionsOrHarvest);
          await prefs.setInt('user_nature_trails', userProfile.natureTrailsCompleted);
          await prefs.setDouble('user_active_mobility', userProfile.activeMobilityKm);
          await prefs.setInt('user_bridge_crossings', userProfile.bridgeCrossings);
          await prefs.setInt('user_coastal_checkins', userProfile.coastalCheckIns);
          await prefs.setInt('user_seaside_food_stops', userProfile.seasideFoodStops);
          await prefs.setInt('user_unlocked_stamps', userProfile.unlockedStampsCount);
          await prefs.setInt('user_penny_itineraries', userProfile.pennyItinerariesCompleted);
          return;
        }
      }
    } catch (e) {
      debugPrint("UserProfileManager.loadProfile Firebase error: $e");
    }

    // 2. Fallback to cached values in SharedPreferences
    final name = prefs.getString('user_name') ?? _defaultProfile.name;
    final email = prefs.getString('user_email') ?? _defaultProfile.email;
    final phone = prefs.getString('user_phone') ?? _defaultProfile.phone;
    final joinedDate = prefs.getString('user_joined') ?? _defaultProfile.joinedDate;
    final rankIndex = prefs.getInt('user_rank') ?? _defaultProfile.rank.index;
    final routes = prefs.getInt('user_routes') ?? _defaultProfile.completedRoutes;
    final distance = prefs.getDouble('user_distance') ?? _defaultProfile.distanceTravelled;
    final styles = prefs.getStringList('user_styles') ?? _defaultProfile.travelStyles;
    final nationality = prefs.getString('user_nationality') ?? _defaultProfile.nationality;
    final nationalityYear = prefs.getInt('user_nationality_last_updated_year');
    final nameDateStr = prefs.getString('user_name_last_updated_date');
    final nameLastUpdatedDate = nameDateStr != null ? DateTime.tryParse(nameDateStr) : null;
    final dietary = prefs.getStringList('user_dietary_preferences') ?? _defaultProfile.dietaryPreferences;
    final isEmailVerified = prefs.getBool('user_email_verified') ?? _defaultProfile.isEmailVerified;
    final isPhoneVerified = prefs.getBool('user_phone_verified') ?? _defaultProfile.isPhoneVerified;

    final heritageCheckIns = prefs.getInt('user_heritage_checkins') ?? _defaultProfile.heritageCheckIns;
    final streetFoodsLogged = prefs.getInt('user_street_foods') ?? _defaultProfile.streetFoodsLogged;
    final outstationCheckIns = prefs.getInt('user_outstation_checkins') ?? _defaultProfile.outstationCheckIns;
    final localAttractions = prefs.getInt('user_harvest_attractions') ?? _defaultProfile.localAttractionsOrHarvest;
    final natureTrails = prefs.getInt('user_nature_trails') ?? _defaultProfile.natureTrailsCompleted;
    final activeMobility = prefs.getDouble('user_active_mobility') ?? (distance > 0 ? distance : _defaultProfile.activeMobilityKm);
    final bridgeCrossings = prefs.getInt('user_bridge_crossings') ?? _defaultProfile.bridgeCrossings;
    final coastalCheckIns = prefs.getInt('user_coastal_checkins') ?? _defaultProfile.coastalCheckIns;
    final seasideFoodStops = prefs.getInt('user_seaside_food_stops') ?? _defaultProfile.seasideFoodStops;
    final unlockedStamps = prefs.getInt('user_unlocked_stamps') ?? (stampsCount > 0 ? stampsCount : _defaultProfile.unlockedStampsCount);
    final pennyItineraries = prefs.getInt('user_penny_itineraries') ?? (routes > 0 ? routes : _defaultProfile.pennyItinerariesCompleted);

    profileNotifier.value = UserProfile(
      name: name,
      email: email,
      phone: phone,
      joinedDate: joinedDate,
      rank: (rankIndex >= 0 && rankIndex < UserRank.values.length)
          ? UserRank.values[rankIndex]
          : UserRank.tourist,
      completedRoutes: routes,
      distanceTravelled: distance,
      travelStyles: styles,
      nationality: nationality,
      nationalityLastUpdatedYear: nationalityYear,
      nameLastUpdatedDate: nameLastUpdatedDate,
      dietaryPreferences: dietary,
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
      heritageCheckIns: heritageCheckIns,
      streetFoodsLogged: streetFoodsLogged,
      outstationCheckIns: outstationCheckIns,
      localAttractionsOrHarvest: localAttractions,
      natureTrailsCompleted: natureTrails,
      activeMobilityKm: activeMobility,
      bridgeCrossings: bridgeCrossings,
      coastalCheckIns: coastalCheckIns,
      seasideFoodStops: seasideFoodStops,
      unlockedStampsCount: unlockedStamps,
      pennyItinerariesCompleted: pennyItineraries,
    );
  }

  // Update profile attributes locally and to Firestore
  static Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? nationality,
    int? nationalityLastUpdatedYear,
    DateTime? nameLastUpdatedDate,
    List<String>? dietaryPreferences,
    bool? isEmailVerified,
    bool? isPhoneVerified,
    List<String>? travelStyles,
    int? heritageCheckIns,
    int? streetFoodsLogged,
    int? outstationCheckIns,
    int? localAttractionsOrHarvest,
    int? natureTrailsCompleted,
    double? activeMobilityKm,
    int? bridgeCrossings,
    int? coastalCheckIns,
    int? seasideFoodStops,
    int? unlockedStampsCount,
    int? pennyItinerariesCompleted,
  }) async {
    final current = profileNotifier.value;

    final updatedHeritage = heritageCheckIns ?? current.heritageCheckIns;
    final updatedFoods = streetFoodsLogged ?? current.streetFoodsLogged;
    final updatedOutstation = outstationCheckIns ?? current.outstationCheckIns;
    final updatedAttractions = localAttractionsOrHarvest ?? current.localAttractionsOrHarvest;
    final updatedTrails = natureTrailsCompleted ?? current.natureTrailsCompleted;
    final updatedMobility = activeMobilityKm ?? current.activeMobilityKm;
    final updatedBridges = bridgeCrossings ?? current.bridgeCrossings;
    final updatedCoastal = coastalCheckIns ?? current.coastalCheckIns;
    final updatedSeaside = seasideFoodStops ?? current.seasideFoodStops;
    final updatedStamps = unlockedStampsCount ?? current.unlockedStampsCount;
    final updatedPenny = pennyItinerariesCompleted ?? current.pennyItinerariesCompleted;

    // Evaluate rank dynamically based on unlocked badges
    UserRank finalRank = current.rank;
    if (updatedStamps >= 25 && updatedPenny >= 3) {
      finalRank = UserRank.legend;
    } else if (updatedBridges >= 2 && updatedCoastal >= 3 && updatedSeaside >= 1) {
      finalRank = UserRank.adventurer;
    } else if (updatedTrails >= 2 && updatedMobility >= 10.0) {
      finalRank = UserRank.explorer;
    } else if (updatedOutstation >= 2 && updatedAttractions >= 2) {
      finalRank = UserRank.traveler;
    } else {
      finalRank = UserRank.tourist;
    }

    final effectiveNameDate = nameLastUpdatedDate ?? (name != null && name != current.name ? DateTime.now() : current.nameLastUpdatedDate);

    final updated = current.copyWith(
      name: name,
      email: email,
      phone: phone,
      nationality: nationality,
      nationalityLastUpdatedYear: nationalityLastUpdatedYear ?? (nationality != null && nationality != current.nationality ? DateTime.now().year : current.nationalityLastUpdatedYear),
      nameLastUpdatedDate: effectiveNameDate,
      dietaryPreferences: dietaryPreferences,
      isEmailVerified: isEmailVerified,
      isPhoneVerified: isPhoneVerified,
      rank: finalRank,
      travelStyles: travelStyles,
      heritageCheckIns: updatedHeritage,
      streetFoodsLogged: updatedFoods,
      outstationCheckIns: updatedOutstation,
      localAttractionsOrHarvest: updatedAttractions,
      natureTrailsCompleted: updatedTrails,
      activeMobilityKm: updatedMobility,
      bridgeCrossings: updatedBridges,
      coastalCheckIns: updatedCoastal,
      seasideFoodStops: updatedSeaside,
      unlockedStampsCount: updatedStamps,
      pennyItinerariesCompleted: updatedPenny,
    );

    profileNotifier.value = updated;

    // Cache locally
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (email != null) await prefs.setString('user_email', email);
    if (phone != null) await prefs.setString('user_phone', phone);
    if (nationality != null) await prefs.setString('user_nationality', nationality);
    if (updated.nationalityLastUpdatedYear != null) {
      await prefs.setInt('user_nationality_last_updated_year', updated.nationalityLastUpdatedYear!);
    }
    if (updated.nameLastUpdatedDate != null) {
      await prefs.setString('user_name_last_updated_date', updated.nameLastUpdatedDate!.toIso8601String());
    }
    if (dietaryPreferences != null) await prefs.setStringList('user_dietary_preferences', dietaryPreferences);
    if (isEmailVerified != null) await prefs.setBool('user_email_verified', isEmailVerified);
    if (travelStyles != null) await prefs.setStringList('user_styles', travelStyles);
    await prefs.setInt('user_rank', finalRank.index);
    await prefs.setInt('user_heritage_checkins', updatedHeritage);
    await prefs.setInt('user_street_foods', updatedFoods);
    await prefs.setInt('user_outstation_checkins', updatedOutstation);
    await prefs.setInt('user_harvest_attractions', updatedAttractions);
    await prefs.setInt('user_nature_trails', updatedTrails);
    await prefs.setDouble('user_active_mobility', updatedMobility);
    await prefs.setInt('user_bridge_crossings', updatedBridges);
    await prefs.setInt('user_coastal_checkins', updatedCoastal);
    await prefs.setInt('user_seaside_food_stops', updatedSeaside);
    await prefs.setInt('user_unlocked_stamps', updatedStamps);
    await prefs.setInt('user_penny_itineraries', updatedPenny);

    // Write updates to Firestore if Firebase user is logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final updateMap = <String, dynamic>{};
        if (name != null) {
          updateMap['name'] = name;
          updateMap['nameLastUpdatedDate'] = effectiveNameDate != null ? Timestamp.fromDate(effectiveNameDate) : null;
        } else if (nameLastUpdatedDate != null) {
          updateMap['nameLastUpdatedDate'] = Timestamp.fromDate(nameLastUpdatedDate);
        }
        if (email != null) updateMap['email'] = email;
        if (phone != null) updateMap['phone'] = phone;
        if (nationality != null) {
          updateMap['nationality'] = nationality;
          updateMap['nationalityLastUpdatedYear'] = updated.nationalityLastUpdatedYear;
        } else if (nationalityLastUpdatedYear != null) {
          updateMap['nationalityLastUpdatedYear'] = nationalityLastUpdatedYear;
        }
        if (dietaryPreferences != null) updateMap['dietaryPreferences'] = dietaryPreferences;
        if (isEmailVerified != null) updateMap['isEmailVerified'] = isEmailVerified;
        if (travelStyles != null) updateMap['travelStyles'] = travelStyles;
        updateMap['rank'] = finalRank.index;
        updateMap['heritageCheckIns'] = updatedHeritage;
        updateMap['streetFoodsLogged'] = updatedFoods;
        updateMap['outstationCheckIns'] = updatedOutstation;
        updateMap['localAttractionsOrHarvest'] = updatedAttractions;
        updateMap['natureTrailsCompleted'] = updatedTrails;
        updateMap['activeMobilityKm'] = updatedMobility;
        updateMap['bridgeCrossings'] = updatedBridges;
        updateMap['coastalCheckIns'] = updatedCoastal;
        updateMap['seasideFoodStops'] = updatedSeaside;
        updateMap['unlockedStampsCount'] = updatedStamps;
        updateMap['pennyItinerariesCompleted'] = updatedPenny;

        if (updateMap.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updateMap);
        }
      }
    } catch (e) {
      debugPrint("UserProfileManager.updateProfile Firebase error: $e");
    }
  }
}
