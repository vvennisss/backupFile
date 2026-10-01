import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import '../theme.dart';
import '../config.dart';
import 'map_screen.dart';

class RapidBusDetailScreen extends StatefulWidget {
  final String busNumber;
  final String origin;
  final String destination;
  final String firstTrip;
  final String lastTrip;
  final String frequency;
  final String zone;
  final Map<String, dynamic>? shapes;
  final List<dynamic>? stops;

  const RapidBusDetailScreen({
    super.key,
    required this.busNumber,
    required this.origin,
    required this.destination,
    required this.firstTrip,
    required this.lastTrip,
    required this.frequency,
    required this.zone,
    this.shapes,
    this.stops,
  });

  @override
  State<RapidBusDetailScreen> createState() => _RapidBusDetailScreenState();
}

class _RapidBusDetailScreenState extends State<RapidBusDetailScreen> {
  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  mapbox.PolylineAnnotationManager? _polylineAnnotationManager;

  bool get _isMapboxConfigured {
    return AppConfig.mapboxAccessToken.isNotEmpty &&
        AppConfig.mapboxAccessToken != 'YOUR_MAPBOX_ACCESS_TOKEN_HERE';
  }

  @override
  void initState() {
    super.initState();
    if (_isMapboxConfigured) {
      mapbox.MapboxOptions.setAccessToken(AppConfig.mapboxAccessToken);
    }
  }

  // Mapped location coordinates for each route terminal
  MapLocation _getRouteCoordinates() {
    final cleanNo = widget.busNumber.trim().toUpperCase();
    switch (cleanNo) {
      case 'CAT':
        return const MapLocation(name: 'Weld Quay (Jetty)', lat: 5.4131, lng: 100.3440, description: 'CAT George Town Loop');
      case '101':
        return const MapLocation(name: 'Teluk Bahang', lat: 5.4591, lng: 100.2144, description: 'Route 101 Terminal');
      case '102':
        return const MapLocation(name: 'Teluk Bahang', lat: 5.4591, lng: 100.2144, description: 'Route 102 Terminal');
      case '104':
        return const MapLocation(name: 'Tanjung Bungah', lat: 5.4659, lng: 100.2817, description: 'Route 104 Terminal');
      case '201':
      case '202':
      case '203':
        return const MapLocation(name: 'Paya Terubong', lat: 5.3725, lng: 100.2750, description: 'Zone 200 Terminal');
      case '204':
        return const MapLocation(name: 'Penang Hill Lower Station', lat: 5.4082, lng: 100.2770, description: 'Penang Hill Lower Station');
      case '206':
        return const MapLocation(name: 'Lotus\'s Tengku Kudin', lat: 5.3792, lng: 100.3113, description: 'Lotus\'s Jelutong');
      case '301':
        return const MapLocation(name: 'Relau', lat: 5.3288, lng: 100.2775, description: 'Route 301 Terminal');
      case '302':
        return const MapLocation(name: 'Batu Maung', lat: 5.2831, lng: 100.2882, description: 'Route 302 Terminal');
      case '303':
      case '304':
        return const MapLocation(name: 'Bukit Gedung', lat: 5.3215, lng: 100.2812, description: 'Zone 300 Terminal');
      case '308':
        return const MapLocation(name: 'Gertak Sanggul', lat: 5.2811, lng: 100.1945, description: 'Route 308 Terminal');
      case '401':
      case '401E':
      case '403':
      case '404':
        return const MapLocation(name: 'Balik Pulau', lat: 5.3516, lng: 100.2369, description: 'Balik Pulau Bus Terminal');
      case '601':
      case '603':
      case '604':
        return const MapLocation(name: 'Penang Sentral', lat: 5.3986, lng: 100.3683, description: 'Penang Sentral Terminal');
      case '606':
      case '701':
      case '702':
      case '703':
      case '709':
      case '802':
        return const MapLocation(name: 'Bukit Mertajam', lat: 5.3633, lng: 100.4562, description: 'Bukit Mertajam Bus Terminal');
      case '801':
        return const MapLocation(name: 'Nibong Tebal', lat: 5.1685, lng: 100.4782, description: 'Nibong Tebal Bus Terminal');
      default:
        return const MapLocation(name: 'Komtar', lat: 5.4147, lng: 100.3298, description: 'Komtar Bus Terminal');
    }
  }

  void _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _drawRouteDetailsOnMapbox();
  }

  void _drawRouteDetailsOnMapbox() async {
    if (_mapboxMap == null) return;

    _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
    _polylineAnnotationManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();

    final destinationLoc = _getRouteCoordinates();

    double sumLat = 0;
    double sumLng = 0;
    int count = 0;

    // Load stop marker image
    Uint8List? stopMarkerBytes;
    try {
      final byteData = await rootBundle.load('assets/images/red-dot.png');
      stopMarkerBytes = byteData.buffer.asUint8List();
    } catch (_) {}

    // Draw bus stops on Mapbox
    if (widget.stops != null) {
      for (var stop in widget.stops!) {
        if (stop is Map) {
          final double lat = double.tryParse(stop['lat']?.toString() ?? '') ?? 0.0;
          final double lng = double.tryParse(stop['lng']?.toString() ?? '') ?? 0.0;
          if (lat != 0.0 && lng != 0.0) {
            sumLat += lat;
            sumLng += lng;
            count++;

            _pointAnnotationManager?.create(
              mapbox.PointAnnotationOptions(
                geometry: mapbox.Point(coordinates: mapbox.Position(lng, lat)),
                image: stopMarkerBytes,
                iconSize: 0.8, // Small clean marker dot
              ),
            );
          }
        }
      }
    }

    // Draw route shapes polylines on Mapbox
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
    }

    // Draw a prominent pin for the destination terminal
    try {
      final byteData = await rootBundle.load('assets/images/discover-details-direct-to-live-maps-location-icon.png');
      final imageData = byteData.buffer.asUint8List();
      _pointAnnotationManager?.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(destinationLoc.lng, destinationLoc.lat)),
          image: imageData,
          iconSize: 0.5,
        ),
      );
    } catch (_) {
      _pointAnnotationManager?.create(
        mapbox.PointAnnotationOptions(
          geometry: mapbox.Point(coordinates: mapbox.Position(destinationLoc.lng, destinationLoc.lat)),
          iconSize: 1.2,
        ),
      );
    }

    // Auto-center map on route center
    final double centerLat = count > 0 ? (sumLat / count) : destinationLoc.lat;
    final double centerLng = count > 0 ? (sumLng / count) : destinationLoc.lng;

    await _mapboxMap?.setCamera(
      mapbox.CameraOptions(
        center: mapbox.Point(coordinates: mapbox.Position(centerLng, centerLat)),
        zoom: 11.2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationLoc = _getRouteCoordinates();
    
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Rapid Buses',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Map Section (Interactive / Fallback Map)
            Container(
              height: MediaQuery.of(context).size.height * 0.5,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    // Dynamic Live Mapbox or Fallback Vector Map
                    Positioned.fill(
                      child: _isMapboxConfigured
                          ? mapbox.MapWidget(
                              cameraOptions: mapbox.CameraOptions(
                                center: mapbox.Point(
                                  coordinates: mapbox.Position(
                                    destinationLoc.lng,
                                    destinationLoc.lat,
                                  ),
                                ),
                                zoom: 11.0,
                              ),
                              onMapCreated: _onMapCreated,
                            )
                          : Container(
                              color: const Color(0xFFE0F2F1), // Clean ocean blue-teal
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 6.0,
                                child: CustomPaint(
                                  size: const Size(360, 480),
                                  painter: PenangMapPainter(
                                    isTerrain: false,
                                    showTraffic: false,
                                    showTransport: true,
                                    stations: [
                                      TransportStation(
                                        name: destinationLoc.name,
                                        lat: destinationLoc.lat,
                                        lng: destinationLoc.lng,
                                        icon: Icons.directions_bus_rounded,
                                      ),
                                    ],
                                    routeShapes: widget.shapes,
                                    routeStops: widget.stops,
                                  ),
                                ),
                              ),
                            ),
                    ),
                    
                    // Pin Overlay (only for vector map fallback)
                    if (!_isMapboxConfigured)
                      Builder(
                        builder: (context) {
                          final double minLat = 5.15;
                          final double maxLat = 5.55;
                          final double minLng = 100.15;
                          final double maxLng = 100.55;

                          final relX = (destinationLoc.lng - minLng) / (maxLng - minLng);
                          final relY = 1.0 - (destinationLoc.lat - minLat) / (maxLat - minLat);

                          return Positioned(
                            left: (relX * 360.0) - 16,
                            top: (relY * 480.0) - 32,
                            child: Image.asset(
                              'assets/images/discover-details-direct-to-live-maps-location-icon.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          );
                        },
                      ),

                    // Blue People Icon Overlay
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapScreen(
                                destination: destinationLoc,
                                showRouteToDestination: true,
                                shapes: widget.shapes,
                                stops: widget.stops,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/images/rapid-bus-screen-people-icon.png',
                              width: 38,
                              height: 38,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Information Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Information:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkNavy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.busNumber,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Origin -> Destination
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.origin,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Icon(
                          Icons.arrow_forward,
                          color: AppColors.black,
                          size: 20,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.destination,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Timing Row/Col
                  Text(
                    'first_trip: ${widget.firstTrip}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'last_trip: ${widget.lastTrip}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Fares Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E), // Dark Blue (Fares container)
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Fares:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.busNumber == 'CAT') ...[
                    const Text(
                      '• George Town CAT Shuttle is FREE of charge.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      '• Standard Passenger Fares:\n'
                      '  - 1st 7km: RM 1.40\n'
                      '  - 7km to 14km: RM 2.00\n'
                      '  - 14km to 21km: RM 2.70\n'
                      '  - 21km to 28km: RM 3.40\n'
                      '  - Over 28km: RM 4.00\n\n'
                      '• Payment Methods: Cash (Exact Fare) or Touch \'n Go Card.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
