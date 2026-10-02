import 'package:flutter/material.dart';
import '../theme.dart';

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
            fontSize: 20, // Clean App Bar size
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemCount: _plans.length,
        itemBuilder: (context, index) {
          final plan = _plans[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
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
                          fontSize: 16, // Spec Normal/Label: 16-18px
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDarkNavy,
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
                    fontSize: 12, // Spec Body/Desc: 12px
                    color: AppColors.textGrey,
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
                                color: AppColors.secondaryRoyalBlue.withOpacity(0.3),
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
                                fontSize: 12, // Spec Body/Desc: 12px
                                color: AppColors.textDark,
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
        },
      ),
    );
  }
}
