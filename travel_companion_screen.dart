import 'package:flutter/material.dart';
import '../config.dart';
import '../controllers/trip_controller.dart';
import '../theme.dart';
import '../widgets/companion/mascot_area_widget.dart';
import '../widgets/companion/contextual_status_banner.dart';
import '../widgets/companion/itinerary_sliding_panel.dart';
import 'map_screen.dart';
import 'main_navigation.dart';
import 'dart:convert';
import 'draft_plan_screen.dart';
import 'itinerary_plan_screen.dart';
import 'set_travel_date_screen.dart';
import 'detail_screen.dart';
import '../services/places_service.dart';
import '../services/weather_service.dart';
import '../services/location_service.dart';

class TravelCompanionScreen extends StatefulWidget {
  const TravelCompanionScreen({super.key});

  @override
  State<TravelCompanionScreen> createState() => _TravelCompanionScreenState();
}

class _TravelCompanionScreenState extends State<TravelCompanionScreen> {
  final TripController _controller = TripController();
  final PlacesService _placesService = PlacesService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isRainyWeather = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.onRequireDatesTriggered = () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetTravelDateScreen(controller: _controller),
        ),
      );
    };
    _checkWeatherForRainfall();
  }

  Future<void> _checkWeatherForRainfall() async {
    try {
      final pos = await LocationService().getCurrentPosition(timeLimit: const Duration(seconds: 4));
      final lat = pos?.latitude ?? LocationService.defaultLat;
      final lng = pos?.longitude ?? LocationService.defaultLng;
      debugPrint('🛰️ [WEATHER CHECK] Querying weather for GPS coords: ($lat, $lng)');
      final weather = await WeatherService().fetchWeather(latitude: lat, longitude: lng);

      // Detect current rainfall or upcoming rainfall forecast within next 2 hours
      final now = DateTime.now();
      final upcomingWindow = weather.getWeatherForTimeRange(now.hour, (now.hour + 2).clamp(0, 23));
      final hasRainRisk = weather.isRainy || upcomingWindow.isRainRisk;

      debugPrint('🌧️ [WEATHER RESULT] isRainy: ${weather.isRainy} | upcomingRainRisk: ${upcomingWindow.isRainRisk} | condition: "${weather.condition}" | maxPrecipProb: ${weather.precipitationProbabilityMax}%');
      debugPrint('🚩 [WEATHER SHORTCUT] "Indoor Discovery" shortcut active: $hasRainRisk');

      if (mounted) {
        setState(() {
          _isRainyWeather = hasRainRisk;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [WEATHER CHECK ERROR] Could not retrieve rainfall forecast: $e');
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.onRequireDatesTriggered = null;
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Phase 2: Date Picker Gatekeeper
  Future<void> _selectTravelDatesAndPlan() async {
    final now = DateTime.now();
    final initialRange = _controller.travelDates ??
        DateTimeRange(
          start: now,
          end: now.add(const Duration(days: 1)),
        );

    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: initialRange,
      helpText: 'Select Penang Travel Dates',
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
      await _executePlanning(dates: picked);
    }
  }

  // Execute AI Itinerary Planning
  Future<void> _executePlanning({DateTimeRange? dates}) async {
    if (_controller.draftItinerary.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one location before planning your trip!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('AI is validating business hours & optimizing timeline...')),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      await _controller.saveAndPlanTripForMeNow(customDates: dates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!e.toString().contains('REQUIRE_DATES')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan generation note: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Handle [ 🚀 Save and Plan Trip for Me Now ]
  Future<void> _handleLockAndStartTrip() async {
    if (_controller.travelDates == null) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetTravelDateScreen(controller: _controller),
        ),
      );
    } else {
      await _executePlanning();
    }
  }

  // Phase 4: Launch Map Screen Transition
  Future<void> _launchJourneyOnMap() async {
    if (_controller.draftItinerary.isEmpty) return;

    // Trigger Fly Away / Success mascot state
    _controller.setMascotState(MascotState.flyAway, autoResetDuration: null);

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final trip = _controller.lockAndStartTrip();

    MapLocation? initialDestination;
    if (trip.places.isNotEmpty) {
      final firstPlace = trip.places.first;
      initialDestination = MapLocation(
        name: firstPlace.name,
        lat: firstPlace.lat,
        lng: firstPlace.lng,
        description: firstPlace.description,
      );
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          destination: initialDestination,
          showRouteToDestination: true,
          stops: trip.places
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

  void _openSlidingPanel() {
    ItinerarySlidingPanel.show(
      context,
      onLockAndStartTrip: _handleLockAndStartTrip,
      onStartJourneyOnMap: _launchJourneyOnMap,
      onSelectDates: _selectTravelDatesAndPlan,
    );
  }

  void _handleMapIconTap() {
    final hasPlan = _controller.timeline.isNotEmpty || _controller.hasActiveTrip;
    if (hasPlan) {
      _openItineraryPlanScreen();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.map_outlined, color: Color(0xFF304FFE), size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No Plan Generated Yet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF19244E),
                  fontFamily: 'SF Pro',
                ),
              ),
            ),
          ],
        ),
        content: Text(
          _controller.draftItinerary.isNotEmpty
              ? 'You have ${_controller.draftItinerary.length} place${_controller.draftItinerary.length == 1 ? '' : 's'} in your draft! Please set your travel dates and generate your plan first.'
              : 'You have not generated an itinerary plan yet. Please add places to your draft plan and set travel dates first.',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF475569),
            fontFamily: 'SF Pro',
            height: 1.4,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Later',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF304FFE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _openDraftPlanScreen();
            },
            child: const Text(
              'Go to Draft Plan',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openItineraryPlanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ItineraryPlanScreen(),
      ),
    );
  }

  void _openDraftPlanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DraftPlanScreen(controller: _controller),
      ),
    );
  }

  Future<void> _openPlaceDetail(ItineraryPlace place) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDarkNavy),
      ),
    );

    try {
      final results = await _placesService.searchMultiplePlaces(place.name);
      Map<String, String>? match;
      if (results.isNotEmpty) {
        final cleanTarget = place.name.trim().toLowerCase();
        try {
          match = results.firstWhere(
            (r) => (r['title'] ?? '').trim().toLowerCase() == cleanTarget,
          );
        } catch (_) {
          try {
            match = results.firstWhere(
              (r) {
                final t = (r['title'] ?? '').trim().toLowerCase();
                return t.contains(cleanTarget) || cleanTarget.contains(t);
              },
            );
          } catch (_) {
            match = results.first;
          }
        }
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        if (match != null) {
          final hours = match['businessHours'] ??
              (place.openingHours is Map ? jsonEncode(place.openingHours) : (place.businessHours ?? 'Check online'));

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScreen(
                title: match!['title'] ?? place.name,
                area: (match['area'] != null && match['area']!.isNotEmpty)
                    ? match['area']!
                    : place.area,
                businessHours: hours,
                description: (match['description'] != null && match['description']!.isNotEmpty)
                    ? match['description']!
                    : (place.description.isNotEmpty ? place.description : 'A recommended place to visit in Penang.'),
                imagePath: (match['imagePath'] != null && match['imagePath']!.isNotEmpty && match['imagePath'] != 'no_image_found')
                    ? match['imagePath']!
                    : (place.imageUrl ?? 'no_image_found'),
                placeInformationJson: match['placeInformation'],
                coordinatesJson: match['coordinates'] ?? jsonEncode({'lat': place.lat, 'lng': place.lng}),
                address: match['address'] ?? place.address,
                hasStreetView: match['hasStreetView'] == 'true',
                mapillaryImageId: match['mapillaryImageId'],
                placeId: match['id'] ?? place.id,
              ),
            ),
          );
        } else {
          String hours;
          if (place.openingHours is Map && (place.openingHours as Map).isNotEmpty) {
            hours = jsonEncode(place.openingHours);
          } else {
            hours = place.businessHours ?? 'Check venue for operating hours';
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailScreen(
                title: place.name,
                area: place.area,
                businessHours: hours,
                description: place.description.isNotEmpty
                    ? place.description
                    : 'A recommended place to visit in Penang.',
                imagePath: (place.imageUrl != null && !place.imageUrl!.contains('unsplash.com/photo-1596422846543-75c6fc197f07'))
                    ? place.imageUrl!
                    : 'no_image_found',
                address: place.address,
                placeId: place.id,
                coordinatesJson: jsonEncode({'lat': place.lat, 'lng': place.lng}),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        String hours;
        if (place.openingHours is Map && (place.openingHours as Map).isNotEmpty) {
          hours = jsonEncode(place.openingHours);
        } else {
          hours = place.businessHours ?? 'Check venue for operating hours';
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailScreen(
              title: place.name,
              area: place.area,
              businessHours: hours,
              description: place.description.isNotEmpty
                  ? place.description
                  : 'A recommended place to visit in Penang.',
              imagePath: (place.imageUrl != null && !place.imageUrl!.contains('unsplash.com/photo-1596422846543-75c6fc197f07'))
                  ? place.imageUrl!
                  : 'no_image_found',
              address: place.address,
              placeId: place.id,
              coordinatesJson: jsonEncode({'lat': place.lat, 'lng': place.lng}),
            ),
          ),
        );
      }
    }
  }

  void _sendCurrentMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    _controller.sendUserMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final hasActive = _controller.hasActiveTrip;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: AppColors.primaryDarkNavy, size: 18),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  MainNavigation.selectedTabNotifier.value = 0;
                }
              },
            ),
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Kia-Kia Travel Companion',
                  style: TextStyle(
                    color: AppColors.primaryDarkNavy,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${AppConfig.activeLLMModel} is in use.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Color(0xFF64748B),
                  size: 22,
                ),
                tooltip: 'Clear Chat History',
                onPressed: () {
                  _controller.clearChat();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat history cleared!'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(
                  Icons.map_outlined,
                  color: Color(0xFF19244E),
                  size: 24,
                ),
                tooltip: _controller.timeline.isNotEmpty ? 'View Itinerary Plan' : 'Generate Itinerary Plan',
                onPressed: _handleMapIconTap,
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Container(
            color: Colors.white,
            child: SafeArea(
              bottom: true,
              child: Column(
                children: [
                  MascotAreaWidget(
                    mascotState: _controller.mascotState,
                    birdMode: _controller.birdModeLabel,
                    birdModeIcon: _controller.birdModeIcon,
                    birdModeColor: _controller.birdModeColor,
                    onTap: () {
                      _controller.setMascotState(MascotState.happy);
                    },
                  ),

                  // --- CONTEXTUAL STATUS BANNER (When hasActiveTrip == true) ---
                  if (hasActive)
                    ContextualStatusBanner(
                      onPlanNewTrip: () {
                        _openSlidingPanel();
                      },
                    ),

                  // --- BOTTOM 2/3: CHAT AREA ---
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _controller.chatMessages.length,
                            itemBuilder: (context, index) {
                              final message = _controller.chatMessages[
                                  _controller.chatMessages.length - 1 - index];
                              
                              final isLatestAiMessage = message.sender == MessageSender.ai &&
                                  (index == 0 ||
                                      (_controller.chatMessages.last.sender == MessageSender.user &&
                                          index == 1));

                              return _buildChatBubble(message,
                                  isLatestAiMessage: isLatestAiMessage);
                            },
                          ),
                        ),

                        if (_controller.mascotState == MascotState.idle)
                          _buildQuickSuggestionChips(),

                        _buildMessageInputBar(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Build Chat Bubble & Rich Interactive Cards
  Widget _buildChatBubble(ChatMessage message, {required bool isLatestAiMessage}) {
    final isAi = message.sender == MessageSender.ai;
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.90;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxBubbleWidth),
          child: Column(
            crossAxisAlignment:
                isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              // Chat Text Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isAi
                      ? const Color(0xFF19244E)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isAi ? 4 : 18),
                    bottomRight: Radius.circular(isAi ? 18 : 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isAi ? Colors.white : const Color(0xFF19244E),
                    fontSize: 14.5,
                    height: 1.38,
                    fontWeight: isAi ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ),

              // 1. Weather Decision & Backup Plan Card (if rainy & outdoor stops)
              if (message.isWeatherDecisionCard && message.weatherAlert != null) ...[
                const SizedBox(height: 10),
                _buildWeatherDecisionCardWidget(message.weatherAlert!),
              ],

              // 2. AI Re-plan Decision Card (when user modifies stops in review mode)
              if (message.isPlanDecisionCard) ...[
                const SizedBox(height: 10),
                _buildPlanDecisionCardWidget(message),
              ],

              // 3. Timeline Preview Cards (Stops & Free Time Bridge Blocks)
              if (message.timelineItems != null && message.timelineItems!.isNotEmpty && !message.isPlanDecisionCard) ...[
                const SizedBox(height: 10),
                _buildTimelineListWidget(message.timelineItems!),
              ],

              // 3. Interactive MongoDB Place Suggestion Cards (Option 1, Option 2)
              if (isAi &&
                  message.suggestedPlaces != null &&
                  message.suggestedPlaces!.where((p) => !_controller.isSystemAction(p.name)).isNotEmpty) ...[
                const SizedBox(height: 10),
                ...message.suggestedPlaces!
                    .where((p) => !_controller.isSystemAction(p.name))
                    .toList()
                    .asMap()
                    .entries
                    .map((entry) {
                  final optionNum = entry.key + 1;
                  final place = entry.value;
                  final isAlreadyAdded = _controller.draftItinerary
                      .any((p) => p.name.toLowerCase() == place.name.toLowerCase());

                  return InkWell(
                    onTap: () => _openPlaceDetail(place),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAlreadyAdded ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF19244E),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Option $optionNum',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  place.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isAlreadyAdded) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 11, color: Color(0xFF059669)),
                                      SizedBox(width: 2),
                                      Text(
                                        'In Plan',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF059669),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (place.description.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              place.description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 3),
                                  Text(
                                    place.area,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.grey[700],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              InkWell(
                                onTap: () => _openPlaceDetail(place),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 16,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 6),
                _buildQuickActionButtons(message),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Weather Decision Card (Phase 2.5)
  Widget _buildWeatherDecisionCardWidget(WeatherAlertInfo alert) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.thunderstorm_outlined, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Weather Advisory & Rainy-Day Plan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '🌧️ Forecast: ${alert.condition} (${alert.description}) predicted on ${alert.date}.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF78350F), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          const Text(
            'We noticed outdoor stops in your itinerary and generated an indoor cultural backup plan. Would you like to switch now or decide on your travel day?',
            style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 14),
                  label: const Text(
                    'Switch to Indoor Plan',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _controller.applyBackupPlan();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _controller.keepOriginalPlan();
                  },
                  child: const Text(
                    'Decide on Travel Day',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // AI Re-plan Decision Card (when user modifies stops in review mode)
  Widget _buildPlanDecisionCardWidget(ChatMessage message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Re-plan for Your Modifications',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You modified your itinerary! AI re-evaluated opening hours, travel distance, and midday heat. Which plan would you like to follow?',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.3),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text(
                    'Use AI Plan',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    _controller.acceptAiPlan();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1D4ED8), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _controller.keepUserDecision();
                  },
                  child: const Text(
                    'Keep My Sequence',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Timeline List Widget (Phase 3 & 4)
  Widget _buildTimelineListWidget(List<TimelineItem> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF304FFE), size: 16),
                  SizedBox(width: 6),
                  Text(
                    'AI Timeline Schedule',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF19244E),
                    ),
                  ),
                ],
              ),
              if (_controller.travelDates != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _controller.travelDates!.start.toIso8601String().split('T').first,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;

            if (item is TimelineFreeTimeItem) {
              return _buildFreeTimeCard(item);
            } else if (item is TimelineStopItem) {
              return _buildTimelineStopCard(item, idx + 1);
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 10),
          // Action Buttons: [ 📋 Review & Modify Plan ] & [ 🚀 Start Journey on Map ]
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF19244E),
                    side: const BorderSide(color: Color(0xFF19244E), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.checklist_rtl_rounded, size: 16),
                  label: const Text(
                    'Review & Modify',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: _openSlidingPanel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF19244E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  icon: const Text('🚀', style: TextStyle(fontSize: 14)),
                  label: const Text(
                    'Start on Map',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  onPressed: _launchJourneyOnMap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Stop Card with Warning Flags
  Widget _buildTimelineStopCard(TimelineStopItem stop, int stopNum) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: stop.isClosed
              ? const Color(0xFFFCA5A5)
              : stop.isPeakHeat
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF19244E),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$stopNum',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.placeName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '⏰ ${stop.timeSlot}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                ),
              ),
            ],
          ),
          if (stop.tip.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '💡 ${stop.tip}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
          if (stop.warningFlag != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: stop.isClosed ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    stop.isClosed ? Icons.cancel_outlined : Icons.wb_sunny_outlined,
                    size: 13,
                    color: stop.isClosed ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    stop.isClosed
                        ? 'Venue may be closed on this day'
                        : 'Peak Midday Heat: Stay hydrated & use sunscreen',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: stop.isClosed ? const Color(0xFFDC2626) : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Free Time Bridge Card (Option A, B, C)
  Widget _buildFreeTimeCard(TimelineFreeTimeItem freeTime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coffee_outlined, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              const Text(
                'Free Time Bridge (自由时间)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF065F46),
                ),
              ),
              const Spacer(),
              Text(
                '⏰ ${freeTime.timeSlot}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildFreeTimeOption('A', freeTime.options.optionA),
          const SizedBox(height: 4),
          _buildFreeTimeOption('B', freeTime.options.optionB),
          const SizedBox(height: 4),
          _buildFreeTimeOption('C', freeTime.options.optionC),
        ],
      ),
    );
  }

  Widget _buildFreeTimeOption(String letter, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xFF059669),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Opt $letter',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF064E3B), height: 1.25),
          ),
        ),
      ],
    );
  }

  // Three quick action buttons below place suggestions matching reference image
  Widget _buildQuickActionButtons(ChatMessage message) {
    final rawPlaces = message.suggestedPlaces;
    if (rawPlaces == null || rawPlaces.isEmpty) return const SizedBox.shrink();

    final places = rawPlaces.where((p) => !_controller.isSystemAction(p.name)).toList();
    if (places.isEmpty) return const SizedBox.shrink();

    final placeA = places[0];
    final placeB = places.length > 1 ? places[1] : null;

    final isPlaceAInDraft = _controller.draftItinerary
        .any((p) => p.name.toLowerCase() == placeA.name.toLowerCase());
    final isPlaceBInDraft = placeB != null &&
        _controller.draftItinerary
            .any((p) => p.name.toLowerCase() == placeB.name.toLowerCase());

    // 1. User made choice condition:
    // Either explicitly marked chosen or either place is already in draft
    final bool hasMadeChoice = message.isOptionChosen || isPlaceAInDraft || isPlaceBInDraft;

    // 2. New input (intent) condition:
    // If this message is not the latest message in the chat list,
    // the user has already input a new message (intent) or conversation has progressed.
    final bool isLatestMessageInChat = _controller.chatMessages.isNotEmpty &&
        _controller.chatMessages.last.id == message.id;

    // The option buttons are disabled (grey color) if user made choice OR if there is new input
    final bool isDisabled = hasMadeChoice || !isLatestMessageInChat;

    const unselectedOptionBg = Color(0x8054DAFF); // Light blue matching shortcut key blue background
    const unselectedOptionBorder = BorderSide(color: Color(0xFFBAE6FD), width: 1.2);
    const selectedActiveBg = Color(0xFF2B52FF);
    const unselectedBothBg = Color(0xFFFFDA0A);
    const unselectedBothBorder = BorderSide(color: Color(0xFFFDE047), width: 1.2);

    const disabledBg = Color(0xFFE2E8F0); // Subtle slate grey background
    const disabledFg = Color(0xFF94A3B8); // Muted slate text/icon color
    const disabledBorder = BorderSide(color: Color(0xFFCBD5E1), width: 1);

    // Option A selection state
    final bool isASelected = message.selectedOption == 'A' ||
        (message.selectedOption == null && isPlaceAInDraft && !isPlaceBInDraft);
    // Option B selection state
    final bool isBSelected = message.selectedOption == 'B' ||
        (message.selectedOption == null && isPlaceBInDraft && !isPlaceAInDraft);
    // Both selection state
    final bool isBothSelected = message.selectedOption == 'Both' ||
        (isPlaceAInDraft && isPlaceBInDraft);

    // Dynamic styling for Option A
    final Color bgA = isASelected
        ? selectedActiveBg
        : (isDisabled ? disabledBg : unselectedOptionBg);
    final Color fgA = isASelected
        ? Colors.white
        : (isDisabled ? disabledFg : const Color(0xFF040E12));
    final BorderSide borderA = isASelected
        ? BorderSide.none
        : (isDisabled ? disabledBorder : unselectedOptionBorder);

    // Dynamic styling for Option B
    final Color bgB = isBSelected
        ? selectedActiveBg
        : (isDisabled ? disabledBg : unselectedOptionBg);
    final Color fgB = isBSelected
        ? Colors.white
        : (isDisabled ? disabledFg : const Color(0xFF040E12));
    final BorderSide borderB = isBSelected
        ? BorderSide.none
        : (isDisabled ? disabledBorder : unselectedOptionBorder);

    // Dynamic styling for Add Both Suggestions button
    final Color bgBoth = isBothSelected
        ? selectedActiveBg
        : (isDisabled ? disabledBg : unselectedBothBg);
    final Color fgBoth = isBothSelected
        ? Colors.white
        : (isDisabled ? disabledFg : const Color(0xFF713F12));
    final BorderSide borderBoth = isBothSelected
        ? BorderSide.none
        : (isDisabled ? disabledBorder : unselectedBothBorder);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        children: [
          if (placeB != null)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bgA,
                      foregroundColor: fgA,
                      disabledBackgroundColor: bgA,
                      disabledForegroundColor: fgA,
                      elevation: isDisabled ? 0 : 1.5,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: borderA,
                      ),
                    ),
                    onPressed: isDisabled
                        ? null
                        : () {
                            setState(() {
                              message.isOptionChosen = true;
                              message.selectedOption = 'A';
                            });
                            _controller.addPlaceToDraft(placeA);
                          },
                    child: Text(
                      isASelected
                          ? '✓ Option A: ${placeA.name}'
                          : 'Option A: ${placeA.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fgA,
                        fontFamily: 'SF Pro',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: bgB,
                      foregroundColor: fgB,
                      disabledBackgroundColor: bgB,
                      disabledForegroundColor: fgB,
                      elevation: isDisabled ? 0 : 1.5,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: borderB,
                      ),
                    ),
                    onPressed: isDisabled
                        ? null
                        : () {
                            setState(() {
                              message.isOptionChosen = true;
                              message.selectedOption = 'B';
                            });
                            _controller.addPlaceToDraft(placeB);
                          },
                    child: Text(
                      isBSelected
                          ? '✓ Option B: ${placeB.name}'
                          : 'Option B: ${placeB.name}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: fgB,
                        fontFamily: 'SF Pro',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bgA,
                  foregroundColor: fgA,
                  disabledBackgroundColor: bgA,
                  disabledForegroundColor: fgA,
                  elevation: isDisabled ? 0 : 1.5,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: borderA,
                  ),
                ),
                onPressed: isDisabled
                    ? null
                    : () {
                        setState(() {
                          message.isOptionChosen = true;
                          message.selectedOption = 'A';
                        });
                        _controller.addPlaceToDraft(placeA);
                      },
                child: Text(
                  isASelected
                      ? '✓ Option A: ${placeA.name}'
                      : 'Option A: ${placeA.name}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: fgA,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: bgBoth,
                foregroundColor: fgBoth,
                disabledBackgroundColor: bgBoth,
                disabledForegroundColor: fgBoth,
                elevation: isDisabled ? 0 : 2,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: borderBoth,
                ),
              ),
              icon: Icon(
                Icons.playlist_add_check_rounded,
                color: fgBoth,
                size: 20,
              ),
              label: Text(
                isBothSelected
                    ? '✓ Both suggestions added'
                    : (placeB != null ? 'Add both suggestions' : 'Add suggestion'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: fgBoth,
                  fontFamily: 'SF Pro',
                ),
              ),
              onPressed: isDisabled
                  ? null
                  : () {
                      setState(() {
                        message.isOptionChosen = true;
                        message.selectedOption = 'Both';
                      });
                      if (placeB != null) {
                        _controller.addPlaceToDraft(placeA, notifyChat: false);
                        _controller.addPlaceToDraft(placeB, notifyChat: true);
                      } else {
                        _controller.addPlaceToDraft(placeA);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }


  // Context-Aware Dynamic Shortcuts
  List<String> _getContextAwareShortcuts() {
    final List<String> list = [];

    // Weather-based: if detect rainfall, display Indoor Discovery before Quick Plan by Area
    final bool hasRain = _isRainyWeather || (_controller.weatherAlert?.isRainy == true);
    if (hasRain) {
      list.add('🌧️ Indoor Discovery');
    }

    // Base shortcuts
    list.add('⚡ Quick Plan by Area');
    list.add('🎯 Digital Stamp Hunt');
    list.add('🏛️ 1-Day Classic Heritage');
    list.add('🍜 Local Foodie Guide');

    // Time-based context-aware shortcuts (only shown during specified hours)
    final now = DateTime.now();
    final totalMinutes = now.hour * 60 + now.minute;

    if (totalMinutes >= 8 * 60 && totalMinutes < 11 * 60) {
      // 08:00 - 11:00
      list.add('☕ Traditional Breakfasts');
    } else if (totalMinutes >= 14 * 60 && totalMinutes <= 16 * 60 + 30) {
      // 14:00 - 16:30
      list.add('🫖 Afternoon Tea');
    } else if (totalMinutes >= 18 * 60) {
      // 18:00 onwards
      list.add('🍻 Night Markets & Bars');
    }
    // During any other hours (11:00-14:00, 16:30-18:00, 00:00-08:00), no time-based shortcut is displayed

    return list;
  }

  // Quick Suggestion Chips (Alternating Light Yellow and Light Blue)
  Widget _buildQuickSuggestionChips() {
    final suggestions = _getContextAwareShortcuts();

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          // Alternating backgrounds: Even = Light Yellow, Odd = Light Blue
          final isYellow = idx % 2 == 0;
          final bgColor = isYellow ? const Color(0xFFFEF9C3) : const Color(0xFFE0F2FE);
          final borderColor = isYellow ? const Color(0xFFFDE047) : const Color(0xFFBAE6FD);
          final textColor = isYellow ? const Color(0xFF713F12) : const Color(0xFF0369A1);

          final chipText = suggestions[idx];
          final isQuickPlan = chipText.contains('Quick Plan by Area');

          return ActionChip(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            backgroundColor: bgColor,
            side: BorderSide(color: borderColor, width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: Text(
              chipText,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              final now = DateTime.now();
              final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
              debugPrint('====================================================');
              debugPrint('🔘 [SHORTCUT TAPPED] at $timeStr');
              debugPrint('🏷️  Label           : "$chipText"');
              debugPrint('🌤️  Weather Context : Rainy detected = $_isRainyWeather');
              debugPrint('⏱️  Time Context    : ${now.hour}:${now.minute.toString().padLeft(2, '0')}');

              if (isQuickPlan) {
                debugPrint('🧭 Action          : Opening Area Picker Bottom Sheet...');
                debugPrint('====================================================');
                _showAreaPickerBottomSheet();
              } else {
                debugPrint('💬 Action          : Sending query prompt to TripController: "$chipText"');
                debugPrint('====================================================');
                _controller.sendUserMessage(chipText);
              }
            },
          );
        },
      ),
    );
  }

  // Bottom Sheet Area Picker for Quick Planning
  void _showAreaPickerBottomSheet() {
    final areas = [
      {
        'name': 'George Town',
        'desc': 'UNESCO Heritage, Street Art & Clan Jetties',
        'emoji': '🏛️',
      },
      {
        'name': 'Batu Ferringhi',
        'desc': 'Golden Beaches, Water Sports & Night Market',
        'emoji': '🏖️',
      },
      {
        'name': 'Gurney Drive',
        'desc': 'Seaside Promenade & Iconic Hawker Delights',
        'emoji': '🛍️',
      },
      {
        'name': 'Air Itam',
        'desc': 'Penang Hill Funicular & Kek Lok Si Temple',
        'emoji': '⛰️',
      },
      {
        'name': 'Teluk Bahang',
        'desc': 'ESCAPE Theme Park & National Park Nature',
        'emoji': '🌿',
      },
      {
        'name': 'Balik Pulau',
        'desc': 'Idyllic Countryside, Durians & Fresh Nutmeg',
        'emoji': '🥑',
      },
      {
        'name': 'Bayan Lepas',
        'desc': 'Queensbay Mall, Snake Temple & South Coast',
        'emoji': '✈️',
      },
      {
        'name': 'Tanjung Bungah',
        'desc': 'Floating Mosque, Coastal Resorts & Avatar Garden',
        'emoji': '🌊',
      },
      {
        'name': 'Butterworth',
        'desc': 'Mainland Art Walk, Tow Boo Kong & Bird Park',
        'emoji': '🚂',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF304FFE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('⚡', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Plan by Area',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[850],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pick an area to prefill your trip planner message',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 6),
              Expanded(
                child: ListView.separated(
                  itemCount: areas.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 48),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(area['emoji']!, style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(
                        area['name']!,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        area['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _onSelectAreaForQuickPlan(area['name']!);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSelectAreaForQuickPlan(String areaName) {
    final prefilledText = 'Plan trip for me in $areaName';
    debugPrint('----------------------------------------------------');
    debugPrint('📍 [AREA PICKER] User selected area: "$areaName"');
    debugPrint('✍️  [AREA PICKER] Prefilling message box with: "$prefilledText"');
    debugPrint('🎯 [AREA PICKER] Requesting focus on text input. Awaiting user tap on send button.');
    debugPrint('----------------------------------------------------');

    _textController.text = prefilledText;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    _focusNode.requestFocus();
  }

  // Message Input Bar
  Widget _buildMessageInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF304FFE),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.playlist_add_check,
                      color: Colors.white, size: 22),
                  tooltip: 'View draft plan',
                  onPressed: _openDraftPlanScreen,
                ),
              ),
              if (_controller.draftItinerary.isNotEmpty)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '${_controller.draftItinerary.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendCurrentMessage(),
                decoration: const InputDecoration(
                  hintText: 'Ask bird or say "Add Kek Lok Si"...',
                  hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF19244E),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _sendCurrentMessage,
            ),
          ),
        ],
      ),
    );
  }
}

