import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../theme.dart';
import '../controllers/trip_controller.dart';
import '../services/saved_trip_plans_manager.dart';
import '../services/weather_service.dart';
import '../widgets/app_image_widget.dart';
import 'map_screen.dart';

/// Screen displaying the list of saved trip plans.
/// Each plan appears as an interactive button/card showing the travel schedule and travel area,
/// preventing direct opening of the detailed plan view when multiple plans exist.
class SavedTripPlansScreen extends StatefulWidget {
  const SavedTripPlansScreen({super.key});

  @override
  State<SavedTripPlansScreen> createState() => _SavedTripPlansScreenState();

  /// Dialog allowing the user to rename their saved plan.
  static Future<void> showEditTitleDialog(BuildContext context, SavedTripPlan plan) async {
    final controller = TextEditingController(text: plan.cleanTitle);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: Color(0xFF304FFE), size: 20),
              SizedBox(width: 8),
              Text(
                'Edit Plan Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Give your Penang trip plan a custom name:',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontFamily: 'SF Pro',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: InputDecoration(
                  hintText: 'e.g. Penang Itinerary',
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF304FFE), width: 1.8),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  fontFamily: 'SF Pro',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SF Pro',
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304FFE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () async {
                final newTitle = controller.text.trim();
                Navigator.pop(ctx);
                await SavedTripPlansManager.updatePlanTitle(plan.id, newTitle);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Plan name updated!'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SavedTripPlansScreenState extends State<SavedTripPlansScreen> {
  @override
  void initState() {
    super.initState();
    // Auto sync saved trip plans with Firebase Firestore
    SavedTripPlansManager.syncWithFirestore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Saved Trip Plans',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
      ),
      body: ValueListenableBuilder<List<SavedTripPlan>>(
        valueListenable: SavedTripPlansManager.savedPlansNotifier,
        builder: (context, plans, _) {
          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark_border_rounded,
                        size: 40,
                        color: Color(0xFF304FFE),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No Saved Trip Plans Yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When you generate an itinerary in Your Plan and tap "Save Plan", your full schedule, visit times, and Penny tips will be saved here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro',
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _buildPlanButtonCard(context, plan);
            },
          );
        },
      ),
    );
  }

  /// Interactive card appearing like a button to display the plan overview:
  /// shows the editable title, edit pencil button above the total stops tag,
  /// travel schedule (date and time below it), travel area, and an action button to open.
  Widget _buildPlanButtonCard(BuildContext context, SavedTripPlan plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedPlanDetailScreen(plan: plan),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title on the left, edit pencil button ABOVE total stops tag on the right
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        plan.cleanTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => SavedTripPlansScreen.showEditTitleDialog(context, plan),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 15,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBEAFE)),
                          ),
                          child: Text(
                            '${plan.stops.length} Stops',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1D4ED8),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Travel Schedule Box (Travel date & Travel time below it)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEDF2F7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Travel Date
                      if (plan.travelDateRange.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            const Text(
                              'Travel Date: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                plan.travelDateRange,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (plan.travelDateRange.isNotEmpty && plan.travelSchedule.isNotEmpty)
                        const SizedBox(height: 8),
                      // Travel Time (displayed below travel date)
                      if (plan.travelSchedule.isNotEmpty)
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 8),
                            const Text(
                              'Travel Time: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                plan.travelSchedule,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Travel Area
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF304FFE)),
                      const SizedBox(width: 6),
                      const Text(
                        'Travel Area: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      Expanded(
                        child: Text(
                          plan.displayArea,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'SF Pro',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Button-like View Plan prompt
                Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF304FFE), // Spec Indigo Accent
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF304FFE).withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'View Plan Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
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
}

/// Detailed view for a specific saved trip plan.
/// Opened only when a user selects a plan button from SavedTripPlansScreen or taps 'Plan is ready'.
/// Rubbish bin icon is removed; plans cannot be deleted.
/// Shows Metro Weather Guard card, View on Map button, and edit pen icon button above total stops tag in card.
class SavedPlanDetailScreen extends StatefulWidget {
  final SavedTripPlan plan;

  const SavedPlanDetailScreen({super.key, required this.plan});

  @override
  State<SavedPlanDetailScreen> createState() => _SavedPlanDetailScreenState();
}

class _SavedPlanDetailScreenState extends State<SavedPlanDetailScreen> {
  final Map<String, WeatherData> _areaWeatherCache = {};
  bool _isWeatherGuardExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadAreaWeather();
  }

  Future<void> _loadAreaWeather() async {
    final areas = widget.plan.stops
        .map((s) => s.area.trim())
        .where((a) => a.isNotEmpty && a.toLowerCase() != 'penang')
        .toSet()
        .toList();
    if (areas.isEmpty) areas.add('George Town');

    final weatherService = WeatherService();
    for (final area in areas) {
      try {
        final matches = widget.plan.stops.where((s) => s.area.trim() == area);
        final sampleStop = matches.isNotEmpty ? matches.first : widget.plan.stops.first;
        final lat = sampleStop.lat != 0.0 ? sampleStop.lat : 5.4141;
        final lng = sampleStop.lng != 0.0 ? sampleStop.lng : 100.3288;
        final w = await weatherService.fetchWeather(
          latitude: lat,
          longitude: lng,
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

  void _launchPlanOnMap(BuildContext context, SavedTripPlan plan) {
    if (plan.stops.isEmpty) return;
    final firstStop = plan.stops.first;
    final initialDestination = MapLocation(
      name: firstStop.placeName,
      lat: firstStop.lat,
      lng: firstStop.lng,
      description: firstStop.pennyTip.isNotEmpty ? firstStop.pennyTip : firstStop.placeName,
    );

    final itineraryPlaces = plan.stops.map((s) {
      return ItineraryPlace(
        id: 'stop_${s.stopNumber}',
        name: s.placeName,
        area: s.area,
        description: s.pennyTip.isNotEmpty ? s.pennyTip : s.placeName,
        lat: s.lat,
        lng: s.lng,
        category: s.category,
        estimatedStayMinutes: 60,
        address: s.address,
        imageUrl: s.imageUrl,
        tip: s.pennyTip,
        isAdjusted: s.isAdjusted,
        adjustmentReason: s.adjustmentReason,
      );
    }).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          destination: initialDestination,
          showRouteToDestination: true,
          itineraryPlaces: itineraryPlaces,
          isItineraryPreview: true,
          initialPlaceIndex: 0,
          stops: plan.stops
              .map((s) => {
                    'name': s.placeName,
                    'lat': s.lat,
                    'lng': s.lng,
                    'area': s.area,
                  })
              .toList(),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Oct';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SavedTripPlan>>(
      valueListenable: SavedTripPlansManager.savedPlansNotifier,
      builder: (context, plans, _) {
        final currentPlan = plans.firstWhere(
          (p) => p.id == widget.plan.id,
          orElse: () => widget.plan,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
              ),
            ),
            title: Text(
              currentPlan.cleanTitle,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.bold,
                fontSize: 18,
                fontFamily: 'SF Pro',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
            // Edit pen icon is intentionally removed from AppBar per user requirement
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Overview Header Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title on the left, edit pencil button ABOVE total stops tag on the right
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              currentPlan.cleanTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => SavedTripPlansScreen.showEditTitleDialog(context, currentPlan),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDBEAFE)),
                                ),
                                child: Text(
                                  '${currentPlan.stops.length} Stops',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1D4ED8),
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Travel Date
                      if (currentPlan.travelDateRange.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            const Text(
                              'Travel Date: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                currentPlan.travelDateRange,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Travel Time (displayed below travel date)
                      if (currentPlan.travelSchedule.isNotEmpty) ...[
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF64748B)),
                            const SizedBox(width: 6),
                            const Text(
                              'Travel Time: ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            Expanded(
                              child: Text(
                                currentPlan.travelSchedule,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Travel Area
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF304FFE)),
                          const SizedBox(width: 6),
                          const Text(
                            'Travel Area: ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                          Expanded(
                            child: Text(
                              currentPlan.displayArea,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // View on Map Button (exact style as in Your Plan screen)
                SizedBox(
                  width: double.infinity,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFamily: 'SF Pro',
                        color: Color(0xFF19244E),
                      ),
                    ),
                    onPressed: () => _launchPlanOnMap(context, currentPlan),
                  ),
                ),

                const SizedBox(height: 12),

                // Metro Weather Guard Card
                _buildWeatherGuardSection(currentPlan),

                const SizedBox(height: 14),

                // Penny Says Message Bubble
                if (currentPlan.pennyOverviewMessage.isNotEmpty)
                  _buildPennyOverviewBubble(currentPlan),

                const SizedBox(height: 14),

                // Plan Breakdown Header
                Row(
                  children: [
                    const Icon(Icons.format_list_bulleted_rounded, size: 18, color: Color(0xFF304FFE)),
                    const SizedBox(width: 8),
                    const Text(
                      'Plan Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${currentPlan.stops.length} stops',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stops List
                Column(
                  children: currentPlan.stops.map((stop) => _buildStopItem(stop)).toList(),
                ),

                const SizedBox(height: 24),

                // Share Plan with Travel Partner Button
                _buildShareWithPartnerButton(context, currentPlan),

                const SizedBox(height: 36),
              ],
            ),
          ),
        );
      },
    );
  }

  // ====================================================================
  // SHARE PLAN WITH TRAVEL PARTNER MODAL & BUTTON
  // ====================================================================
  Widget _buildShareWithPartnerButton(BuildContext context, SavedTripPlan plan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCE8), // Warm light yellow surface
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A), width: 1.4), // Soft amber/yellow border
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEAB308).withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEA00), // Primary Yellow Accent (0xFFFFEA00)
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: Colors.black, // Text & Icon color: Colors.black for Yellow Accent
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Travel Partner Sharing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Share this itinerary with family or friends for live sync',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78716C),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _handleShareTrip(context, plan),
              icon: const Icon(Icons.share_rounded, size: 20, color: Colors.black),
              label: const Text(
                'Share with Travel Partner',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto Mono', // Rule: Roboto Mono
                  color: Colors.black, // Text & icon color: Colors.black
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEA00), // Background: Colors.yellowAccent[400]
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                shadowColor: const Color(0xFFCA8A04).withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShareTrip(BuildContext context, SavedTripPlan plan) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF304FFE)),
                SizedBox(height: 14),
                Text(
                  'Generating Trip Access Key...',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final code = await SavedTripPlansManager.sharePlanToFirebase(plan);
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // Show share dialog with generated code
      _showShareSuccessDialog(context, plan, code);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate share key: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showShareSuccessDialog(BuildContext context, SavedTripPlan plan, String code) {
    // Generate the direct companion link with auto-fill query param
    final companionWebUrl = '${AppConfig.companionWebBaseUrl}/?code=$code';
    final shareMessage =
        'Hey! Join our Penang trip plan "${plan.cleanTitle}" on the Kia Kia Companion Portal.\n\n'
        'Tap the link to join directly:\n'
        '$companionWebUrl\n\n'
        'Passcode: $code\n'
        '(Open directly in your browser - no app installation needed!)';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          backgroundColor: Colors.white,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 400,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF08A),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.key_rounded,
                      color: Color(0xFFCA8A04),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trip Access Code',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Share this 6-digit passcode or copy the invitation link for instant browser access:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontFamily: 'SF Pro',
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Passcode Display Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          code,
                          style: const TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, color: Color(0xFF78716C), size: 20),
                          tooltip: 'Copy Code Only',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Passcode copied to clipboard!'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 2. Copy Invitation Link & Message (User Requested Feature)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareMessage));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invitation message & link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF854D0E)),
                      label: const Text(
                        'Copy Link & Message',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Roboto Mono',
                          color: Color(0xFF854D0E),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF9C3),
                        side: const BorderSide(color: Color(0xFFFDE047), width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 3. Info Notice Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFEF3C7)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Synced to Firebase: Companions open the link in browser without installing the app.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF92400E),
                              fontFamily: 'SF Pro',
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Done Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEA00), // Yellow Accent
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: 1,
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontFamily: 'Roboto Mono',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
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

  // Metro Weather Guard Section with microclimate scan per area
  Widget _buildWeatherGuardSection(SavedTripPlan plan) {
    final areas = plan.stops
        .map((s) => s.area.trim())
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
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDBEAFE)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform.scale(
                      scale: 2.2,
                      alignment: const Alignment(0.15, -0.68),
                      child: Image.asset(
                        'assets/blue_bird_mascot.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.wb_sunny_rounded, color: Color(0xFF2563EB), size: 18),
                        ),
                      ),
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
                              'Metro Weather Guard',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontFamily: 'SF Pro',
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
                                      fontFamily: 'SF Pro',
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
                            fontFamily: 'SF Pro',
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

  Widget _buildAreaWeatherItem(String area, WeatherData? weather) {
    final tempMax = weather?.tempMax.round() ?? 31;
    final tempMin = weather?.tempMin.round() ?? 25;
    final rainProb = weather?.precipitationProbabilityMax ?? 20;
    final condition = weather?.condition ?? 'Mainly Clear';

    final String rainWindow;
    if (rainProb >= 50) {
      rainWindow = 'High rain probability predicted during afternoon';
    } else if (rainProb >= 30) {
      rainWindow = 'Scattered showers possible across afternoon';
    } else {
      rainWindow = 'Low rain probability across afternoon';
    }

    final now = DateTime.now();
    final dateStr = '${_monthName(now.month)} ${now.day}, ${now.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
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
                  const Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Text(
                    area,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'SF Pro'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                          Text(
                            condition,
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontFamily: 'SF Pro'),
                          ),
                          Text(
                            '$tempMax°C / $tempMin°C',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'SF Pro'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500, fontFamily: 'SF Pro'),
                          ),
                          Text(
                            '$rainProb% Rain',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8), fontFamily: 'SF Pro'),
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
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Metro Mascot Weather Advisory Chat Bubble
          Builder(builder: (context) {
            final isSunscreenNeeded = tempMax >= 30 || (weather != null && weather.uvIndex >= 5.0) || condition.toLowerCase().contains('sun');
            final isRainUmbrellaNeeded = rainProb >= 30 || (weather != null && weather.isRainy) || condition.toLowerCase().contains('rain');
            final isSunUmbrellaNeeded = !isRainUmbrellaNeeded && (tempMax >= 31);

            if (!isSunscreenNeeded && !isRainUmbrellaNeeded && !isSunUmbrellaNeeded) {
              return const SizedBox.shrink();
            }

            final List<String> adviceParts = [];
            if (isSunscreenNeeded) {
              adviceParts.add('apply sunscreen');
            }
            if (isRainUmbrellaNeeded) {
              adviceParts.add('take an umbrella');
            } else if (isSunUmbrellaNeeded) {
              adviceParts.add('bring a sun umbrella');
            }

            final String adviceText = adviceParts.length == 2
                ? 'Remember to ${adviceParts[0]} and ${adviceParts[1]}!'
                : (adviceParts.isNotEmpty ? 'Remember to ${adviceParts[0]}!' : '');

            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                  topLeft: Radius.circular(3),
                ),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 1.0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFDBEAFE),
                      border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform.scale(
                      scale: 2.2,
                      alignment: const Alignment(0.15, -0.68),
                      child: Image.asset(
                        'assets/blue_bird_mascot.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.wb_sunny_rounded, color: Color(0xFF2563EB), size: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontFamily: 'SF Pro',
                          height: 1.3,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Metro says: ',
                            style: TextStyle(
                              color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: adviceText,
                            style: const TextStyle(
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Penny says speech bubble
  Widget _buildPennyOverviewBubble(SavedTripPlan plan) {
    final hasMod = plan.pennyModificationMessage != null && plan.pennyModificationMessage!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFBCFE8), width: 1.1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF472B6), width: 1.1),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/pink_bird_mascot.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Text('🐦', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'Penny says:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9D174D),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'AI Timeline Note',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDB2777),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.pennyOverviewMessage,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF1E293B),
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'SF Pro',
                    height: 1.36,
                  ),
                ),
                if (hasMod) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Divider(
                      height: 1,
                      thickness: 0.8,
                      color: const Color(0xFFFBCFE8).withValues(alpha: 0.8),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 4),
                        child: Icon(Icons.sync_rounded, size: 12, color: Color(0xFFDB2777)),
                      ),
                      Expanded(
                        child: Text(
                          plan.pennyModificationMessage!.trim(),
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF475569),
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'SF Pro',
                            height: 1.34,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Stop card with Penny tip, visit time, duration, area
  Widget _buildStopItem(SavedPlanStop stop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Penny mascot tip bubble above stop card
          if (stop.pennyTip.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFCE7F3),
                      border: Border.all(color: const Color(0xFFFBCFE8), width: 1.1),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/pink_bird_mascot.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Text('🐦', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF2F8),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                          topLeft: Radius.circular(3),
                        ),
                        border: Border.all(color: const Color(0xFFFBCFE8), width: 1.0),
                      ),
                      child: Text(
                        stop.pennyTip,
                        style: const TextStyle(
                          color: Colors.black,
                          fontStyle: FontStyle.italic,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'SF Pro',
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 2. Frameless rescheduled note if adjusted
          if (stop.isAdjusted && stop.adjustmentReason != null && stop.adjustmentReason!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 13),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      stop.adjustmentReason!,
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Stop card container
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: stop.isAdjusted ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                width: stop.isAdjusted ? 1.5 : 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: stop.isAdjusted ? const Color(0xFFD97706) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${stop.stopNumber}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        stop.placeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          fontFamily: 'SF Pro',
                        ),
                      ),
                    ),
                  ],
                ),
                if (stop.imageUrl != null && stop.imageUrl!.isNotEmpty && stop.imageUrl != 'no_image_found') ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: AppImageWidget(
                        imagePath: stop.imageUrl!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Time Slot
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded, size: 10.5, color: Color(0xFF2563EB)),
                          const SizedBox(width: 4),
                          Text(
                            stop.timeSlot,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E40AF),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Specific Area
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF475569)),
                          const SizedBox(width: 3),
                          Text(
                            stop.area,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Stay Duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 10.5, color: Color(0xFF64748B)),
                          const SizedBox(width: 3),
                          Text(
                            stop.stayDuration,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
