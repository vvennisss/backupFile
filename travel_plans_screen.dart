import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/saved_trip_plans_manager.dart';
import 'saved_trip_plans_screen.dart';

class TravelPlanRoute {
  final String title;
  final String date;
  final double distance; // in km
  final String duration;
  final List<String> stops;

  TravelPlanRoute({
    required this.title,
    required this.date,
    required this.distance,
    required this.duration,
    required this.stops,
  });
}

class TravelPlansScreen extends StatelessWidget {
  TravelPlansScreen({super.key});

  final List<TravelPlanRoute> _plans = [
    TravelPlanRoute(
      title: 'George Town Street Art Hunt',
      date: 'Aug 10, 2026',
      distance: 5.8,
      duration: '2.5 hrs',
      stops: ['Armenian Street Mural', 'Chew Jetty', 'Khoo Kongsi'],
    ),
    TravelPlanRoute(
      title: 'Penang Hill & Kek Lok Si Temple Tour',
      date: 'July 24, 2026',
      distance: 14.2,
      duration: '6.0 hrs',
      stops: ['Ayer Itam Laksa', 'Kek Lok Si Temple', 'Penang Hill Funicular'],
    ),
    TravelPlanRoute(
      title: 'Batu Ferringhi Coastline Walk',
      date: 'June 18, 2026',
      distance: 8.5,
      duration: '3.0 hrs',
      stops: ['Batu Ferringhi Beach', 'Penang National Park', 'Monkey Beach'],
    ),
    TravelPlanRoute(
      title: 'Balik Pulau Food & Heritage Ride',
      date: 'May 02, 2026',
      distance: 22.0,
      duration: '4.5 hrs',
      stops: ['Saei Lemoi Paddy Fields', 'Audi Dream Farm', 'Balik Pulau Town Center'],
    ),
  ];

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
          final expiredPlans = allSavedPlans.where((p) => SavedTripPlansManager.isPlanExpired(p)).toList();

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // 1. COMPLETED SAVED TRIP PLANS (Expired scheduled plans kept in history)
              if (expiredPlans.isNotEmpty) ...[
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
                const SizedBox(height: 16),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 8),
              ],

              // 2. COMPLETED WALKING / EXPLORATION TRAILS
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
                      '${_plans.length} Trails',
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
              const SizedBox(height: 14),
              ..._plans.map((route) => _buildRouteCard(route)),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
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
  Widget _buildRouteCard(TravelPlanRoute plan) {
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
        border: Border.all(color: const Color(0xFFF1F7FA), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              const Icon(
                Icons.map_outlined,
                color: AppColors.secondaryRoyalBlue,
                size: 20,
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
}
