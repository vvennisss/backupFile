import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_trip_plans_manager.dart';
import '../models/completed_trip_summary.dart';
import '../services/completed_trails_manager.dart';
import '../widgets/trip_route_summary_map.dart';
import '../services/trail_share_service.dart';
import '../services/route_polyline_service.dart';
import 'saved_trip_plans_screen.dart';

enum TravelHistoryFilter {
  completedTrails,
  pastScheduledItineraries,
}

class TravelPlansScreen extends StatefulWidget {
  const TravelPlansScreen({super.key});

  @override
  State<TravelPlansScreen> createState() => _TravelPlansScreenState();
}

class _TravelPlansScreenState extends State<TravelPlansScreen> {
  TravelHistoryFilter _selectedFilter = TravelHistoryFilter.completedTrails;
  bool _isFilterMenuOpen = false;

  final List<TravelPlanRoute> _plans = kDefaultHistoryTrails;

  @override
  Widget build(BuildContext context) {
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
          'Travel History',
          style: TextStyle(
            color: Color(0xFF303030), // Colors.grey[850]
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<SavedTripPlan>>(
        valueListenable: SavedTripPlansManager.savedPlansNotifier,
        builder: (context, allSavedPlans, _) {
          final expiredPlans = allSavedPlans
              .where((p) => SavedTripPlansManager.isPlanExpired(p) && !SavedTripPlansManager.isPlanCompleted(p))
              .toList();

          return ValueListenableBuilder<List<TravelPlanRoute>>(
            valueListenable: CompletedTrailsManager.completedTrailsNotifier,
            builder: (context, userCompletedTrails, _) {
              final allTrails = [...userCompletedTrails, ..._plans];

              return ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Collapse Filter Selector (Default: Completed Trail Routes)
                  _buildCollapseFilter(allTrails.length, expiredPlans.length),
                  const SizedBox(height: 16),

                  // 2. Display ONLY the selected filter ("not allow to show both")
                  if (_selectedFilter == TravelHistoryFilter.completedTrails) ...[
                    _buildCompletedTrailsSection(context, allTrails),
                  ] else ...[
                    _buildPastScheduledItinerariesSection(context, expiredPlans),
                  ],

                  const SizedBox(height: 40),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Collapsible Filter Bar with animated dropdown menu
  Widget _buildCollapseFilter(int completedCount, int scheduledCount) {
    final isCompleted = _selectedFilter == TravelHistoryFilter.completedTrails;
    final activeTitle = isCompleted ? 'Completed Trail Routes' : 'Past Scheduled Itineraries';
    final activeCount = isCompleted ? '$completedCount Trails' : '$scheduledCount Archived';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isFilterMenuOpen ? const Color(0xFF38BDF8) : const Color(0xFFE2E8F0),
          width: _isFilterMenuOpen ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main clickable filter header
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _isFilterMenuOpen = !_isFilterMenuOpen;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCompleted ? Icons.route_rounded : Icons.calendar_month_rounded,
                      size: 18,
                      color: isCompleted ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FILTER VIEW',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeTitle,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      activeCount,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _isFilterMenuOpen ? 0.5 : 0.0,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dropdown options revealed when user taps collapse menu
          if (_isFilterMenuOpen) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            _buildFilterMenuItem(
              title: 'Completed Trail Routes',
              subtitle: 'Finished trips & walking trails with car path',
              count: '$completedCount Trails',
              icon: Icons.route_rounded,
              isSelected: isCompleted,
              onTap: () {
                setState(() {
                  _selectedFilter = TravelHistoryFilter.completedTrails;
                  _isFilterMenuOpen = false;
                });
              },
            ),
            const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 56),
            _buildFilterMenuItem(
              title: 'Past Scheduled Itineraries',
              subtitle: 'Trip plans whose scheduled dates have concluded',
              count: '$scheduledCount Archived',
              icon: Icons.calendar_month_rounded,
              isSelected: !isCompleted,
              onTap: () {
                setState(() {
                  _selectedFilter = TravelHistoryFilter.pastScheduledItineraries;
                  _isFilterMenuOpen = false;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterMenuItem({
    required String title,
    required String subtitle,
    required String count,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                const Icon(Icons.check_rounded, color: Color(0xFF1D4ED8), size: 18)
              else
                Text(
                  count,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section displaying Completed Trail Routes
  Widget _buildCompletedTrailsSection(BuildContext context, List<TravelPlanRoute> allTrails) {
    if (allTrails.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.route_outlined, size: 44, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No Completed Trails Yet',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'End an active itinerary to see your finished trip with curved car driving path here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Completed Trail Routes',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${allTrails.length} Trails',
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
        const SizedBox(height: 4),
        const Text(
          'Completed trails with recorded journeys. Tap the pathline icon to view curved car path.',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        ...allTrails.map((route) => _buildRouteCard(context, route)),
      ],
    );
  }

  /// Section displaying Past Scheduled Itineraries
  Widget _buildPastScheduledItinerariesSection(BuildContext context, List<SavedTripPlan> expiredPlans) {
    if (expiredPlans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(
          children: [
            Icon(Icons.calendar_today_outlined, size: 44, color: Color(0xFF94A3B8)),
            SizedBox(height: 12),
            Text(
              'No Past Scheduled Itineraries',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'All your planned trip itineraries are upcoming or active.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Past Scheduled Itineraries',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${expiredPlans.length} Archived',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Trip plans whose scheduled dates have concluded are kept in your history.',
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 12,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 14),
        ...expiredPlans.map((plan) => _buildExpiredPlanCard(context, plan)),
      ],
    );
  }

  /// Card displaying an expired / completed saved trip plan with visited stops and view details CTA
  Widget _buildExpiredPlanCard(BuildContext context, SavedTripPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.cleanTitle,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF64748B)),
              const SizedBox(width: 5),
              Text(
                'Date: ${plan.travelDateRange}',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: Color(0xFF1D4ED8), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '${plan.stops.length} Stops',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.displayArea,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFF1F5F9)),
          const Text(
            'Visited Stops:',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(plan.stops.length, (idx) {
              final isLast = idx == plan.stops.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: const BoxDecoration(
                          color: Color(0xFF2563EB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1.5,
                          height: 18,
                          color: const Color(0xFFBFDBFE),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                      child: Text(
                        plan.stops[idx].placeName,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 14),
          // View Details Button with Blue Gradient
          Container(
            width: double.infinity,
            height: 38,
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
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SavedPlanDetailScreen(plan: plan),
                    ),
                  );
                },
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_rounded, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'View Saved Details',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card displaying a predefined walking / travel trail route
  Widget _buildRouteCard(BuildContext context, TravelPlanRoute plan) {
    final hasCarPath = plan.routePoints != null && plan.routePoints!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasCarPath ? const Color(0xFFBAE6FD) : const Color(0xFFF1F7FA),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkNavy,
                    fontFamily: 'SF Pro',
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _showCurvedCarPathPopout(context, plan),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A), // Dark slate navy
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.7), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.polyline_rounded, // Pathline icon
                              color: Color(0xFF00E5FF),
                              size: 15,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Path',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Date: ${plan.date}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: AppColors.secondaryRoyalBlue, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${plan.distance} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryRoyalBlue,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.secondaryRoyalBlue, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      plan.duration,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryRoyalBlue,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plan.stampsEarned != null && plan.stampsEarned!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: Color(0xFFD97706), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${plan.stampsEarned!.length} Stamp${plan.stampsEarned!.length > 1 ? "s" : ""} Collected',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF92400E),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24, color: Colors.black12),
          const Text(
            'Visited Stops:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkNavy,
              fontFamily: 'SF Pro',
            ),
          ),
          const SizedBox(height: 8),
          Column(
            children: List.generate(plan.stops.length, (idx) {
              final isLast = idx == plan.stops.length - 1;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.secondaryRoyalBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1.5,
                          height: 20,
                          color: AppColors.secondaryRoyalBlue.withValues(alpha: 0.3),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                      child: Text(
                        plan.stops[idx],
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDark,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  /// Open Pop-out Window displaying the curved car driving path map with Save Image & Social Media Export capabilities
  void _showCurvedCarPathPopout(BuildContext context, TravelPlanRoute plan) async {
    List<Map<String, double>> routeCoords = plan.routePoints ?? [];
    final resolvedStops = plan.getResolvedStops();

    // If car path coordinates not yet generated, dynamically fetch realistic driving road polyline
    if (routeCoords.isEmpty) {
      final stopCoords = resolvedStops.map((s) => {'lat': s.lat, 'lng': s.lng}).toList();
      routeCoords = await RoutePolylineService.fetchDrivingCarPath(stops: stopCoords);
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _CurvedCarPathPopoutDialog(
        plan: plan,
        routeCoordinates: routeCoords,
        resolvedStops: resolvedStops,
      ),
    );
  }
}

/// Popout dialog displaying the curved car path map with options to save as image to phone and export to social media
class _CurvedCarPathPopoutDialog extends StatefulWidget {
  final TravelPlanRoute plan;
  final List<Map<String, double>> routeCoordinates;
  final List<SavedPlanStop> resolvedStops;

  const _CurvedCarPathPopoutDialog({
    required this.plan,
    required this.routeCoordinates,
    required this.resolvedStops,
  });

  @override
  State<_CurvedCarPathPopoutDialog> createState() => _CurvedCarPathPopoutDialogState();
}

class _CurvedCarPathPopoutDialogState extends State<_CurvedCarPathPopoutDialog> {
  final GlobalKey _captureCardKey = GlobalKey();
  bool _isSaving = false;
  bool _isExporting = false;
  String? _successMessage;

  Future<void> _handleSaveImage() async {
    if (_isSaving || _isExporting) return;
    setState(() {
      _isSaving = true;
      _successMessage = null;
    });

    try {
      final pngBytes = await TrailShareService.captureWidgetToPng(_captureCardKey, pixelRatio: 3.0);
      if (pngBytes == null) {
        throw Exception('Failed to capture high-definition trail snapshot');
      }

      final savedPath = await TrailShareService.saveTrailImageToPhone(
        pngBytes: pngBytes,
        trailTitle: widget.plan.title,
      );

      if (savedPath == null) {
        throw Exception('Could not save image to phone. Please check storage permissions.');
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
          _successMessage = 'Saved to Phone Gallery successfully! 📸';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Trail path saved to Phone Gallery!\n$savedPath',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontFamily: 'SF Pro'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleExportSocialMedia() async {
    if (_isSaving || _isExporting) return;
    setState(() {
      _isExporting = true;
      _successMessage = null;
    });

    try {
      final pngBytes = await TrailShareService.captureWidgetToPng(_captureCardKey, pixelRatio: 3.0);
      if (pngBytes == null) {
        throw Exception('Failed to capture trail snapshot');
      }

      await TrailShareService.exportTrailToSocialMedia(
        pngBytes: pngBytes,
        plan: widget.plan,
      );

      if (mounted) {
        setState(() {
          _isExporting = false;
          _successMessage = 'Opened social media export sheet!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: const Color(0xFF070D1E), // Deep navy background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Popout Header (Outside RepaintBoundary so close button is not captured)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                      ),
                      child: const Icon(Icons.polyline_rounded, color: Color(0xFF00E5FF), size: 18),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // 2. The Capture Card (RepaintBoundary for saving to phone & exporting to social media)
              RepaintBoundary(
                key: _captureCardKey,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B132B), // Deep Slate Navy Poster Background
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row: App Branding & Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(Icons.explore_rounded, size: 14, color: Colors.black),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Kia Kia Penang · Trail Route',
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF38BDF8),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.plan.date,
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Trail Title
                      Text(
                        widget.plan.title,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Badge Row: Red frame badge moved here (X Stops · Y km)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.place_rounded, color: Color(0xFF00E5FF), size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.resolvedStops.length} Stops · ${widget.plan.distance} km',
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00E5FF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Curved Car Path Map Canvas (Clean export view without badges, static for snapshot)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: TripRouteSummaryMap(
                          routeCoordinates: widget.routeCoordinates,
                          stops: widget.resolvedStops,
                          totalDistanceKm: widget.plan.distance,
                          height: 270,
                          showOverlays: false,
                          isInteractive: false, // Cannot pinch to zoom in export popout dialog!
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Visited Stops Breakdown
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Completed Stops Visited',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...widget.plan.stops.asMap().entries.map((e) {
                              final idx = e.key;
                              final name = e.value;
                              return Padding(
                                padding: EdgeInsets.only(bottom: idx == widget.plan.stops.length - 1 ? 0 : 6),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16A34A),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.check_rounded, color: Colors.white, size: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Poster Tagline
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome, size: 12, color: const Color(0xFFF59E0B).withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(
                            'Kia Kia Penang · Memories Made in Penang 🌸',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 10,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Success Message Banner if available
              if (_successMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF064E3B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 3. Action Buttons: Save Image to Phone & Export to Social Media
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Row(
                  children: [
                    // Button 1: Save Image to Phone (Rich Amber, black text, Roboto Mono)
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber
                            foregroundColor: Colors.black,
                            elevation: 2,
                            shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: _isSaving ? null : _handleSaveImage,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                )
                              : const Icon(Icons.download_rounded, size: 18, color: Colors.black),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save Image',
                            style: const TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Button 2: Export to Social Media (Indigo Accent, white text, Roboto Mono)
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF304FFE), // Indigo Accent
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: const Color(0xFF304FFE).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: _isExporting ? null : _handleExportSocialMedia,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.share_rounded, size: 18, color: Colors.white),
                          label: Text(
                            _isExporting ? 'Exporting...' : 'Export Social',
                            style: const TextStyle(
                              fontFamily: 'Roboto Mono',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
