import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_trip_plans_manager.dart';

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
  @override
  void initState() {
    super.initState();
    // Load local cache and sync with Firestore for up-to-date saved trip plans
    SavedTripPlansManager.init();
    SavedTripPlansManager.syncWithFirestore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
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
                      // BLUE GRADIENT BANNER FOR THE MOST UPCOMING PLAN
                      _buildUpcomingPlanBanner(upcomingPlan, dateInfo),
                      const SizedBox(height: 24),

                      // If there are other plans, list them cleanly below
                      if (plans.length > 1) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Other Saved Plans',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF303030), // Colors.grey[850]
                              ),
                            ),
                            Text(
                              '${plans.length} Total Plans',
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...plans
                            .where((p) => p.id != upcomingPlan.id)
                            .map((p) => _buildSecondaryPlanCard(p)),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
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

  /// Secondary Plan Card when multiple saved plans exist
  Widget _buildSecondaryPlanCard(SavedTripPlan plan) {
    final dateInfo = _parsePlanDates(plan);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan.cleanTitle,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dateInfo.countdownBadgeText,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 11,
                    color: Color(0xFF304FFE),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 5),
              Text(
                dateInfo.displayDateRange,
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.place_rounded, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 4),
              Text(
                '${plan.stops.length} stops',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 13, color: AppColors.textGrey),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  plan.displayArea,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
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
