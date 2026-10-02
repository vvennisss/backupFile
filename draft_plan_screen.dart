import 'package:flutter/material.dart';
import '../controllers/trip_controller.dart';
import 'itinerary_plan_screen.dart';
import 'search_places_screen.dart';
import 'set_travel_date_screen.dart';

/// Full-screen Draft Plan page — replaces the old bottom sheet.
/// Shows all places in the draft itinerary with:
///  • Primary category as a light-background chip (fallback to sub_categories)
///  • True features as dark-background chips (Halal, Vegetarian, Michelin, etc.)
///  • Red ✕ button to remove a place with a confirmation dialog
///  • "Save & Plan Trip" CTA button at the bottom
class DraftPlanScreen extends StatelessWidget {
  final TripController controller;

  const DraftPlanScreen({super.key, required this.controller});

  // ── Category chip colour (light background) ─────────────────────────────
  static const Map<String, Color> _categoryBgColors = {
    'Cafes': Color(0xFFFFF3E0),
    'Food & Dining': Color(0xFFE8F5E9),
    'Nightlife & Speakeasies': Color(0xFFF3E5F5),
    'Heritage & Culture': Color(0xFFE3F2FD),
    'Arts & Workshops': Color(0xFFFCE4EC),
    'Religious Sites': Color(0xFFF9FBE7),
    'Nature & Parks': Color(0xFFE0F2F1),
    'Family & Adventure': Color(0xFFFFF8E1),
    'Shopping & Markets': Color(0xFFE8EAF6),
    'Local Souvenirs': Color(0xFFFBE9E7),
    'Boutique Stays': Color(0xFFEDE7F6),
    'Wellness & Spa': Color(0xFFE0F7FA),
    'Entertainment': Color(0xFFF1F8E9),
    'Others': Color(0xFFF5F5F5),
  };

  static const Map<String, Color> _categoryTextColors = {
    'Cafes': Color(0xFFE65100),
    'Food & Dining': Color(0xFF1B5E20),
    'Nightlife & Speakeasies': Color(0xFF4A148C),
    'Heritage & Culture': Color(0xFF0D47A1),
    'Arts & Workshops': Color(0xFF880E4F),
    'Religious Sites': Color(0xFF827717),
    'Nature & Parks': Color(0xFF004D40),
    'Family & Adventure': Color(0xFFF57F17),
    'Shopping & Markets': Color(0xFF1A237E),
    'Local Souvenirs': Color(0xFFBF360C),
    'Boutique Stays': Color(0xFF311B92),
    'Wellness & Spa': Color(0xFF006064),
    'Entertainment': Color(0xFF33691E),
    'Others': Color(0xFF424242),
  };

  // ── Feature label / icon mapping ────────────────────────────────────────
  static const Map<String, ({String label, IconData icon})> _featureMap = {
    'is_halal':               (label: 'Halal', icon: Icons.star_rounded),
    'is_vegetarian_friendly': (label: 'Vegetarian', icon: Icons.eco_rounded),
    'is_michelin':            (label: 'Michelin', icon: Icons.restaurant_menu_rounded),
    'has_aircon':             (label: 'Air-Con', icon: Icons.ac_unit_rounded),
    'has_parking':            (label: 'Parking', icon: Icons.local_parking_rounded),
    'is_wheelchair_accessible': (label: 'Accessible', icon: Icons.accessible_rounded),
    'wifi_available':         (label: 'Wi-Fi', icon: Icons.wifi_rounded),
    'specialty_coffee':       (label: 'Specialty Coffee', icon: Icons.coffee_rounded),
  };

  static const Color _featureBg   = Color(0xFF1E293B);
  static const Color _featureText = Colors.white;

  // ── Helpers ──────────────────────────────────────────────────────────────
  String _displayCategory(ItineraryPlace place) {
    if (place.primaryCategory != null && place.primaryCategory!.isNotEmpty) {
      return place.primaryCategory!;
    }
    if (place.subCategories.isNotEmpty) return place.subCategories.first;
    if (place.category.isNotEmpty) return place.category;
    return 'Others';
  }

  List<MapEntry<String, String>> _trueFeatures(ItineraryPlace place) {
    return place.features.entries
        .where((e) => e.value == true && _featureMap.containsKey(e.key))
        .map((e) => MapEntry(e.key, _featureMap[e.key]!.label))
        .toList();
  }

  void _openSearchPlacesScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchPlacesScreen(controller: controller),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final draftList = controller.draftItinerary;
        final canSave = draftList.length >= 2;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0.5,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF19244E)),
              onPressed: () => Navigator.pop(context),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.playlist_add_check_circle_rounded,
                    color: Color(0xFF304FFE), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Draft Plan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF19244E),
                    fontFamily: 'SF Pro',
                  ),
                ),
              ],
            ),
          ),

          body: Column(
            children: [
              // ── Header & Add Button before the place list ─────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 18, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'Places in Draft (${draftList.length})',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'SF Pro',
                      ),
                    ),
                    const Spacer(),
                    // Add Icon Button before the place
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF304FFE), size: 24),
                      tooltip: 'Search & Add Place',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _openSearchPlacesScreen(context),
                    ),
                  ],
                ),
              ),

              // ── Search & Add Tap Bar before place cards ───────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InkWell(
                  onTap: () => _openSearchPlacesScreen(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: Color(0xFF304FFE), size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Search and add places...',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ),
                        const Icon(Icons.search, color: Color(0xFF94A3B8), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Place List ─────────────────────────────────────────────
              Expanded(
                child: draftList.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: draftList.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _buildPlaceCard(context, draftList, index),
                      ),
              ),

              // ── Bottom CTA ─────────────────────────────────────────────
              _buildBottomCTA(context, canSave, draftList.length),
            ],
          ),
        );
      },
    );
  }

  // ─── Empty State ─────────────────────────────────────────────────────────
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No places yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                fontFamily: 'SF Pro',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search Penang places or chat with Kia-Kia Bird to add destinations to your draft plan.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, fontFamily: 'SF Pro'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304FFE),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
              onPressed: () => _openSearchPlacesScreen(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Search & Add Places',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'SF Pro',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Place Card ───────────────────────────────────────────────────────────
  Widget _buildPlaceCard(
      BuildContext context, List<ItineraryPlace> draftList, int index) {
    final place = draftList[index];
    final catLabel = _displayCategory(place);
    final catBg = _categoryBgColors[catLabel] ?? const Color(0xFFF1F5F9);
    final catText = _categoryTextColors[catLabel] ?? const Color(0xFF475569);
    final trueFeats = _trueFeatures(place);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bullet — cycles through a colour palette
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: const [
                  Color(0xFF304FFE), // indigo
                  Color(0xFF10B981), // emerald
                  Color(0xFFF59E0B), // amber
                  Color(0xFFEF4444), // red
                  Color(0xFF8B5CF6), // violet
                  Color(0xFF06B6D4), // cyan
                  Color(0xFFEC4899), // pink
                  Color(0xFF84CC16), // lime
                ][index % 8],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Category Tag on TOP of Place Name
                  _buildTag(
                    label: catLabel,
                    bg: catBg,
                    textColor: catText,
                    isDark: false,
                  ),
                  const SizedBox(height: 5),

                  // 2. Place Name
                  Text(
                    place.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Color(0xFF1E293B),
                      fontFamily: 'SF Pro',
                    ),
                  ),

                  // 3. Area
                  if (place.area.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          place.area,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ],
                    ),
                  ],

                  // 4. Feature tags (dark background, only if true)
                  if (trueFeats.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: trueFeats
                          .map((e) => _buildTag(
                                label: e.value,
                                icon: _featureMap[e.key]?.icon,
                                bg: _featureBg,
                                textColor: _featureText,
                                isDark: true,
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Remove button — centered, no background
            Center(
              child: GestureDetector(
                onTap: () => _confirmRemove(context, place, index),
                child: const Icon(Icons.close_rounded,
                    color: Color(0xFFEF4444), size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Single Tag Chip ──────────────────────────────────────────────────────
  Widget _buildTag({
    required String label,
    required Color bg,
    required Color textColor,
    IconData? icon,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontFamily: 'SF Pro',
            ),
          ),
        ],
      ),
    );
  }

  // ─── Confirm Remove Dialog ────────────────────────────────────────────────
  void _confirmRemove(BuildContext context, ItineraryPlace place, int index) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Place?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontFamily: 'SF Pro'),
        ),
        content: Text(
          'Are you sure you want to remove "${place.name}" from your draft plan?',
          style: const TextStyle(fontSize: 13.5, height: 1.4, fontFamily: 'SF Pro'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'SF Pro')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogCtx);
              controller.removePlaceFromDraft(index, notifyChat: false);
            },
            child: const Text('Remove', style: TextStyle(fontFamily: 'SF Pro')),
          ),
        ],
      ),
    );
  }

  // ─── Bottom CTA ───────────────────────────────────────────────────────────
  Widget _buildBottomCTA(BuildContext context, bool canSave, int placeCount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFF1F5F9), width: 1.5),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, -3)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!canSave)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 5),
                  Text(
                    'Add at least 2 places to save & optimise your trip',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                      fontFamily: 'SF Pro',
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    canSave ? const Color(0xFF304FFE) : Colors.grey.shade300,
                foregroundColor:
                    canSave ? Colors.white : Colors.grey.shade600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: canSave ? 2 : 0,
              ),
              onPressed: canSave
                  ? () {
                      if (controller.travelDates == null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SetTravelDateScreen(controller: controller),
                          ),
                        );
                      } else {
                        Navigator.pop(context); // close Draft screen
                        // Trigger save & optimise via itinerary plan flow
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ItineraryPlanScreen()),
                        );
                      }
                    }
                  : null,
              child: Text(
                '✨  Generate Plan with $placeCount Place${placeCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto Mono',
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
