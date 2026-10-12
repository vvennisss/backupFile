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
    final rawImageUrl = (data['stampImage'] ??
            data['stamp_image'] ??
            data['imageUrl'] ??
            data['image_url'] ??
            data['image'] ??
            data['imagePath'] ??
            data['photoUrl'] ??
            data['thumbnail'] ??
            '')
        .toString();
    final imageUrl = _normalizeImageUrl(rawImageUrl);

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

  static String _normalizeImageUrl(String url) {
    if (url.contains('github.com') && url.contains('/blob/')) {
      return url.replaceFirst('github.com', 'raw.githubusercontent.com').replaceFirst('/blob/', '/');
    }
    return url;
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
    for (final s in kPredefined28DigitalStamps) {
      final sLower = s.title.toLowerCase();
      if (lower.contains(sLower) || sLower.contains(title.toLowerCase())) {
        return (s.lat, s.lng);
      }
    }

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

// --- 28 AUTHENTIC DIGITAL STAMPS FROM MY STAMPS SCREEN ---
const List<DigitalStamp> kPredefined28DigitalStamps = [
  DigitalStamp(
    id: '0HImpKF9orxkuGRhucDK',
    title: 'Leong San Tong Khoo Kongsi',
    location: 'George Town',
    date: '',
    description: "Widely considered the most magnificent clan house in Southeast Asia, Leong San Tong was founded in 1835 in Cannon Square. Built by master craftsmen imported from China, its roofs feature staggering 25-ton ceramic decorations, showcasing the immense wealth and power of the Khoo clan in colonial Penang.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Leong%20San%20Tong%20Khoo%20Kongsi.jpg',
    icon: Icons.account_balance_rounded,
    color: Color(0xFFD32F2F),
    order: 1,
    lat: 5.4151,
    lng: 100.3364,
    unlockRequirement: 'Visit Leong San Tong Khoo Kongsi in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: '3OybCn4zGMZpFPyzgDlE',
    title: 'Central Fire Station (Lebuh Pantai Fire Station)',
    location: 'George Town',
    date: '',
    description: "Built in 1908 at the junction of Beach Street and Chulia Street Ghaut, this is the oldest fire station still in operation in Penang. Its classical Mughal-influenced architecture is highlighted by a distinctive four-story watchtower.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Central%20Fire%20Station%20(Lebuh%20Pantai%20Fire%20Station).jpg',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFC62828),
    order: 2,
    lat: 5.4143,
    lng: 100.3398,
    unlockRequirement: 'Visit Central Fire Station in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: '4J0ZskFzHnhT1MNGgNzB',
    title: "St George's Church",
    location: 'George Town',
    date: '',
    description: "Built in 1818 and consecrated in 1819, St George's Church is the oldest purpose-built Anglican church in Southeast Asia. Designed by Captain Robert Smith, it boasts elegant Neoclassical and Georgian architecture with distinct Doric columns.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/St%20George%27s%20Church.jpg',
    icon: Icons.church_rounded,
    color: Color(0xFF1976D2),
    order: 3,
    lat: 5.4202,
    lng: 100.3392,
    unlockRequirement: "Visit St George's Church in George Town to unlock this digital stamp.",
  ),
  DigitalStamp(
    id: '6yOxh3Wu8nY0CQUPu1Oc',
    title: 'Kapitan Keling Mosque',
    location: 'George Town',
    date: '',
    description: "Built in 1801, this magnificent mosque was founded by the first Indian Muslim settlers (Chulias). Featuring striking Mughal architecture, black domes, and a towering minaret, it has stood for over two centuries as the spiritual nucleus of Penang's Indian Muslim community.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Kapitan%20Keling%20Mosque.jpg',
    icon: Icons.mosque_rounded,
    color: Color(0xFF2E7D32),
    order: 4,
    lat: 5.4165,
    lng: 100.3375,
    unlockRequirement: 'Visit Kapitan Keling Mosque in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: '8TSR3utpsJTgdrYhYOse',
    title: 'Cenotaph War Memorial',
    location: 'George Town',
    date: '',
    description: "Facing the open civic space of the Esplanade seafront, the Cenotaph is a poignant war memorial originally erected in 1929 to commemorate Allied servicemen who perished in World War I, and later reconstructed using surviving original granite blocks.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Cenotaph%20War%20Memorial.jpg',
    icon: Icons.emoji_flags_rounded,
    color: Color(0xFF455A64),
    order: 5,
    lat: 5.4220,
    lng: 100.3410,
    unlockRequirement: 'Visit Cenotaph War Memorial in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: '910BjFLOMeBuVjLW6MpS',
    title: 'Standard Chartered Building',
    location: 'George Town',
    date: '',
    description: "Located in the heart of the Beach Street banking district, this imposing building was completed in 1930. Designed by Stark & McNeill, it features a blend of Palladian and Art Deco styles, reflecting the historical financing of regional tin and rubber trades.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Standard%20Chartered%20Building.jpg',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF00796B),
    order: 6,
    lat: 5.4168,
    lng: 100.3421,
    unlockRequirement: 'Visit Standard Chartered Building in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'A1pPkdzY9PKedhD8Va4K',
    title: 'Har Yang Sit Teik Tong Yeoh Kongsi',
    location: 'George Town',
    date: '',
    description: "Established in 1836 near Chulia Street and Victoria Street, this clan house was founded by Yeoh clansmen. Constructed in a traditional courtyard layout, it houses an exquisite main altar dedicated to patron deity Chye Tian Tai Seng (The Monkey God).",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Har%20Yang%20Sit%20Teik%20Tong%20Yeoh%20Kongsi.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFFE64A19),
    order: 7,
    lat: 5.4137,
    lng: 100.3395,
    unlockRequirement: 'Visit Har Yang Sit Teik Tong Yeoh Kongsi in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'F16WxF8yRroDkC59aXwl',
    title: 'India House',
    location: 'George Town',
    date: '',
    description: "Completed in 1937, India House is a striking example of early Art Deco architecture on Beach Street. Built by prominent Chettiar businessman S.N.A.S.N.M. Somasundram, its distinct geometric facade highlights South Indian mercantile influence in colonial George Town.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/India%20House.jpg',
    icon: Icons.business_rounded,
    color: Color(0xFF5D4037),
    order: 8,
    lat: 5.4150,
    lng: 100.3418,
    unlockRequirement: 'Visit India House in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'GiPD8hlRcjYIZ5EoRtZg',
    title: 'Koh Seang Tat Fountain',
    location: 'George Town',
    date: '',
    description: "Standing proudly at the junction of Esplanade Road and Light Street, this Victorian cast-iron fountain was donated to the Municipal Council in 1883 by millionaire philanthropist Koh Seang Tat in conjunction with the opening of the adjacent Town Hall.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Koh%20Seang%20Tat%20Fountain.jpg',
    icon: Icons.park_rounded,
    color: Color(0xFF0097A7),
    order: 9,
    lat: 5.4214,
    lng: 100.3412,
    unlockRequirement: 'Visit Koh Seang Tat Fountain in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'HNlJg8edjuORjev68Aj0',
    title: 'Pinang Peranakan Mansion',
    location: 'George Town',
    date: '',
    description: "Built at the end of the 19th century as 'Hai Kee Chan', this vibrant green mansion was the residence of Kapitan Chung Keng Quee. A masterpiece of Straits Eclectic architecture, it showcases over 1,000 antiques reflecting the opulent Baba Nyonya lifestyle.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Pinang%20Peranakan%20Mansion.jpg',
    icon: Icons.museum_rounded,
    color: Color(0xFF2E7D32),
    order: 10,
    lat: 5.4180,
    lng: 100.3411,
    unlockRequirement: 'Visit Pinang Peranakan Mansion in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'HxqHijSbF2XdpMFAiWhs',
    title: 'Malayan Railway Building',
    location: 'George Town',
    date: '',
    description: "Built in 1907 by the Federated Malay States Railways, this building has a famous quirk: it was a railway station that never saw a single train. Passengers bought tickets here and took a railway ferry across the strait to Butterworth. Now known as Wisma Kastam.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Malayan%20Railway%20Building.jpg',
    icon: Icons.directions_railway_rounded,
    color: Color(0xFF455A64),
    order: 11,
    lat: 5.4157,
    lng: 100.3426,
    unlockRequirement: 'Visit Malayan Railway Building in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'IvuqDJKKzwvZq3kGcXWf',
    title: 'Lim Jetty',
    location: 'George Town',
    date: '',
    description: "Lim Jetty (姓林桥) was founded by settlers from Houcunzhuang. Rebuilt post-war into 30 stilt houses with zinc roofs, it houses several significant temples including Ri Yue Than (Sun Moon Temple), which hosts an annual Mazu birthday sea procession.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Lim%20Jetty.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 12,
    lat: 5.4133,
    lng: 100.3398,
    unlockRequirement: 'Visit Lim Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'K1ogvPUyRER3GSEpTYjw',
    title: 'Sri Mahamariamman Temple',
    location: 'George Town',
    date: '',
    description: "Established in 1833 in Little India, this is Penang's oldest Hindu temple. It is famous for its magnificent 23.6-foot-tall gopuram entrance tower with 38 intricately carved deity statues, and serves as the starting point for the annual Thaipusam chariot procession.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Sri%20Mahamariamman%20Temple.jpg',
    icon: Icons.temple_hindu_rounded,
    color: Color(0xFFF57C00),
    order: 13,
    lat: 5.4164,
    lng: 100.3399,
    unlockRequirement: 'Visit Sri Mahamariamman Temple in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'Mdst5odUdCD1Neggwv0r',
    title: 'Lee Jetty',
    location: 'George Town',
    date: '',
    description: "Lee Jetty (姓李桥) was established by settlers from Duishancun who worked as port boatmen. Rebuilt in the early 1960s with 24 stilt houses, its Kim Aun San Si Temple honors the Baosheng God of Health and houses a historic statue of Child Prince Nazha.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Lee%20Jetty.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 14,
    lat: 5.4118,
    lng: 100.3390,
    unlockRequirement: 'Visit Lee Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'PNXucAfr20emF5WDuxpr',
    title: 'Eng Chuan Tong Tan Kongsi',
    location: 'George Town',
    date: '',
    description: "Founded in 1878 in Seh Tan Court off Beach Street, this kongsi serves the prominent Tan clan. Dedicated to patron deity Tan Goan-kong, a Tang Dynasty general, the heavily ornamented temple preserves magnificent gilded wood carvings and ancestral tablets.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Eng%20Chuan%20Tong%20Tan%20Kongsi.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFFC2185B),
    order: 15,
    lat: 5.4124,
    lng: 100.3385,
    unlockRequirement: 'Visit Eng Chuan Tong Tan Kongsi in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'TpNGDOa2vkYy4wv8rqWC',
    title: 'Queen Victoria Memorial Clock Tower',
    location: 'George Town',
    date: '',
    description: "Located at Light Street and Beach Street, the 97-foot tall Indo-Saracenic clock tower was built to commemorate the 1897 Diamond Jubilee of Queen Victoria. Financed by Penang tycoon Cheah Chen Eok, each of its 60 feet represents a year of the Queen's reign.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Queen%20Victoria%20Memorial%20Clock%20Tower.jpg',
    icon: Icons.access_time_filled_rounded,
    color: Color(0xFFFBC02D),
    order: 16,
    lat: 5.4196,
    lng: 100.3440,
    unlockRequirement: 'Visit Queen Victoria Memorial Clock Tower in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'UF73txO0iCmjdf8oFaAF',
    title: 'Cheong Fatt Tze Mansion',
    location: 'George Town',
    date: '',
    description: "Famously known as 'The Blue Mansion', this 1890s architectural marvel was built by Cheong Fatt Tze ('Rockefeller of the East'). Featuring 38 rooms, 5 granite courtyards, and striking indigo-blue lime-washed walls, it won the UNESCO Asia-Pacific Heritage Award in 2000.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Cheong%20Fatt%20Tze%20Mansion.jpg',
    icon: Icons.museum_rounded,
    color: Color(0xFF303F9F),
    order: 17,
    lat: 5.4215,
    lng: 100.3346,
    unlockRequirement: 'Visit Cheong Fatt Tze Mansion in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'VCkm7vFuyj8JzaHQIP0D',
    title: 'Nagore Durgha Shrine',
    location: 'George Town',
    date: '',
    description: "Built in the early 1800s by the Chulia Muslim community, this shrine is dedicated to Syed Abdul Kadir Al Hasan, a revered 13th-century saint from Nagore, India. Features striking Southern Indian Islamic architecture with miniature domes and minarets.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Nagore%20Durgha%20Shrine.jpg',
    icon: Icons.mosque_rounded,
    color: Color(0xFF388E3C),
    order: 18,
    lat: 5.4172,
    lng: 100.3386,
    unlockRequirement: 'Visit Nagore Durgha Shrine in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'Wk98JrSsb8ql3wujXaO9',
    title: 'Seh Tek Tong Cheah Kongsi',
    location: 'George Town',
    date: '',
    description: "Founded in 1810 on Armenian Street, this is one of the oldest Hokkien clan associations in George Town. It features a unique fusion of Southern Fujian design and European classical elements, including British lion statues and classical columns.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Seh%20Tek%20Tong%20Cheah%20Kongsi.jpg',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF7B1FA2),
    order: 19,
    lat: 5.4155,
    lng: 100.3377,
    unlockRequirement: 'Visit Seh Tek Tong Cheah Kongsi in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'bENfgibA6l2owYnuAKAt',
    title: 'Logan Memorial',
    location: 'George Town',
    date: '',
    description: "Erected in 1873, this Gothic memorial honors James Richardson Logan, a Scottish lawyer who championed the civil rights of Asians in colonial Penang. Features four allegorical statues representing Justice, Fortitude, Wisdom, and Temperance.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Logan%20Memorial.jpg',
    icon: Icons.emoji_flags_rounded,
    color: Color(0xFF512DA8),
    order: 20,
    lat: 5.4211,
    lng: 100.3405,
    unlockRequirement: 'Visit Logan Memorial in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'fX9TSwNiio9oQQPRvwKF',
    title: 'Chew Jetty',
    location: 'George Town',
    date: '',
    description: "Chew Jetty (姓周桥) is the largest and most famous clan jetty water village, with 75 stilt houses on Weld Quay. Renowned for its grand annual Jade Emperor's Birthday celebration with a 50-meter altar table, roast pigs, and midnight fireworks.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Chew%20Jetty.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 21,
    lat: 5.4126,
    lng: 100.3396,
    unlockRequirement: 'Visit Chew Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'fqBvKbcIUkntAG8Tw7VV',
    title: 'Tan Jetty',
    location: 'George Town',
    date: '',
    description: "Tan Jetty (姓陈桥) was founded by fishermen and oyster harvesters from Bingzhoushe. Features Chow Eng Tien temple and a long, picturesque timber pier extending into the sea, serving as the sacred send-off point for the Nine Emperor Gods festival.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Tan%20Jetty.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 22,
    lat: 5.4112,
    lng: 100.3388,
    unlockRequirement: 'Visit Tan Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'mvdlW637pEjiKrcWIW4X',
    title: 'Francis Light Memorial',
    location: 'George Town',
    date: '',
    description: "Located on the grounds of St. George's Church along Farquhar Street, this Georgian and Palladian-style domed pavilion with ornamental urns was erected in the 1840s to honor Captain Francis Light, founder of the British settlement in Penang.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Francis%20Light%20Memorial.jpg',
    icon: Icons.account_balance_rounded,
    color: Color(0xFF689F38),
    order: 23,
    lat: 5.4204,
    lng: 100.3395,
    unlockRequirement: 'Visit Francis Light Memorial in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'ou4DGIOVXTBKYSFz8qJe',
    title: 'Boon San Tong Khoo Kongsi',
    location: 'George Town',
    date: '',
    description: "Established in 1878 on Victoria Street, Boon San Tong represents the 'Hai Kee' branch of the Khoo family. The building underwent an award-winning restoration to preserve its authentic frescoes, gold-leaf timber carvings, and intimate ancestral altar.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Boon%20San%20Tong%20Khoo%20Kongsi.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFFC2185B),
    order: 24,
    lat: 5.4140,
    lng: 100.3390,
    unlockRequirement: 'Visit Boon San Tong Khoo Kongsi in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'rhHJNTtFtyvmW4M0Cw6j',
    title: 'Mixed Surname Jetty (New Jetty)',
    location: 'George Town',
    date: '',
    description: "Mixed Surname Jetty / New Jetty (杂姓桥) was founded in 1962 for families of mixed surnames. Built under municipal town planning with vintage 1960s window grilles across 20 stilt houses, ending at Kee Thean Keong temple overlooking the sea.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Mixed%20Surname%20Jetty%20(New%20Jetty).jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 25,
    lat: 5.4105,
    lng: 100.3382,
    unlockRequirement: 'Visit Mixed Surname Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'v80jeUDBWt3nRc7r71sa',
    title: 'Ong Jetty',
    location: 'George Town',
    date: '',
    description: "Ong Jetty (姓王桥) is the first jetty south of Raja Tun Uda Ferry Terminal on Weld Quay. Unlike other clan jetties, it was never a residential stilt settlement and maintains its working function with historic sheds and an extended wooden pier.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Ong%20Jetty.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFF0288D1),
    order: 26,
    lat: 5.4142,
    lng: 100.3405,
    unlockRequirement: 'Visit Ong Jetty in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'wZTwLLb4i8ycDYoUptds',
    title: 'Ng See Kah Miew (Ng Ancestral Temple)',
    location: 'George Town',
    date: '',
    description: "Built in 1897 along King Street, this ancestral temple for the Ng clan is celebrated for its intricate timber carvings and roof ridges adorned with 'Chian Nien' (porcelain shard art) depicting dragons and legendary figures.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Ng%20See%20Kah%20Miew.jpg',
    icon: Icons.home_work_rounded,
    color: Color(0xFFD84315),
    order: 27,
    lat: 5.4175,
    lng: 100.3391,
    unlockRequirement: 'Visit Ng See Kah Miew in George Town to unlock this digital stamp.',
  ),
  DigitalStamp(
    id: 'wpbfERq7Y5kZLUYoWGQS',
    title: 'Goddess of Mercy Temple',
    location: 'George Town',
    date: '',
    description: "Built in 1728 on Pitt Street, the Goddess of Mercy Temple (Kuan Yin Teng) is Penang's oldest Taoist temple. Revered for miraculously surviving multiple fires and WWII Japanese bombings completely unscathed, it remains a vibrant center of worship.",
    imageUrl: 'https://raw.githubusercontent.com/vvennisss/0824-setup-mongoDB-places-table-nodejs/master/stampsimages/Goddess%20of%20Mercy%20Temple.jpg',
    icon: Icons.temple_buddhist_rounded,
    color: Color(0xFFE91E63),
    order: 28,
    lat: 5.4187,
    lng: 100.3390,
    unlockRequirement: 'Visit Goddess of Mercy Temple in George Town to unlock this digital stamp.',
  ),
];

// --- STAMPS SERVICE ---
class StampsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // In-memory fast cache to eliminate any loading wait time, pre-seeded with 28 stamps
  static List<DigitalStamp> cachedStamps = List.from(kPredefined28DigitalStamps);
  static final ValueNotifier<List<DigitalStamp>> stampsNotifier =
      ValueNotifier<List<DigitalStamp>>(List.from(kPredefined28DigitalStamps));
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
      debugPrint('Error getting stamps: $e');
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
      debugPrint('Error unlocking stamp: $e');
      return false;
    }
  }
}
