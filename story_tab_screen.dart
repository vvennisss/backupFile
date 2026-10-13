import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_trip_plans_manager.dart';
import '../services/live_journey_service.dart';
import '../widgets/companion/penny_place_chat_sheet.dart';

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

  @override
  void initState() {
    super.initState();
    // Load local cache and sync with Firestore for up-to-date saved trip plans
    SavedTripPlansManager.init();
    SavedTripPlansManager.syncWithFirestore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LiveJourneyService.instance,
      builder: (context, _) {
        final liveJourney = LiveJourneyService.instance;

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
                  const SizedBox(height: 18),

                  // 2. SAVED PLANS CONTENT & UPCOMING BANNER
                  ValueListenableBuilder<List<SavedTripPlan>>(
                    valueListenable: SavedTripPlansManager.savedPlansNotifier,
                    builder: (context, plans, _) {
                      if (plans.isEmpty) {
                        return _buildEmptyStateBanner();
                      }

                      // Find the most upcoming plan
                      final upcomingPlan = _findMostUpcomingPlan(plans);
                      final dateInfo = _parsePlanDates(upcomingPlan);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Blue card for the most upcoming itinerary
                          _buildUpcomingPlanBanner(upcomingPlan, dateInfo),
                          const SizedBox(height: 16),

                          // Action Button: Begin Live Journey
                          _buildBeginJourneyButton(upcomingPlan, liveJourney),

                          // Live Location Activity section (scroll down to view)
                          if (liveJourney.isJourneyActive) ...[
                            const SizedBox(height: 24),
                            _buildLiveLocationActivity(upcomingPlan, liveJourney),
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

  /// Blue Gradient Banner for the Most Upcoming Saved Plan
  Widget _buildUpcomingPlanBanner(SavedTripPlan plan, _PlanDateInfo dateInfo) {
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
          // Row 1: Tag & Countdown Pill
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
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flight_takeoff_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'UPCOMING TRIP',
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
          const SizedBox(height: 16),

          // Friendly Mascot Travel Tip Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tips_and_updates_rounded,
                  color: Color(0xFFFFD54F),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plan.pennyOverviewMessage.isNotEmpty
                        ? plan.pennyOverviewMessage
                        : 'Get ready for delicious street food, heritage streets, and scenic views!',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  /// Algorithm to pick the most upcoming plan:
  /// Prioritizes future plans sorted by earliest start date,
  /// then ongoing plans, then most recently saved plan.
  SavedTripPlan _findMostUpcomingPlan(List<SavedTripPlan> plans) {
    if (plans.length == 1) return plans.first;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    SavedTripPlan? closestFuturePlan;
    int minDaysToStart = 999999;

    SavedTripPlan? ongoingPlan;

    for (final plan in plans) {
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
  _PlanDateInfo _parsePlanDates(SavedTripPlan plan) {
    final raw = plan.travelDateRange.trim();
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

    // Regex match "YYYY-MM-DD"
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
            const Color(0xFFFFEA00), // Vibrant Sunshine Yellow
            const Color(0xFFFFC400), // Amber Gold
            const Color(0xFFFF9100), // Warm Sunset Amber
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
              await liveJourney.startJourney(plan);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E3A8A),
                    content: Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: Color(0xFFFFEA00), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Live journey started! Synced ${plan.stops.length} stops to dashboard.',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                // Scroll down smoothly to show Live Location Activity
                _scrollController.animateTo(
                  360.0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
              }
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
                      color: Colors.greenAccent.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.greenAccent.withValues(alpha: 0.6),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: liveJourney.dashboardConnected
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                liveJourney.dashboardConnected ? '🛰️ Dashboard Synced' : '🚗 GPS Active',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: liveJourney.dashboardConnected
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF304FFE),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 2. Live Real-Time Travel Status Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isArrived
                  ? Colors.green.withValues(alpha: 0.4)
                  : const Color(0xFF304FFE).withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                        color: isArrived ? const Color(0xFFE8F5E9) : const Color(0xFFEEF2FF),
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
                            color: isArrived ? const Color(0xFF2E7D32) : const Color(0xFF304FFE),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              isArrived
                                  ? 'ARRIVED & EXPLORING'
                                  : (liveJourney.travelMode == 'driving'
                                      ? 'DRIVING BY CAR (35 KM/H)'
                                      : 'WALKING (4.5 KM/H)'),
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isArrived ? const Color(0xFF2E7D32) : const Color(0xFF304FFE),
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
                        'Weather: ${liveJourney.weatherCondition.toUpperCase()} ${liveJourney.weatherTemp.round()}°C · Humidity ${liveJourney.weatherHumidity}% · Location: ${liveJourney.weatherLocation}',
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
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
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
                            const Text(
                              'Traffic & Incident Alert',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
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
                        onTap: () => liveJourney.injectIncident('rain_cleared'),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF991B1B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // 🚗 Travel Progress Bar from Stop A to Stop B
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                            color: isArrived ? Colors.green : const Color(0xFF304FFE),
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
                                        : [const Color(0xFF304FFE), const Color(0xFF6366F1)],
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
                                    color: isArrived ? Colors.green : const Color(0xFF304FFE),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: (isArrived ? Colors.green : const Color(0xFF304FFE)).withValues(alpha: 0.35),
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
                            color: isArrived ? const Color(0xFF16A34A) : const Color(0xFF304FFE),
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

              // Telemetry Grid (Remaining Meters & Live GPS)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Remaining',
                            style: TextStyle(fontFamily: 'SF Pro', fontSize: 10.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArrived ? '0 m' : '${liveJourney.remainingDistanceMeters.round()} m',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: Colors.grey.shade300),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live GPS (Synced)',
                            style: TextStyle(fontFamily: 'SF Pro', fontSize: 10.5, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${liveJourney.currentLat.toStringAsFixed(4)}, ${liveJourney.currentLng.toStringAsFixed(4)}',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
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

              // Clean Next Stop Action Button (When arrived and has upcoming stops)
              if (isArrived && liveJourney.currentStopIndex < plan.stops.length - 1) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEA00), // Colors.yellowAccent[400]
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => liveJourney.advanceToNextStop(),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: Text(
                      'Depart to Stop ${liveJourney.currentStopIndex + 2}: ${plan.stops[liveJourney.currentStopIndex + 1].placeName}',
                      style: const TextStyle(
                        fontFamily: 'Roboto Mono',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
              color: isCurrent ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isCurrent
                    ? Colors.green.shade400
                    : Colors.grey.withValues(alpha: 0.15),
                width: isCurrent ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isPast
                        ? Colors.green.shade100
                        : (isCurrent ? Colors.greenAccent.shade700 : Colors.grey.shade100),
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
                const SizedBox(width: 12),
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
                            ? (isArrived ? const Color(0xFFE8F5E9) : const Color(0xFFEEF2FF))
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
                              ? (isArrived ? Colors.green.shade700 : const Color(0xFF304FFE))
                              : Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
