import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_trip_plans_manager.dart';
import '../services/live_journey_service.dart';
import '../services/weather_service.dart';
import '../widgets/companion/penny_place_chat_sheet.dart';
import '../widgets/journey_start_workflow.dart';
import '../widgets/trip_route_summary_map.dart';
import '../models/companion_alert.dart';
import '../models/completed_trip_summary.dart';
import '../services/companion_alert_service.dart';
import '../services/completed_trails_manager.dart';
import 'travel_plans_screen.dart';

/// Screen displayed when user taps the 2nd tab icon (Story Tab, navigationBar-map-icon).
/// Displays the user's most upcoming saved trip plan in a blue gradient banner,
/// showing countdown to their Penang trip (e.g. "Visiting Penang in X days"),
/// travel dates, schedule, areas, and planned stops.
class StoryTabScreen extends StatefulWidget {
  const StoryTabScreen({super.key});

  @override
  State<StoryTabScreen> createState() => _StoryTabScreenState();
}

class _StoryTabScreenState extends State<StoryTabScreen> {
  final ScrollController _scrollController = ScrollController();
  WeatherData? _todayWeather;
  String? _lastWeatherArea;
  bool _isBannerManuallyExpanded = false;

  @override
  void initState() {
    super.initState();
    // Load local cache and sync with Firestore for up-to-date saved trip plans
    SavedTripPlansManager.init();
    SavedTripPlansManager.syncWithFirestore();
    CompletedTrailsManager.init();
  }

  Future<void> _loadWeatherForPlan(SavedTripPlan plan) async {
    final area = plan.displayArea;
    if (_lastWeatherArea == area && _todayWeather != null) return;
    _lastWeatherArea = area;

    final sampleStop = plan.stops.isNotEmpty ? plan.stops.first : null;
    final lat = (sampleStop != null && sampleStop.lat != 0.0) ? sampleStop.lat : 5.4141;
    final lng = (sampleStop != null && sampleStop.lng != 0.0) ? sampleStop.lng : 100.3288;
    final cityName = sampleStop?.area.isNotEmpty == true ? sampleStop!.area : 'George Town';

    try {
      final w = await WeatherService().fetchWeather(
        latitude: lat,
        longitude: lng,
        cityName: cityName,
      );
      if (mounted) {
        setState(() {
          _todayWeather = w;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _todayWeather = WeatherData.mockRainy();
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LiveJourneyService.instance,
        SavedTripPlansManager.savedPlansNotifier,
        SavedTripPlansManager.selectedPlanIdNotifier,
      ]),
      builder: (context, _) {
        final liveJourney = LiveJourneyService.instance;
        final plans = SavedTripPlansManager.savedPlansNotifier.value;
        final selectedId = SavedTripPlansManager.selectedPlanId;

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: _buildFloatingMascotButton(liveJourney),
          body: SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP HEADER
                  _buildHeader(),
                  const SizedBox(height: 12),

                  // Companion Safety Alerts Pill (if any active alerts)
                  _buildActiveCompanionAlertsPill(),

                  const SizedBox(height: 8),

                  // 2. SAVED PLANS CONTENT & UPCOMING BANNER
                  Builder(
                    builder: (context) {
                      // Plan resolution:
                      // 1. If live journey is running with an active plan, prioritize it immediately regardless of scheduled dates!
                      // 2. Else if user explicitly started/selected a trip from Saved Plans, use it
                      // 3. Otherwise, use the closest upcoming unexpired plan
                      SavedTripPlan? activePlan;

                      if (liveJourney.isJourneyActive && liveJourney.activePlan != null) {
                        activePlan = liveJourney.activePlan;
                      } else if (selectedId != null && plans.any((p) => p.id == selectedId)) {
                        final cand = plans.firstWhere((p) => p.id == selectedId);
                        // Do not use candidate if it has already been completed or expired!
                        if (!SavedTripPlansManager.isPlanCompleted(cand) && !SavedTripPlansManager.isPlanExpired(cand)) {
                          activePlan = cand;
                        }
                      }

                      if (activePlan == null) {
                        final unexpiredPlans = plans
                            .where((p) => !SavedTripPlansManager.isPlanCompleted(p) && !SavedTripPlansManager.isPlanExpired(p))
                            .toList();
                        if (unexpiredPlans.isNotEmpty) {
                          activePlan = _findMostUpcomingPlan(unexpiredPlans);
                        }
                      }

                      // If trip has just completed, show the Completed Trip Summary View with Map on top!
                      final completedSummary = liveJourney.completedTripSummary ??
                          CompletedTrailsManager.latestCompletedSummaryNotifier.value;
                      if (completedSummary != null && !liveJourney.isJourneyActive) {
                        return _buildCompletedTripSummaryView(context, liveJourney, completedSummary);
                      }

                      if (activePlan == null) {
                        return _buildEmptyStateBanner();
                      }

                      _loadWeatherForPlan(activePlan);

                      final dateInfo = _parsePlanDates(
                        activePlan,
                        isLiveActive: liveJourney.isJourneyActive && liveJourney.activePlan?.id == activePlan.id,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Blue card for the active/upcoming itinerary (collapsible when trip is active)
                          _buildUpcomingPlanBanner(
                            activePlan,
                            dateInfo,
                            liveJourney,
                          ),
                          const SizedBox(height: 14),

                          // Day Weather Forecast Card
                          _buildDayWeatherForecastCard(activePlan),
                          const SizedBox(height: 14),

                          // Pre-journey Mock Real-Time Location Toggle (before journey starts)
                          if (!liveJourney.isJourneyActive) ...[
                            _buildMockLocationToggleCard(activePlan, liveJourney),
                            const SizedBox(height: 14),
                          ],

                          // Action Button: Begin Live Journey
                          _buildBeginJourneyButton(activePlan, liveJourney),

                          // Live Location Activity section or Itinerary Stops Preview
                          if (liveJourney.isJourneyActive) ...[
                            const SizedBox(height: 24),
                            _buildLiveLocationActivity(activePlan, liveJourney),
                          ] else ...[
                            const SizedBox(height: 24),
                            _buildItineraryStopsPreview(activePlan),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Screen Title Header
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Trip Itinerary',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF303030), // Colors.grey[850]
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Your upcoming adventure in Penang',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        // Mascot avatar indicator
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/pink_bird_mascot.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/pink_bird_mascot.png',
                fit: BoxFit.contain,
                errorBuilder: (context, error2, stackTrace2) => const Center(
                  child: Text('🌸', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Displays a persistent alert bar if any companion safety status / SOS is currently active
  Widget _buildActiveCompanionAlertsPill() {
    return ValueListenableBuilder<List<CompanionAlert>>(
      valueListenable: CompanionAlertService.instance.activeAlertsNotifier,
      builder: (context, alerts, _) {
        if (alerts.isEmpty) return const SizedBox.shrink();

        final topAlert = alerts.first;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: topAlert.backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: topAlert.primaryColor,
              width: topAlert.isUrgent ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: topAlert.primaryColor.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () {
                // Re-open floating banner
                CompanionAlertService.instance.latestAlertNotifier.value = topAlert;
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: topAlert.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        topAlert.iconData,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                topAlert.senderNickname,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF303030),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: topAlert.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  topAlert.typeLabel,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            topAlert.message,
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: topAlert.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Blue Gradient Banner for the Active / Upcoming Saved Plan
  /// Automatically collapses into a compact status bar when the trip is active,
  /// with an interactive tap to expand/collapse.
  Widget _buildUpcomingPlanBanner(
    SavedTripPlan plan,
    _PlanDateInfo dateInfo,
    LiveJourneyService liveJourney,
  ) {
    // If plan is completed and journey is not actively running, do NOT show as upcoming!
    if (SavedTripPlansManager.isPlanCompleted(plan) && !liveJourney.isJourneyActive) {
      return const SizedBox.shrink();
    }

    // If trip is active and user has not manually expanded the card, show collapsed view
    if (liveJourney.isJourneyActive && !_isBannerManuallyExpanded) {
      return _buildCollapsedUpcomingPlanBanner(plan, dateInfo, liveJourney);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Deep Slate Navy
            Color(0xFF1E3A8A), // Royal Navy Blue
            Color(0xFF2563EB), // Vibrant Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Tag & Countdown Pill (with Collapse button if active)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      liveJourney.isJourneyActive
                          ? Icons.navigation_rounded
                          : Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      liveJourney.isJourneyActive ? 'LIVE TRIP ACTIVE' : 'UPCOMING TRIP',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD54F), // Warm gold highlight
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      dateInfo.countdownBadgeText,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        color: Color(0xFF0F172A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (liveJourney.isJourneyActive) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isBannerManuallyExpanded = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '',//remove collapse
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: Headline Countdown (e.g. "Visiting Penang in 4 days")
          Text(
            dateInfo.headlineText,
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 21,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),

          // Row 3: Plan Title
          Text(
            plan.cleanTitle,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.92),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          const SizedBox(height: 14),

          // Row 4: Trip Information Badges
          // Travel Dates
          _buildInfoRow(
            icon: Icons.calendar_month_rounded,
            label: 'Travel Dates',
            value: dateInfo.displayDateRange,
          ),
          const SizedBox(height: 10),

          // Daily Schedule
          _buildInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Schedule',
            value: plan.travelSchedule,
          ),
          const SizedBox(height: 10),

          // Simulated Mock Travel Time (Dashboard Synced)
          _buildInfoRow(
            icon: Icons.access_time_filled_rounded,
            label: 'Simulated Time',
            value: liveJourney.isJourneyActive
                ? liveJourney.virtualTimeString
                : LiveJourneyService.formatVirtualClock(LiveJourneyService.parsePlanScheduledDateTime(plan)),
          ),
          const SizedBox(height: 10),

          // Travel Area
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            label: 'Area',
            value: plan.displayArea,
          ),
          const SizedBox(height: 10),

          // Planned Stops Count
          _buildInfoRow(
            icon: Icons.place_rounded,
            label: 'Itinerary',
            value: '${plan.stops.length} Planned Stops',
          ),

          // If active, show tap-to-collapse button at the bottom
          if (liveJourney.isJourneyActive) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isBannerManuallyExpanded = false;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Collapse Trip Plan Details',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact Collapsed Blue Gradient Banner when a trip is active
  Widget _buildCollapsedUpcomingPlanBanner(
    SavedTripPlan plan,
    _PlanDateInfo dateInfo,
    LiveJourneyService liveJourney,
  ) {
    if (SavedTripPlansManager.isPlanCompleted(plan) && !liveJourney.isJourneyActive) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A), // Deep Slate Navy
            Color(0xFF1E3A8A), // Royal Navy Blue
            Color(0xFF2563EB), // Vibrant Blue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _isBannerManuallyExpanded = true;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Live Journey Pulse Icon
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF38BDF8),
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.navigation_rounded,
                      color: Color(0xFF38BDF8),
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF4ADE80),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'TRIP ACTIVE',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF86EFAC),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '⏰ ${liveJourney.virtualTimeString}',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 10.5,
                                color: Colors.white.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        plan.cleanTitle,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${plan.displayArea} · ${plan.stops.length} Planned Stops',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Expand Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Plan',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Helper row inside the upcoming banner
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 15,
          color: Colors.white.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 12.5,
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Empty State Banner when user has no saved plans yet
  Widget _buildEmptyStateBanner() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E3A8A),
            Color(0xFF2563EB),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 5),
                    Text(
                      'TRIP ITINERARY',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'No Upcoming Trip Plans Yet',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You haven\'t saved any Penang trip plans yet. Explore Penang attractions in the Discover tab or plan your custom itinerary to see your countdown here!',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Pre-journey Mock Real-Time Location Toggle card
  Widget _buildMockLocationToggleCard(SavedTripPlan plan, LiveJourneyService liveJourney) {
    final firstStop = plan.stops.isNotEmpty ? plan.stops.first : null;
    final matchedHotel = MockHotelRegistry.findForArea(firstStop?.area);
    final isMockOn = liveJourney.useMockLocation;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMockOn ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
          width: isMockOn ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMockOn ? const Color(0xFF38BDF8) : Colors.black).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Toggle Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isMockOn ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          isMockOn ? Icons.hotel_rounded : Icons.my_location_rounded,
                          color: isMockOn ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          size: 19,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mock Real-Time Location',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            isMockOn ? 'Simulate starting from nearby hotel' : 'Using real device GPS location',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: isMockOn,
                onChanged: (val) {
                  liveJourney.setUseMockLocation(val);
                },
                activeThumbColor: const Color(0xFF304FFE), // Colors.indigoAccent[700]
                activeTrackColor: const Color(0xFFC7D2FE),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Detail Section based on toggle state
          if (isMockOn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_city_rounded, size: 15, color: Color(0xFF0369A1)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          matchedHotel.hotelName,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MOCK GPS',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '📍 1st Stop Area: ${firstStop?.area ?? matchedHotel.area} · Matched: ${matchedHotel.area}',
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '🌐 Coordinates: ${matchedHotel.lat.toStringAsFixed(4)}° N, ${matchedHotel.lng.toStringAsFixed(4)}° E',
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, size: 16, color: Color(0xFF475569)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trip departure starts from your device\'s actual live GPS coordinates.',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                      ),
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

  /// Algorithm to pick the most upcoming plan:
  /// Prioritizes future plans sorted by earliest start date,
  /// then ongoing plans, then most recently saved plan.
  SavedTripPlan _findMostUpcomingPlan(List<SavedTripPlan> plans) {
    final validPlans = plans
        .where((p) => !SavedTripPlansManager.isPlanCompleted(p) && !SavedTripPlansManager.isPlanExpired(p))
        .toList();
    if (validPlans.isEmpty) return plans.first;
    if (validPlans.length == 1) return validPlans.first;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    SavedTripPlan? closestFuturePlan;
    int minDaysToStart = 999999;

    SavedTripPlan? ongoingPlan;

    for (final plan in validPlans) {
      final dateInfo = _parsePlanDates(plan);
      if (dateInfo.startDate != null) {
        final startOnly = DateTime(
          dateInfo.startDate!.year,
          dateInfo.startDate!.month,
          dateInfo.startDate!.day,
        );
        final diff = startOnly.difference(today).inDays;

        if (diff >= 0 && diff < minDaysToStart) {
          minDaysToStart = diff;
          closestFuturePlan = plan;
        } else if (diff < 0 && dateInfo.endDate != null) {
          final endOnly = DateTime(
            dateInfo.endDate!.year,
            dateInfo.endDate!.month,
            dateInfo.endDate!.day,
          );
          if (!endOnly.isBefore(today)) {
            ongoingPlan = plan;
          }
        }
      }
    }

    if (closestFuturePlan != null) return closestFuturePlan;
    if (ongoingPlan != null) return ongoingPlan;

    // Fallback: return the most recently saved plan
    final sortedBySaved = List<SavedTripPlan>.from(plans)
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return sortedBySaved.first;
  }

  /// Parses date range string into structured _PlanDateInfo with countdown text
  _PlanDateInfo _parsePlanDates(SavedTripPlan plan, {bool isLiveActive = false}) {
    final raw = plan.travelDateRange.trim();
    if (isLiveActive) {
      return _PlanDateInfo(
        startDate: null,
        endDate: null,
        daysUntil: 0,
        headlineText: 'Trip in progress today!',
        countdownBadgeText: 'Active Trip',
        displayDateRange: raw.isNotEmpty && !raw.toLowerCase().contains('unselected')
            ? raw
            : 'Started Today (${_formatDate(DateTime.now())})',
      );
    }
    if (SavedTripPlansManager.isPlanCompleted(plan)) {
      return _PlanDateInfo(
        startDate: null,
        endDate: null,
        daysUntil: null,
        headlineText: 'Trip Completed',
        countdownBadgeText: 'Completed',
        displayDateRange: raw.isNotEmpty ? raw : 'Completed Itinerary',
      );
    }
    if (raw.isEmpty || raw.toLowerCase().contains('unselected')) {
      return _PlanDateInfo(
        startDate: null,
        endDate: null,
        daysUntil: null,
        headlineText: 'Penang Itinerary Planned',
        countdownBadgeText: 'Plan Ready',
        displayDateRange: 'Dates Unselected',
      );
    }

    DateTime? start;
    DateTime? end;

    // 1. Regex match "YYYY-MM-DD"
    final matches = RegExp(r'(\d{4})-(\d{1,2})-(\d{1,2})').allMatches(raw).toList();
    if (matches.isNotEmpty) {
      final m1 = matches[0];
      start = DateTime(
        int.parse(m1.group(1)!),
        int.parse(m1.group(2)!),
        int.parse(m1.group(3)!),
      );
      if (matches.length > 1) {
        final m2 = matches[1];
        end = DateTime(
          int.parse(m2.group(1)!),
          int.parse(m2.group(2)!),
          int.parse(m2.group(3)!),
        );
      }
    }

    // 2. Check Text matches e.g. "14 Oct 2026" or "Oct 14, 2026"
    if (start == null) {
      const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
      final textDates = <DateTime>[];

      // Day-first
      final dayMatches = RegExp(r'(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{4})').allMatches(raw);
      for (final m in dayMatches) {
        final day = int.parse(m.group(1)!);
        final monthStr = m.group(2)!;
        final monthName = monthStr.length >= 3 ? monthStr.substring(0, 3).toLowerCase() : '';
        final year = int.parse(m.group(3)!);
        final monthIdx = months.indexOf(monthName);
        if (monthIdx != -1) {
          textDates.add(DateTime(year, monthIdx + 1, day));
        }
      }

      // Month-first
      if (textDates.isEmpty) {
        final monthMatches = RegExp(r'([a-zA-Z]{3,9})\s+(\d{1,2}),?\s+(\d{4})').allMatches(raw);
        for (final m in monthMatches) {
          final monthStr = m.group(1)!;
          final monthName = monthStr.length >= 3 ? monthStr.substring(0, 3).toLowerCase() : '';
          final day = int.parse(m.group(2)!);
          final year = int.parse(m.group(3)!);
          final monthIdx = months.indexOf(monthName);
          if (monthIdx != -1) {
            textDates.add(DateTime(year, monthIdx + 1, day));
          }
        }
      }

      if (textDates.isNotEmpty) {
        start = textDates.first;
        if (textDates.length > 1) {
          end = textDates.last;
        }
      }
    }

    if (start == null) {
      return _PlanDateInfo(
        startDate: null,
        endDate: null,
        daysUntil: null,
        headlineText: 'Penang Itinerary Ready',
        countdownBadgeText: 'Saved Plan',
        displayDateRange: raw,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = end != null ? DateTime(end.year, end.month, end.day) : startDay;
    final daysDiff = startDay.difference(today).inDays;

    final displayRange = end != null && end != start
        ? '${_formatDate(start)} – ${_formatDate(end)}'
        : _formatDate(start);

    if (daysDiff > 1) {
      return _PlanDateInfo(
        startDate: start,
        endDate: end,
        daysUntil: daysDiff,
        headlineText: 'Visiting Penang in $daysDiff days',
        countdownBadgeText: '$daysDiff Days To Go',
        displayDateRange: displayRange,
      );
    } else if (daysDiff == 1) {
      return _PlanDateInfo(
        startDate: start,
        endDate: end,
        daysUntil: 1,
        headlineText: 'Visiting Penang tomorrow!',
        countdownBadgeText: 'Starts Tomorrow',
        displayDateRange: displayRange,
      );
    } else if (daysDiff == 0) {
      return _PlanDateInfo(
        startDate: start,
        endDate: end,
        daysUntil: 0,
        headlineText: 'Your Penang trip starts today!',
        countdownBadgeText: 'Starts Today',
        displayDateRange: displayRange,
      );
    } else if (!endDay.isBefore(today)) {
      return _PlanDateInfo(
        startDate: start,
        endDate: end,
        daysUntil: 0,
        headlineText: 'Currently in Penang!',
        countdownBadgeText: 'In Progress',
        displayDateRange: displayRange,
      );
    } else {
      return _PlanDateInfo(
        startDate: start,
        endDate: end,
        daysUntil: daysDiff,
        headlineText: 'Past Penang Trip',
        countdownBadgeText: 'Completed',
        displayDateRange: displayRange,
      );
    }
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  /// Floating Pink Bird Mascot Button for live landmark assistance & cultural Q&A (Full-width banner)
  Widget? _buildFloatingMascotButton(LiveJourneyService liveJourney) {
    if (!liveJourney.isJourneyActive) return null;

    final isArrived = liveJourney.isArrived;
    final currentStop = liveJourney.currentStopName;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: GestureDetector(
        onTap: () {
          PennyPlaceChatSheet.show(
            context,
            placeName: currentStop,
            area: liveJourney.currentArea,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF80AB), Color(0xFFFF4081)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF4081).withValues(alpha: 0.42),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/pink_bird_mascot.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/pink_bird_mascot.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context2, error2, stackTrace2) =>
                          const Text('🌸', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Penny @ $currentStop',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArrived
                          ? '✨ Tap to explore local stories & secrets'
                          : '🚗 In transit (${(liveJourney.remainingSeconds / 60).toStringAsFixed(1)}m) · Tap to ask Penny',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Weather Forecast card for the planned/active trip day
  Widget _buildDayWeatherForecastCard(SavedTripPlan plan) {
    final weather = _todayWeather ?? WeatherData.mockRainy();
    final temp = weather.temp.round();
    final tempMax = weather.tempMax.round();
    final tempMin = weather.tempMin.round();
    final rainProb = weather.precipitationProbabilityMax;
    final isRainRisk = rainProb >= 40 || weather.isRainy;
    final primaryRain = weather.primaryRainWindow;

    final String adviceText;
    if (primaryRain != null) {
      adviceText = 'Rain pour expected around ${primaryRain.timeRangeString} (${primaryRain.maxPrecipProb}%). Carry an umbrella and plan indoor stops during this window!';
    } else if (isRainRisk) {
      adviceText = 'Rain showers are likely. Remember an umbrella and check indoor backup stops!';
    } else if (tempMax >= 32 || weather.uvIndex >= 7.0) {
      adviceText = 'Bright and sunny Penang sunshine! Stay hydrated and wear sun protection.';
    } else {
      adviceText = 'Great weather for exploring Penang heritage streets and hawker stalls!';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRainRisk ? const Color(0xFF93C5FD) : const Color(0xFFFDE68A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    isRainRisk ? '🌧️' : '☀️',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Day Weather Forecast',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isRainRisk ? const Color(0xFFEFF6FF) : const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isRainRisk ? const Color(0xFFBFDBFE) : const Color(0xFFFEF08A),
                  ),
                ),
                child: Text(
                  weather.condition.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isRainRisk ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Weather Highlight Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$temp°C',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High $tempMax°C · Low $tempMin°C',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 ${plan.displayArea}',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 1: Rain Prediction Tag First (with percentage & estimated pour time range)
          _buildWeatherMetricPill(
            icon: Icons.water_drop_outlined,
            label: primaryRain != null
                ? 'Rain: $rainProb% (Est. ${primaryRain.timeRangeString})'
                : (isRainRisk ? 'Rain: $rainProb% (Showers Likely)' : 'Rain: $rainProb% (No Rain Estimated)'),
            color: isRainRisk ? const Color(0xFF2563EB) : const Color(0xFF64748B),
            bgColor: isRainRisk ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
            fullWidth: true,
          ),
          const SizedBox(height: 8),

          // Row 2: UV and Humidity
          Row(
            children: [
              Expanded(
                child: _buildWeatherMetricPill(
                  icon: Icons.wb_sunny_outlined,
                  label: 'UV: ${weather.uvIndex.toStringAsFixed(1)} (${weather.uvIndex >= 8.0 ? "Very High" : (weather.uvIndex >= 6.0 ? "High" : "Moderate")})',
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFFFBEB),
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildWeatherMetricPill(
                  icon: Icons.air_rounded,
                  label: '${weather.humidity}% Humidity',
                  color: const Color(0xFF475569),
                  bgColor: const Color(0xFFF1F5F9),
                  fullWidth: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Penny tip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, size: 15, color: Color(0xFFEAB308)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    adviceText,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11,
                      color: Color(0xFF475569),
                      height: 1.25,
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

  Widget _buildWeatherMetricPill({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            flex: fullWidth ? 1 : 0,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Itinerary Stops preview list when journey hasn't been started
  Widget _buildItineraryStopsPreview(SavedTripPlan plan) {
    if (plan.stops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.format_list_bulleted_rounded, size: 18, color: Color(0xFF304FFE)),
                SizedBox(width: 8),
                Text(
                  'Planned Itinerary Stops',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${plan.stops.length} Stops',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...plan.stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final stop = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF304FFE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.placeName,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            stop.area,
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            stop.timeSlot,
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (stop.pennyTip.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFEF3C7)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tips_and_updates_outlined, size: 13, color: Color(0xFFD97706)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  stop.pennyTip,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 11,
                                    color: Color(0xFF92400E),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Action Button: Begin Live Journey (Modern gradient styling & refined typography)
  Widget _buildBeginJourneyButton(SavedTripPlan plan, LiveJourneyService liveJourney) {
    final isActive = liveJourney.isJourneyActive;
    final isPaused = liveJourney.isPaused;

    // Elegant gradient matching tab aesthetic
    final gradientColors = isActive
        ? (isPaused
            ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
            : [const Color(0xFF0F172A), const Color(0xFF1E3A8A), const Color(0xFF2563EB)])
        : [
            const Color(0xFFFBBF24), // Vibrant Amber 400
            const Color(0xFFF59E0B), // Rich Amber 500
            const Color(0xFFD97706), // Warm Sunset Amber 600
          ];

    final textColor = isActive ? Colors.white : const Color(0xFF0F172A);

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                : const Color(0xFFFF9100).withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            if (!isActive) {
              await JourneyStartWorkflow.startJourneyFlow(context, plan);
            } else {
              liveJourney.togglePause();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Icon Badge
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isActive
                          ? (isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded)
                          : Icons.navigation_rounded,
                      color: textColor,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Button Title & Status
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isActive
                            ? (isPaused ? 'Journey Paused' : 'Live Journey Active')
                            : 'Begin Live Journey',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isActive
                            ? (isPaused ? 'Tap to resume simulation' : 'Syncing telemetry & live GPS')
                            : 'Sync stops to dashboard & track live GPS',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Right Indicator Pill / Arrow
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isActive
                            ? (isPaused ? 'RESUME' : 'LIVE')
                            : 'START',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isActive ? Icons.sync_rounded : Icons.arrow_forward_rounded,
                        color: textColor,
                        size: 13,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Live Location Activity component showing traveler telemetry, A-to-B route progress, live weather, and dynamic alerts
  Widget _buildLiveLocationActivity(SavedTripPlan plan, LiveJourneyService liveJourney) {
    final currentStop = liveJourney.currentStop;
    final isArrived = liveJourney.isArrived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Section Header Row (Overflow Protected)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isArrived ? Colors.greenAccent.shade700 : const Color(0xFFE11D48),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isArrived ? Colors.greenAccent : const Color(0xFFE11D48)).withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Live Location Activity',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF303030), // Colors.grey[850]
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 5,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: liveJourney.dashboardConnected
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    liveJourney.dashboardConnected ? '🛰️ Dashboard' : '🚗 GPS Active',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: liveJourney.dashboardConnected
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF304FFE),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: liveJourney.isWeatherFromDashboard
                        ? const Color(0xFFF3E8FF)
                        : const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: liveJourney.isWeatherFromDashboard
                          ? const Color(0xFFD8B4FE)
                          : const Color(0xFFBAE6FD),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    liveJourney.isWeatherFromDashboard ? '🛰️ Custom Weather' : '🌐 Open-Meteo',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: liveJourney.isWeatherFromDashboard
                          ? const Color(0xFF7E22CE)
                          : const Color(0xFF0369A1),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Live Real-Time Travel Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isArrived ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isArrived
                  ? Colors.green.shade400
                  : const Color(0xFFFB7185),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isArrived ? Colors.green : const Color(0xFFE11D48)).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge & Transit Mode Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isArrived ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isArrived
                                ? Icons.check_circle_rounded
                                : (liveJourney.travelMode == 'driving'
                                    ? Icons.directions_car_rounded
                                    : Icons.directions_walk_rounded),
                            size: 14,
                            color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isArrived
                                  ? 'ARRIVED & EXPLORING'
                                  : (liveJourney.travelMode == 'driving'
                                      ? 'IN TRANSIT · DRIVING (35 KM/H)'
                                      : 'IN TRANSIT · WALKING'),
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Stop ${liveJourney.currentStopIndex + 1} of ${plan.stops.length}',
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Destination Name
              Text(
                liveJourney.currentStopName,
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),

              // Row 1: Separate Area Row
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF757575)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Area: ${liveJourney.currentArea}',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12.5,
                        color: Color(0xFF616161),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 2: Separate Scheduled Time Row
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF757575)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Scheduled Time: ${currentStop?.timeSlot ?? "10:00 AM"}',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12.5,
                        color: Color(0xFF616161),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Row 3: Live Simulated Travel Time (Dashboard Synced) - Split into 2 rows
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF2563EB)),
                          SizedBox(width: 6),
                          Text(
                            'Simulated Time (Virtual Clock)',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 12,
                              color: Color(0xFF1D4ED8),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MOCK TIME',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(
                      liveJourney.virtualTimeString,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),

              // 🌤️ Expanded Weather Card (Full Details, No '...')
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: liveJourney.isRainyWeather
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: liveJourney.isRainyWeather
                        ? const Color(0xFF93C5FD)
                        : const Color(0xFFFDE68A),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      liveJourney.weatherCondition == 'rainy'
                          ? '🌧️'
                          : (liveJourney.weatherCondition == 'thunderstorm'
                              ? '⛈️'
                              : (liveJourney.weatherCondition == 'cloudy' ? '⛅' : '☀️')),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Weather: ${liveJourney.weatherCondition.toUpperCase()} ${liveJourney.weatherTemp.round()}°C · Rain ${liveJourney.rainRateMmHr.toStringAsFixed(1)} mm/hr · Humidity ${liveJourney.weatherHumidity}% · [${liveJourney.weatherSource}]',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: liveJourney.isRainyWeather
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF92400E),
                          height: 1.3,
                        ),
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: liveJourney.isWeatherFromDashboard
                              ? const Color(0xFFD8B4FE)
                              : const Color(0xFF93C5FD),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            liveJourney.isWeatherFromDashboard
                                ? Icons.tune_rounded
                                : Icons.cloud_outlined,
                            size: 10,
                            color: liveJourney.isWeatherFromDashboard
                                ? const Color(0xFF7E22CE)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            liveJourney.isWeatherFromDashboard ? 'DASHBOARD' : 'OPEN-METEO',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: liveJourney.isWeatherFromDashboard
                                  ? const Color(0xFF7E22CE)
                                  : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ⚠️ Live Incident & Traffic Alert Banner (If triggered in Dashboard)
              if (liveJourney.activeIncident != null && liveJourney.activeIncident!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Traffic & Incident Alert',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF991B1B),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEE2E2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF87171), width: 0.7),
                                  ),
                                  child: const Text(
                                    '30s Alert',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF991B1B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              liveJourney.activeIncident!,
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11,
                                color: Color(0xFF7F1D1D),
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => liveJourney.clearActiveIncident(),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 🔀 Scenario C: Off-Route / Impromptu Stop Self-Correction Banner
              if (liveJourney.isOffRoute) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF), // Soft Blue
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF60A5FA), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        blurRadius: 8,
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
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.explore_rounded, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Off-Course Impromptu Stop',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You deviated off planned route for an impromptu stop. Tap below to smoothly return to your plan.',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          color: Color(0xFF475569),
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B), // Rich Amber (GEMINI.md rule)
                            foregroundColor: Colors.black, // Black text
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.replay_rounded, size: 16, color: Colors.black),
                          label: const Text(
                            'Recalculate Route & Return to Plan',
                            style: TextStyle(
                              fontFamily: 'Roboto Mono', // GEMINI.md rule
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          onPressed: () async {
                            await liveJourney.recalculateReturnRouteFromCurrentLocation();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF1E293B),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                content: const Row(
                                  children: [
                                    Icon(Icons.navigation_rounded, color: Color(0xFFF59E0B)),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Return route recalculated from current GPS! Resuming journey.',
                                        style: TextStyle(fontFamily: 'SF Pro', color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ⛈️ Severe Weather Quick Access Pill (if user dismissed but weather is still severe)
              if ((liveJourney.isSevereWeather || liveJourney.rainRateMmHr > 7.6) && liveJourney.userDismissedSevereWeather) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    liveJourney.triggerSevereWeatherAlert(
                      rainRate: liveJourney.rainRateMmHr > 0 ? liveJourney.rainRateMmHr : 8.5,
                      temp: liveJourney.weatherTemp,
                      condition: liveJourney.weatherCondition,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.thunderstorm_rounded, color: Color(0xFFDC2626), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Heavy Rain (${liveJourney.rainRateMmHr.toStringAsFixed(1)} mm/hr) · Tap to view indoor shelters',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF991B1B), size: 16),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 🚗 Travel Progress Bar from Stop A to Stop B
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isArrived
                        ? Colors.green.shade200
                        : const Color(0xFFFECDD3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leg Distance in km above A and B (Big Font Size)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              (liveJourney.totalLegDistanceMeters / 1000.0).toStringAsFixed(2),
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'km',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isArrived ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isArrived ? Icons.check_circle_rounded : Icons.directions_car_rounded,
                                size: 12,
                                color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isArrived ? 'Arrived Destination' : 'Leg Transit Distance',
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Origin A to Destination B Stop Badges
                    Row(
                      children: [
                        // Stop A (Origin)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE0E7FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'A',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF304FFE),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'Origin',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                liveJourney.originStopName,
                                style: const TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Arrow separator
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                            size: 18,
                          ),
                        ),
                        // Stop B (Destination)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Destination',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: isArrived ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'B',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                liveJourney.targetStopName,
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isArrived ? const Color(0xFF16A34A) : const Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Travel Progress Track with Moving Vehicle Marker
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        final clampedProgress = liveJourney.progressPercentage.clamp(0.0, 1.0);
                        final markerLeft = (barWidth - 24) * clampedProgress;

                        return SizedBox(
                          height: 28,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Background track
                              Container(
                                height: 8,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Active fill
                              Container(
                                height: 8,
                                width: barWidth * clampedProgress,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isArrived
                                        ? [Colors.green, Colors.greenAccent.shade700]
                                        : [const Color(0xFFE11D48), const Color(0xFFFB7185)],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // Vehicle Icon moving along the track
                              Positioned(
                                left: markerLeft.clamp(0.0, barWidth - 24),
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isArrived ? Colors.green : const Color(0xFFE11D48),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isArrived ? Colors.green : const Color(0xFFE11D48)).withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isArrived
                                          ? Icons.check_rounded
                                          : (liveJourney.travelMode == 'driving'
                                              ? Icons.directions_car_rounded
                                              : Icons.directions_walk_rounded),
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 6),

                    // Live Travel Stats Row (% Traveled, Remaining Meters, ETA)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArrived
                              ? '✅ Arrived at Stop ${liveJourney.currentStopIndex + 1}'
                              : '${(liveJourney.progressPercentage * 100).toInt()}% Traveled',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              isArrived
                                  ? '0 m remaining'
                                  : '${liveJourney.remainingDistanceMeters.round()} m remaining',
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (!isArrived) ...[
                              const SizedBox(width: 6),
                              Text(
                                '· ${(liveJourney.remainingSeconds / 60).toStringAsFixed(1)} min',
                                style: const TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 11.5,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Telemetry Details (Live GPS & Mock Clock on 2 distinct rows)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isArrived
                        ? Colors.green.shade100
                        : const Color(0xFFFCE7F3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Row 1: Live GPS
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF475569)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Live GPS',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${liveJourney.currentLat.toStringAsFixed(5)}, ${liveJourney.currentLng.toStringAsFixed(5)}',
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, thickness: 0.8, color: Color(0xFFF1F5F9)),
                    ),
                    // Row 2: Mock Clock
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Mock Clock',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          liveJourney.virtualTimeString.contains(',')
                              ? liveJourney.virtualTimeString.split(',')[1].trim()
                              : liveJourney.virtualTimeString,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Clean Next Stop Action Button (When arrived and has upcoming stops)
              if (isArrived && liveJourney.currentStopIndex < plan.stops.length - 1) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => liveJourney.advanceToNextStop(),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                    label: Text(
                      'Depart to Stop ${liveJourney.currentStopIndex + 2}: ${plan.stops[liveJourney.currentStopIndex + 1].placeName}',
                      style: const TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],

              // End Trip Plan Action Button (When arrived at the LAST stop)
              if (isArrived && liveJourney.currentStopIndex >= plan.stops.length - 1) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
                      foregroundColor: Colors.black,
                      elevation: 2,
                      shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _handleEndTripPlan(context, liveJourney, plan),
                    icon: const Icon(Icons.flag_rounded, size: 20, color: Colors.black),
                    label: const Text(
                      '🏁 End Trip Plan',
                      style: TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Timeline of Itinerary Stops
        const Text(
          'Journey Timeline Stops',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303030),
          ),
        ),
        const SizedBox(height: 10),
        ...plan.stops.asMap().entries.map((entry) {
          final idx = entry.key;
          final stop = entry.value;
          final isPast = idx < liveJourney.currentStopIndex;
          final isCurrent = idx == liveJourney.currentStopIndex;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrent
                  ? (isArrived ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2))
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? (isArrived ? Colors.green.shade400 : const Color(0xFFFB7185))
                    : Colors.grey.withValues(alpha: 0.15),
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.green.shade100
                            : (isCurrent
                                ? (isArrived ? Colors.greenAccent.shade700 : const Color(0xFFE11D48))
                                : Colors.grey.shade100),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isPast
                            ? const Icon(Icons.check_rounded, color: Colors.green, size: 18)
                            : Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent ? Colors.white : Colors.grey.shade700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.placeName,
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 13.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF303030),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${stop.area} · ${stop.timeSlot}',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPast
                            ? Colors.grey.shade100
                            : (isCurrent
                                ? (isArrived ? const Color(0xFFDCFCE7) : const Color(0xFFFFE4E6))
                                : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPast
                            ? 'Completed'
                            : (isCurrent ? (isArrived ? 'Arrived' : 'In Transit') : 'Waiting'),
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isPast
                              ? Colors.grey
                              : (isCurrent
                                  ? (isArrived ? const Color(0xFF16A34A) : const Color(0xFFE11D48))
                                  : Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isPast || (isCurrent && isArrived)) ...[
                  Builder(
                    builder: (context) {
                      final depRecord = liveJourney.getDepartureRecordForStop(idx);
                      final arrRecord = liveJourney.getArrivalRecordForStop(idx);
                      if (depRecord == null && arrRecord == null) return const SizedBox.shrink();

                      final badges = <Widget>[];

                      // 1. Arrived Time Badge
                      if (arrRecord?.actualArriveTime != null) {
                        final arriveDiff = arrRecord!.arriveVarianceMinutes ?? 0;
                        final isArrLate = arriveDiff > 0;
                        final isArrOnTime = arriveDiff == 0;
                        final arrColor = isArrOnTime
                            ? const Color(0xFF16A34A)
                            : (isArrLate ? const Color(0xFFD97706) : const Color(0xFF2563EB));
                        final arrBg = isArrOnTime
                            ? const Color(0xFFDCFCE7)
                            : (isArrLate ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE));
                        final aTimeStr = LiveJourneyService.formatVirtualClock(arrRecord.actualArriveTime!);
                        final aDispTime = aTimeStr.contains(',') ? aTimeStr.split(',').last.trim() : aTimeStr;
                        // Clean time string without seconds e.g. "06:56 PM"
                        final cleanArriveTime = aDispTime.replaceAll(RegExp(r':\d{2}(?=\s*[AP]M)'), '');
                        final aSummary = arrRecord.arriveVarianceSummary ??
                            (isArrOnTime ? 'On Schedule' : (isArrLate ? '+$arriveDiff min Late' : '${arriveDiff.abs()} min Early'));

                        badges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: arrBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isArrOnTime
                                    ? Icons.check_circle_outline_rounded
                                    : (isArrLate ? Icons.timer_outlined : Icons.speed_rounded),
                                size: 10,
                                color: arrColor,
                              ),
                              const SizedBox(width: 3.5),
                              Flexible(
                                child: Text(
                                  'Arrived $cleanArriveTime ($aSummary)',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 9.5, // Scaled down to prevent pixel overflow
                                    fontWeight: FontWeight.bold,
                                    color: arrColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ));
                      }

                      // 2. Departed Time Badge
                      if (depRecord != null) {
                        final isLate = depRecord.varianceMinutes > 0;
                        final isOnTime = depRecord.varianceMinutes == 0;
                        final tagColor = isOnTime
                            ? const Color(0xFF16A34A)
                            : (isLate ? const Color(0xFFD97706) : const Color(0xFF2563EB));
                        final tagBg = isOnTime
                            ? const Color(0xFFDCFCE7)
                            : (isLate ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE));
                        final timeStr = LiveJourneyService.formatVirtualClock(depRecord.actualDepartTime);
                        final dispTime = timeStr.contains(',') ? timeStr.split(',').last.trim() : timeStr;
                        // Clean time string without seconds e.g. "07:43 PM"
                        final cleanDepartTime = dispTime.replaceAll(RegExp(r':\d{2}(?=\s*[AP]M)'), '');

                        badges.add(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOnTime
                                    ? Icons.flight_takeoff_rounded
                                    : (isLate ? Icons.timer_outlined : Icons.speed_rounded),
                                size: 10,
                                color: tagColor,
                              ),
                              const SizedBox(width: 3.5),
                              Flexible(
                                child: Text(
                                  'Departed $cleanDepartTime (${depRecord.varianceSummary})',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 9.5, // Scaled down to prevent pixel overflow
                                    fontWeight: FontWeight.bold,
                                    color: tagColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ));
                      }

                      // 3. Actual Stay Duration separated into 2 dedicated rows
                      final currentPendingOverstay = (isArrived && isCurrent)
                          ? max(liveJourney.pendingStopOverstayMinutes,
                              LiveJourneyService.extractOverstayMinutes(liveJourney.activeIncident))
                          : 0;
                      final overstay = depRecord != null ? depRecord.overstayMinutes : currentPendingOverstay;
                      final plannedStay = depRecord?.plannedStayMinutes ??
                          (isArrived && isCurrent ? LiveJourneyService.parseStayMinutes(stop.stayDuration) : 0);
                      final stayMins = depRecord?.actualStayMinutes ??
                          (isArrived && isCurrent ? (plannedStay + overstay) : 0);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (badges.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 38),
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: badges,
                              ),
                            ),
                          if (stayMins > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 6, left: 38),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        overstay > 0 ? Icons.warning_amber_rounded : Icons.hourglass_bottom_rounded,
                                        size: 13,
                                        color: overstay > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Actual Stay Duration',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      if (overstay > 0) ...[
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '+${overstay}m Overstay',
                                            style: const TextStyle(
                                              fontFamily: 'SF Pro',
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFD97706),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 19),
                                    child: Text(
                                      overstay > 0
                                          ? '$stayMins min (${plannedStay}m planned + ${overstay}m overstay)'
                                          : '$stayMins min (As planned)',
                                      style: TextStyle(
                                        fontFamily: 'SF Pro',
                                        fontSize: 13.5, // Standardized bigger font size
                                        fontWeight: FontWeight.bold,
                                        color: overstay > 0 ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  /// Handles user tapping "End Trip Plan" at the last stop
  Future<void> _handleEndTripPlan(
    BuildContext context,
    LiveJourneyService liveJourney,
    SavedTripPlan plan,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF1D4ED8), strokeWidth: 3),
              SizedBox(height: 18),
              Text(
                'Generating Trip Summary...',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Drawing road travel path & saving to trail history',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      await liveJourney.endAndCompleteTrip();
    } finally {
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
    if (mounted) setState(() {});
  }

  /// View displayed on StoryTabScreen when a trip is completed
  Widget _buildCompletedTripSummaryView(
    BuildContext context,
    LiveJourneyService liveJourney,
    CompletedTripSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top of Screen: Glowing Light Blue Car Path Map (Interactive pinch-to-zoom enabled)
        TripRouteSummaryMap(
          routeCoordinates: summary.routeCoordinates,
          stops: summary.stops,
          totalDistanceKm: summary.totalDistanceKm,
          height: 290,
          showOverlays: true,
          isInteractive: true,
        ),
        const SizedBox(height: 18),

        // 2. Journey Celebration Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF0F172A), // Deep Slate Navy
                Color(0xFF1E3A8A), // Royal Blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B), // Rich Amber Accent
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.emoji_events_rounded, size: 14, color: Colors.black),
                        SizedBox(width: 4),
                        Text(
                          'Trail Completed',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    summary.travelDateRange,
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                summary.planTitle,
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All ${summary.stops.length} itinerary destinations successfully visited across Penang.',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),

              // 4 Stat Badges Grid
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryStatItem(
                      icon: Icons.place_rounded,
                      label: 'Stops',
                      value: '${summary.stops.length} Visited',
                      iconColor: const Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryStatItem(
                      icon: Icons.directions_car_rounded,
                      label: 'Distance',
                      value: '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                      iconColor: const Color(0xFF4ADE80),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryStatItem(
                      icon: Icons.access_time_rounded,
                      label: 'Duration',
                      value: summary.totalDurationStr,
                      iconColor: const Color(0xFFFACC15),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryStatItem(
                      icon: Icons.hourglass_top_rounded,
                      label: 'Overstay',
                      value: summary.totalOverstayMinutes > 0
                          ? '+${summary.totalOverstayMinutes}m Wait'
                          : 'On Schedule',
                      iconColor: summary.totalOverstayMinutes > 0
                          ? const Color(0xFFFB923C)
                          : const Color(0xFF34D399),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 3. Completed Stops Timeline Breakdown
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Completed Stops Breakdown',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${summary.stops.length}/${summary.stops.length} Visited',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF16A34A),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stop List: Only green tick and place name
        ...summary.stops.map((stop) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop.placeName,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 18),

        // 4. Action Buttons: View in Travel History & Plan Another Trip
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
              foregroundColor: Colors.black,
              elevation: 2,
              shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TravelPlansScreen()),
              );
            },
            icon: const Icon(Icons.history_edu_rounded, size: 20, color: Colors.black),
            label: const Text(
              'View in Travel History',
              style: TextStyle(
                fontFamily: 'Roboto Mono',
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E293B),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await liveJourney.resetCompletedTrip();
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Plan Another Trip / Back to Itinerary',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildSummaryStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDateInfo {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? daysUntil;
  final String headlineText;
  final String countdownBadgeText;
  final String displayDateRange;

  _PlanDateInfo({
    required this.startDate,
    required this.endDate,
    required this.daysUntil,
    required this.headlineText,
    required this.countdownBadgeText,
    required this.displayDateRange,
  });
}

