class Place {
  final String id;
  final String title;
  final double lat;
  final double lng;
  final bool hasStreetView;
  final String? mapillaryImageId;

  Place({
    required this.id,
    required this.title,
    required this.lat,
    required this.lng,
    this.hasStreetView = false,
    this.mapillaryImageId,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    // Compatible with GeoJSON coordinates: [lng, lat] or direct lat/lng fields
    double lat = 0.0;
    double lng = 0.0;

    if (json['place_location'] != null &&
        json['place_location']['coordinates'] is List &&
        (json['place_location']['coordinates'] as List).length >= 2) {
      final coords = json['place_location']['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else if (json['location'] != null &&
        json['location']['coordinates'] is List &&
        (json['location']['coordinates'] as List).length >= 2) {
      final coords = json['location']['coordinates'] as List;
      lng = (coords[0] as num).toDouble();
      lat = (coords[1] as num).toDouble();
    } else {
      lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (json['lng'] as num?)?.toDouble() ?? 0.0;
    }

    return Place(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? json['place_name']?.toString() ?? json['title']?.toString() ?? 'Unknown Place',
      lat: lat,
      lng: lng,
      hasStreetView: json['hasStreetView'] == true || json['has_street_view'] == true,
      mapillaryImageId: json['mapillaryImageId']?.toString() ?? json['mapillary_image_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'lat': lat,
      'lng': lng,
      'hasStreetView': hasStreetView,
      if (mapillaryImageId != null) 'mapillaryImageId': mapillaryImageId,
    };
  }
}
