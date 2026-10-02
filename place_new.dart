class PlaceImage {
  final String url;
  final String caption;
  final bool isCover;
  final String source;

  PlaceImage({
    required this.url,
    this.caption = '',
    this.isCover = false,
    this.source = 'user',
  });

  factory PlaceImage.fromJson(Map<String, dynamic> json) {
    return PlaceImage(
      url: json['url']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      isCover: json['is_cover'] == true,
      source: json['source']?.toString() ?? 'user',
    );
  }

  Map<String, dynamic> toJson() => {
    'url': url,
    'caption': caption,
    'is_cover': isCover,
    'source': source,
  };
}

class PlaceInformation {
  final String phone;
  final String website;
  final double rating;
  final int reviewsCount;
  final String priceLevel;

  PlaceInformation({
    this.phone = '',
    this.website = '',
    this.rating = 4.5,
    this.reviewsCount = 0,
    this.priceLevel = 'RM 15–35',
  });

  factory PlaceInformation.fromJson(Map<String, dynamic> json) {
    return PlaceInformation(
      phone: json['phone']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
      priceLevel: json['price_level']?.toString() ?? 'RM 15–35',
    );
  }

  Map<String, dynamic> toJson() => {
    'phone': phone,
    'website': website,
    'rating': rating,
    'reviews_count': reviewsCount,
    'price_level': priceLevel,
  };
}

class PlaceFeatures {
  final bool isHalal;
  final bool isVegetarianFriendly;
  final bool hasAircon;
  final bool isWheelchairAccessible;
  final bool hasParking;
  final bool isMichelin;

  PlaceFeatures({
    this.isHalal = false,
    this.isVegetarianFriendly = false,
    this.hasAircon = true,
    this.isWheelchairAccessible = true,
    this.hasParking = false,
    this.isMichelin = false,
  });

  factory PlaceFeatures.fromJson(Map<String, dynamic> json) {
    return PlaceFeatures(
      isHalal: json['is_halal'] == true,
      isVegetarianFriendly: json['is_vegetarian_friendly'] == true,
      hasAircon: json['has_aircon'] == true,
      isWheelchairAccessible: json['is_wheelchair_accessible'] == true,
      hasParking: json['has_parking'] == true,
      isMichelin: json['is_michelin'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_halal': isHalal,
    'is_vegetarian_friendly': isVegetarianFriendly,
    'has_aircon': hasAircon,
    'is_wheelchair_accessible': isWheelchairAccessible,
    'has_parking': hasParking,
    'is_michelin': isMichelin,
  };
}

class PlaceNew {
  final String id;
  final String externalPlaceId; // Google 地图 ID (如 ChIJ...)
  final String name;
  final String nameZh;
  final String primaryCategory;
  final String placeCategory;
  final List<String> subCategories;
  final String area;
  final String address;
  final double lat;
  final double lng;
  final double geofenceRadius;
  final String summary;
  final String placeSummary; // 完整咖啡馆介绍与推荐语
  final String description;
  final int avgDurationMinutes;
  final String rawHoursText;
  final Map<String, dynamic>? openingHours;
  final bool isOpenNow;
  final double rating;
  final int reviewCount;
  final int priceLevel;
  final PlaceFeatures features;
  final PlaceInformation information;
  final String thumbnail; // 能够直接显示的 place_media.thumbnail
  final List<PlaceImage> images;
  final bool hasStreetView;
  final bool isPano; // 360° 全景标志
  final String? mapillaryImageId;
  final DateTime? streetViewUpdatedAt; // 街景更新时间
  final List<String> searchKeywords;

  PlaceNew({
    required this.id,
    required this.externalPlaceId,
    required this.name,
    this.nameZh = '',
    required this.primaryCategory,
    this.placeCategory = 'Cafes',
    this.subCategories = const [],
    required this.area,
    this.address = '',
    required this.lat,
    required this.lng,
    this.geofenceRadius = 50.0,
    this.summary = '',
    this.placeSummary = '',
    this.description = '',
    this.avgDurationMinutes = 60,
    this.rawHoursText = 'Check online',
    this.openingHours,
    this.isOpenNow = true,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.priceLevel = 1,
    PlaceFeatures? features,
    PlaceInformation? information,
    this.thumbnail = '',
    this.images = const [],
    this.hasStreetView = false,
    this.isPano = false,
    this.mapillaryImageId,
    this.streetViewUpdatedAt,
    this.searchKeywords = const [],
  })  : features = features ?? PlaceFeatures(),
        information = information ?? PlaceInformation();

  // 快捷获取电话
  String get phone => information.phone;
  // 快捷获取网址
  String get website => information.website;

  factory PlaceNew.fromJson(Map<String, dynamic> json) {
    // 经纬度提取（支持 GeoJSON [lng, lat] 以及平铺字段）
    double lat = 0.0;
    double lng = 0.0;

    if (json['location'] != null &&
        json['location']['coordinates'] is List &&
        (json['location']['coordinates'] as List).length >= 2) {
      final coords = json['location']['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else if (json['place_location'] != null &&
        json['place_location']['coordinates'] is List &&
        (json['place_location']['coordinates'] as List).length >= 2) {
      final coords = json['place_location']['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else {
      lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    }

    // 缩略图：提取 place_media.thumbnail
    String thumb = '';
    if (json['place_media'] != null && json['place_media'] is Map) {
      thumb = json['place_media']['thumbnail']?.toString() ?? '';
    }
    if (thumb.isEmpty) {
      thumb = json['cover_image']?.toString() ?? '';
    }

    // 图片列表
    List<PlaceImage> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => PlaceImage.fromJson(m))
          .toList();
    }
    if (thumb.isEmpty && imgList.isNotEmpty) {
      thumb = imgList.first.url;
    }


    // 子分类与关键词
    List<String> subCats = [];
    if (json['sub_categories'] is List) {
      subCats = (json['sub_categories'] as List).map((e) => e.toString()).toList();
    }

    List<String> keywords = [];
    if (json['search_keywords'] is List) {
      keywords = (json['search_keywords'] as List).map((e) => e.toString()).toList();
    }

    // 街景更新时间
    DateTime? svUpdatedAt;
    if (json['streetViewUpdatedAt'] != null) {
      svUpdatedAt = DateTime.tryParse(json['streetViewUpdatedAt'].toString());
    }

    // 完整推荐语
    final pSummary = json['place_summary']?.toString() ??
        json['summary']?.toString() ??
        json['description']?.toString() ??
        '';

    return PlaceNew(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      externalPlaceId: json['external_place_id']?.toString() ?? '',
      name: json['place_name']?.toString() ?? json['name']?.toString() ?? json['title']?.toString() ?? 'Penang Place',
      nameZh: json['local_names']?['zh']?.toString() ?? '',
      primaryCategory: json['primary_category']?.toString() ?? json['place_category']?.toString() ?? 'Cafes',
      placeCategory: json['place_category']?.toString() ?? json['primary_category']?.toString() ?? 'Cafes',
      subCategories: subCats,
      area: json['area']?.toString() ?? 'George Town',
      address: json['place_address']?.toString() ?? json['address']?.toString() ?? '',
      lat: lat,
      lng: lng,
      geofenceRadius: (json['place_geofence_radius'] as num?)?.toDouble() ??
          (json['geofence_radius'] as num?)?.toDouble() ??
          50.0,
      summary: json['summary']?.toString() ?? pSummary,
      placeSummary: pSummary,
      description: (json['description'] != null && json['description'].toString().trim().isNotEmpty)
          ? json['description'].toString().trim()
          : pSummary,
      avgDurationMinutes: (json['avg_duration_minutes'] as num?)?.toInt() ?? 60,
      rawHoursText: json['raw_hours_text']?.toString() ?? 'Check online',
      openingHours: (json['opening_hours'] is Map)
          ? Map<String, dynamic>.from(json['opening_hours'])
          : (json['place_business_hours'] is Map
              ? Map<String, dynamic>.from(json['place_business_hours'])
              : null),
      isOpenNow: json['is_open_now'] == true,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      priceLevel: (json['price_level'] as num?)?.toInt() ?? 1,
      features: json['features'] != null && json['features'] is Map<String, dynamic>
          ? PlaceFeatures.fromJson(json['features'])
          : null,
      information: json['place_information'] != null && json['place_information'] is Map<String, dynamic>
          ? PlaceInformation.fromJson(json['place_information'])
          : null,
      thumbnail: thumb,
      images: imgList,
      hasStreetView: json['hasStreetView'] == true || json['has_street_view'] == true,
      isPano: json['isPano'] == true,
      mapillaryImageId: json['mapillaryImageId']?.toString() ?? json['mapillary_image_id']?.toString(),
      streetViewUpdatedAt: svUpdatedAt,
      searchKeywords: keywords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'external_place_id': externalPlaceId,
      'name': name,
      'place_name': name,
      'name_zh': nameZh,
      'primary_category': primaryCategory,
      'place_category': placeCategory,
      'sub_categories': subCategories,
      'area': area,
      'address': address,
      'place_address': address,
      'lat': lat,
      'lng': lng,
      'geofence_radius': geofenceRadius,
      'summary': summary,
      'place_summary': placeSummary,
      'description': description,
      'avg_duration_minutes': avgDurationMinutes,
      'raw_hours_text': rawHoursText,
      'opening_hours': openingHours,
      'is_open_now': isOpenNow,
      'rating': rating,
      'review_count': reviewCount,
      'price_level': priceLevel,
      'features': features.toJson(),
      'place_information': information.toJson(),
      'place_media': {
        'thumbnail': thumbnail,
        'photos': images.map((i) => i.url).toList(),
      },
      'hasStreetView': hasStreetView,
      'isPano': isPano,
      'mapillaryImageId': mapillaryImageId,
      'streetViewUpdatedAt': streetViewUpdatedAt?.toIso8601String(),
      'search_keywords': searchKeywords,
    };
  }
}
