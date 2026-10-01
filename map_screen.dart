import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import '../theme.dart';
import 'package:flutter/services.dart';
import 'main_navigation.dart';
import 'package:http/http.dart' as http;
import '../services/places_service.dart';
import '../services/location_service.dart';
import '../controllers/trip_controller.dart';

// Searchable Location model
class MapLocation {
  final String name;
  final double lat;
  final double lng;
  final String description;

  const MapLocation({
    required this.name,
    required this.lat,
    required this.lng,
    required this.description,
  });
}

// Public Transport Station model
class TransportStation {
  final String name;
  final double lat;
  final double lng;
  final IconData icon;

  const TransportStation({
    required this.name,
    required this.lat,
    required this.lng,
    required this.icon,
  });
}

class MapScreen extends StatefulWidget {
  final MapLocation? destination;
  final bool showRouteToDestination;
  final Map<String, dynamic>? shapes;
  final List<dynamic>? stops;
  final List<ItineraryPlace>? itineraryPlaces;
  final bool isItineraryPreview;
  final int initialPlaceIndex;

  const MapScreen({
    super.key,
    this.destination,
    this.showRouteToDestination = false,
    this.shapes,
    this.stops,
    this.itineraryPlaces,
    this.isItineraryPreview = false,
    this.initialPlaceIndex = 0,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with SingleTickerProviderStateMixin {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;
  final PlacesService _placesService = PlacesService();
  int _searchSessionId = 0;

  // Map state configuration
  bool _isTerrainView = false;
  bool _showTransport = false;
  bool _showTraffic = false;

  final TextEditingController _searchController = TextEditingController();
  List<MapLocation> _suggestions = [];
  MapLocation? _selectedLocation;

  // Itinerary Step-through & Travel Mode State
  int _currentPlaceIndex = 0;
  String _selectedTravelMode = 'car'; // 'car', 'walk', 'transit'
  final TripController _tripController = TripController();
  bool _isPlanApplied = false;

  // Search dataset centered around Penang
  final List<MapLocation> _locations = const [
    MapLocation(name: 'George Town', lat: 5.4141, lng: 100.3288, description: 'Capital city of Penang, heritage hub.'),
    MapLocation(name: 'Bayan Lepas', lat: 5.2951, lng: 100.2595, description: 'Industrial free trade zone & airport location.'),
    MapLocation(name: 'Ayer Itam', lat: 5.4012, lng: 100.2780, description: 'Suburban town, home to Kek Lok Si.'),
    MapLocation(name: 'Tanjung Bungah', lat: 5.4659, lng: 100.2817, description: 'Seaside suburb with sandy beaches.'),
    MapLocation(name: 'Balik Pulau', lat: 5.3516, lng: 100.2369, description: 'Scenic countryside, famous for durians & farms.'),
    MapLocation(name: 'Batu Ferringhi', lat: 5.4748, lng: 100.2483, description: 'Famous resort beach strip in Penang.'),
    MapLocation(name: 'Butterworth', lat: 5.3991, lng: 100.3638, description: 'Major mainland port & transportation hub.'),
    MapLocation(name: 'Bukit Mertajam', lat: 5.3633, lng: 100.4562, description: 'Historical mainland town center.'),
    MapLocation(name: 'Kek Lok Si Temple', lat: 5.4012, lng: 100.2780, description: 'Largest Buddhist temple in Malaysia.'),
    MapLocation(name: 'Penang Hill', lat: 5.4084, lng: 100.2687, description: 'Cool hill resort offering panoramic views.'),
    MapLocation(name: 'ESCAPE Penang', lat: 5.4492, lng: 100.2154, description: 'Nature-based adventure theme park.'),
    MapLocation(name: 'Chew Jetty', lat: 5.4126, lng: 100.3396, description: 'Traditional wooden clan jetty on water.'),
  ];

  // Transport Stations dataset
  final List<TransportStation> _stations = const [
    TransportStation(name: 'Penang International Airport', lat: 5.2931, lng: 100.2651, icon: Icons.local_airport),
    TransportStation(name: 'Weld Quay Bus Terminal', lat: 5.4131, lng: 100.3440, icon: Icons.directions_bus_rounded),
    TransportStation(name: 'Raja Tun Uda Ferry Terminal', lat: 5.4138, lng: 100.3446, icon: Icons.directions_boat_rounded),
    TransportStation(name: 'Penang Sentral (Mainland)', lat: 5.3986, lng: 100.3683, icon: Icons.train_rounded),
    TransportStation(name: 'Penang Hill Lower Station', lat: 5.4082, lng: 100.2770, icon: Icons.tram_rounded),
    TransportStation(name: 'Sungai Nibong Bus Terminal', lat: 5.3344, lng: 100.3013, icon: Icons.directions_bus_rounded),
  ];

  // Map Bounds for Penang Malaysia to restrict map focus
  final double _penangLat = 5.4141;
  final double _penangLng = 100.3288;

  // Real-time GPS User Location state
  final LocationService _locationService = LocationService();
  double _userLat = LocationService.defaultLat;
  double _userLng = LocationService.defaultLng;
  bool _hasRealGpsLocation = false;
  StreamSubscription<Position>? _positionSubscription;

  // Simulation parameters for local vector fallback map
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _mapAnimation;

  // Check if Mapbox is correctly configured
  bool get _isMapboxConfigured {
    return AppConfig.mapboxAccessToken.isNotEmpty &&
        AppConfig.mapboxAccessToken != 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';
  }

  @override
  void initState() {
    super.initState();
    _isPlanApplied = _tripController.hasActiveTrip;

    if (_isMapboxConfigured) {
      mapbox.MapboxOptions.setAccessToken(AppConfig.mapboxAccessToken);
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Set initial position of fallback map (Centered on Penang)
    _transformationController.value = Matrix4.identity()
      ..translate(-120.0, -180.0) // Position coordinates near George Town
      ..scale(2.2);

    MainNavigation.mapFocusNotifier.addListener(_onMapFocusChanged);
    
    // Fetch live GPS location immediately
    _initUserLocation();

    // Focus location if itinerary places are provided or destination is passed
    if (widget.itineraryPlaces != null && widget.itineraryPlaces!.isNotEmpty) {
      _currentPlaceIndex = widget.initialPlaceIndex.clamp(0, widget.itineraryPlaces!.length - 1);
      final initialPlace = widget.itineraryPlaces![_currentPlaceIndex];
      _selectedLocation = MapLocation(
        name: initialPlace.name,
        lat: initialPlace.lat,
        lng: initialPlace.lng,
        description: initialPlace.description,
      );
      _searchController.text = initialPlace.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToLocation(initialPlace.lat, initialPlace.lng);
        }
      });
    } else if (widget.destination != null) {
      _selectedLocation = widget.destination;
      _searchController.text = widget.destination!.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToLocation(widget.destination!.lat, widget.destination!.lng);
        }
      });
    } else if (MainNavigation.mapFocusNotifier.value != null) {
      final initialLoc = MainNavigation.mapFocusNotifier.value!;
      _selectedLocation = initialLoc;
      _searchController.text = initialLoc.name;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToLocation(initialLoc.lat, initialLoc.lng);
        }
      });
    }
  }

  void _goToPlaceIndex(int index) {
    if (widget.itineraryPlaces == null || widget.itineraryPlaces!.isEmpty) return;
    final clamped = index.clamp(0, widget.itineraryPlaces!.length - 1);
    final place = widget.itineraryPlaces![clamped];
    setState(() {
      _currentPlaceIndex = clamped;
      _selectedLocation = MapLocation(
        name: place.name,
        lat: place.lat,
        lng: place.lng,
        description: place.description,
      );
      _searchController.text = place.name;
    });

    _navigateToLocation(place.lat, place.lng);
    if (_isMapboxConfigured) {
      _updateMapAnnotations();
    }
  }

  void _nextPlace() {
    if (widget.itineraryPlaces != null && _currentPlaceIndex < widget.itineraryPlaces!.length - 1) {
      _goToPlaceIndex(_currentPlaceIndex + 1);
    }
  }

  void _prevPlace() {
    if (widget.itineraryPlaces != null && _currentPlaceIndex > 0) {
      _goToPlaceIndex(_currentPlaceIndex - 1);
    }
  }

  // Calculate distance for the active leg:
  // Leg 1: User GPS -> Place 1
  // Leg 2+: Place[i-1] -> Place[i]
  double get _currentLegDistance {
    if (widget.itineraryPlaces == null || widget.itineraryPlaces!.isEmpty) {
      if (_selectedLocation != null) {
        return _calculateDistance(_userLat, _userLng, _selectedLocation!.lat, _selectedLocation!.lng);
      }
      return 0.0;
    }
    final current = widget.itineraryPlaces![_currentPlaceIndex];
    if (_currentPlaceIndex == 0) {
      return _calculateDistance(_userLat, _userLng, current.lat, current.lng);
    } else {
      final prev = widget.itineraryPlaces![_currentPlaceIndex - 1];
      return _calculateDistance(prev.lat, prev.lng, current.lat, current.lng);
    }
  }

  int _getCarDurationMinutes(double distKm) {
    return ((distKm / 28.0) * 60).round().clamp(2, 180);
  }

  int _getWalkDurationMinutes(double distKm) {
    return ((distKm / 4.5) * 60).round().clamp(1, 300);
  }

  int _getTransitDurationMinutes(double distKm) {
    return (((distKm / 16.0) * 60) + 5).round().clamp(5, 240);
  }

  Future<void> _initUserLocation({bool moveToLocation = false}) async {
    try {
      final pos = await _locationService.getCurrentPosition();
      if (pos != null && mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _hasRealGpsLocation = true;
        });

        if (_isMapboxConfigured) {
          _updateMapAnnotations();
        }

        if (moveToLocation) {
          _navigateToLocation(_userLat, _userLng, zoom: 16.0);
        }
      }
    } catch (e) {
      debugPrint('Location initialization error: $e');
    }

    _subscribeToLiveLocation();
  }

  void _subscribeToLiveLocation() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.getPositionStream()?.listen((pos) {
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _hasRealGpsLocation = true;
        });
        if (_isMapboxConfigured) {
          _updateMapAnnotations();
        }
      }
    });
  }

  Future<void> _moveToUserLocation() async {
    final hasPerm = await _locationService.requestPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable GPS & location permissions to view your real-time location.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    await _initUserLocation(moveToLocation: true);
  }

  void _onMapFocusChanged() {
    final location = MainNavigation.mapFocusNotifier.value;
    if (location != null) {
      setState(() {
        _selectedLocation = location;
        _searchController.text = location.name;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _navigateToLocation(location.lat, location.lng);
        }
      });
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    MainNavigation.mapFocusNotifier.removeListener(_onMapFocusChanged);
    _searchController.dispose();
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Camera navigation helper
  void _navigateToLocation(double lat, double lng, {double zoom = 16.5}) async {
    if (_isMapboxConfigured && _mapboxMap != null) {
      await _mapboxMap?.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
          zoom: zoom,
          bearing: 0,
          pitch: 0,
        ),
        mapbox.MapAnimationOptions(duration: 1500),
      );
      _updateMapAnnotations();
    } else {
      // Mock Map zoom animation
      final double minLat = 5.15;
      final double maxLat = 5.55;
      final double minLng = 100.15;
      final double maxLng = 100.55;

      final relX = (lng - minLng) / (maxLng - minLng);
      final relY = 1.0 - (lat - minLat) / (maxLat - minLat);

      // Coordinates mapping to pixel dimensions of map canvas (360x480 size)
      final targetX = relX * 360.0;
      final targetY = relY * 480.0;

      final double scale = 6.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height - 180.0; // Subtract search / options height

      final endMatrix = Matrix4.identity()
        ..translate(
          (screenWidth / 2) - (targetX * scale),
          (screenHeight / 2) - (targetY * scale),
        )
        ..scale(scale);

      _mapAnimation = Matrix4Tween(
        begin: _transformationController.value,
        end: endMatrix,
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOutCubic),
      );

      _animationController.addListener(() {
        _transformationController.value = _mapAnimation!.value;
      });

      _animationController.forward(from: 0.0);
    }
  }

  // Setup Mapbox Annotations (Markers and Traffic)
  void _updateMapAnnotations() async {
    if (_mapboxMap == null) return;

    // Clear previous annotations
    if (_pointAnnotationManager != null) {
      await _pointAnnotationManager?.deleteAll();
    }
    if (_polylineAnnotationManager != null) {
      await _polylineAnnotationManager?.deleteAll();
    }

    _pointAnnotationManager ??= await _mapboxMap!.annotations.createPointAnnotationManager();
    _polylineAnnotationManager ??= await _mapboxMap!.annotations.createPolylineAnnotationManager();

    // 1. Itinerary Places numbered markers & active leg route
    if (widget.itineraryPlaces != null && widget.itineraryPlaces!.isNotEmpty) {
      final places = widget.itineraryPlaces!;
      
      // Draw entire itinerary connection path
      final List<mapbox.Position> allCoords = [];
      for (final p in places) {
        allCoords.add(mapbox.Position(p.lng, p.lat));
      }
      if (allCoords.length >= 2) {
        _polylineAnnotationManager?.create(
          mapbox.PolylineAnnotationOptions(
            geometry: mapbox.LineString(coordinates: allCoords),
            lineColor: Colors.blue.withValues(alpha: 0.35).value,
            lineWidth: 3.0,
          ),
        );
      }

      // Draw active leg route
      final currentPlace = places[_currentPlaceIndex];
      final List<mapbox.Position> activeLegCoords = [];
      if (_currentPlaceIndex == 0) {
        activeLegCoords.add(mapbox.Position(_userLng, _userLat));
        activeLegCoords.add(mapbox.Position(currentPlace.lng, currentPlace.lat));
      } else {
        final prevPlace = places[_currentPlaceIndex - 1];
        activeLegCoords.add(mapbox.Position(prevPlace.lng, prevPlace.lat));
        activeLegCoords.add(mapbox.Position(currentPlace.lng, currentPlace.lat));
      }

      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: activeLegCoords),
          lineColor: const Color(0xFF2563EB).value,
          lineWidth: 5.5,
        ),
      );

      // Draw numbered markers for all stops
      for (int i = 0; i < places.length; i++) {
        final p = places[i];
        final isCurrent = i == _currentPlaceIndex;
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(p.lng, p.lat)),
            textField: '${i + 1}. ${p.name}',
            textSize: isCurrent ? 12.0 : 10.0,
            textColor: isCurrent ? Colors.blue.shade900.value : Colors.black87.value,
            textHaloColor: Colors.white.value,
            textHaloWidth: 2.0,
            textOffset: [0.0, 1.2],
          ),
        );
      }

      // Draw user GPS position marker
      _pointAnnotationManager?.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(_userLng, _userLat)),
          textField: 'Your Location',
          textSize: 9.0,
          textColor: Colors.indigo.value,
        ),
      );
      return;
    }

    // 2. Search Results pin
    if (_selectedLocation != null) {
      try {
        final byteData = await rootBundle.load('assets/images/discover-details-direct-to-live-maps-location-icon.png');
        final imageData = byteData.buffer.asUint8List();
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(_selectedLocation!.lng, _selectedLocation!.lat)),
            image: imageData,
            iconSize: 0.5, //2.5
          ),
        );
      } catch (e) {
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(_selectedLocation!.lng, _selectedLocation!.lat)),
            iconSize: 1.5,
          ),
        );
      }
    }

    // 1.1 Route navigation line
    if (widget.showRouteToDestination && _selectedLocation != null) {
      if (widget.shapes != null) {
        widget.shapes!.forEach((directionKey, pointsList) {
          if (pointsList is List) {
            final List<mapbox.Position> coords = [];
            for (var point in pointsList) {
              if (point is List && point.length >= 2) {
                final double lat = double.tryParse(point[0].toString()) ?? 0.0;
                final double lng = double.tryParse(point[1].toString()) ?? 0.0;
                if (lat != 0.0 && lng != 0.0) {
                  coords.add(mapbox.Position(lng, lat));
                }
              }
            }
            if (coords.isNotEmpty) {
              _polylineAnnotationManager?.create(
                mapbox.PolylineAnnotationOptions(
                  geometry: mapbox.LineString(coordinates: coords),
                  lineColor: Colors.teal.shade700.value,
                  lineWidth: 4.0,
                ),
              );
            }
          }
        });
      } else {
        _polylineAnnotationManager?.create(
          mapbox.PolylineAnnotationOptions(
            geometry: mapbox.LineString(coordinates: [
              mapbox.Position(_userLng, _userLat), // Real-time GPS user location
              mapbox.Position(_selectedLocation!.lng, _selectedLocation!.lat), // Destination
            ]),
            lineColor: Colors.blue.value,
            lineWidth: 5.0,
          ),
        );
      }
      
      // Load stop marker image
      Uint8List? stopMarkerBytes;
      try {
        final byteData = await rootBundle.load('assets/images/red-dot.png');
        stopMarkerBytes = byteData.buffer.asUint8List();
      } catch (_) {}

      // Draw bus stops on Mapbox if available
      if (widget.stops != null) {
        for (var stop in widget.stops!) {
          if (stop is Map) {
            final double lat = double.tryParse(stop['lat']?.toString() ?? '') ?? 0.0;
            final double lng = double.tryParse(stop['lng']?.toString() ?? '') ?? 0.0;
            final String stopName = stop['stop_name']?.toString() ?? 'Bus Stop';
            if (lat != 0.0 && lng != 0.0) {
              _pointAnnotationManager?.create(
                mapbox.PointAnnotationOptions(
                  geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
                  image: stopMarkerBytes,
                  iconSize: 0.8, // Small clean marker dot
                  textField: stopName,
                  textSize: 9.0,
                  textColor: Colors.red.shade900.value,
                  textOffset: [0.0, 1.2],
                ),
              );
            }
          }
        }
      }
      
      try {
        final byteData = await rootBundle.load('assets/images/rapid-bus-screen-people-icon.png');
        final imageData = byteData.buffer.asUint8List();
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(_userLng, _userLat)),
            image: imageData,
            iconSize: 0.5,
          ),
        );
      } catch (_) {
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(_userLng, _userLat)),
            iconSize: 1.5,
          ),
        );
      }
    }

    // 2. Transport Stations markers
    if (_showTransport) {
      for (final st in _stations) {
        _pointAnnotationManager?.create(
          mapbox.PointAnnotationOptions(
            geometry: mapbox.Point(coordinates: mapbox.Position(st.lng, st.lat)),
            iconSize: 1.0,
            textField: st.name,
            textColor: Colors.blue.value,
            textSize: 10,
          ),
        );
      }
    }

    // 3. Traffic polylines
    if (_showTraffic) {
      // Draw lines on Penang Bridges and Expressway
      // First Bridge (Heavy Traffic - Red)
      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: [
            mapbox.Position(100.3113, 5.3564),
            mapbox.Position(100.3325, 5.3535),
            mapbox.Position(100.3540, 5.3524),
            mapbox.Position(100.3804, 5.3621),
          ]),
          lineColor: Colors.red.value, // Heavy Traffic Simulated
          lineWidth: 4.0,
        ),
      );

      // Second Bridge (Smooth to Moderate Traffic - Green & Orange)
      // Batu Maung to Midpoint (Green)
      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: [
            mapbox.Position(100.2856, 5.2678),
            mapbox.Position(100.3015, 5.2612),
            mapbox.Position(100.3340, 5.2445),
          ]),
          lineColor: Colors.green.value, 
          lineWidth: 4.0,
        ),
      );
      // Midpoint to Batu Kawan (Orange)
      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: [
            mapbox.Position(100.3340, 5.2445),
            mapbox.Position(100.3685, 5.2425),
            mapbox.Position(100.4132, 5.2530),
          ]),
          lineColor: Colors.orange.value, 
          lineWidth: 4.0,
        ),
      );

      // Tun Dr Lim Chong Eu Expressway (Mixed Traffic)
      // George Town to Gelugor (Red/Heavy)
      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: [
            mapbox.Position(100.3400, 5.4200),
            mapbox.Position(100.3245, 5.3955),
            mapbox.Position(100.3118, 5.3662),
            mapbox.Position(100.3113, 5.3564),
          ]),
          lineColor: Colors.red.value,
          lineWidth: 3.5,
        ),
      );
      // Gelugor to Bayan Lepas (Green/Smooth)
      _polylineAnnotationManager?.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: [
            mapbox.Position(100.3113, 5.3564),
            mapbox.Position(100.3082, 5.3385),
            mapbox.Position(100.2985, 5.3125),
            mapbox.Position(100.2651, 5.2931),
          ]),
          lineColor: Colors.green.value,
          lineWidth: 3.5,
        ),
      );
    }
  }

  void _onSearchChanged(String text) async {
    final sessionId = ++_searchSessionId;
    
    if (text.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }

    final query = text.toLowerCase().trim();

    // 1. Check local static suggestions first (instant)
    final localMatches = _locations
        .where((loc) => loc.name.toLowerCase().contains(query))
        .toList();

    if (sessionId != _searchSessionId) return;
    setState(() {
      _suggestions = localMatches;
    });

    // 2. Query MongoDB backend places
    List<MapLocation> backendMatches = [];
    try {
      final backendResults = await _placesService.searchMultiplePlaces(query);
      if (backendResults.isNotEmpty) {
        for (final item in backendResults) {
          final title = item['title'] ?? '';
          final desc = item['description'] ?? 'Attraction in Penang';
          
          double lat = _penangLat;
          double lng = _penangLng;
          if (item['coordinates'] != null) {
            try {
              final List coordsList = json.decode(item['coordinates']!);
              if (coordsList.length == 2) {
                lng = coordsList[0].toDouble();
                lat = coordsList[1].toDouble();
              }
            } catch (_) {}
          }
          
          if (title.isNotEmpty) {
            backendMatches.add(MapLocation(
              name: title,
              lat: lat,
              lng: lng,
              description: desc,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('MongoDB Search failed: $e');
    }

    if (sessionId != _searchSessionId) return;

    // Combine unique suggestions
    final List<MapLocation> combined = [..._suggestions];
    for (final bLoc in backendMatches) {
      if (!combined.any((loc) => loc.name.toLowerCase() == bLoc.name.toLowerCase())) {
        combined.add(bLoc);
      }
    }

    setState(() {
      _suggestions = combined;
    });

    // 3. Fallback to OpenStreetMap API if MongoDB and local matches have no results!
    if (combined.isEmpty) {
      try {
        final osmResults = await _queryOpenStreetMapNominatim(query);
        if (sessionId != _searchSessionId) return;
        if (osmResults.isNotEmpty) {
          setState(() {
            _suggestions = osmResults;
          });
        }
      } catch (e) {
        debugPrint('OSM Search failed: $e');
      }
    }
  }

  Future<List<MapLocation>> _queryOpenStreetMapNominatim(String query) async {
    // Restrict search to Penang, Malaysia
    final searchPrompt = query.toLowerCase().contains('penang') ? query : '$query, Penang, Malaysia';
    
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeComponent(searchPrompt)}'
      '&format=json'
      '&addressdetails=1'
      '&limit=5'
    );

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'KiaPenangApp/1.0.0 (contact: support@kiapenang.example.com)',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      final List<MapLocation> results = [];
      for (final item in data) {
        final title = item['display_name']?.toString().split(',')[0] ?? query;
        final latStr = item['lat'];
        final lngStr = item['lon'];
        final address = item['address'] ?? {};
        final area = address['suburb'] ?? 
                     address['neighbourhood'] ?? 
                     address['city_district'] ?? 
                     address['city'] ?? 
                     'Penang';
                     
        if (latStr != null && lngStr != null) {
          results.add(MapLocation(
            name: title,
            lat: double.parse(latStr.toString()),
            lng: double.parse(lngStr.toString()),
            description: '$area • OSM Location',
          ));
        }
      }
      return results;
    }
    return [];
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  void _toggleTerrain() async {
    setState(() {
      _isTerrainView = !_isTerrainView;
    });

    if (_isMapboxConfigured && _mapboxMap != null) {
      final style = _isTerrainView ? mapbox.MapboxStyles.OUTDOORS : mapbox.MapboxStyles.MAPBOX_STREETS;
      await _mapboxMap?.loadStyleURI(style);
      // Wait for style load and re-add annotations
      Future.delayed(const Duration(milliseconds: 500), () {
        _updateMapAnnotations();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isItineraryMode = widget.itineraryPlaces != null && widget.itineraryPlaces!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // 1. DYNAMIC MAP CONTAINER (Mapbox OR Vector Mock Fallback)
          Positioned.fill(
            child: _isMapboxConfigured 
                ? mapbox.MapWidget(
                    cameraOptions: mapbox.CameraOptions(
                      center: mapbox.Point(coordinates: mapbox.Position(_penangLng, _penangLat)),
                      zoom: 10.5,
                    ),
                    onMapCreated: (mapboxMap) {
                      _mapboxMap = mapboxMap;
                      _updateMapAnnotations();
                    },
                  )
                : _buildFallbackVectorMap(),
          ),

          // 2. TOP BAR OVERLAY: ITINERARY PREVIEW BANNER OR SEARCH BAR
          if (isItineraryMode)
            Positioned(
              top: 24,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _isPlanApplied ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isPlanApplied ? 'Active Trip Route' : 'Draft Itinerary Preview (Unapplied)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF19244E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19244E),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_currentPlaceIndex + 1}/${widget.itineraryPlaces!.length}',
                                style: const TextStyle(
                                  color: Color(0xFFFFEA00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (widget.showRouteToDestination)
            Positioned(
              top: 24,
              left: 20,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 18),
                  ),
                ),
              ),
            )
          else
            Positioned(
              top: 24,
              left: 20,
              right: 20,
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.robotoMono(
                          fontSize: 14,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search Penang places...',
                          hintStyle: GoogleFonts.robotoMono(fontSize: 13, color: AppColors.textGrey),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textGrey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, color: AppColors.textGrey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _suggestions = [];
                                      _selectedLocation = null;
                                    });
                                    if (_isMapboxConfigured) _updateMapAnnotations();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ),

                    // Suggestions list drop-down
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final loc = _suggestions[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on_rounded, color: AppColors.secondaryRoyalBlue),
                                title: Text(
                                  loc.name,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                subtitle: Text(
                                  loc.description,
                                  style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.textGrey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedLocation = loc;
                                    _searchController.text = loc.name;
                                    _suggestions = [];
                                  });
                                  FocusScope.of(context).unfocus();
                                  _navigateToLocation(loc.lat, loc.lng);
                                },
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // 3. MAP STYLE & LAYER CONTROLS (Floating controls right side)
          Positioned(
            right: 20,
            bottom: isItineraryMode ? 210 : 120,
            child: Column(
              children: [
                // Real-time GPS Location button
                _buildMapControl(
                  icon: _hasRealGpsLocation ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  label: 'My GPS',
                  onTap: _moveToUserLocation,
                  isActive: _hasRealGpsLocation,
                ),
                const SizedBox(height: 12),

                // Toggle Terrain button
                _buildMapControl(
                  icon: _isTerrainView ? Icons.terrain_rounded : Icons.map_rounded,
                  label: _isTerrainView ? 'Terrain' : 'Normal',
                  onTap: _toggleTerrain,
                  isActive: _isTerrainView,
                ),
                const SizedBox(height: 12),
                
                // Toggle Transport Overlay
                _buildMapControl(
                  icon: Icons.directions_bus_rounded,
                  label: 'Transit',
                  onTap: () {
                    setState(() => _showTransport = !_showTransport);
                    if (_isMapboxConfigured) _updateMapAnnotations();
                  },
                  isActive: _showTransport,
                ),
                const SizedBox(height: 12),
                
                // Toggle Traffic Overlay
                _buildMapControl(
                  icon: Icons.traffic_rounded,
                  label: 'Traffic',
                  onTap: () {
                    setState(() => _showTraffic = !_showTraffic);
                    if (_isMapboxConfigured) _updateMapAnnotations();
                  },
                  isActive: _showTraffic,
                ),
              ],
            ),
          ),

          // 4. BOTTOM PANEL: ITINERARY INTERACTIVE PANEL OR DESTINATION ROUTE CARD
          if (isItineraryMode)
            _buildItineraryPreviewBottomPanel()
          else if (widget.showRouteToDestination) ...[
            Builder(
              builder: (context) {
                final double dist = _selectedLocation != null 
                    ? _calculateDistance(_userLat, _userLng, _selectedLocation!.lat, _selectedLocation!.lng)
                    : 0.0;
                return Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Route to ${_selectedLocation?.name ?? "Destination"}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDarkNavy,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.directions_walk, color: AppColors.secondaryRoyalBlue, size: 18),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _hasRealGpsLocation
                                      ? 'Distance: ${dist.toStringAsFixed(2)} km (from your live GPS location)'
                                      : 'Distance: ${dist.toStringAsFixed(2)} km (locating GPS...)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ],
        ],
      ),
    );
  }

  // Interactive Bottom Panel for Itinerary Step-Through Navigation
  Widget _buildItineraryPreviewBottomPanel() {
    final places = widget.itineraryPlaces!;
    final currentPlace = places[_currentPlaceIndex];
    final prevPlace = _currentPlaceIndex > 0 ? places[_currentPlaceIndex - 1] : null;
    final distKm = _currentLegDistance;
    final carMins = _getCarDurationMinutes(distKm);
    final walkMins = _getWalkDurationMinutes(distKm);
    final transitMins = _getTransitDurationMinutes(distKm);

    return Positioned(
      left: 14,
      right: 14,
      bottom: 16,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Header (Stop badge, Origin -> Destination title, Distance)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF19244E),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${_currentPlaceIndex + 1}',
                      style: const TextStyle(
                        color: Color(0xFFFFEA00),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto Mono',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentPlaceIndex == 0
                              ? 'Route to ${currentPlace.name}'
                              : 'From ${prevPlace?.name ?? "Previous Stop"} to ${currentPlace.name}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF19244E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _currentPlaceIndex == 0
                              ? 'Starting from your live GPS location'
                              : 'Leg between Stop #${_currentPlaceIndex} and Stop #${_currentPlaceIndex + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Text(
                      '📍 ${distKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 2: Ways to Travel header
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, size: 13, color: Color(0xFF4B5563)),
                  const SizedBox(width: 4),
                  Text(
                    'WAYS TO TRAVEL TO STOP #${_currentPlaceIndex + 1}:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Row 3: Travel Mode options (Car/Grab, Walk, Public Transit)
              Row(
                children: [
                  Expanded(
                    child: _buildTravelModeCard(
                      mode: 'car',
                      icon: Icons.directions_car_rounded,
                      label: 'By Car / Grab',
                      duration: '~$carMins min',
                      subtext: 'Fastest route',
                      isSelected: _selectedTravelMode == 'car',
                      onTap: () => setState(() => _selectedTravelMode = 'car'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTravelModeCard(
                      mode: 'walk',
                      icon: Icons.directions_walk_rounded,
                      label: 'By Walk',
                      duration: '~$walkMins min',
                      subtext: distKm <= 1.0 ? 'Scenic walk' : 'Foot transit',
                      isSelected: _selectedTravelMode == 'walk',
                      onTap: () => setState(() => _selectedTravelMode = 'walk'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildTravelModeCard(
                      mode: 'transit',
                      icon: Icons.directions_bus_rounded,
                      label: 'Public Bus',
                      duration: '~$transitMins min',
                      subtext: 'Rapid Penang',
                      isSelected: _selectedTravelMode == 'transit',
                      onTap: () => setState(() => _selectedTravelMode = 'transit'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Row 4: Step-Through Carousel & Navigation Buttons
              Row(
                children: [
                  // Previous Button
                  SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF19244E),
                        side: BorderSide(
                          color: _currentPlaceIndex > 0 ? const Color(0xFFCBD5E1) : Colors.grey.shade200,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: const Text(
                        'Prev',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _currentPlaceIndex > 0 ? _prevPlace : null,
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Stop Indicators Carousel Pills
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: places.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 5),
                        itemBuilder: (ctx, i) {
                          final isSel = i == _currentPlaceIndex;
                          return GestureDetector(
                            onTap: () => _goToPlaceIndex(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF19244E) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? const Color(0xFFFFEA00) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '#${i + 1}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSel ? const Color(0xFFFFEA00) : const Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Next Button (Following GEMINI.md Map Tab guidelines)
                  if (_currentPlaceIndex < places.length - 1)
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEA00), // Colors.yellowAccent[400]
                          foregroundColor: Colors.black,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        icon: const Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'Roboto Mono',
                          ),
                        ),
                        label: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.black),
                        onPressed: _nextPlace,
                      ),
                    )
                  else
                    SizedBox(
                      height: 38,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 15),
                        label: Text(
                          _isPlanApplied ? 'Applied ✔' : 'Apply Plan',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (!_isPlanApplied) {
                            _tripController.lockAndStartTrip();
                            setState(() => _isPlanApplied = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🎉 Itinerary Plan Confirmed & Applied!'),
                                backgroundColor: Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Plan is already active!'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
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

  Widget _buildTravelModeCard({
    required String mode,
    required IconData icon,
    required String label,
    required String duration,
    required String subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
            ),
            const SizedBox(height: 2),
            Text(
              duration,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControl({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.secondaryRoyalBlue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F7FA), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : AppColors.secondaryRoyalBlue,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.robotoMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Interactive Fallback Vector Map of Penang
  Widget _buildFallbackVectorMap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: const Color(0xFFE0F2F1), // Clean ocean blue-teal
          child: InteractiveViewer(
            transformationController: _transformationController,
            minScale: 1.0,
            maxScale: 6.0,
            child: Stack(
              children: [
                // Render Vector Penang Map shapes
                CustomPaint(
                  size: const Size(360, 480),
                  painter: PenangMapPainter(
                    isTerrain: _isTerrainView,
                    showTraffic: _showTraffic,
                    showTransport: _showTransport,
                    stations: _stations,
                    showRoute: widget.showRouteToDestination,
                    routeDestination: _selectedLocation,
                    itineraryPlaces: widget.itineraryPlaces,
                    currentPlaceIndex: _currentPlaceIndex,
                    userLat: _userLat,
                    userLng: _userLng,
                    hasUserGps: _hasRealGpsLocation,
                  ),
                ),

                // Plot Search Pin overlay dynamically (if not in itinerary mode)
                if (widget.itineraryPlaces == null && _selectedLocation != null) ...[
                  Builder(
                    builder: (context) {
                      final double minLat = 5.15;
                      final double maxLat = 5.55;
                      final double minLng = 100.15;
                      final double maxLng = 100.55;

                      final relX = (_selectedLocation!.lng - minLng) / (maxLng - minLng);
                      final relY = 1.0 - (_selectedLocation!.lat - minLat) / (maxLat - minLat);

                      return Positioned(
                        left: (relX * 360.0) - 24,
                        top: (relY * 480.0) - 48,
                        child: Image.asset(
                          'assets/images/discover-details-direct-to-live-maps-location-icon.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// Vector Painter for Penang Island, Mainland, Bridges, Traffic, Transit and Numbered Itinerary Pins
class PenangMapPainter extends CustomPainter {
  final bool isTerrain;
  final bool showTraffic;
  final bool showTransport;
  final List<TransportStation> stations;
  final bool showRoute;
  final MapLocation? routeDestination;
  final Map<String, dynamic>? routeShapes;
  final List<dynamic>? routeStops;
  final List<ItineraryPlace>? itineraryPlaces;
  final int currentPlaceIndex;
  final double userLat;
  final double userLng;
  final bool hasUserGps;

  PenangMapPainter({
    required this.isTerrain,
    required this.showTraffic,
    required this.showTransport,
    required this.stations,
    this.showRoute = false,
    this.routeDestination,
    this.routeShapes,
    this.routeStops,
    this.itineraryPlaces,
    this.currentPlaceIndex = 0,
    this.userLat = LocationService.defaultLat,
    this.userLng = LocationService.defaultLng,
    this.hasUserGps = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Map bounds mapping
    final double minLat = 5.15;
    final double maxLat = 5.55;
    final double minLng = 100.15;
    final double maxLng = 100.55;

    Offset toPixel(double lat, double lng) {
      final x = (lng - minLng) / (maxLng - minLng) * size.width;
      final y = (1.0 - (lat - minLat) / (maxLat - minLat)) * size.height;
      return Offset(x, y);
    }

    final paintLand = Paint()
      ..color = isTerrain ? const Color(0xFFC8E6C9) : const Color(0xFFF1F8E9)
      ..style = PaintingStyle.fill;

    final paintMainland = Paint()
      ..color = isTerrain ? const Color(0xFFA5D6A7) : const Color(0xFFECEFF1)
      ..style = PaintingStyle.fill;

    // 1. Draw Penang Island shape (Vector Approximation)
    final islandPath = Path()
      ..moveTo(toPixel(5.4750, 100.2500).dx, toPixel(5.4750, 100.2500).dy) // Batu Ferringhi
      ..lineTo(toPixel(5.4600, 100.2800).dx, toPixel(5.4600, 100.2800).dy) // Tanjung Bungah
      ..lineTo(toPixel(5.4300, 100.3100).dx, toPixel(5.4300, 100.3100).dy) // Pulau Tikus
      ..lineTo(toPixel(5.4200, 100.3400).dx, toPixel(5.4200, 100.3400).dy) // George Town
      ..lineTo(toPixel(5.3700, 100.3100).dx, toPixel(5.3700, 100.3100).dy) // Jelutong
      ..lineTo(toPixel(5.3100, 100.3050).dx, toPixel(5.3100, 100.3050).dy) // Bayan Lepas
      ..lineTo(toPixel(5.2700, 100.2700).dx, toPixel(5.2700, 100.2700).dy) // Teluk Tempoyak
      ..lineTo(toPixel(5.2800, 100.2000).dx, toPixel(5.2800, 100.2000).dy) // Gertak Sanggul
      ..lineTo(toPixel(5.3500, 100.2000).dx, toPixel(5.3500, 100.2000).dy) // Balik Pulau
      ..lineTo(toPixel(5.4200, 100.1900).dx, toPixel(5.4200, 100.1900).dy) // Pantai Acheh
      ..lineTo(toPixel(5.4600, 100.2000).dx, toPixel(5.4600, 100.2000).dy) // Teluk Bahang
      ..close();

    canvas.drawPath(islandPath, paintLand);

    // 2. Draw Seberang Perai Mainland
    final mainlandPath = Path()
      ..moveTo(toPixel(5.55, 100.37).dx, toPixel(5.55, 100.37).dy)
      ..lineTo(toPixel(5.55, 100.55).dx, toPixel(5.55, 100.55).dy)
      ..lineTo(toPixel(5.15, 100.55).dx, toPixel(5.15, 100.55).dy)
      ..lineTo(toPixel(5.15, 100.44).dx, toPixel(5.15, 100.44).dy)
      ..lineTo(toPixel(5.28, 100.41).dx, toPixel(5.28, 100.41).dy)
      ..lineTo(toPixel(5.35, 100.35).dx, toPixel(5.35, 100.35).dy)
      ..lineTo(toPixel(5.42, 100.36).dx, toPixel(5.42, 100.36).dy)
      ..close();

    canvas.drawPath(mainlandPath, paintMainland);

    final paintBridge = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 3. Draw Penang First Bridge
    final bridge1Path = Path()
      ..moveTo(toPixel(5.3564, 100.3113).dx, toPixel(5.3564, 100.3113).dy)
      ..lineTo(toPixel(5.3535, 100.3325).dx, toPixel(5.3535, 100.3325).dy)
      ..lineTo(toPixel(5.3524, 100.3540).dx, toPixel(5.3524, 100.3540).dy)
      ..lineTo(toPixel(5.3621, 100.3804).dx, toPixel(5.3621, 100.3804).dy);
    canvas.drawPath(bridge1Path, paintBridge);

    // 4. Draw Penang Second Bridge
    final bridge2Path = Path()
      ..moveTo(toPixel(5.2678, 100.2856).dx, toPixel(5.2678, 100.2856).dy)
      ..lineTo(toPixel(5.2612, 100.3015).dx, toPixel(5.2612, 100.3015).dy)
      ..lineTo(toPixel(5.2445, 100.3340).dx, toPixel(5.2445, 100.3340).dy)
      ..lineTo(toPixel(5.2425, 100.3685).dx, toPixel(5.2425, 100.3685).dy)
      ..lineTo(toPixel(5.2530, 100.4132).dx, toPixel(5.2530, 100.4132).dy);
    canvas.drawPath(bridge2Path, paintBridge);

    // 5. Draw major road grid outline
    final expressPath = Path()
      ..moveTo(toPixel(5.4200, 100.3400).dx, toPixel(5.4200, 100.3400).dy)
      ..lineTo(toPixel(5.3955, 100.3245).dx, toPixel(5.3955, 100.3245).dy)
      ..lineTo(toPixel(5.3662, 100.3118).dx, toPixel(5.3662, 100.3118).dy)
      ..lineTo(toPixel(5.3564, 100.3113).dx, toPixel(5.3564, 100.3113).dy)
      ..lineTo(toPixel(5.3385, 100.3082).dx, toPixel(5.3385, 100.3082).dy)
      ..lineTo(toPixel(5.3125, 100.2985).dx, toPixel(5.3125, 100.2985).dy)
      ..lineTo(toPixel(5.2931, 100.2651).dx, toPixel(5.2931, 100.2651).dy);

    final paintRoad = Paint()
      ..color = Colors.amber.shade300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(expressPath, paintRoad);

    // 6. Draw Traffic Overlay
    if (showTraffic) {
      final heavyTraffic = Paint()..color = Colors.red..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final moderateTraffic = Paint()..color = Colors.orange..strokeWidth = 3.0..style = PaintingStyle.stroke;
      final smoothTraffic = Paint()..color = Colors.green..strokeWidth = 3.0..style = PaintingStyle.stroke;

      canvas.drawPath(bridge1Path, heavyTraffic);

      final bridge2GreenPath = Path()
        ..moveTo(toPixel(5.2678, 100.2856).dx, toPixel(5.2678, 100.2856).dy)
        ..lineTo(toPixel(5.2612, 100.3015).dx, toPixel(5.2612, 100.3015).dy)
        ..lineTo(toPixel(5.2445, 100.3340).dx, toPixel(5.2445, 100.3340).dy);
      canvas.drawPath(bridge2GreenPath, smoothTraffic);
      
      final bridge2OrangePath = Path()
        ..moveTo(toPixel(5.2445, 100.3340).dx, toPixel(5.2445, 100.3340).dy)
        ..lineTo(toPixel(5.2425, 100.3685).dx, toPixel(5.2425, 100.3685).dy)
        ..lineTo(toPixel(5.2530, 100.4132).dx, toPixel(5.2530, 100.4132).dy);
      canvas.drawPath(bridge2OrangePath, moderateTraffic);

      final expressRedPath = Path()
        ..moveTo(toPixel(5.4200, 100.3400).dx, toPixel(5.4200, 100.3400).dy)
        ..lineTo(toPixel(5.3955, 100.3245).dx, toPixel(5.3955, 100.3245).dy)
        ..lineTo(toPixel(5.3662, 100.3118).dx, toPixel(5.3662, 100.3118).dy)
        ..lineTo(toPixel(5.3564, 100.3113).dx, toPixel(5.3564, 100.3113).dy);
      canvas.drawPath(expressRedPath, heavyTraffic);

      final expressGreenPath = Path()
        ..moveTo(toPixel(5.3564, 100.3113).dx, toPixel(5.3564, 100.3113).dy)
        ..lineTo(toPixel(5.3385, 100.3082).dx, toPixel(5.3385, 100.3082).dy)
        ..lineTo(toPixel(5.3125, 100.2985).dx, toPixel(5.3125, 100.2985).dy)
        ..lineTo(toPixel(5.2931, 100.2651).dx, toPixel(5.2931, 100.2651).dy);
      canvas.drawPath(expressGreenPath, smoothTraffic);
    }

    // 7. Draw Labels for towns
    final textStyle = TextStyle(
      color: Colors.blueGrey.shade800,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    void drawLabel(String text, double lat, double lng) {
      final pos = toPixel(lat, lng);
      final textSpan = TextSpan(text: text, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(pos.dx - (textPainter.width / 2), pos.dy - 12));
    }

    drawLabel('George Town', 5.4141, 100.3288);
    drawLabel('Bayan Lepas', 5.2951, 100.2595);
    drawLabel('Batu Ferringhi', 5.4748, 100.2483);
    drawLabel('Butterworth', 5.3991, 100.3638);
    drawLabel('Balik Pulau', 5.3516, 100.2369);

    // 8. Draw Public Transport Overlay (Transit Icons)
    if (showTransport) {
      final paintStation = Paint()..color = Colors.blue.shade700..style = PaintingStyle.fill;
      for (final st in stations) {
        final pos = toPixel(st.lat, st.lng);
        canvas.drawCircle(pos, 5.0, paintStation);

        final nameStyle = TextStyle(
          color: Colors.indigo.shade900,
          fontSize: 7,
          fontWeight: FontWeight.w600,
          backgroundColor: Colors.white70,
        );

        final textSpan = TextSpan(text: st.name, style: nameStyle);
        final textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
        textPainter.paint(canvas, Offset(pos.dx - (textPainter.width / 2), pos.dy + 6));
      }
    }

    // 9. Draw Real-time User GPS Marker Dot
    final userPos = toPixel(userLat, userLng);
    final pulsePaint = Paint()
      ..color = const Color(0xFF304FFE).withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 10.0, pulsePaint);

    final userDotPaint = Paint()..color = const Color(0xFF304FFE)..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 5.0, userDotPaint);

    final userBorderPaint = Paint()..color = Colors.white..strokeWidth = 2.0..style = PaintingStyle.stroke;
    canvas.drawCircle(userPos, 5.0, userBorderPaint);

    // 10. ITINERARY NUMBERED MARKERS & ROUTE LINES
    if (itineraryPlaces != null && itineraryPlaces!.isNotEmpty) {
      // 10A. Draw full itinerary sequence line (soft blue)
      final allRoutePaint = Paint()
        ..color = const Color(0xFF3B82F6).withOpacity(0.35)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < itineraryPlaces!.length - 1; i++) {
        final pA = toPixel(itineraryPlaces![i].lat, itineraryPlaces![i].lng);
        final pB = toPixel(itineraryPlaces![i + 1].lat, itineraryPlaces![i + 1].lng);
        canvas.drawLine(pA, pB, allRoutePaint);
      }

      // 10B. Draw Active Leg Route (Bold vibrant blue line)
      final activeRoutePaint = Paint()
        ..color = const Color(0xFF1D4ED8)
        ..strokeWidth = 4.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final currentP = itineraryPlaces![currentPlaceIndex];
      final currentPixel = toPixel(currentP.lat, currentP.lng);

      if (currentPlaceIndex == 0) {
        canvas.drawLine(userPos, currentPixel, activeRoutePaint);
      } else {
        final prevP = itineraryPlaces![currentPlaceIndex - 1];
        final prevPixel = toPixel(prevP.lat, prevP.lng);
        canvas.drawLine(prevPixel, currentPixel, activeRoutePaint);
      }

      // 10C. Draw Numbered Marker for each place
      for (int i = 0; i < itineraryPlaces!.length; i++) {
        final p = itineraryPlaces![i];
        final pos = toPixel(p.lat, p.lng);
        final isCurrent = i == currentPlaceIndex;

        // Glow for active marker
        if (isCurrent) {
          final glowPaint = Paint()
            ..color = const Color(0xFFFFEA00).withOpacity(0.5)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(pos, 16.0, glowPaint);

          final ringPaint = Paint()
            ..color = const Color(0xFFFFEA00)
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(pos, 13.0, ringPaint);
        }

        // Main pin circle
        final circlePaint = Paint()
          ..color = isCurrent ? const Color(0xFF19244E) : const Color(0xFF304FFE)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, isCurrent ? 11.0 : 8.5, circlePaint);

        // White border
        final borderPaint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(pos, isCurrent ? 11.0 : 8.5, borderPaint);

        // Number text inside pin
        final numSpan = TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: isCurrent ? const Color(0xFFFFEA00) : Colors.white,
            fontSize: isCurrent ? 10.5 : 8.5,
            fontWeight: FontWeight.bold,
          ),
        );
        final numPainter = TextPainter(text: numSpan, textDirection: TextDirection.ltr)..layout();
        numPainter.paint(canvas, Offset(pos.dx - (numPainter.width / 2), pos.dy - (numPainter.height / 2)));

        // Place label below pin
        final labelText = '${i + 1}. ${p.name}';
        final labelSpan = TextSpan(
          text: labelText,
          style: TextStyle(
            color: isCurrent ? const Color(0xFF19244E) : const Color(0xFF374151),
            fontSize: isCurrent ? 9.5 : 7.5,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            backgroundColor: Colors.white.withOpacity(0.85),
          ),
        );
        final labelPainter = TextPainter(text: labelSpan, textDirection: TextDirection.ltr)..layout();
        labelPainter.paint(canvas, Offset(pos.dx - (labelPainter.width / 2), pos.dy + (isCurrent ? 14 : 10)));
      }
    } else if (showRoute && routeDestination != null && routeShapes == null) {
      // Regular single destination route
      final destPos = toPixel(routeDestination!.lat, routeDestination!.lng);
      final routePaint = Paint()
        ..color = const Color(0xFF304FFE)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(userPos, destPos, routePaint);
    }

    // 11. Custom Shapes / Bus Stops (if provided)
    if (routeShapes != null) {
      final routeLinePaint = Paint()
        ..color = const Color(0xFF00796B)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      routeShapes!.forEach((key, pointsList) {
        if (pointsList is List && pointsList.isNotEmpty) {
          final path = Path();
          bool first = true;
          for (var point in pointsList) {
            if (point is List && point.length >= 2) {
              final double lat = double.tryParse(point[0].toString()) ?? 0.0;
              final double lng = double.tryParse(point[1].toString()) ?? 0.0;
              if (lat != 0.0 && lng != 0.0) {
                final pixelPos = toPixel(lat, lng);
                if (first) {
                  path.moveTo(pixelPos.dx, pixelPos.dy);
                  first = false;
                } else {
                  path.lineTo(pixelPos.dx, pixelPos.dy);
                }
              }
            }
          }
          if (!first) {
            canvas.drawPath(path, routeLinePaint);
          }
        }
      });
    }

    if (routeStops != null && (itineraryPlaces == null || itineraryPlaces!.isEmpty)) {
      final stopPaint = Paint()..color = const Color(0xFFC62828)..style = PaintingStyle.fill;
      final stopBorderPaint = Paint()..color = Colors.white..strokeWidth = 0.5..style = PaintingStyle.stroke;

      for (var stop in routeStops!) {
        if (stop is Map) {
          final double lat = double.tryParse(stop['lat']?.toString() ?? '') ?? 0.0;
          final double lng = double.tryParse(stop['lng']?.toString() ?? '') ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            final pixelPos = toPixel(lat, lng);
            canvas.drawCircle(pixelPos, 1.2, stopPaint);
            canvas.drawCircle(pixelPos, 1.2, stopBorderPaint);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PenangMapPainter oldDelegate) {
    return oldDelegate.isTerrain != isTerrain ||
        oldDelegate.showTraffic != showTraffic ||
        oldDelegate.showTransport != showTransport ||
        oldDelegate.showRoute != showRoute ||
        oldDelegate.routeDestination != routeDestination ||
        oldDelegate.routeShapes != routeShapes ||
        oldDelegate.routeStops != routeStops ||
        oldDelegate.itineraryPlaces != itineraryPlaces ||
        oldDelegate.currentPlaceIndex != currentPlaceIndex ||
        oldDelegate.userLat != userLat ||
        oldDelegate.userLng != userLng ||
        oldDelegate.hasUserGps != hasUserGps;
  }
}
