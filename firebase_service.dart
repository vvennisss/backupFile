import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// TODO: Firebase Integration
// When you connect Firebase:
// 1. Import firebase packages:
//    import 'package:firebase_auth/firebase_auth.dart';
//    import 'package:cloud_firestore/cloud_firestore.dart';
//
// 2. Replace the local mockup storage logic in UserProfileManager with Firebase Firestore calls:
//    final _db = FirebaseFirestore.instance;
//    final _auth = FirebaseAuth.instance;

enum UserRank {
  bronze,
  silver,
  gold,
  platinum;

  String get displayName {
    switch (this) {
      case UserRank.bronze:
        return 'Bronze Explorer';
      case UserRank.silver:
        return 'Silver Adventurer';
      case UserRank.gold:
        return 'Gold Pioneer';
      case UserRank.platinum:
        return 'Platinum Trailblazer';
    }
  }

  String get description {
    switch (this) {
      case UserRank.bronze:
        return 'You have just started your journey! Visit more locations in Penang to level up.';
      case UserRank.silver:
        return 'You are actively exploring Penang! Visited 5+ locations and completed at least 2 routes.';
      case UserRank.gold:
        return 'You have experienced a lot of Penang heritage, nature, and food! Visited 15+ locations.';
      case UserRank.platinum:
        return 'The ultimate explorer! You have charted almost every corner of Penang island & mainland.';
    }
  }

  int get requiredRoutes {
    switch (this) {
      case UserRank.bronze: return 0;
      case UserRank.silver: return 2;
      case UserRank.gold: return 5;
      case UserRank.platinum: return 10;
    }
  }

  IconData get icon {
    switch (this) {
      case UserRank.bronze:
        return Icons.shield_outlined;
      case UserRank.silver:
        return Icons.star_border_rounded;
      case UserRank.gold:
        return Icons.emoji_events_outlined;
      case UserRank.platinum:
        return Icons.diamond_outlined;
    }
  }

  Color get color {
    switch (this) {
      case UserRank.bronze:
        return Colors.brown.shade400;
      case UserRank.silver:
        return Colors.grey.shade400;
      case UserRank.gold:
        return Colors.amber.shade600;
      case UserRank.platinum:
        return Colors.cyan.shade300;
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

  UserProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.joinedDate,
    required this.rank,
    required this.completedRoutes,
    required this.distanceTravelled,
    required this.travelStyles,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? joinedDate,
    UserRank? rank,
    int? completedRoutes,
    double? distanceTravelled,
    List<String>? travelStyles,
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
    );
  }
}

class UserProfileManager {
  static final UserProfile _defaultProfile = UserProfile(
    name: 'Noah Thompson',
    email: 'noah.thompson@gmail.com',
    phone: '+60 17 423 4112',
    joinedDate: 'August 2026',
    rank: UserRank.silver,
    completedRoutes: 3,
    distanceTravelled: 82.5,
    travelStyles: ['Foodie', 'Nature Lover', 'Adventure'],
  );

  static final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(_defaultProfile);

  // Initialize and load saved local state
  static Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Read cached values
    final name = prefs.getString('user_name') ?? _defaultProfile.name;
    final email = prefs.getString('user_email') ?? _defaultProfile.email;
    final phone = prefs.getString('user_phone') ?? _defaultProfile.phone;
    final joinedDate = prefs.getString('user_joined') ?? _defaultProfile.joinedDate;
    final rankIndex = prefs.getInt('user_rank') ?? _defaultProfile.rank.index;
    final routes = prefs.getInt('user_routes') ?? _defaultProfile.completedRoutes;
    final distance = prefs.getDouble('user_distance') ?? _defaultProfile.distanceTravelled;
    final styles = prefs.getStringList('user_styles') ?? _defaultProfile.travelStyles;

    profileNotifier.value = UserProfile(
      name: name,
      email: email,
      phone: phone,
      joinedDate: joinedDate,
      rank: UserRank.values[rankIndex],
      completedRoutes: routes,
      distanceTravelled: distance,
      travelStyles: styles,
    );

    // TODO: Firebase Integration
    // When Firebase is connected, load profile from firestore:
    /*
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        profileNotifier.value = UserProfile(
          name: data['name'] ?? 'Penang Explorer',
          email: user.email ?? data['email'] ?? '',
          phone: user.phoneNumber ?? data['phone'] ?? '',
          joinedDate: data['joinedDate'] ?? 'August 2026',
          rank: UserRank.values[data['rank'] ?? 0],
          completedRoutes: data['completedRoutes'] ?? 0,
          distanceTravelled: (data['distanceTravelled'] ?? 0.0) as double,
          travelStyles: List<String>.from(data['travelStyles'] ?? []),
        );
      }
    }
    */
  }

  // Update profile attributes locally and persistent
  static Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    List<String>? travelStyles,
  }) async {
    final current = profileNotifier.value;
    
    // Determine new rank dynamically based on completed routes
    int finalRoutes = current.completedRoutes;
    UserRank finalRank = current.rank;
    if (finalRoutes >= UserRank.platinum.requiredRoutes) {
      finalRank = UserRank.platinum;
    } else if (finalRoutes >= UserRank.gold.requiredRoutes) {
      finalRank = UserRank.gold;
    } else if (finalRoutes >= UserRank.silver.requiredRoutes) {
      finalRank = UserRank.silver;
    } else {
      finalRank = UserRank.bronze;
    }

    final updated = current.copyWith(
      name: name,
      email: email,
      phone: phone,
      rank: finalRank,
      travelStyles: travelStyles,
    );

    profileNotifier.value = updated;

    // Cache locally
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('user_name', name);
    if (email != null) await prefs.setString('user_email', email);
    if (phone != null) await prefs.setString('user_phone', phone);
    if (travelStyles != null) await prefs.setStringList('user_styles', travelStyles);
    await prefs.setInt('user_rank', finalRank.index);

    // TODO: Firebase Integration
    // When Firebase is connected, write updates to Firestore:
    /*
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        if (name != null) 'name': name,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (travelStyles != null) 'travelStyles': travelStyles,
        'rank': finalRank.index,
      });
    }
    */
  }
}
