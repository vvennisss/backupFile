import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import '../services/places_service.dart';
import '../services/weather_service.dart';
import 'map_screen.dart';
import '../widgets/app_image_widget.dart';


class ItineraryPlanScreen extends StatefulWidget {
  final int initialDayIndex;

  const ItineraryPlanScreen({
    super.key,
    this.initialDayIndex = 2,
  });

  @override
  State<ItineraryPlanScreen> createState() => _ItineraryPlanScreenState();
}

class _ItineraryPlanScreenState extends State<ItineraryPlanScreen> with TickerProviderStateMixin {
  final TripController _controller = TripController();
  final PlacesService _placesService = PlacesService();
  final WeatherService _weatherService = WeatherService();
  final Map<String, WeatherData> _areaWeatherCache = {};
  final Set<int> _expandedCardIndices = {}; // Cards collapsed by default
  final Set<String> _dismissedSuggestions = {}; // Dismissed in-sequence heat suggestions
  final Set<String> _resolvedWeatherConflicts = {}; // Track accepted/resolved weather conflicts
  bool _isWeatherGuardExpanded = false;
  late final AnimationController _breathingController;

  // History stack for Undo and Redo operations
  final List<List<ItineraryPlace>> _undoStack = [];
  final List<List<ItineraryPlace>> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _controller.addListener(_onControllerUpdate);
    _loadAreaWeatherForDraft();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) {
      _loadAreaWeatherForDraft();
      setState(() {});
    }
  }

  // Fetch real-time / cached area weather for all stops in the draft itinerary
  Future<void> _loadAreaWeatherForDraft() async {
    final places = _controller.draftItinerary;
    final areas = places.map((p) => p.specificArea).toSet();
    for (final area in areas) {
      if (_areaWeatherCache.containsKey(area)) continue;
      try {
        final samplePlace = places.firstWhere((p) => p.specificArea == area);
        final w = await _weatherService.fetchWeather(
          latitude: samplePlace.lat != 0.0 ? samplePlace.lat : 5.4141,
          longitude: samplePlace.lng != 0.0 ? samplePlace.lng : 100.3288,
          cityName: area,
        );
        if (mounted) {
          setState(() {
            _areaWeatherCache[area] = w;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _areaWeatherCache[area] = WeatherData.mockRainy();
          });
        }
      }
    }
  }

  // Save current state snapshot before performing any mutating action
  void _saveSnapshot() {
    _undoStack.add(List<ItineraryPlace>.from(_controller.draftItinerary));
    _redoStack.clear();
    if (_undoStack.length > 25) {
      _undoStack.removeAt(0);
    }
  }

  // Undo action
  void _undo() {
    if (_undoStack.isEmpty) return;
    final previous = _undoStack.removeLast();
    _redoStack.add(List<ItineraryPlace>.from(_controller.draftItinerary));
    _controller.setDraftItinerary(previous);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('↶ Action Undone'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Redo action
  void _redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.add(List<ItineraryPlace>.from(_controller.draftItinerary));
    _controller.setDraftItinerary(next);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('↷ Action Redone'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Pick Travel Dates
  Future<void> _selectTravelDates() async {
    final now = DateTime.now();
    final initialRange = _controller.travelDates ??
        DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 1)),
        );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      helpText: 'Select Travel Dates',
      confirmText: 'Confirm Dates',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF19244E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF19244E),
              secondary: Color(0xFF304FFE),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _controller.setTravelDates(picked);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Travel dates updated to ${_formatDateRange(picked)}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatDateRange(DateTimeRange? range) {
    if (range == null) return 'No dates selected';
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startM = months[range.start.month - 1];
    final startD = range.start.day.toString().padLeft(2, '0');
    final endM = months[range.end.month - 1];
    final endD = range.end.day.toString().padLeft(2, '0');
    final year = range.start.year;

    if (startM == endM) {
      return '$startM $startD – $endM $endD, $year';
    }
    return '$startM $startD – $endM $endD, $year';
  }

  // Launch Journey on Map
  Future<void> _launchJourneyOnMap() async {
    if (_controller.draftItinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one stop before viewing the map!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _controller.setMascotState(MascotState.flyAway, autoResetDuration: null);

    final placesList = List<ItineraryPlace>.from(_controller.draftItinerary);
    final firstPlace = placesList.first;
    final initialDestination = MapLocation(
      name: firstPlace.name,
      lat: firstPlace.lat,
      lng: firstPlace.lng,
      description: firstPlace.description,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          destination: initialDestination,
          showRouteToDestination: true,
          itineraryPlaces: placesList,
          isItineraryPreview: !_controller.hasActiveTrip,
          initialPlaceIndex: 0,
          stops: placesList
              .map((p) => {
                    'name': p.name,
                    'lat': p.lat,
                    'lng': p.lng,
                    'area': p.area,
                  })
              .toList(),
        ),
      ),
    );

    if (mounted) {
      _controller.setMascotState(MascotState.idle);
      setState(() {});
    }
  }

  // Open Place Picker Bottom Sheet
  void _openAddPlaceDialog() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];
    bool isSearching = false;

    final defaultSuggestions = [
      {'name': 'Penang Hill Funicular', 'area': 'Air Itam', 'category': 'Nature', 'lat': 5.4085, 'lng': 100.2770, 'duration': 90, 'desc': 'Scenic railway to panoramic hill top'},
      {'name': 'Khoo Kongsi Clan House', 'area': 'George Town', 'category': 'Heritage', 'lat': 5.4150, 'lng': 100.3370, 'duration': 60, 'desc': 'Grand Chinese clan temple architecture'},
      {'name': 'Chew Jetty Heritage Village', 'area': 'Weld Quay', 'category': 'Heritage', 'lat': 5.4132, 'lng': 100.3400, 'duration': 45, 'desc': 'Historic stilt house waterfront community'},
      {'name': 'Penang Peranakan Mansion', 'area': 'George Town', 'category': 'Museum', 'lat': 5.4180, 'lng': 100.3411, 'duration': 60, 'desc': 'Opulent Baba Nyonya heritage mansion with air conditioning'},
      {'name': 'Wonderfood Museum', 'area': 'George Town', 'category': 'Museum', 'lat': 5.4165, 'lng': 100.3410, 'duration': 60, 'desc': 'Giant food replica museum with full air conditioning'},
      {'name': 'Escape Theme Park', 'area': 'Teluk Bahang', 'category': 'Adventure', 'lat': 5.4485, 'lng': 100.2155, 'duration': 180, 'desc': 'World-class outdoor & water adventure park'},
      {'name': 'Entopia by Penang Butterfly Farm', 'area': 'Teluk Bahang', 'category': 'Nature', 'lat': 5.4462, 'lng': 100.2227, 'duration': 90, 'desc': 'Vibrant living insect sanctuary and garden'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.78,
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
                      const Text(
                        'Add Stop to Itinerary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF19244E),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Search box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: searchCtrl,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                        hintText: 'Search Penang places or attractions...',
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                      ),
                      onChanged: (val) async {
                        if (val.trim().isEmpty) {
                          setModalState(() {
                            searchResults = [];
                            isSearching = false;
                          });
                          return;
                        }
                        setModalState(() => isSearching = true);
                        final res = await _placesService.searchMultiplePlaces(val.trim());
                        setModalState(() {
                          searchResults = res
                              .map((p) => {
                                    'name': p['title'] ?? '',
                                    'area': p['area'] ?? 'Penang',
                                    'category': p['category'] ?? 'Attraction',
                                    'lat': 5.414,
                                    'lng': 100.328,
                                    'duration': 60,
                                    'desc': p['description'] ?? '',
                                  })
                              .toList();
                          isSearching = false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Suggestions & Popular Spots',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isSearching
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF304FFE)))
                        : ListView.separated(
                            itemCount: searchResults.isNotEmpty ? searchResults.length : defaultSuggestions.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, idx) {
                              final item = searchResults.isNotEmpty ? searchResults[idx] : defaultSuggestions[idx];
                              final isAlreadyAdded = _controller.draftItinerary.any((p) => p.name.toLowerCase() == item['name']!.toLowerCase());

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                leading: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.location_on, color: Color(0xFF304FFE), size: 22),
                                ),
                                title: Text(
                                  item['name']!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                ),
                                subtitle: Text(
                                  '${item['area']} • ${item['category']} • ${item['duration']} min',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isAlreadyAdded ? const Color(0xFF10B981) : const Color(0xFF304FFE),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: isAlreadyAdded
                                      ? null
                                      : () {
                                          _saveSnapshot();
                                          _controller.addPlaceToDraft(
                                            ItineraryPlace(
                                              id: 'add_${DateTime.now().millisecondsSinceEpoch}_$idx',
                                              name: item['name']!,
                                              area: item['area']!,
                                              description: item['desc'] ?? '',
                                              lat: (item['lat'] as num).toDouble(),
                                              lng: (item['lng'] as num).toDouble(),
                                              category: item['category']!,
                                              estimatedStayMinutes: item['duration'] as int,
                                            ),
                                          );
                                          setModalState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added ${item['name']} to itinerary!'),
                                              duration: const Duration(milliseconds: 1200),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                  child: Text(
                                    isAlreadyAdded ? 'Added' : 'Add',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  // Haversine straight-line distance calculation in kilometers
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    if (lat1 == 0.0 || lon1 == 0.0 || lat2 == 0.0 || lon2 == 0.0) return 0.0;
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Calculate realistic car transit time and distance between two stops in Penang
  Map<String, dynamic> _calculateCarTransit(ItineraryPlace from, ItineraryPlace to) {
    final straightKm = _calculateDistanceKm(from.lat, from.lng, to.lat, to.lng);
    // Real-world Penang road detour factor (~1.25x straight-line, min 0.3km)
    final roadKm = straightKm > 0 ? max(0.3, straightKm * 1.25) : 0.8;
    // Average urban/suburban driving speed in Penang is ~28 km/h + traffic/parking buffer
    final transitMins = max(3, (roadKm / 28 * 60).round() + (roadKm > 1.0 ? 3 : 1));
    return {
      'roadKm': roadKm,
      'straightKm': straightKm,
      'transitMins': transitMins,
    };
  }

  // Calculate dynamic time for a stop index based on cumulative stay duration + transit buffer
  String _getTimeSlotForIndex(int idx, List<ItineraryPlace> places) {
    if (idx < 0 || idx >= places.length) return '09:00 AM – 10:30 AM';
    final place = places[idx];
    if (place.bestVisitTime != null && place.bestVisitTime!.isNotEmpty) {
      return place.bestVisitTime!;
    }

    // Cumulative schedule starting at 09:00 AM (540 minutes from midnight)
    int currentMinutes = 9 * 60; // 09:00 AM

    for (int i = 0; i <= idx; i++) {
      final p = places[i];
      final stayMinutes = p.dynamicStayMinutes;
      final start = currentMinutes;
      final end = start + stayMinutes;

      if (i == idx) {
        return '${_formatClockTime(start)} – ${_formatClockTime(end)}';
      }

      // Dynamic car transit buffer between consecutive stops
      if (i + 1 < places.length) {
        final transit = _calculateCarTransit(places[i], places[i + 1]);
        currentMinutes = end + (transit['transitMins'] as int);
      } else {
        currentMinutes = end + 15;
      }
    }

    return '09:00 AM – 10:30 AM';
  }

  String _formatClockTime(int totalMinutes) {
    final normalized = totalMinutes % (24 * 60);
    final hour24 = normalized ~/ 60;
    final minute = normalized % 60;

    final period = hour24 >= 12 ? 'PM' : 'AM';
    int hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;

    final hStr = hour12.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  int? _parseClockTimeToMinutes(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final numbers = clean.replaceAll(RegExp(r'[^0-9:]'), '').split(':');
      if (numbers.length >= 2) {
        int hour = int.parse(numbers[0]);
        final min = int.parse(numbers[1]);
        if (isPM && hour < 12) hour += 12;
        if (isAM && hour == 12) hour = 0;
        return hour * 60 + min;
      }
    } catch (_) {}
    return null;
  }

  String _getRescheduledSlot(ItineraryPlace current, String currentSlot) {
    final parts = currentSlot.split('–');
    if (parts.length == 2) {
      final endMin = _parseClockTimeToMinutes(parts[1]);
      if (endMin != null) {
        final startMin = endMin + 15; // 15 min buffer between spots
        final afterEndMin = startMin + current.dynamicStayMinutes;
        return '${_formatClockTime(startMin)} – ${_formatClockTime(afterEndMin)}';
      }
    }
    return '04:15 PM – 05:45 PM';
  }

  ({int startHour, int endHour}) _parseTimeSlotHours(String timeSlot) {
    final parts = timeSlot.split('–');
    if (parts.length == 2) {
      final startMin = _parseClockTimeToMinutes(parts[0]) ?? (12 * 60);
      final endMin = _parseClockTimeToMinutes(parts[1]) ?? (14 * 60);
      return (startHour: startMin ~/ 60, endHour: endMin ~/ 60);
    }
    return (startHour: 12, endHour: 14);
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_sunny_rounded;
    final cond = condition.toLowerCase();
    if (cond.contains('rain') || cond.contains('drizzle')) return Icons.grain_rounded;
    if (cond.contains('thunder')) return Icons.thunderstorm_rounded;
    if (cond.contains('cloud')) return Icons.cloud_outlined;
    return Icons.wb_sunny_rounded;
  }

  Color _getWeatherColor(String? condition) {
    if (condition == null) return const Color(0xFFF59E0B);
    final cond = condition.toLowerCase();
    if (cond.contains('rain') || cond.contains('thunder')) return const Color(0xFF2563EB);
    if (cond.contains('cloud')) return const Color(0xFF64748B);
    return const Color(0xFFF59E0B);
  }

  String _getAreaWeatherSummary(String area, WeatherData? weather) {
    if (weather == null) {
      return 'Forecast in $area: Warm tropical weather, ideal for exploration.';
    }
    if (weather.isRainy || weather.precipitationProbabilityMax >= 50) {
      return 'Showers predicted in $area. Carry an umbrella or plan indoor breaks.';
    }
    if (weather.uvIndex >= 7.0 || weather.temp >= 32.0) {
      return 'High UV & heat in $area. Stay hydrated and seek shaded spots midday.';
    }
    return 'Pleasant conditions expected in $area for sightseeing.';
  }

  Widget _buildMiniWeatherStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  static const Map<String, ({String label, IconData icon})> _featureCatalog = {
    'is_wheelchair_accessible': (label: 'Wheelchair Accessible', icon: Icons.accessible_rounded),
    'has_aircon': (label: 'Air-Conditioned', icon: Icons.ac_unit_rounded),
    'is_halal': (label: 'Halal Certified', icon: Icons.verified_user_rounded),
    'has_parking': (label: 'Parking Available', icon: Icons.local_parking_rounded),
    'wifi_available': (label: 'Free Wi-Fi', icon: Icons.wifi_rounded),
    'is_vegetarian_friendly': (label: 'Vegetarian Friendly', icon: Icons.eco_rounded),
    'is_michelin': (label: 'Michelin Guide', icon: Icons.restaurant_menu_rounded),
    'specialty_coffee': (label: 'Specialty Coffee', icon: Icons.coffee_rounded),
    'pet_friendly': (label: 'Pet Friendly', icon: Icons.pets_rounded),
    'free_entry': (label: 'Free Entry', icon: Icons.money_off_rounded),
  };

  List<({String label, IconData icon})> _getPlaceFeatureTags(ItineraryPlace place) {
    final list = <({String label, IconData icon})>[];
    place.features.forEach((key, isTrue) {
      if (isTrue && _featureCatalog.containsKey(key)) {
        list.add(_featureCatalog[key]!);
      }
    });

    if (list.isEmpty) {
      final n = place.name.toLowerCase();
      final c = place.category.toLowerCase();
      if (n.contains('street art') || n.contains('jetty') || n.contains('fort') || n.contains('clan')) {
        list.add(_featureCatalog['is_wheelchair_accessible']!);
        list.add(_featureCatalog['free_entry']!);
      } else if (n.contains('mansion') || n.contains('museum') || n.contains('gallery') || n.contains('mall')) {
        list.add(_featureCatalog['has_aircon']!);
        list.add(_featureCatalog['is_wheelchair_accessible']!);
        list.add(_featureCatalog['has_parking']!);
      } else if (c.contains('food') || c.contains('cafe')) {
        list.add(_featureCatalog['is_halal']!);
        list.add(_featureCatalog['has_parking']!);
      } else {
        list.add(_featureCatalog['has_parking']!);
        list.add(_featureCatalog['is_wheelchair_accessible']!);
      }
    }
    return list;
  }

  String _getOpeningHoursForDay(ItineraryPlace place, DateTime visitDate) {
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final weekdayName = weekdays[visitDate.weekday - 1];
    final dayKey = weekdayName.toLowerCase();

    if (place.openingHours != null) {
      try {
        dynamic raw = place.openingHours;
        if (raw is String && raw.startsWith('{')) {
          raw = json.decode(raw);
        }
        if (raw is Map) {
          for (final entry in raw.entries) {
            if (entry.key.toString().toLowerCase() == dayKey) {
              return '$weekdayName: ${entry.value}';
            }
          }
          if (raw.containsKey('hours')) {
            return '$weekdayName: ${raw['hours']}';
          }
        } else if (raw is String && raw.isNotEmpty && !raw.startsWith('{')) {
          return '$weekdayName: $raw';
        }
      } catch (_) {}
    }

    if (place.businessHours != null && place.businessHours!.isNotEmpty && !place.businessHours!.startsWith('{')) {
      return '$weekdayName: ${place.businessHours}';
    }

    final n = place.name.toLowerCase();
    if (n.contains('street art') || n.contains('mural') || n.contains('beach') || n.contains('jetty')) {
      return '$weekdayName: Open 24 Hours';
    }
    if (n.contains('peranakan')) {
      return '$weekdayName: 09:30 – 17:00';
    }
    if (n.contains('blue mansion') || n.contains('cheong fatt tze')) {
      return '$weekdayName: 11:00 – 18:00';
    }
    if (n.contains('khoo kongsi')) {
      return '$weekdayName: 09:00 – 17:00';
    }
    if (n.contains('fort cornwallis')) {
      return '$weekdayName: 08:00 – 20:00';
    }
    if (n.contains('balik pulau') || n.contains('艺术村') || n.contains('dream farm')) {
      return '$weekdayName: 09:00 – 18:00';
    }
    if (n.contains('kek lok si')) {
      return '$weekdayName: 08:30 – 17:30';
    }
    if (n.contains('penang hill') || n.contains('funicular')) {
      return '$weekdayName: 06:30 – 23:00';
    }
    if (n.contains('entopia') || n.contains('butterfly')) {
      return '$weekdayName: 09:00 – 17:00';
    }
    if (n.contains('escape')) {
      return '$weekdayName: 10:00 – 18:00';
    }
    if (n.contains('wonderfood')) {
      return '$weekdayName: 09:00 – 18:00';
    }
    if (n.contains('top penang') || n.contains('komtar')) {
      return '$weekdayName: 11:00 – 22:00';
    }
    if (n.contains('market') || n.contains('pasir') || n.contains('pasar')) {
      return '$weekdayName: 07:00 – 13:00';
    }

    return '$weekdayName: 09:00 – 18:00';
  }

  String _getRainTimeWindow(WeatherData? weather) {
    if (weather == null) return 'No rainfall predicted';
    final rainHours = weather.hourlyForecast.where(
      (h) => h.precipProb >= 40 || h.condition.toLowerCase().contains('rain'),
    ).toList();
    if (rainHours.isEmpty) {
      if (weather.precipitationProbabilityMax >= 50) {
        return 'Possible passing showers around 02:30 PM – 04:30 PM';
      }
      return 'Low rain risk during travel hours';
    }
    final startHour = rainHours.first.time.hour;
    final endHour = min(23, rainHours.last.time.hour + 1);
    return 'Rain window: ${_formatClockTime(startHour * 60)} – ${_formatClockTime(endHour * 60)} (${rainHours.first.precipProb}%)';
  }

  // Detect route zig-zag / backtrack inefficiencies between distant Penang areas
  Map<String, dynamic>? _detectRouteInefficiency(List<ItineraryPlace> places) {
    if (places.length < 3) return null;

    for (int i = 0; i < places.length - 2; i++) {
      final areaA = places[i].specificArea;
      for (int j = i + 1; j < places.length - 1; j++) {
        final areaB = places[j].specificArea;
        if (areaA == areaB) continue;

        final distAB = _calculateDistanceKm(
          places[i].lat, places[i].lng,
          places[j].lat, places[j].lng,
        );

        // Meaningful distance between distinct areas (e.g. George Town <-> Balik Pulau is ~17.5km)
        if (distAB >= 8.5) {
          for (int k = j + 1; k < places.length; k++) {
            final areaC = places[k].specificArea;
            if (areaC == areaA) {
              final distBC = _calculateDistanceKm(
                places[j].lat, places[j].lng,
                places[k].lat, places[k].lng,
              );
              final totalDetourKm = (distAB + distBC) * 1.25;
              final extraMins = ((totalDetourKm / 26) * 60).round();

              return {
                'fromArea': areaA,
                'detourArea': areaB,
                'detourKm': totalDetourKm,
                'extraMinutes': extraMins,
                'message':
                    'You have stops alternating between $areaA and $areaB, then returning to $areaA (~${totalDetourKm.toStringAsFixed(1)} km detour across winding mountain/urban roads). This travel style will cause heavy traffic congestion, route inefficiency (路线不顺), and travel fatigue.',
              };
            }
          }
        }
      }
    }
    return null;
  }

  void _autoGroupByArea() {
    _saveSnapshot();
    final places = List<ItineraryPlace>.from(_controller.draftItinerary);
    final areaOrder = <String>[];
    for (final p in places) {
      if (!areaOrder.contains(p.specificArea)) {
        areaOrder.add(p.specificArea);
      }
    }

    final grouped = <ItineraryPlace>[];
    for (final a in areaOrder) {
      grouped.addAll(places.where((p) => p.specificArea == a));
    }

    _controller.setDraftItinerary(grouped);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✨ Route re-clustered by area! Inefficient travel eliminated.'),
        backgroundColor: const Color(0xFF059669),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.amber,
          onPressed: _undo,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Collapsible Transit & Area Weather Card for Stop Item
  Widget _buildCollapsibleTransitAndWeatherCard(
    int index,
    ItineraryPlace place,
    List<ItineraryPlace> places,
  ) {
    final isExpanded = _expandedCardIndices.contains(index);
    final isFirstStop = index == 0;
    final prevPlace = !isFirstStop ? places[index - 1] : null;

    final transit = !isFirstStop
        ? _calculateCarTransit(prevPlace!, place)
        : {'roadKm': 0.0, 'transitMins': 0};
    final transitMins = transit['transitMins'] as int;
    final roadKm = transit['roadKm'] as double;

    // Retrieve cached weather or fallback
    final areaName = place.specificArea;
    final weather = _areaWeatherCache[areaName];

    // Summary line for collapsed/header state
    // Required mention: "(from xxx) transit time: 15m"
    final transitSummaryText = isFirstStop
        ? 'Starting Point • Plan begins here'
        : '(from ${prevPlace!.name}) transit time: ${transitMins}m';

    final weatherSummary = weather != null
        ? '${weather.temp.round()}°C • ${weather.condition}'
        : '30°C • Warm';

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapsible Header (Tappable)
          InkWell(
            onTap: () {
              setState(() {
                if (_expandedCardIndices.contains(index)) {
                  _expandedCardIndices.remove(index);
                } else {
                  _expandedCardIndices.add(index);
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4.5),
                    decoration: BoxDecoration(
                      color: isFirstStop ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      isFirstStop ? Icons.flag_outlined : Icons.directions_car_rounded,
                      size: 13.5,
                      color: isFirstStop ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transitSummaryText,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isFirstStop)
                          Text(
                            '${roadKm.toStringAsFixed(1)} km by car • $areaName',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Weather pill in header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getWeatherIcon(weather?.condition),
                          size: 11.5,
                          color: _getWeatherColor(weather?.condition),
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          weatherSummary,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Details
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transit Detail Card
                  if (!isFirstStop) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.drive_eta_rounded, size: 15, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                                children: [
                                  const TextSpan(text: 'Transportation: '),
                                  TextSpan(
                                    text: '(from ${prevPlace!.name}) transit time: ${transitMins}m',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  TextSpan(
                                    text: ' • ${roadKm.toStringAsFixed(1)} km driving distance',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.trip_origin, size: 15, color: Color(0xFF16A34A)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Day begins here at 09:00 AM. Initial starting location.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF166534), fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Weather Predict Card for this place area
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wb_cloudy_outlined, size: 13.5, color: Color(0xFF0284C7)),
                                const SizedBox(width: 4.5),
                                Text(
                                  'Weather Predict: $areaName',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                weather != null ? '${weather.temp.round()}°C' : '30°C',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0369A1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildMiniWeatherStat(
                              Icons.thermostat,
                              'Feels ${weather?.feelsLike.round() ?? 32}°C',
                              const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 10),
                            _buildMiniWeatherStat(
                              Icons.water_drop_outlined,
                              '${weather?.precipitationProbabilityMax ?? 20}% Rain',
                              const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 10),
                            _buildMiniWeatherStat(
                              Icons.wb_sunny_outlined,
                              'UV ${weather?.uvIndex.toStringAsFixed(1) ?? "6.0"}',
                              const Color(0xFFD97706),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _getAreaWeatherSummary(areaName, weather),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Opening Hours on the Visit Day
                  Builder(builder: (context) {
                    final visitDate = _controller.travelDates?.start ?? DateTime.now();
                    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                    final weekdayName = weekdays[visitDate.weekday - 1];
                    final openingHoursText = _getOpeningHoursForDay(place, visitDate);

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 13.5, color: Color(0xFF0F172A)),
                              const SizedBox(width: 5),
                              Text(
                                'Opening Hours ($weekdayName)',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Open on Visit Day',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            openingHoursText,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // 4. Place Feature Tags (if features are true in places_new)
                  Builder(builder: (context) {
                    final featureTags = _getPlaceFeatureTags(place);
                    if (featureTags.isEmpty) return const SizedBox.shrink();

                    return Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.stars_rounded, size: 13.5, color: Color(0xFF475569)),
                              SizedBox(width: 5),
                              Text(
                                'Features & Highlights',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 5,
                            children: featureTags.map((f) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(f.icon, size: 11.5, color: const Color(0xFF475569)),
                                    const SizedBox(width: 4),
                                    Text(
                                      f.label,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRemovePlace(int index, ItineraryPlace place) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Remove Place',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text('Are you sure you want to remove ${place.name} from your travel plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _saveSnapshot();
              _controller.removePlaceFromDraft(index, notifyChat: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${place.name}'),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: Colors.amber,
                    onPressed: _undo,
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Comprehensive multi-area indoor and sheltered attractions catalog
  static const List<ItineraryPlace> _indoorCandidates = [
      // Balik Pulau
      const ItineraryPlace(
        id: 'sug_bp_nutmeg',
        name: 'Ghee Hup Nutmeg Factory',
        area: 'Balik Pulau',
        description: 'Sheltered traditional nutmeg factory with fresh herbal processing',
        lat: 5.3582,
        lng: 100.2410,
        category: 'Heritage',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_bp_kim_laksa',
        name: 'Kim Laksa Balik Pulau',
        area: 'Balik Pulau',
        description: 'Covered local dining stall famous for Siamese Coconut & Assam Laksa',
        lat: 5.3524,
        lng: 100.2372,
        category: 'Food',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_bp_audi_farm',
        name: 'Audi Dream Farm',
        area: 'Balik Pulau',
        description: 'Sheltered family petting farm with organic vegetable patches',
        lat: 5.3420,
        lng: 100.2215,
        category: 'Nature',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_bp_saanen_goat',
        name: 'Saanen Dairy Goat Farm',
        area: 'Balik Pulau',
        description: 'Shaded family-run goat farm with organic dairy tastings',
        lat: 5.3620,
        lng: 100.2380,
        category: 'Nature',
        estimatedStayMinutes: 45,
      ),
      // Air Itam & Penang Hill
      const ItineraryPlace(
        id: 'sug_ai_kek_lok_si',
        name: 'Kek Lok Si Inner Pavilions',
        area: 'Air Itam',
        description: 'Sheltered Buddhist prayer halls and pagoda exhibits',
        lat: 5.4012,
        lng: 100.2780,
        category: 'Worship',
        estimatedStayMinutes: 75,
      ),
      const ItineraryPlace(
        id: 'sug_ai_market_laksa',
        name: 'Air Itam Market & Food Hall',
        area: 'Air Itam',
        description: 'Covered historic food court with legendary local hawkers',
        lat: 5.4019,
        lng: 100.2773,
        category: 'Food',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_ai_edgecliff_gallery',
        name: 'Penang Hill Gallery @ Edgecliff',
        area: 'Air Itam',
        description: 'Air-conditioned hill heritage gallery with scenic views',
        lat: 5.4242,
        lng: 100.2690,
        category: 'Museum',
        estimatedStayMinutes: 60,
      ),
      // Teluk Bahang
      const ItineraryPlace(
        id: 'sug_tb_entopia',
        name: 'Entopia Butterfly Sanctuary (The Cocoon)',
        area: 'Teluk Bahang',
        description: 'Air-conditioned indoor discovery dome with living butterflies',
        lat: 5.4470,
        lng: 100.2185,
        category: 'Nature',
        estimatedStayMinutes: 90,
      ),
      const ItineraryPlace(
        id: 'sug_tb_fruit_farm',
        name: 'Tropical Fruit Farm Pavilion',
        area: 'Teluk Bahang',
        description: 'Covered mountain fruit pavilion with fresh tropical fruit tastings',
        lat: 5.4150,
        lng: 100.2180,
        category: 'Food',
        estimatedStayMinutes: 50,
      ),
      const ItineraryPlace(
        id: 'sug_tb_batik_factory',
        name: 'Penang Batik Factory Teluk Bahang',
        area: 'Teluk Bahang',
        description: 'Indoor traditional batik art crafting workshop & showroom',
        lat: 5.4540,
        lng: 100.2230,
        category: 'Heritage',
        estimatedStayMinutes: 45,
      ),
      // Batu Ferringhi
      const ItineraryPlace(
        id: 'sug_bf_yahong',
        name: 'Yahong Art Gallery',
        area: 'Batu Ferringhi',
        description: 'Air-conditioned batik painting and antique cultural art center',
        lat: 5.4735,
        lng: 100.2458,
        category: 'Art',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_bf_spice_centre',
        name: 'Tropical Spice Garden Indoor Centre',
        area: 'Batu Ferringhi',
        description: 'Sheltered spice herb discovery hub and cooking pavilion',
        lat: 5.4632,
        lng: 100.2291,
        category: 'Nature',
        estimatedStayMinutes: 60,
      ),
      // Bayan Lepas / Southern Penang
      const ItineraryPlace(
        id: 'sug_bl_war_museum',
        name: 'Penang War Museum Bunker Tunnels',
        area: 'Bayan Lepas',
        description: 'Underground fortress bunkers and sheltered historical tunnels',
        lat: 5.2814,
        lng: 100.2889,
        category: 'Historic',
        estimatedStayMinutes: 75,
      ),
      const ItineraryPlace(
        id: 'sug_bl_fri_aquarium',
        name: 'Fisheries Research Institute Aquarium',
        area: 'Bayan Lepas',
        description: 'Air-conditioned marine conservation discovery aquarium',
        lat: 5.2851,
        lng: 100.2870,
        category: 'Nature',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_bl_snake_temple',
        name: 'Snake Temple & Heritage Hall',
        area: 'Bayan Lepas',
        description: 'Historic sheltered temple and heritage exhibition hall',
        lat: 5.3138,
        lng: 100.2852,
        category: 'Worship',
        estimatedStayMinutes: 45,
      ),
      const ItineraryPlace(
        id: 'sug_bl_queensbay',
        name: 'Queensbay Mall Cultural & Dining Hub',
        area: 'Bayan Lepas',
        description: 'Air-conditioned waterfront shopping & dining lifestyle complex',
        lat: 5.3328,
        lng: 100.3066,
        category: 'Shopping',
        estimatedStayMinutes: 60,
      ),
      // George Town
      const ItineraryPlace(
        id: 'sug_peranakan_mansion',
        name: 'Pinang Peranakan Mansion',
        area: 'George Town',
        description: 'Opulent indoor air-conditioned Baba Nyonya heritage museum',
        lat: 5.4180,
        lng: 100.3411,
        category: 'Museum',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_wonderfood',
        name: 'Wonderfood Museum',
        area: 'George Town',
        description: 'Vibrant indoor giant food replica museum with full air conditioning',
        lat: 5.4165,
        lng: 100.3410,
        category: 'Museum',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_state_museum',
        name: 'Penang State Museum & Art Gallery',
        area: 'George Town',
        description: 'Air-conditioned historical exhibits and Straits artwork',
        lat: 5.4205,
        lng: 100.3392,
        category: 'Museum',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_cheong_fatt_tze',
        name: 'Cheong Fatt Tze (The Blue Mansion)',
        area: 'George Town',
        description: 'Historic indigo-hued courtyard mansion and museum',
        lat: 5.4200,
        lng: 100.3340,
        category: 'Heritage',
        estimatedStayMinutes: 60,
      ),
      // Gurney & Pulau Tikus
      const ItineraryPlace(
        id: 'sug_gu_gurney_plaza',
        name: 'Gurney Plaza Indoor Atrium',
        area: 'Pulau Tikus',
        description: 'Modern air-conditioned seaside lifestyle and dining hub',
        lat: 5.4370,
        lng: 100.3095,
        category: 'Shopping',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_gu_dhammikarama',
        name: 'Dhammikarama Burmese Temple Hall',
        area: 'Pulau Tikus',
        description: 'Sheltered Burmese temple shrine with golden stupas',
        lat: 5.4312,
        lng: 100.3138,
        category: 'Worship',
        estimatedStayMinutes: 45,
      ),
      // Tanjung Bungah & Tanjung Tokong
      const ItineraryPlace(
        id: 'sug_tb_straits_quay',
        name: 'Straits Quay Marina Indoor Promenade',
        area: 'Tanjung Tokong',
        description: 'Covered seaside marina atrium with cafes, shops, and lighthouse walkway',
        lat: 5.4583,
        lng: 100.3133,
        category: 'Leisure',
        estimatedStayMinutes: 60,
      ),
      const ItineraryPlace(
        id: 'sug_tb_floating_mosque',
        name: 'Penang Floating Mosque Hall',
        area: 'Tanjung Bungah',
        description: 'Sheltered coastal prayer hall built on stilts over the ocean',
        lat: 5.4667,
        lng: 100.2764,
        category: 'Worship',
        estimatedStayMinutes: 45,
      ),
      // Butterworth & Mainland
      const ItineraryPlace(
        id: 'sug_bw_tow_boo_kong',
        name: 'Tow Boo Kong Temple Main Hall',
        area: 'Butterworth',
        description: 'Sheltered Nine Emperor Gods temple with majestic dragon pillars',
        lat: 5.4332,
        lng: 100.3846,
        category: 'Worship',
        estimatedStayMinutes: 50,
      ),
      const ItineraryPlace(
        id: 'sug_bw_bird_park',
        name: 'Penang Bird Park Covered Walkways',
        area: 'Butterworth',
        description: 'Sheltered aviary exhibits and nature discovery centre',
        lat: 5.3942,
        lng: 100.3985,
        category: 'Nature',
        estimatedStayMinutes: 75,
      ),
      const ItineraryPlace(
        id: 'sug_bw_sunway_carnival',
        name: 'Sunway Carnival Mall Hub',
        area: 'Butterworth',
        description: 'Air-conditioned mainland lifestyle shopping and dining complex',
        lat: 5.3980,
        lng: 100.3980,
        category: 'Shopping',
        estimatedStayMinutes: 60,
      ),
  ];

  ItineraryPlace? _findNearbyIndoorAlternative(
    ItineraryPlace current,
    List<ItineraryPlace> places, {
    Set<String>? excludedIds,
  }) {
    final area = current.specificArea;
    final available = _indoorCandidates.where((cand) {
      if (_dismissedSuggestions.contains(cand.id)) return false;
      if (excludedIds != null && excludedIds.contains(cand.id)) return false;
      return !places.any((p) => p.name.trim().toLowerCase() == cand.name.trim().toLowerCase());
    }).toList();

    if (available.isEmpty) {
      if (excludedIds != null && excludedIds.isNotEmpty) {
        return _findNearbyIndoorAlternative(current, places, excludedIds: null);
      }
      return null;
    }

    available.sort((a, b) {
      final aSame = a.specificArea == area ? 0 : 1;
      final bSame = b.specificArea == area ? 0 : 1;
      if (aSame != bSame) return aSame.compareTo(bSame);
      final distA = _calculateDistanceKm(current.lat, current.lng, a.lat, a.lng);
      final distB = _calculateDistanceKm(current.lat, current.lng, b.lat, b.lng);
      return distA.compareTo(distB);
    });

    return available.first;
  }

  Widget _buildWeatherAdviceBadge({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color iconColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
                fontFamily: 'SF Pro',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // In-memory cache for place photos to avoid repeated network calls
  final Map<String, String> _placePhotoCache = {};

  // Build Place Image Widget (fetched from MongoDB / places_new with fallback)
  Widget _buildPlaceCardImage(ItineraryPlace place) {
    // 1. Check in-memory state cache first
    final cached = _placePhotoCache[place.id] ?? _placePhotoCache[place.name];
    if (cached != null && cached.isNotEmpty && cached != 'no_image_found') {
      return _renderImageWidget(cached);
    }

    // 2. Check if place already has an imageUrl set
    if (place.imageUrl != null && place.imageUrl!.isNotEmpty && place.imageUrl != 'no_image_found') {
      _placePhotoCache[place.id] = place.imageUrl!;
      return _renderImageWidget(place.imageUrl!);
    }

    // 3. Asynchronously fetch from PlacesService (which queries MongoDB place_media.thumbnail first)
    return FutureBuilder<String>(
      future: _placesService.fetchPhotoForPlace(
        place.name,
        category: place.category,
        area: place.area,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.isNotEmpty &&
            snapshot.data != 'no_image_found') {
          _placePhotoCache[place.id] = snapshot.data!;
          return _renderImageWidget(snapshot.data!);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildImagePlaceholder();
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _renderImageWidget(String url) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      height: 125,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF1F5F9),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AppImageWidget(
            imagePath: url,
            fit: BoxFit.cover,
            errorWidget: _buildImagePlaceholder(),
            placeholder: _buildImagePlaceholder(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 24,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      height: 125,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF1F5F9),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  // Standalone Pink Suggestion Card in the sequence
  Widget _buildStandaloneSuggestionCard({
    required ItineraryPlace place,
    required ItineraryPlace alternative,
    required int index,
    required String timeSlot,
    required bool isHeatConflict,
    required bool isRainRisk,
    required List<ItineraryPlace> places,
  }) {
    final rescheduledTime = _getRescheduledSlot(place, timeSlot);
    final slotHours = _parseTimeSlotHours(timeSlot);
    final slotWeather = _areaWeatherCache[place.specificArea]?.getWeatherForTimeRange(slotHours.startHour, slotHours.endHour);

    final heatDetails = slotWeather != null
        ? '${slotWeather.maxTemp.toStringAsFixed(1)}°C (Feels like ${slotWeather.maxFeelsLike.toStringAsFixed(1)}°C${slotWeather.maxUv > 0 ? " • UV ${slotWeather.maxUv.toStringAsFixed(1)}" : ""})'
        : 'Peak midday heat';
    final rainDetails = slotWeather != null
        ? '${slotWeather.maxPrecipProb}% chance of rain'
        : 'High probability of rain';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5), // Soft pink background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF48FB1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Badges Row (Using Wrap to prevent overflow on small screens)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE4EC),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF48FB1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isRainRisk && !isHeatConflict
                          ? Icons.water_drop_rounded
                          : (isRainRisk && isHeatConflict
                              ? Icons.thunderstorm_rounded
                              : Icons.wb_sunny_rounded),
                      color: const Color(0xFFC2185B),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isRainRisk && !isHeatConflict
                          ? 'AI Recommendation • Rain Shelter'
                          : (isRainRisk && isHeatConflict
                              ? 'AI Recommendation • Heat & Rain'
                              : 'AI Recommendation • Midday Heat'),
                      style: const TextStyle(
                        color: Color(0xFFC2185B),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD1DC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isRainRisk && !isHeatConflict ? 'Rain Risk' : 'High UV Heat (>33°C / UV>6)',
                  style: const TextStyle(
                    color: Color(0xFF880E4F),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          // 2. Explanatory guidance text with real API weather metrics
          Text(
            isRainRisk && !isHeatConflict
                ? '🌧️ Rain forecast ($rainDetails) at $timeSlot in ${place.specificArea}. Outdoor sightseeing will get wet. We suggest visiting sheltered ${alternative.name} during this hour, and visiting ${place.name} after at $rescheduledTime.'
                : '☀️ Peak heat forecast ($heatDetails) at $timeSlot for ${place.name}. Sun exposure is intense at this hour. We suggest visiting air-conditioned ${alternative.name} at $timeSlot, and visiting ${place.name} after at $rescheduledTime.',
            style: const TextStyle(
              color: Color(0xFF880E4F),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),

          const SizedBox(height: 10),

          // 3. Alternative Place Photo (Fetched from MongoDB)
          _buildPlaceCardImage(alternative),

          const SizedBox(height: 8),

          // 4. Alternative Name & Area/Stay info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.museum_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alternative.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '📍 ${alternative.specificArea}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        Text(
                          '• ⏱️ ${alternative.formattedStayDuration}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE4EC),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isRainRisk ? 'Rain Sheltered' : 'Air-Conditioned',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC2185B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // 5. Suggested Time Slot on ITS OWN ROW (Zero horizontal overflow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF48FB1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFC2185B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Suggested: $timeSlot (Then ${place.name} at $rescheduledTime)',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC2185B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (alternative.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              alternative.description,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // 6. Action Buttons Row: [ Yes, add to plan ] and [ No ]
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.add_circle, size: 16),
                  label: const Text(
                    'Yes, add to plan',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _saveSnapshot();
                    final list = List<ItineraryPlace>.from(_controller.draftItinerary);
                    final targetIdx = list.indexWhere((p) => p.id == place.id);
                    if (targetIdx != -1) {
                      final alternativeToAdd = alternative.copyWith(
                        bestVisitTime: null,
                        timeReason: isRainRisk
                            ? 'Sheltered indoor visit during rain forecast'
                            : 'Air-conditioned visit during peak midday heat',
                        warningFlag: null,
                      );

                      final updatedOriginal = place.copyWith(
                        bestVisitTime: null,
                        timeReason: 'Visited after ${alternative.name} to avoid midday weather conflict',
                        warningFlag: null,
                      );

                      // Insert alternative at targetIdx, and place at targetIdx + 1
                      list.removeAt(targetIdx);
                      list.insert(targetIdx, alternativeToAdd);
                      list.insert(targetIdx + 1, updatedOriginal);

                      setState(() {
                        _dismissedSuggestions.add('${place.id}_heat');
                        _dismissedSuggestions.add('${place.id}_weather');
                        _dismissedSuggestions.add('${alternative.id}_weather');
                        _dismissedSuggestions.add(alternative.id);
                        _resolvedWeatherConflicts.add(place.id);
                        _resolvedWeatherConflicts.add(alternative.id);
                      });

                      _controller.setDraftItinerary(list);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '✨ Added ${alternative.name} at $timeSlot! ${place.name} shifted to cooler slot ($rescheduledTime).',
                          ),
                          backgroundColor: const Color(0xFFE91E63),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF880E4F),
                  side: const BorderSide(color: Color(0xFFF48FB1)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() {
                    _dismissedSuggestions.add('${place.id}_heat');
                    _dismissedSuggestions.add('${place.id}_weather');
                    _dismissedSuggestions.add(alternative.id);
                    _resolvedWeatherConflicts.add(place.id);
                  });
                },
                child: const Text('No', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sequence connector between alternative and original place
  Widget _buildSuggestionSequenceConnector({
    required String alternativeName,
    required String originalName,
    required String rescheduledTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFEDD5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFFEA580C)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Next in plan: $originalName (rescheduled to $rescheduledTime to avoid peak heat)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Build Weather Guard Section with area-based alerts
  // Area-specific weather info card with small black text title, min/max temp, rain probability %, and estimated rainfall time
  Widget _buildAreaWeatherItem(String area, WeatherData? weather) {
    final tempMin = weather?.tempMin.round() ?? 25;
    final tempMax = weather?.tempMax.round() ?? 32;
    final rainProb = weather?.precipitationProbabilityMax ?? 30;
    final rainWindow = _getRainTimeWindow(weather);
    final condition = weather?.condition ?? 'Partly Cloudy';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small black text title for the area
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF0F172A)),
              const SizedBox(width: 4),
              Text(
                area,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A), // Small black text title
                  fontFamily: 'SF Pro',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getWeatherIcon(condition), size: 12, color: _getWeatherColor(condition)),
                    const SizedBox(width: 4),
                    Text(
                      condition,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weather Details Row: Min & Max Temp + Rain Probability %
          Row(
            children: [
              // Min & Max Temp
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.thermostat_rounded, size: 15, color: Color(0xFFEA580C)),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Temp Range',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$tempMin°C – $tempMax°C',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Rain Probability % with Rain Icon
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, size: 15, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rain Chance',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '$rainProb% Rain',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // Rain Window / Assumed Rain Time
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: rainProb >= 50 ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: rainProb >= 50 ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  rainProb >= 50 ? Icons.umbrella_rounded : Icons.wb_sunny_outlined,
                  size: 13,
                  color: rainProb >= 50 ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    rainWindow,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: rainProb >= 50 ? const Color(0xFF1E40AF) : const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build Weather Guard Section with separated area info
  Widget _buildWeatherGuardSection(List<ItineraryPlace> places) {
    final areas = places
        .map((p) => p.specificArea.trim())
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'penang')
        .toSet()
        .toList();
    if (areas.isEmpty) areas.add('George Town');

    final scanText = areas.length > 1
        ? 'Live ${areas.take(3).join(' & ')} microclimate scan'
        : 'Live ${areas.first} microclimate scan';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Weather Guard Title Bar
          InkWell(
            onTap: () {
              setState(() {
                _isWeatherGuardExpanded = !_isWeatherGuardExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('🕊️', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Kia-Kia Weather Guard',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, color: Color(0xFF16A34A), size: 6),
                                  SizedBox(width: 3),
                                  Text(
                                    'Active',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          scanText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isWeatherGuardExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF64748B),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isWeatherGuardExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...areas.map((area) {
                    final w = _areaWeatherCache[area];
                    return _buildAreaWeatherItem(area, w);
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Route Inefficiency Warning Card (路线不顺警示)
  Widget _buildRouteInefficiencyWarningCard(Map<String, dynamic> alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Soft warm amber
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE68A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.traffic_rounded, color: Color(0xFFB45309), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Heavy Traffic & Detour Alert (路线不顺)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF92400E),
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert['message'] as String,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF78350F),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.alt_route_rounded, size: 15),
                label: const Text(
                  'Auto-Group by Area',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                onPressed: _autoGroupByArea,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build Empty State when no stops have been added yet
  Widget _buildEmptyStateView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFDBEAFE), width: 2),
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 50,
                color: Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No stops added yet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'You haven’t added any attractions to your Penang itinerary yet. Start building your plan to explore!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0044CC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
              icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              label: const Text(
                'Start Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              onPressed: _openAddPlaceDialog,
            ),
          ],
        ),
      ),
    );
  }

  // Build Bottom Action Panel
  Widget _buildBottomActionPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Route Efficiency Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF059669), size: 14),
              const SizedBox(width: 5),
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                  children: [
                    TextSpan(text: 'Route Efficiency: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextSpan(text: 'Optimal Sequence — 18 min transit'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Optimize with Weather Guard Button (gated on travelDates != null)
          Builder(builder: (context) {
            final hasDates = _controller.travelDates != null;
            return SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasDates ? const Color(0xFF0044CC) : const Color(0xFFE2E8F0),
                  foregroundColor: hasDates ? Colors.white : const Color(0xFF64748B),
                  elevation: hasDates ? 1 : 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(
                  hasDates ? Icons.auto_awesome : Icons.calendar_today_outlined,
                  size: 16,
                  color: hasDates ? Colors.white : const Color(0xFF64748B),
                ),
                label: Text(
                  hasDates
                      ? 'Optimize with Weather Guard'
                      : 'Set Travel Dates to Optimize',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    color: hasDates ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                onPressed: hasDates
                    ? () {
                        _saveSnapshot();
                        _controller.reoptimizeWithWeatherGuard();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✨ Plan optimized for weather! Indoor stops scheduled for midday peak heat hours.'),
                            backgroundColor: Color(0xFF059669),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📅 Please select your travel dates first before optimizing.'),
                            backgroundColor: Color(0xFFD97706),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        await _selectTravelDates();
                      },
              ),
            );
          }),
          const SizedBox(height: 8),

          // Secondary Action Row: View on Map & Apply Plan
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFEFF6FF),
                      foregroundColor: const Color(0xFF19244E),
                      side: const BorderSide(color: Color(0xFFBFDBFE), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.map_outlined, size: 16, color: Color(0xFF2563EB)),
                    label: const Text(
                      'View on Map',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _launchJourneyOnMap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF19244E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      'Apply Plan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      _controller.lockAndStartTrip();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🎉 Penang Itinerary Confirmed & Applied!'),
                          backgroundColor: Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final places = _controller.draftItinerary;
    final travelDatesStr = _formatDateRange(_controller.travelDates);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF19244E), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI-Optimized Plan',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF19244E),
            fontFamily: 'SF Pro',
          ),
        ),
      ),
      body: places.isEmpty
          ? _buildEmptyStateView()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECTION 1: HEADER, UNDO / REDO & ADD BUTTON ---
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI-Optimized Plan',
                                    style: TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${places.length} stops arranged • Weather-aware scheduling',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Undo Button
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.undo_rounded,
                                size: 20,
                                color: _undoStack.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                              ),
                              tooltip: 'Undo',
                              onPressed: _undoStack.isNotEmpty ? _undo : null,
                            ),

                            // Redo Button
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.redo_rounded,
                                size: 20,
                                color: _redoStack.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                              ),
                              tooltip: 'Redo',
                              onPressed: _redoStack.isNotEmpty ? _redo : null,
                            ),

                            const SizedBox(width: 2),

                            // '+' Add button
                            Material(
                              color: const Color(0xFF0044CC),
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _openAddPlaceDialog,
                                child: const Padding(
                                  padding: EdgeInsets.all(9),
                                  child: Icon(Icons.add, color: Colors.white, size: 19),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // --- SECTION 2: TRAVEL SCHEDULE CARD (Breathing effect when dates are not set) ---
                        AnimatedBuilder(
                          animation: _breathingController,
                          builder: (context, _) {
                            final isDateMissing = _controller.travelDates == null;
                            final breath = isDateMissing ? _breathingController.value : 0.0;
                            final borderColor = isDateMissing
                                ? Color.lerp(const Color(0xFFF59E0B), const Color(0xFFD97706), breath)!
                                : const Color(0xFFE2E8F0);
                            final borderWidth = isDateMissing ? (1.5 + 1.2 * breath) : 1.0;
                            final boxShadow = isDateMissing
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15 + 0.30 * breath),
                                      blurRadius: 8 + 6 * breath,
                                      spreadRadius: 0.5 + 1.5 * breath,
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ];

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor, width: borderWidth),
                                boxShadow: boxShadow,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    color: isDateMissing
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF2563EB),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Text(
                                              'Travel Schedule',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF64748B),
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                            if (isDateMissing) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Required to optimize',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFB45309),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          isDateMissing
                                              ? 'Select dates to optimize'
                                              : travelDatesStr,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isDateMissing
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF0F172A),
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _selectTravelDates,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDateMissing
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: isDateMissing
                                            ? Border.all(color: const Color(0xFFF59E0B), width: 1.0)
                                            : null,
                                      ),
                                      child: Text(
                                        isDateMissing ? 'Set Dates' : 'Change',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDateMissing
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF2563EB),
                                          fontFamily: 'SF Pro',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // --- SECTION 3: KIA-KIA WEATHER GUARD ---
                        _buildWeatherGuardSection(places),

                        const SizedBox(height: 12),

                        // Route Inefficiency Warning Card (Check if route zig-zags between distant areas e.g. George Town -> Balik Pulau -> George Town)
                        Builder(builder: (context) {
                          final routeAlert = _detectRouteInefficiency(places);
                          if (routeAlert != null) {
                            return Column(
                              children: [
                                _buildRouteInefficiencyWarningCard(routeAlert),
                                const SizedBox(height: 4),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        }),

                        const SizedBox(height: 12),

                        // --- SECTION 5: REORDER INSTRUCTIONS ---
                        const Row(
                          children: [
                            Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF3B82F6)),
                            SizedBox(width: 4),
                            Text(
                              'Press and hold handle ⠿ to reorder',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // --- SECTION 6: REORDERABLE STOPS LIST ---
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: places.length,
                          onReorder: (oldIndex, newIndex) {
                            _saveSnapshot();
                            _controller.reorderDraft(oldIndex, newIndex);
                          },
                          itemBuilder: (context, index) {
                            final place = places[index];
                            final stopNumber = index + 1;
                            final timeSlot = _getTimeSlotForIndex(index, places);
                            final isMiddaySlot = timeSlot.contains('12:') ||
                                timeSlot.contains('01:') ||
                                timeSlot.contains('02:') ||
                                timeSlot.contains('11:3') ||
                                timeSlot.contains('11:4') ||
                                timeSlot.contains('11:5');

                            final isOutdoorSunExposed = (place.features['has_aircon'] != true) &&
                                !place.category.toLowerCase().contains('indoor') &&
                                !place.category.toLowerCase().contains('museum') &&
                                !place.category.toLowerCase().contains('mall') &&
                                !place.name.toLowerCase().contains('mansion') &&
                                !place.name.toLowerCase().contains('indoor');

                            final weather = _areaWeatherCache[place.specificArea];
                            final slotHours = _parseTimeSlotHours(timeSlot);
                            final slotWeather = weather?.getWeatherForTimeRange(slotHours.startHour, slotHours.endHour);

                            final isRainRisk = isOutdoorSunExposed &&
                                ((slotWeather?.isRainRisk == true) ||
                                    ((weather?.precipitationProbabilityMax ?? 0) >= 45) ||
                                    place.warningFlag == 'RAIN_RISK');
                            // Peak heat check: over 33 degrees OR UV above 6
                            final isPeakHeatCondition = (slotWeather != null && (slotWeather.maxTemp > 33.0 || slotWeather.maxUv > 6.0)) ||
                                (weather != null && (weather.temp > 33.0 || weather.uvIndex > 6.0)) ||
                                (slotWeather?.isPeakHeat == true) ||
                                (isMiddaySlot && ((slotWeather?.maxTemp ?? weather?.temp ?? 33.5) > 33.0 || (slotWeather?.maxUv ?? weather?.uvIndex ?? 6.5) > 6.0)) ||
                                place.warningFlag == 'PEAK_HEAT';
                            final isHeatConflict = isOutdoorSunExposed && isPeakHeatCondition;
                            final hasWeatherIssue = isHeatConflict || isRainRisk;

                            // Precalculate alternative for this place if it has a weather conflict
                            final heatAlternative = (hasWeatherIssue &&
                                    !_resolvedWeatherConflicts.contains(place.id) &&
                                    !_dismissedSuggestions.contains('${place.id}_weather') &&
                                    !_dismissedSuggestions.contains('${place.id}_heat'))
                                ? _findNearbyIndoorAlternative(place, places)
                                : null;

                            final placeCard = Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: hasWeatherIssue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.02),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Top row: Number box, Place Name, and Drag handle
                                    Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0F172A),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '$stopNumber',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            place.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                         InkWell(
                                           onTap: () => _confirmRemovePlace(index, place),
                                           borderRadius: BorderRadius.circular(12),
                                           child: const Padding(
                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                             child: Icon(Icons.cancel, color: Color(0xFF94A3B8), size: 19),
                                           ),
                                         ),
                                         const SizedBox(width: 4),
                                         ReorderableDragStartListener(
                                           index: index,
                                           child: const Padding(
                                             padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                             child: Icon(Icons.drag_indicator, color: Color(0xFF94A3B8), size: 20),
                                           ),
                                         ),
                                       ],
                                     ),

                                     // Place photo fetched from MongoDB / PlacesService directly below place name
                                     _buildPlaceCardImage(place),

                                     const SizedBox(height: 6),

                                     // Badges row: Dynamic Time Slot + Specific Area Tag + Dynamic Stay Duration Tag + Weather Advice Tags
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 5,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          // Dynamic Time Slot Badge with Weather Conflict Indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: hasWeatherIssue ? const Color(0xFFFFEBEE) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isHeatConflict
                                                      ? Icons.wb_sunny_rounded
                                                      : (isRainRisk ? Icons.water_drop_rounded : Icons.access_time_rounded),
                                                  size: 11,
                                                  color: hasWeatherIssue ? const Color(0xFFC62828) : const Color(0xFF2563EB),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    timeSlot +
                                                        (isHeatConflict
                                                            ? ' • ⚠️ Heat (${slotWeather != null ? "${slotWeather.maxTemp.round()}°C" : "Peak"})'
                                                            : (isRainRisk
                                                                ? ' • 🌧️ Rain (${slotWeather != null ? "${slotWeather.maxPrecipProb}%" : "Risk"})'
                                                                : '')),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: hasWeatherIssue ? const Color(0xFFC62828) : const Color(0xFF1E40AF),
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Specific Area Tag (postcode and district aware)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 11.5,
                                                  color: Color(0xFF475569),
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    place.specificArea,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF334155),
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Dynamic Stay Duration Tag
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.timer_outlined,
                                                  size: 11,
                                                  color: Color(0xFF64748B),
                                                ),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    place.formattedStayDuration,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF475569),
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Weather Advisory Tags: "Remember apply sunscreen" & "Take an umbrella with you"
                                          if (isHeatConflict || isPeakHeatCondition) ...[
                                            _buildWeatherAdviceBadge(
                                              icon: Icons.wb_sunny_rounded,
                                              label: 'Remember apply sunscreen',
                                              backgroundColor: const Color(0xFFFFF7ED),
                                              textColor: const Color(0xFFC2410C),
                                              iconColor: const Color(0xFFEA580C),
                                              borderColor: const Color(0xFFFFEDD5),
                                            ),
                                            _buildWeatherAdviceBadge(
                                              icon: Icons.beach_access_rounded,
                                              label: 'Take an umbrella with you',
                                              backgroundColor: const Color(0xFFFEF3C7),
                                              textColor: const Color(0xFFB45309),
                                              iconColor: const Color(0xFFD97706),
                                              borderColor: const Color(0xFFFDE68A),
                                            ),
                                          ] else if (isRainRisk) ...[
                                            _buildWeatherAdviceBadge(
                                              icon: Icons.umbrella_rounded,
                                              label: 'Take an umbrella with you',
                                              backgroundColor: const Color(0xFFEFF6FF),
                                              textColor: const Color(0xFF1D4ED8),
                                              iconColor: const Color(0xFF2563EB),
                                              borderColor: const Color(0xFFDBEAFE),
                                            ),
                                          ],
                                        ],
                                      ),

                                      // Collapsible Transit (by car & distance) & Area Weather Predict Card
                                     _buildCollapsibleTransitAndWeatherCard(index, place, places),

                                  ],
                                ),
                              );

                              if (heatAlternative != null) {
                                return Column(
                                  key: ValueKey('stop_${place.id}_$index'),
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildStandaloneSuggestionCard(
                                      place: place,
                                      alternative: heatAlternative,
                                      index: index,
                                      timeSlot: timeSlot,
                                      isHeatConflict: isHeatConflict,
                                      isRainRisk: isRainRisk,
                                      places: places,
                                    ),
                                    _buildSuggestionSequenceConnector(
                                      alternativeName: heatAlternative.name,
                                      originalName: place.name,
                                      rescheduledTime: _getRescheduledSlot(place, timeSlot),
                                    ),
                                    placeCard,
                                  ],
                                );
                              }

                              return KeyedSubtree(
                                key: ValueKey('stop_${place.id}_$index'),
                                child: placeCard,
                              );
                            },
                            ),
                          ],
                        ),
                      ),
                    ),

                    _buildBottomActionPanel(),
                  ],
                ),
    );
  }
}
