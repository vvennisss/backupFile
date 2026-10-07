import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import '../widgets/app_image_widget.dart';
import 'detail_screen.dart';

class ModifyPlanScreen extends StatefulWidget {
  const ModifyPlanScreen({super.key});

  @override
  State<ModifyPlanScreen> createState() => _ModifyPlanScreenState();
}

class _ModifyPlanScreenState extends State<ModifyPlanScreen> {
  final TripController _controller = TripController();
  late List<ItineraryPlace> _places;
  List<WeatherRecommendation> _heatRecommendations = [];
  List<WeatherRecommendation> _rainRecommendations = [];

  @override
  void initState() {
    super.initState();
    _places = List.from(_controller.draftItinerary);
    _loadRecommendations();
  }

  void _loadRecommendations() async {
    if (_controller.heatRecommendations.isEmpty && _controller.rainRecommendations.isEmpty) {
      await _controller.fetchWeatherRecommendationsIfNeeded();
    }
    if (mounted) {
      setState(() {
        _heatRecommendations = List.from(_controller.heatRecommendations);
        _rainRecommendations = List.from(_controller.rainRecommendations);
      });
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _places.removeAt(oldIndex);
      _places.insert(newIndex, item);
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
    setState(() {
      _places.removeAt(index);
    });
  }

  void _acceptRecommendation(WeatherRecommendation rec, {bool isHeat = true}) {
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
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "${rec.name}" to your plan!'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _rejectRecommendation(WeatherRecommendation rec, {bool isHeat = true}) {
    setState(() {
      if (isHeat) {
        _heatRecommendations.removeWhere((r) => r.id == rec.id || r.name == rec.name);
      } else {
        _rainRecommendations.removeWhere((r) => r.id == rec.id || r.name == rec.name);
      }
    });
  }

  Future<void> _handleSaveAndApply() async {
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
                const Text(
                  'Optimizing Your Itinerary...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'SF Pro',
                  ),
                ),
                const SizedBox(height: 10),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Kia-Kia is checking venue opening hours and aligning visit sequences to avoid conflicts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
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

    // Call TripController to send modified places to Gemma4:cloud backend
    await _controller.optimizeAndApplyModifiedPlan(_places);

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
                                      const SizedBox(height: 3),
                                      Text(
                                        '🕒 ${place.bestVisitTime}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2563EB),
                                          fontFamily: 'SF Pro',
                                        ),
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
                      ..._heatRecommendations.map((rec) => _buildRecommendationCard(rec, isHeat: true)),
                      const SizedBox(height: 16),
                    ],

                    // Rain Recommendations
                    if (_rainRecommendations.isNotEmpty) ...[
                      _buildRecommendationCategoryHeader('🌧️ Rain Shelter Alternatives'),
                      const SizedBox(height: 8),
                      ..._rainRecommendations.map((rec) => _buildRecommendationCard(rec, isHeat: false)),
                      const SizedBox(height: 16),
                    ],
                  ],
                ],
              ),
            ),
          ),

          // --- BOTTOM ACTION BAR: SAVE AND APPLY ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _handleSaveAndApply,
                  icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Save and Apply',
                    style: TextStyle(
                      fontSize: 16,
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
                  ),
                ),
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

  // High-contrast Solid Blue Recommendation Card
  Widget _buildRecommendationCard(WeatherRecommendation rec, {required bool isHeat}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB), // Solid contrast blue
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.25),
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
                        color: Colors.white,
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
                        color: Color(0xFFDBEAFE),
                        fontWeight: FontWeight.w500,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Short Reason (strictly <= 12 words)
                    Text(
                      rec.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Color(0xFF60A5FA), height: 1),
          const SizedBox(height: 8),

          // Actions Row: More / Details button, Accept button, Reject button
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
                icon: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'More',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'SF Pro',
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              const Spacer(),

              // Reject / Dismiss Icon Button
              IconButton(
                onPressed: () => _rejectRecommendation(rec, isHeat: isHeat),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                tooltip: 'Dismiss recommendation',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(34, 34),
                ),
              ),
              const SizedBox(width: 8),

              // Accept / Add Icon Button
              IconButton(
                onPressed: () => _acceptRecommendation(rec, isHeat: isHeat),
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                tooltip: 'Accept & Add to Plan',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald green
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(34, 34),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
