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
import 'detail_screen.dart';
import '../services/places_service.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerUpdate);
    _controller.onRequireDatesTriggered = _selectTravelDatesAndPlan;
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
      await _selectTravelDatesAndPlan();
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
              if (isAi && message.suggestedPlaces != null && message.suggestedPlaces!.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...message.suggestedPlaces!.asMap().entries.map((entry) {
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
                _buildQuickActionButtons(message.suggestedPlaces!),
              ],

              // Smart Action Chips: Render ONLY on the latest AI message
              if (isLatestAiMessage && message.showActionChips) ...[
                const SizedBox(height: 8),
                _buildSmartActionChips(),
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
  Widget _buildQuickActionButtons(List<ItineraryPlace> places) {
    if (places.isEmpty) return const SizedBox.shrink();

    final placeA = places[0];
    final placeB = places.length > 1 ? places[1] : null;

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
                      backgroundColor: const Color(0xFFFFD600), // Bright Yellow
                      foregroundColor: Colors.black,
                      elevation: 1.5,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      _controller.addPlaceToDraft(placeA);
                    },
                    child: Text(
                      'Option A: ${placeA.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                      backgroundColor: const Color(0xFFF48FB1), // Pastel Pink / Rose
                      foregroundColor: Colors.black,
                      elevation: 1.5,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      _controller.addPlaceToDraft(placeB);
                    },
                    child: Text(
                      'Option B: ${placeB.name}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
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
                  backgroundColor: const Color(0xFFFFD600),
                  foregroundColor: Colors.black,
                  elevation: 1.5,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  _controller.addPlaceToDraft(placeA);
                },
                child: Text(
                  'Option A: ${placeA.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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
                backgroundColor: const Color(0xFF304FFE), // Vibrant Blue
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.white, size: 20),
              label: Text(
                placeB != null ? 'Add both suggestions' : 'Add suggestion',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'SF Pro',
                ),
              ),
              onPressed: () {
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

  // Smart Action Chips Row
  Widget _buildSmartActionChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ActionChip(
            elevation: 2,
            backgroundColor: const Color(0xFF19244E),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🚀', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  'Save and Plan Trip for Me Now',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onPressed: _handleLockAndStartTrip,
          ),
          const SizedBox(width: 8),
          ActionChip(
            elevation: 1,
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFF3B82F6), width: 1.2),
            label: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('➕', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Text(
                  'Add More Places',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onPressed: () {
              _focusNode.requestFocus();
              _textController.text = 'Add ';
              _textController.selection = TextSelection.fromPosition(
                TextPosition(offset: _textController.text.length),
              );
            },
          ),
        ],
      ),
    );
  }

  // Quick Suggestion Chips
  Widget _buildQuickSuggestionChips() {
    final suggestions = [
      '🏛️ 1-Day Heritage Tour',
      '🍜 Recommend Penang food',
      '⛰️ Add Penang Hill',
      '🌊 Beach & Nature trip',
    ];

    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: suggestions.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          return ActionChip(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            label: Text(
              suggestions[idx],
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF19244E),
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              _controller.sendUserMessage(suggestions[idx]);
            },
          );
        },
      ),
    );
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

