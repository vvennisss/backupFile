import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/places_service.dart';
import 'detail_screen.dart';
import '../widgets/app_image_widget.dart';
import 'rapid_bus_detail_screen.dart';
import 'main_navigation.dart';
import 'map_screen.dart';

class ServiceListScreen extends StatefulWidget {
  final String serviceName;
  final String serviceRoute;

  const ServiceListScreen({
    super.key,
    required this.serviceName,
    required this.serviceRoute,
  });

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final PlacesService _placesService = PlacesService();
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Area Filter feature state for Rapid Buses
  String? _selectedArea;
  final List<String> _areas = [
    'City Center & Free Transit (CAT)',
    'Northern Coast',
    'Air Itam & Central Suburbs',
    'Bayan Lepas & Southern Penang',
    'Balik Pulau & Western Penang',
    'Mainland (Seberang Perai)',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final results = await _placesService.fetchServiceData(widget.serviceRoute);
      setState(() {
        _items = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _items = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri url = Uri.parse('tel:${phoneNumber.replaceAll(' ', '')}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    } catch (e) {
      debugPrint('Could not dial $phoneNumber: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _items.where((item) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final address = (item['address'] ?? '').toString().toLowerCase();
      final desc = (item['description'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || address.contains(query) || desc.contains(query);
    }).toList();

    Widget bodyContent;

    if (_isLoading) {
      bodyContent = SizedBox.expand(
        child: Image.asset(
          _getLoadingAnimationPath(),
          fit: BoxFit.cover,
        ),
      );
    } else if (_items.isEmpty) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: AppColors.textGrey),
              const SizedBox(height: 16),
              Text(
                'No ${widget.serviceName.toLowerCase()} found.',
                style: const TextStyle(fontSize: 16, color: AppColors.textDark, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please ensure the backend server and MongoDB are connected and running.',
                style: const TextStyle(fontSize: 14, color: AppColors.textGrey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryRoyalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final List<Map<String, dynamic>> displayList;
      if (widget.serviceRoute == 'accommodations') {
        displayList = filteredItems;
      } else if (widget.serviceRoute == 'rapid-buses') {
        if (_selectedArea != null) {
          displayList = _items.where((item) => _isItemInArea(item, _selectedArea!)).toList();
        } else {
          displayList = _items;
        }
      } else {
        displayList = _items;
      }

      if (displayList.isEmpty) {
        final String noItemsMsg = widget.serviceRoute == 'accommodations'
            ? 'No matching accommodations found.'
            : 'No rapid bus stations found in $_selectedArea.';
        bodyContent = Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              noItemsMsg,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
        );
      } else {
        bodyContent = ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: displayList.length,
          itemBuilder: (context, index) {
            final item = displayList[index];
            return _buildServiceCard(item);
          },
        );
      }
    }

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
        title: Text(
          widget.serviceName,
          style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Search Bar for Accommodations
          if (widget.serviceRoute == 'accommodations' && !_isLoading && _items.isNotEmpty)
            _buildSearchBar(),

          // 2. Nearest Bus Stop Button & Area Filter for Rapid Buses
          if (widget.serviceRoute == 'rapid-buses' && !_isLoading && _items.isNotEmpty) ...[
            _buildNearestBusStopButton(),
            _buildAreaFilterWidget(),
          ],

          // 3. Main content List
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.textDark, fontSize: 15),
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search accommodations...',
          hintStyle: const TextStyle(color: AppColors.textGrey, fontSize: 15),
          prefixIcon: const Icon(Icons.search, color: AppColors.secondaryRoyalBlue),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.textGrey, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildNearestBusStopButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _findAndNavigateToNearestBusStop,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondaryRoyalBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 2,
        ),
        icon: const Icon(Icons.my_location),
        label: const Text(
          'Find Nearest Bus Stop',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildAreaFilterWidget() {
    final hasFilter = _selectedArea != null;

    // Count how many bus stations are in the selected area
    final int filteredCount = hasFilter
        ? _items.where((item) => _isItemInArea(item, _selectedArea!)).length
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _showAreaSelectionDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasFilter
                          ? AppColors.accentMintTeal
                          : Colors.white,
                      foregroundColor: hasFilter
                          ? Colors.white
                          : AppColors.primaryDarkNavy,
                      side: BorderSide(
                        color: hasFilter
                            ? Colors.transparent
                            : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      elevation: hasFilter ? 2 : 0,
                    ),
                    icon: Icon(
                      hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
                      color: hasFilter ? Colors.blueGrey : AppColors.secondaryRoyalBlue,
                    ),
                    label: Text(
                      hasFilter ? 'Showing $_selectedArea stations' : 'Select specific area',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: hasFilter ? Colors.blueGrey : AppColors.primaryDarkNavy,
                      ),
                    ),
                  ),
                ),
              ),
              if (hasFilter) ...[
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _selectedArea = null;
                      });
                    },
                    tooltip: 'Clear filter',
                  ),
                ),
              ],
            ],
          ),
          if (hasFilter) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.secondaryRoyalBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.secondaryRoyalBlue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.secondaryRoyalBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _getZoneDescription(_selectedArea!),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryDarkNavy,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Divider(height: 1, thickness: 0.5),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryDarkNavy,
                      ),
                      children: [
                        const TextSpan(text: 'Found '),
                        TextSpan(
                          text: '$filteredCount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryRoyalBlue,
                          ),
                        ),
                        const TextSpan(
                          text: ' rapid bus routes in ',
                        ),
                        TextSpan(
                          text: _selectedArea!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  void _showAreaSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.location_city, color: AppColors.secondaryRoyalBlue),
              SizedBox(width: 8),
              Text('Select Area', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _areas.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final area = _areas[index];
                final isSelected = _selectedArea == area;
                return ListTile(
                  title: Text(
                    area,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.secondaryRoyalBlue : AppColors.primaryDarkNavy,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.secondaryRoyalBlue)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedArea = area;
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
            ),
          ],
        );
      },
    );
  }

  String _getLoadingAnimationPath() {
    switch (widget.serviceRoute) {
      case 'accommodations':
        return 'assets/images/accommodation-hotel-stays-loading-design.gif';
      case 'car-rentals':
        return 'assets/images/car-rental-loading-design.gif';
      case 'ferry-service':
        return 'assets/images/penang-ferry-service-loading-design.gif';
      case 'rapid-buses':
        return 'assets/images/rapid-buses-loading-design.gif';
      default:
        return 'assets/images/penang-weather-loading-waitingServer-animation-gif.gif';
    }
  }

  void _findAndNavigateToNearestBusStop() {
    if (_items.isEmpty) return;

    // Simulated user coordinates (Komtar, George Town, Penang)
    const double userLat = 5.4147;
    const double userLng = 100.3298;

    double minDistance = double.maxFinite;
    Map<String, dynamic>? nearestStop;

    for (final item in _items) {
      final coords = item['coordinates'] ?? {};
      final lat = coords['lat'];
      final lng = coords['lng'];

      if (lat != null && lng != null) {
        final dist = _calculateDistance(userLat, userLng, lat.toDouble(), lng.toDouble());
        if (dist < minDistance) {
          minDistance = dist;
          nearestStop = item;
        }
      }
    }

    if (nearestStop != null) {
      final stopName = nearestStop['name'] ?? 'Bus Stop';
      final stopAddress = nearestStop['address'] ?? 'Penang, Malaysia';
      final stopRef = nearestStop['ref'] ?? '';
      final coords = nearestStop['coordinates'] ?? {};
      final lat = coords['lat'];
      final lng = coords['lng'];

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.directions_bus, color: AppColors.secondaryRoyalBlue),
                SizedBox(width: 8),
                Text('Nearest Bus Stop', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stopName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Distance: ${minDistance.toStringAsFixed(2)} km away',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (stopRef.toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Routes: $stopRef', style: const TextStyle(fontSize: 13, color: AppColors.textDark)),
                ],
                const SizedBox(height: 8),
                Text(stopAddress, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 12),
                const Text(
                  '(Based on your current simulated location at Komtar, Penang)',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textGrey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppColors.textGrey)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  
                  // Switch tab to Map (index 2)
                  MainNavigation.selectedTabNotifier.value = 2;
                  // Focus the coordinates on Map
                  MainNavigation.mapFocusNotifier.value = MapLocation(
                    name: stopName,
                    lat: lat.toDouble(),
                    lng: lng.toDouble(),
                    description: 'Nearest Bus Stop: ${minDistance.toStringAsFixed(2)} km away. Routes: $stopRef',
                  );
                  // Pop back to root to reveal MainNavigation with Map Tab active
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryRoyalBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.map),
                label: const Text('Open in Map'),
              ),
            ],
          );
        },
      );
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  String _getDbZoneFromArea(String area) {
    switch (area) {
      case 'City Center & Free Transit (CAT)':
        return 'City Center';
      case 'Northern Coast':
        return 'Zone 100';
      case 'Air Itam & Central Suburbs':
        return 'Zone 200';
      case 'Bayan Lepas & Southern Penang':
        return 'Zone 300';
      case 'Balik Pulau & Western Penang':
        return 'Zone 400';
      case 'Mainland (Seberang Perai)':
        return 'Zone 600-800';
      default:
        return '';
    }
  }

  String _getZoneDescription(String area) {
    switch (area) {
      case 'City Center & Free Transit (CAT)':
        return 'These routes operate within the George Town city limits, including the free shuttle service for tourists and locals.';
      case 'Northern Coast':
        return 'These buses run along the northern coast of Penang Island, heading towards the popular beaches.';
      case 'Air Itam & Central Suburbs':
        return 'If you are heading to Kek Lok Si Temple, Penang Hill, or the densely populated central suburbs, these are your buses.';
      case 'Bayan Lepas & Southern Penang':
        return 'These routes connect the city center to the southern industrial zones, airport areas, and Queensbay Mall.';
      case 'Balik Pulau & Western Penang':
        return 'These buses travel across the hills or around the southern coast to reach the rural and agricultural western side of the island.';
      case 'Mainland (Seberang Perai)':
        return 'These routes start mostly from Penang Sentral (Butterworth), which connects to the ferry terminal, train station (KTM), and interstate buses.';
      default:
        return '';
    }
  }

  bool _isItemInArea(Map<String, dynamic> item, String area) {
    final dbZone = _getDbZoneFromArea(area);
    final itemZone = item['zone'] ?? '';
    if (dbZone == 'Zone 600-800') {
      return itemZone == 'Zone 600-800' || itemZone == 'Zone 600–800';
    }
    return itemZone.toString().toLowerCase().trim() == dbZone.toLowerCase().trim();
  }



  Widget _buildServiceCard(Map<String, dynamic> item) {
    switch (widget.serviceRoute) {
      case 'accommodations':
        return _buildAccommodationCard(item);
      case 'car-rentals':
        return _buildCarRentalCard(item);
      case 'ferry-service':
        return _buildFerryCard(item);
      case 'rapid-buses':
        return _buildBusCard(item);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- 1. ACCOMMODATION CARD DESIGN ---
  Widget _buildAccommodationCard(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Unknown Accommodation';
    final type = item['type'] ?? 'Hotel';
    final address = item['address'] ?? 'Penang, Malaysia';
    final desc = item['description'] ?? 'Comfortable stay in Penang.';
    final images = List<String>.from(item['images'] ?? []);
    final facilities = List<String>.from(item['facilities'] ?? []);
    final phone = item['phone'] ?? '';
    final website = item['website'] ?? '';
    final coords = item['coordinates'] ?? {};
    final lat = coords['lat'];
    final lng = coords['lng'];

    final imagePath = images.isNotEmpty ? images.first : 'no_image_found';

    return _buildBaseCard(
      title: name,
      subtitle: type,
      address: address,
      description: desc,
      imagePath: imagePath,
      phone: phone,
      website: website,
      lat: lat,
      lng: lng,
      extraWidgets: [
        if (facilities.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: facilities.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accentMintTeal.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                f,
                style: const TextStyle(fontSize: 11, color: AppColors.secondaryRoyalBlue, fontWeight: FontWeight.bold),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }

  // --- 2. CAR RENTAL CARD DESIGN ---
  Widget _buildCarRentalCard(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Car Rental';
    final address = item['address'] ?? 'Penang, Malaysia';
    final desc = item['description'] ?? 'Affordable car rentals in Penang.';
    final images = List<String>.from(item['images'] ?? []);
    final phone = item['phone'] ?? '';
    final website = item['website'] ?? '';
    final coords = item['coordinates'] ?? {};
    final lat = coords['lat'];
    final lng = coords['lng'];

    final imagePath = images.isNotEmpty ? images.first : 'no_image_found';

    return _buildBaseCard(
      title: name,
      subtitle: 'Car Rental Service',
      address: address,
      description: desc,
      imagePath: imagePath,
      phone: phone,
      website: website,
      lat: lat,
      lng: lng,
    );
  }

  // --- 3. FERRY CARD DESIGN ---
  Widget _buildFerryCard(Map<String, dynamic> item) {
    final name = item['name'] ?? 'Ferry Terminal';
    final address = item['address'] ?? 'Penang Port, Malaysia';
    final operator = item['operator'] ?? 'Penang Port';
    final phone = item['phone'] ?? '';
    final website = item['website'] ?? '';
    final sched = item['schedule'] ?? {};
    final firstFerry = sched['firstFerry'] ?? '06:30 AM';
    final lastFerry = sched['lastFerry'] ?? '11:30 PM';
    final coords = item['coordinates'] ?? {};
    final lat = coords['lat'];
    final lng = coords['lng'];

    return _buildBaseCard(
      title: name,
      subtitle: 'Ferry Terminal',
      address: address,
      description: 'Operator: $operator\nService hours: First ferry at $firstFerry, Last ferry at $lastFerry.',
      imagePath: 'no_image_found',
      phone: phone,
      website: website,
      lat: lat,
      lng: lng,
      extraWidgets: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200, width: 0.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppColors.amberOrange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'First Departure: $firstFerry | Last: $lastFerry',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- 4. RAPID BUS CARD DESIGN ---
  Widget _buildBusCard(Map<String, dynamic> item) {
    final busNumber = item['bus_number'] ?? 'N/A';
    final frequency = item['frequency'] ?? 'N/A';
    final origin = item['origin'] ?? 'N/A';
    final destination = item['destination'] ?? 'N/A';
    final firstTrip = item['first_trip'] ?? 'N/A';
    final lastTrip = item['last_trip'] ?? 'N/A';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RapidBusDetailScreen(
              busNumber: busNumber,
              origin: origin,
              destination: destination,
              firstTrip: firstTrip,
              lastTrip: lastTrip,
              frequency: frequency,
              zone: item['zone'] ?? '',
              shapes: item['shapes'],
              stops: item['stops'],
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (Red Background)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFC62828), // Dark Red
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    busNumber,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    frequency,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            // Body Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Origin -> Destination Row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          origin,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                          ),
                          textAlign: TextAlign.left,
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
                          destination,
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
                  const SizedBox(height: 12),
                  
                  // Trip Timings
                  Text(
                    'First trip: $firstTrip',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last trip: $lastTrip',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textGrey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- GENERAL BASE CARD WIDGET ---
  Widget _buildBaseCard({
    required String title,
    required String subtitle,
    required String address,
    required String description,
    required String imagePath,
    String phone = '',
    String website = '',
    double? lat,
    double? lng,
    List<Widget> extraWidgets = const [],
  }) {
    final String? coordinatesJson = (lat != null && lng != null) ? json.encode([lng, lat]) : null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailScreen(
              title: title,
              area: widget.serviceName,
              businessHours: 'Check schedule',
              description: description,
              imagePath: imagePath,
              address: address,
              coordinatesJson: coordinatesJson,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Image if available and of a valid image URL
            if (imagePath != 'no_image_found' && imagePath.isNotEmpty)
              AppImageWidget(
                imagePath: imagePath,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 12, color: AppColors.textGrey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Top right button navigation indicator
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.secondaryRoyalBlue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(fontSize: 12, color: AppColors.textDark),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Description summary
                  if (description.isNotEmpty) ...[
                    Text(
                      description,
                      style: const TextStyle(fontSize: 12, color: AppColors.textGrey, height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Custom extra widgets (like routes or facilities)
                  ...extraWidgets,

                  // Action Buttons (Call / Website)
                  if (phone.isNotEmpty || website.isNotEmpty) ...[
                    const Divider(height: 20, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (phone.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _makePhoneCall(phone),
                            icon: const Icon(Icons.phone, size: 16, color: AppColors.secondaryRoyalBlue),
                            label: Text(
                              phone,
                              style: const TextStyle(fontSize: 12, color: AppColors.secondaryRoyalBlue, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        if (phone.isNotEmpty && website.isNotEmpty) const SizedBox(width: 12),
                        if (website.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _launchURL(website),
                            icon: const Icon(Icons.language, size: 16, color: AppColors.secondaryRoyalBlue),
                            label: const Text(
                              'Website',
                              style: TextStyle(fontSize: 12, color: AppColors.secondaryRoyalBlue, fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
