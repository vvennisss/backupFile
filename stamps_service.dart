import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- STAMP MODEL ---
class DigitalStamp {
  final String id;
  final String title;
  final String location;
  final String date;
  final String description;
  final String imageUrl;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final String unlockRequirement;
  final int order;
  final double lat;
  final double lng;

  const DigitalStamp({
    required this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.description,
    this.imageUrl = '',
    required this.icon,
    required this.color,
    this.isUnlocked = false, // Strictly false by default (no mock unlocks)
    this.unlockRequirement = '',
    this.order = 0,
    this.lat = 5.4141,
    this.lng = 100.3288,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'date': date,
      'description': description,
      'imageUrl': imageUrl,
      'icon': icon.codePoint,
      'color': color.value,
      'isUnlocked': isUnlocked,
      'unlockRequirement': unlockRequirement,
      'order': order,
      'lat': lat,
      'lng': lng,
    };
  }

  factory DigitalStamp.fromJson(Map<String, dynamic> json) {
    return DigitalStamp(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? 'Penang',
      date: json['date'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      icon: json['icon'] != null
          ? IconData(json['icon'] as int, fontFamily: 'MaterialIcons')
          : Icons.place_rounded,
      color: json['color'] != null ? Color(json['color'] as int) : const Color(0xFF304FFE),
      isUnlocked: json['isUnlocked'] == true,
      unlockRequirement: json['unlockRequirement'] ?? '',
      order: (json['order'] ?? 0) as int,
      lat: (json['lat'] is num) ? (json['lat'] as num).toDouble() : 5.4141,
      lng: (json['lng'] is num) ? (json['lng'] as num).toDouble() : 100.3288,
    );
  }

  DigitalStamp copyWith({
    String? id,
    String? title,
    String? location,
    String? date,
    String? description,
    String? imageUrl,
    IconData? icon,
    Color? color,
    bool? isUnlocked,
    String? unlockRequirement,
    int? order,
    double? lat,
    double? lng,
  }) {
    return DigitalStamp(
      id: id ?? this.id,
      title: title ?? this.title,
      location: location ?? this.location,
      date: date ?? this.date,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockRequirement: unlockRequirement ?? this.unlockRequirement,
      order: order ?? this.order,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  factory DigitalStamp.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    bool isUnlocked = false,
    String? unlockedDate,
  }) {
    final data = doc.data() ?? {};

    // 1. Stamp Name / Place Name
    final title = (data['stampName'] ??
            data['stamp_name'] ??
            data['name'] ??
            data['placeName'] ??
            data['place_name'] ??
            data['title'] ??
            doc.id)
        .toString();

    // 2. Location / Area
    final location = (data['location'] ??
            data['area'] ??
            data['place_address'] ??
            data['address'] ??
            'Penang')
        .toString();

    // 3. Information / Description
    final description = (data['stampInformation'] ??
            data['stamp_information'] ??
            data['stampInfo'] ??
            data['stamp_info'] ??
            data['information'] ??
            data['description'] ??
            data['info'] ??
            data['place_information'] ??
            data['details'] ??
            'Discover this unique landmark in Penang to earn your digital stamp.')
        .toString();

    // 4. Image URL
    final imageUrl = (data['stampImage'] ??
            data['stamp_image'] ??
            data['imageUrl'] ??
            data['image_url'] ??
            data['image'] ??
            data['imagePath'] ??
            data['photoUrl'] ??
            data['thumbnail'] ??
            '')
        .toString();

    // 5. Unlock requirement
    final unlockRequirement = (data['unlockRequirement'] ??
            data['unlock_requirement'] ??
            data['requirement'] ??
            data['criteria'] ??
            'Visit $title in Penang to unlock this stamp.')
        .toString();

    // 6. Icon
    final icon = _resolveIcon(data['icon'], title);

    // 7. Color
    final color = _resolveColor(data['color'], title);

    // 8. Order
    final order = (data['order'] ?? data['index'] ?? 0) is int
        ? (data['order'] ?? data['index'] ?? 0) as int
        : 0;

    // 9. Coordinates
    final coords = _resolveCoordinates(data, title, location);

    return DigitalStamp(
      id: doc.id,
      title: title,
      location: location,
      date: isUnlocked ? (unlockedDate ?? data['date']?.toString() ?? 'Collected') : '',
      description: description,
      imageUrl: imageUrl,
      icon: icon,
      color: color,
      isUnlocked: isUnlocked,
      unlockRequirement: unlockRequirement,
      order: order,
      lat: coords.$1,
      lng: coords.$2,
    );
  }

  static (double, double) _resolveCoordinates(Map<String, dynamic> data, String title, String location) {
    if (data['lat'] is num && data['lng'] is num) {
      return ((data['lat'] as num).toDouble(), (data['lng'] as num).toDouble());
    }
    if (data['latitude'] is num && data['longitude'] is num) {
      return ((data['latitude'] as num).toDouble(), (data['longitude'] as num).toDouble());
    }
    if (data['coordinates'] is List && (data['coordinates'] as List).length >= 2) {
      final list = data['coordinates'] as List;
      final c0 = (list[0] as num).toDouble();
      final c1 = (list[1] as num).toDouble();
      if (c0 > 90) return (c1, c0);
      return (c0, c1);
    }
    if (data['place_location'] is Map && data['place_location']['coordinates'] is List) {
      final list = data['place_location']['coordinates'] as List;
      if (list.length >= 2) {
        final c0 = (list[0] as num).toDouble();
        final c1 = (list[1] as num).toDouble();
        if (c0 > 90) return (c1, c0);
        return (c0, c1);
      }
    }

    final lower = '$title $location'.toLowerCase();
    if (lower.contains('chew jetty') || lower.contains('clan jetty')) return (5.4126, 100.3396);
    if (lower.contains('penang hill') || lower.contains('bukit bendera')) return (5.4084, 100.2687);
    if (lower.contains('kek lok si')) return (5.3995, 100.2736);
    if (lower.contains('fort cornwallis')) return (5.4206, 100.3440);
    if (lower.contains('batu ferringhi')) return (5.4748, 100.2483);
    if (lower.contains('khoo kongsi') || lower.contains('clan house')) return (5.4151, 100.3364);
    if (lower.contains('association')) return (5.4160, 100.3380);
    if (lower.contains('historic') || lower.contains('clock tower')) return (5.4190, 100.3420);
    if (lower.contains('monument') || lower.contains('cenotaph')) return (5.4220, 100.3410);
    if (lower.contains('worship') || lower.contains('kapitan keling')) return (5.4165, 100.3375);
    if (lower.contains('escape')) return (5.4492, 100.2154);
    if (lower.contains('entopia')) return (5.4470, 100.2185);
    if (lower.contains('gurney')) return (5.4398, 100.3090);
    if (lower.contains('balik pulau')) return (5.3516, 100.2369);
    if (lower.contains('top') || lower.contains('komtar')) return (5.4145, 100.3295);
    if (lower.contains('air itam')) return (5.4000, 100.2750);
    if (lower.contains('teluk bahang')) return (5.4500, 100.2150);

    return (5.4141, 100.3288); // Default George Town
  }

  static IconData _resolveIcon(dynamic rawIcon, String title) {
    if (rawIcon is int) {
      return IconData(rawIcon, fontFamily: 'MaterialIcons');
    }
    final lower = title.toLowerCase();
    if (lower.contains('jetty') || lower.contains('clan') || lower.contains('water')) {
      return Icons.home_work_rounded;
    } else if (lower.contains('hill') || lower.contains('mountain') || lower.contains('peak')) {
      return Icons.terrain_rounded;
    } else if (lower.contains('temple') || lower.contains('kek lok si') || lower.contains('pagoda')) {
      return Icons.account_balance_rounded;
    } else if (lower.contains('fort') || lower.contains('castle') || lower.contains('cornwallis')) {
      return Icons.castle_rounded;
    } else if (lower.contains('beach') || lower.contains('ferringhi') || lower.contains('sea')) {
      return Icons.beach_access_rounded;
    } else if (lower.contains('mosque') || lower.contains('church') || lower.contains('worship')) {
      return Icons.church_rounded;
    } else if (lower.contains('monument') || lower.contains('cenotaph') || lower.contains('statue')) {
      return Icons.emoji_flags_rounded;
    } else if (lower.contains('food') || lower.contains('cafe') || lower.contains('market')) {
      return Icons.restaurant_rounded;
    } else if (lower.contains('museum') || lower.contains('art') || lower.contains('heritage')) {
      return Icons.museum_rounded;
    } else if (lower.contains('park') || lower.contains('garden') || lower.contains('nature')) {
      return Icons.park_rounded;
    }
    return Icons.place_rounded;
  }

  static Color _resolveColor(dynamic rawColor, String title) {
    if (rawColor is int) {
      return Color(rawColor);
    }
    if (rawColor is String && rawColor.isNotEmpty) {
      final hex = rawColor.replaceAll('#', '').trim();
      if (hex.length == 6) {
        final parsed = int.tryParse('0xFF$hex');
        if (parsed != null) return Color(parsed);
      } else if (hex.length == 8) {
        final parsed = int.tryParse('0x$hex');
        if (parsed != null) return Color(parsed);
      }
    }
    // Color palette based on string hash
    const palette = [
      Color(0xFFFF9800), // Amber
      Color(0xFF2196F3), // Blue
      Color(0xFFE91E63), // Pink
      Color(0xFF4CAF50), // Green
      Color(0xFF9C27B0), // Purple
      Color(0xFFFF5722), // Deep Orange
      Color(0xFF00BCD4), // Cyan
      Color(0xFF3F51B5), // Indigo
      Color(0xFF009688), // Teal
      Color(0xFFFF7043), // Coral
    ];
    final hash = title.hashCode.abs() % palette.length;
    return palette[hash];
  }
}

// --- STAMPS SERVICE ---
class StampsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory fast cache to eliminate any loading wait time
  static List<DigitalStamp> cachedStamps = [];
  static final ValueNotifier<List<DigitalStamp>> stampsNotifier = ValueNotifier<List<DigitalStamp>>([]);
  static bool _hasLoadedFromPrefs = false;

  /// Haversine distance in km
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Get nearby stamps sorted by distance from a given point
  static List<MapEntry<DigitalStamp, double>> getNearbyStamps({
    required double lat,
    required double lng,
    String? excludeStampId,
    double maxDistanceKm = 10.0,
  }) {
    final list = <MapEntry<DigitalStamp, double>>[];
    for (final stamp in cachedStamps) {
      if (excludeStampId != null && stamp.id == excludeStampId) continue;
      final dist = calculateDistanceKm(lat, lng, stamp.lat, stamp.lng);
      if (dist <= maxDistanceKm) {
        list.add(MapEntry(stamp, dist));
      }
    }
    // Sort by locked first (to help collect new stamps), then by closest distance
    list.sort((a, b) {
      if (!a.key.isUnlocked && b.key.isUnlocked) return -1;
      if (a.key.isUnlocked && !b.key.isUnlocked) return 1;
      return a.value.compareTo(b.value);
    });
    return list;
  }

  /// Load cached stamps from persistent local storage for instantaneous display
  static Future<void> initCache() async {
    if (_hasLoadedFromPrefs) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_digital_stamps');
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final List list = json.decode(cachedJson);
        cachedStamps = list.map((item) => DigitalStamp.fromJson(Map<String, dynamic>.from(item))).toList();
        stampsNotifier.value = List.from(cachedStamps);
      }
    } catch (_) {}
    _hasLoadedFromPrefs = true;
  }

  static void _saveToCache(List<DigitalStamp> stamps) {
    cachedStamps = List.from(stamps);
    stampsNotifier.value = List.from(stamps);
    SharedPreferences.getInstance().then((prefs) {
      final jsonList = stamps.map((s) => s.toJson()).toList();
      prefs.setString('cached_digital_stamps', json.encode(jsonList));
    }).catchError((_) {});
  }

  /// Stream of digital stamps from Firestore `stamps` collection
  /// combined with the current user's unlocked stamps records.
  static Stream<List<DigitalStamp>> streamStamps() {
    initCache();
    final user = _auth.currentUser;

    if (user == null) {
      // Not logged in or guest: Fetch stamps with isUnlocked = false
      return _firestore.collection('stamps').snapshots().map((snapshot) {
        final stamps = snapshot.docs.map((doc) {
          return DigitalStamp.fromFirestore(doc, isUnlocked: false);
        }).toList();
        stamps.sort((a, b) => a.order.compareTo(b.order));
        _saveToCache(stamps);
        return stamps;
      });
    }

    // When user is logged in, listen to user's profile/unlocked records and stamps collection
    return _firestore.collection('users').doc(user.uid).snapshots().asyncMap((userDoc) async {
      final userData = userDoc.data() ?? {};
      final Map<String, String> unlockedMap = {};

      // 1. Check `unlockedStamps` list or map in user doc
      final rawUnlocked = userData['unlockedStamps'] ?? userData['unlocked_stamps'] ?? userData['stamps'];
      if (rawUnlocked is List) {
        for (var item in rawUnlocked) {
          if (item is String) {
            unlockedMap[item.toLowerCase().trim()] = 'Unlocked';
          } else if (item is Map) {
            final id = (item['id'] ?? item['stampId'] ?? item['stampName'] ?? '').toString().toLowerCase().trim();
            final date = (item['date'] ?? item['unlockedAt'] ?? 'Unlocked').toString();
            if (id.isNotEmpty) unlockedMap[id] = date;
          }
        }
      } else if (rawUnlocked is Map) {
        for (var entry in rawUnlocked.entries) {
          final id = entry.key.toString().toLowerCase().trim();
          final val = entry.value;
          final date = val is Map ? (val['date'] ?? val['unlockedAt'] ?? 'Unlocked').toString() : val.toString();
          unlockedMap[id] = date;
        }
      }

      // 2. Also check subcollection `users/{uid}/unlocked_stamps` if any exist
      try {
        final subCol = await _firestore.collection('users').doc(user.uid).collection('unlocked_stamps').get();
        for (var doc in subCol.docs) {
          final data = doc.data();
          final id = doc.id.toLowerCase().trim();
          final name = (data['stampName'] ?? data['name'] ?? '').toString().toLowerCase().trim();
          final date = (data['date'] ?? data['unlockedAt'] ?? 'Unlocked').toString();
          unlockedMap[id] = date;
          if (name.isNotEmpty) unlockedMap[name] = date;
        }
      } catch (_) {}

      // 3. Fetch stamps snapshot
      final stampsSnapshot = await _firestore.collection('stamps').get();
      final stamps = stampsSnapshot.docs.map((doc) {
        final docId = doc.id.toLowerCase().trim();
        final stampName = (doc.data()['stampName'] ??
                doc.data()['stamp_name'] ??
                doc.data()['name'] ??
                doc.data()['placeName'] ??
                doc.data()['title'] ??
                doc.id)
            .toString()
            .toLowerCase()
            .trim();

        bool isUnlocked = false;
        String? unlockDate;

        if (unlockedMap.containsKey(docId)) {
          isUnlocked = true;
          unlockDate = unlockedMap[docId];
        } else if (unlockedMap.containsKey(stampName)) {
          isUnlocked = true;
          unlockDate = unlockedMap[stampName];
        }

        return DigitalStamp.fromFirestore(
          doc,
          isUnlocked: isUnlocked,
          unlockedDate: unlockDate,
        );
      }).toList();

      stamps.sort((a, b) => a.order.compareTo(b.order));
      _saveToCache(stamps);
      return stamps;
    });
  }

  /// One-time fetch of all stamps
  static Future<List<DigitalStamp>> getStamps() async {
    try {
      final user = _auth.currentUser;
      final Map<String, String> unlockedMap = {};

      if (user != null) {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final userData = userDoc.data() ?? {};
          final rawUnlocked = userData['unlockedStamps'] ?? userData['unlocked_stamps'] ?? userData['stamps'];
          if (rawUnlocked is List) {
            for (var item in rawUnlocked) {
              if (item is String) {
                unlockedMap[item.toLowerCase().trim()] = 'Unlocked';
              } else if (item is Map) {
                final id = (item['id'] ?? item['stampId'] ?? item['stampName'] ?? '').toString().toLowerCase().trim();
                final date = (item['date'] ?? item['unlockedAt'] ?? 'Unlocked').toString();
                if (id.isNotEmpty) unlockedMap[id] = date;
              }
            }
          } else if (rawUnlocked is Map) {
            for (var entry in rawUnlocked.entries) {
              final id = entry.key.toString().toLowerCase().trim();
              unlockedMap[id] = entry.value.toString();
            }
          }
        }
      }

      final snapshot = await _firestore.collection('stamps').get();
      final stamps = snapshot.docs.map((doc) {
        final docId = doc.id.toLowerCase().trim();
        final stampName = (doc.data()['stampName'] ??
                doc.data()['stamp_name'] ??
                doc.data()['name'] ??
                doc.data()['placeName'] ??
                doc.data()['title'] ??
                doc.id)
            .toString()
            .toLowerCase()
            .trim();

        bool isUnlocked = false;
        String? unlockDate;

        if (unlockedMap.containsKey(docId)) {
          isUnlocked = true;
          unlockDate = unlockedMap[docId];
        } else if (unlockedMap.containsKey(stampName)) {
          isUnlocked = true;
          unlockDate = unlockedMap[stampName];
        }

        return DigitalStamp.fromFirestore(
          doc,
          isUnlocked: isUnlocked,
          unlockedDate: unlockDate,
        );
      }).toList();

      stamps.sort((a, b) => a.order.compareTo(b.order));
      _saveToCache(stamps);
      return stamps;
    } catch (e) {
      print('Error getting stamps: $e');
      return cachedStamps;
    }
  }

  /// Unlock a stamp for the currently authenticated user
  static Future<bool> unlockStamp({
    required String stampId,
    required String stampName,
  }) async {
    try {
      final user = _auth.currentUser;
      final nowStr = '${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().year}';

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'unlockedStamps': FieldValue.arrayUnion([
            {
              'stampId': stampId,
              'stampName': stampName,
              'date': nowStr,
              'unlockedAt': FieldValue.serverTimestamp(),
            }
          ]),
        });
        return true;
      } else {
        final prefs = await SharedPreferences.getInstance();
        final localList = prefs.getStringList('local_unlocked_stamps') ?? [];
        if (!localList.contains(stampId)) {
          localList.add(stampId);
          await prefs.setStringList('local_unlocked_stamps', localList);
        }
        return true;
      }
    } catch (e) {
      print('Error unlocking stamp: $e');
      return false;
    }
  }
}
