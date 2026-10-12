import 'dart:convert';
import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import '../services/places_service.dart';
import '../widgets/app_image_widget.dart';
import 'detail_screen.dart';

class _PlanSnapshot {
  final List<ItineraryPlace> places;
  final List<WeatherRecommendation> heatRecommendations;
  final List<WeatherRecommendation> rainRecommendations;

  _PlanSnapshot({
    required List<ItineraryPlace> places,
    required List<WeatherRecommendation> heatRecommendations,
    required List<WeatherRecommendation> rainRecommendations,
  })  : places = places.map((p) => ItineraryPlace(
          id: p.id,
          name: p.name,
          area: p.area,
          address: p.address,
          description: p.description,
          lat: p.lat,
          lng: p.lng,
          category: p.category,
          imageUrl: p.imageUrl,
          businessHours: p.businessHours,
          estimatedStayMinutes: p.estimatedStayMinutes,
          tip: p.tip,
          bestVisitTime: p.bestVisitTime,
          warningFlag: p.warningFlag,
        )).toList(),
        heatRecommendations = List.from(heatRecommendations),
        rainRecommendations = List.from(rainRecommendations);
}

class ModifyPlanScreen extends StatefulWidget {
  const ModifyPlanScreen({super.key});

  @override
  State<ModifyPlanScreen> createState() => _ModifyPlanScreenState();
}

class _ModifyPlanScreenState extends State<ModifyPlanScreen> {
  final TripController _controller = TripController();
  final PlacesService _placesService = PlacesService();
  late List<ItineraryPlace> _places;
  List<WeatherRecommendation> _heatRecommendations = [];
  List<WeatherRecommendation> _rainRecommendations = [];

  // Undo / Redo history stacks
  final List<_PlanSnapshot> _undoStack = [];
  final List<_PlanSnapshot> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _places = List.from(_controller.draftItinerary);
    _recalculateSuggestedVisitTimes();
    _loadRecommendations();
  }

  String _formatMinutesClock(int totalMinutes) {
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

  // Model dynamically suggests visit times for every stop in the modified sequence
  void _recalculateSuggestedVisitTimes() {
    if (_places.isEmpty) return;

    final depart = _controller.departTime;
    int currentMinutes = depart.hour * 60 + depart.minute;
    const transitMins = 15;
    final visitDate = _controller.travelDates?.start ?? DateTime.now();

    for (int i = 0; i < _places.length; i++) {
      final place = _places[i];
      final stay = place.estimatedStayMinutes > 0 ? place.estimatedStayMinutes : 60;
      final startMins = currentMinutes;
      final endMins = startMins + stay;

      final startClock = _formatMinutesClock(startMins);
      final endClock = _formatMinutesClock(endMins);
      final timeSlot = '$startClock – $endClock';

      // Evaluate warning flags dynamically:
      final bool isClosed = place.warningFlag == 'CLOSED' || _controller.checkIfPlaceClosed(place, visitDate);
      String? warning;
      String? reason;

      if (isClosed) {
        warning = 'CLOSED';
        reason = 'Venue may be closed on this day';
      } else {
        // Peak heat check: 12:00 PM to 02:30 PM for outdoor walking spots
        final isMidday = (startMins >= 11 * 60 + 45 && startMins <= 14 * 60 + 30);
        final isOutdoor = place.category.toLowerCase().contains('beach') ||
            place.category.toLowerCase().contains('nature') ||
            place.category.toLowerCase().contains('heritage') ||
            place.category.toLowerCase().contains('art') ||
            place.name.toLowerCase().contains('khoo kongsi') ||
            place.name.toLowerCase().contains('street art') ||
            place.name.toLowerCase().contains('jetty');
        if (isMidday && isOutdoor) {
          warning = 'PEAK_HEAT';
          reason = 'Midday peak sun & heat';
        }
      }

      _places[i] = place.copyWith(
        bestVisitTime: timeSlot,
        warningFlag: warning,
        adjustmentReason: reason,
      );

      currentMinutes = endMins + transitMins;
    }
  }

  void _recordSnapshot() {
    _undoStack.add(_PlanSnapshot(
      places: _places,
      heatRecommendations: _heatRecommendations,
      rainRecommendations: _rainRecommendations,
    ));
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final current = _PlanSnapshot(
      places: _places,
      heatRecommendations: _heatRecommendations,
      rainRecommendations: _rainRecommendations,
    );
    _redoStack.add(current);
    final previous = _undoStack.removeLast();
    setState(() {
      _places = List.from(previous.places);
      _heatRecommendations = List.from(previous.heatRecommendations);
      _rainRecommendations = List.from(previous.rainRecommendations);
      _recalculateSuggestedVisitTimes();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final current = _PlanSnapshot(
      places: _places,
      heatRecommendations: _heatRecommendations,
      rainRecommendations: _rainRecommendations,
    );
    _undoStack.add(current);
    final next = _redoStack.removeLast();
    setState(() {
      _places = List.from(next.places);
      _heatRecommendations = List.from(next.heatRecommendations);
      _rainRecommendations = List.from(next.rainRecommendations);
      _recalculateSuggestedVisitTimes();
    });
  }

  void _loadRecommendations() async {
    final currentAreas = _places
        .map((p) => p.specificArea)
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'penang')
        .toSet();
    final recAreas = _controller.heatRecommendations
        .map((r) => r.area)
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'penang')
        .toSet();
    final bool areaMismatch = currentAreas.isNotEmpty && recAreas.isNotEmpty && currentAreas.intersection(recAreas).isEmpty;

    if (_controller.heatRecommendations.isEmpty && _controller.rainRecommendations.isEmpty || areaMismatch) {
      await _controller.fetchWeatherRecommendationsIfNeeded(force: true);
    }
    if (mounted) {
      setState(() {
        _heatRecommendations = List.from(_controller.heatRecommendations);
        _rainRecommendations = List.from(_controller.rainRecommendations);
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    _recordSnapshot();
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _places.removeAt(oldIndex);
      _places.insert(newIndex, item);
      _recalculateSuggestedVisitTimes();
    });
  }

  void _removePlace(int index) {
    if (_places.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one place is required in your itinerary.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    _recordSnapshot();
    setState(() {
      _places.removeAt(index);
      _recalculateSuggestedVisitTimes();
    });
  }

  void _acceptRecommendation(WeatherRecommendation rec, {bool isHeat = true}) {
    _recordSnapshot();
    setState(() {
      final newPlace = rec.toItineraryPlace();
      // Insert in middle (e.g. at midday slot) or at end
      if (_places.length >= 2) {
        _places.insert((_places.length / 2).floor(), newPlace);
      } else {
        _places.add(newPlace);
      }

      if (isHeat) {
        _heatRecommendations.removeWhere((r) => r.id == rec.id || r.name == rec.name);
      } else {
        _rainRecommendations.removeWhere((r) => r.id == rec.id || r.name == rec.name);
      }
      _recalculateSuggestedVisitTimes();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${rec.name}" to your plan!'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Open Place Picker Bottom Sheet to add a new stop to itinerary
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
                          fontFamily: 'SF Pro',
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
                        hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontFamily: 'SF Pro'),
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
                          searchResults = res.map((p) {
                            double lat = 5.414;
                            double lng = 100.328;
                            if (p['coordinates'] != null) {
                              dynamic coords = p['coordinates'];
                              if (coords is String) {
                                try {
                                  coords = json.decode(coords);
                                } catch (_) {}
                              }
                              if (coords is List && coords.length >= 2) {
                                lng = (coords[0] as num).toDouble();
                                lat = (coords[1] as num).toDouble();
                              } else if (coords is Map) {
                                lat = (coords['latitude'] ?? coords['lat'] as num?)?.toDouble() ?? lat;
                                lng = (coords['longitude'] ?? coords['lng'] as num?)?.toDouble() ?? lng;
                              }
                            }
                            return {
                              'id': p['id']?.toString() ?? '',
                              'name': p['title'] ?? '',
                              'area': p['area'] ?? 'Penang',
                              'category': p['category'] ?? 'Attraction',
                              'lat': lat,
                              'lng': lng,
                              'duration': 60,
                              'desc': p['description'] ?? '',
                              'imagePath': p['imagePath'],
                              'businessHours': p['businessHours'],
                              'openingHours': p['openingHours'],
                            };
                          }).toList();
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
                      fontFamily: 'SF Pro',
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
                              final isAlreadyAdded = _places.any((p) => p.name.toLowerCase() == item['name']!.toLowerCase());

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
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'SF Pro'),
                                ),
                                subtitle: Text(
                                  '${item['area']} • ${item['category']} • ${item['duration']} min',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'SF Pro'),
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
                                          _recordSnapshot();
                                          setState(() {
                                            _places.add(
                                              ItineraryPlace(
                                                id: (item['id'] != null && item['id'].toString().isNotEmpty)
                                                    ? item['id'].toString()
                                                    : 'add_${DateTime.now().millisecondsSinceEpoch}_$idx',
                                                name: item['name']!,
                                                area: item['area']!,
                                                description: item['desc'] ?? '',
                                                lat: (item['lat'] as num).toDouble(),
                                                lng: (item['lng'] as num).toDouble(),
                                                category: item['category']!,
                                                estimatedStayMinutes: item['duration'] as int,
                                                imageUrl: item['imagePath']?.toString(),
                                                businessHours: item['businessHours']?.toString(),
                                                openingHours: item['openingHours'],
                                              ),
                                            );
                                            _recalculateSuggestedVisitTimes();
                                          });
                                          setModalState(() {});
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Added ${item['name']} to plan!'),
                                              duration: const Duration(milliseconds: 1200),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                  child: Text(
                                    isAlreadyAdded ? 'Added' : 'Add',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'SF Pro'),
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

  Future<void> _handleApplyPlan({required bool stickToUserPlan}) async {
    if (_places.isEmpty) return;

    // Show White-background Fullscreen Thinking Loading Modal
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/pink-bird-thinking.gif',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const CircularProgressIndicator(
                    color: Color(0xFF304FFE),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  stickToUserPlan ? 'Applying Your Custom Plan...' : 'Optimizing Your Itinerary...',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'SF Pro',
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    stickToUserPlan
                        ? 'Penny is applying your custom sequence and locking in suggested visit times.'
                        : 'Penny is checking venue opening hours and aligning visit sequences to avoid conflicts.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      fontFamily: 'SF Pro',
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Call TripController to send modified places with user sequence preference
    await _controller.applyModifiedPlan(places: _places, stickToUserPlan: stickToUserPlan);

    if (mounted) {
      // Pop loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      // Pop ModifyPlanScreen back to Your Plan
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Modify Plan',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'SF Pro',
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.undo_rounded,
              size: 22,
              color: _undoStack.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
            tooltip: 'Undo',
            onPressed: _undoStack.isNotEmpty ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo_rounded,
              size: 22,
              color: _redoStack.isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
            ),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              size: 23,
              color: Color(0xFF304FFE),
            ),
            tooltip: 'Add Stop',
            onPressed: _openAddPlaceDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION 1: HEADER & INSTRUCTIONS ---
                  Row(
                    children: [
                      const Icon(Icons.drag_indicator_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Drag ⠿ to adjust visit sequence (${_places.length} stops)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // --- SECTION 2: REORDERABLE LIST (WITHOUT TIPS, BLUE FRAME) ---
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _places.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return Container(
                        key: ValueKey('modify_place_${place.id}_$index'),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF3B82F6), // Blue frame
                            width: 1.3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              // Drag Handle
                              ReorderableDragStartListener(
                                index: index,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.drag_indicator_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Sequence Number Circle
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Image Thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AppImageWidget(
                                  imagePath: place.imageUrl,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Place Info (Without Tip)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${place.specificArea} • ${place.category}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                    if (place.bestVisitTime != null && place.bestVisitTime!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.access_time_filled_rounded, size: 12, color: Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Suggested: ',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2563EB),
                                                    fontFamily: 'SF Pro',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (place.warningFlag != null)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                              decoration: BoxDecoration(
                                                color: place.warningFlag == 'CLOSED' ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                place.warningFlag == 'CLOSED' ? 'Closed' : (place.warningFlag == 'PEAK_HEAT' ? 'Peak Heat' : 'Conflict'),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: place.warningFlag == 'CLOSED' ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                                  fontFamily: 'SF Pro',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Delete Stop Button
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                                onPressed: () => _removePlace(index),
                                tooltip: 'Remove from plan',
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // --- SECTION 3: AI-RECOMMENDATION CARDS (HEAT & RAIN) ---
                  if (_heatRecommendations.isNotEmpty || _rainRecommendations.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 18),
                        const SizedBox(width: 6),
                        const Text(
                          'AI-Recommendation',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Curated indoor & sheltered spots by Gemma to avoid midday heat & rain.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Heat Recommendations
                    if (_heatRecommendations.isNotEmpty) ...[
                      _buildRecommendationCategoryHeader('☀️ Midday Heat Alternatives'),
                      const SizedBox(height: 8),
                      ..._heatRecommendations.asMap().entries.map(
                        (e) => _buildRecommendationCard(e.value, isHeat: true, index: e.key),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Rain Recommendations
                    if (_rainRecommendations.isNotEmpty) ...[
                      _buildRecommendationCategoryHeader('🌧️ Rain Shelter Alternatives'),
                      const SizedBox(height: 8),
                      ..._rainRecommendations.asMap().entries.map(
                        (e) => _buildRecommendationCard(e.value, isHeat: false, index: _heatRecommendations.length + e.key),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // --- BOTTOM ACTION BAR: STICK TO MY PLAN vs MODEL OPTIMIZED ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Informative Helper Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF304FFE)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Penny suggested visit times for your ${_places.length} stops. You can stick to your plan or optimize with AI.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons Row: [ Stick to My Plan ] and [ Model Optimized ]
                  Row(
                    children: [
                      // Button 1: Stick to My Plan (User Custom Sequence)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => _handleApplyPlan(stickToUserPlan: true),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFF304FFE)),
                            label: const Text(
                              'Stick to My Plan',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF304FFE),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFEEF2FF),
                              side: const BorderSide(color: Color(0xFF304FFE), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Button 2: Model Optimized Plan (AI Route Optimization)
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () => _handleApplyPlan(stickToUserPlan: false),
                            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
                            label: const Text(
                              'Model Optimized',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF304FFE), // Indigo Accent 700
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
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
    );
  }

  Widget _buildRecommendationCategoryHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
        fontFamily: 'SF Pro',
      ),
    );
  }

  // Alternating Warm Shell (#FFF8E7) and Cream (#FFFDD0) Recommendation Card
  Widget _buildRecommendationCard(WeatherRecommendation rec, {required bool isHeat, required int index}) {
    final bool isEven = index.isEven;
    final Color cardBg = isEven ? const Color(0xFFFFF8E7) : const Color(0xFFFFFDD0);
    final Color borderColor = isEven ? const Color(0xFFFFE4C4) : const Color(0xFFFDE68A);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cardBg.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImageWidget(
                  imagePath: rec.imageUrl,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // Place Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '📍 ${rec.area} • 🕒 ${rec.suggestedVisitTime}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.black.withValues(alpha: 0.1), height: 1),
          const SizedBox(height: 8),

          // Actions Row: More / Details button on left, Accept button on right
          Row(
            children: [
              // More details button
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(
                        title: rec.name,
                        area: rec.area,
                        businessHours: rec.businessHours,
                        description: rec.description.isNotEmpty ? rec.description : rec.reason,
                        imagePath: rec.imageUrl,
                        placeId: rec.id,
                        primaryCategory: rec.category,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF1E293B), size: 16),
                label: const Text(
                  'More',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro',
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  backgroundColor: Colors.white.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                  ),
                ),
              ),

              const Spacer(),

              // Add to My Plan Button (Pill/Rounded shape with circular tick icon)
              ElevatedButton.icon(
                onPressed: () => _acceptRecommendation(rec, isHeat: isHeat),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald green
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20), // 圆外型 (Rounded capsule/pill shape)
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'Add to My Plan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'SF Pro',
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
