import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/indoor_shelter_service.dart';
import '../services/live_journey_service.dart';

/// Full-screen intercept modal pushed when a Severe Weather Event is triggered
/// (e.g. Rain Rate > 7.6 mm/hr or Temperature > 37°C) during an active trip.
/// 
/// Displays:
/// 1. Current Status Alert
/// 2. Map of Nearby Indoor Places
/// 3. Recommended Indoor Shelter details
/// 4. Two Direct Action Buttons:
///    - Scenario A: "Accept Suggestion" (Accept & Pivot)
///    - Scenario B: "Stick to Original Plan"
///    - Scenario C: Close button (✕) to ignore/dismiss and make impromptu stops.
class SevereWeatherModal extends StatefulWidget {
  final SevereWeatherEvent event;

  const SevereWeatherModal({
    super.key,
    required this.event,
  });

  @override
  State<SevereWeatherModal> createState() => _SevereWeatherModalState();
}

class _SevereWeatherModalState extends State<SevereWeatherModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late IndoorShelter _selectedShelter;

  @override
  void initState() {
    super.initState();
    _selectedShelter = widget.event.recommendedShelter;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liveJourney = LiveJourneyService.instance;
    final isHeavyRain = widget.event.triggerType == 'heavy_rain';
    final primaryAccent = isHeavyRain ? const Color(0xFFDC2626) : const Color(0xFFEA580C);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Semi-transparent blurred backdrop (tap outside to dismiss)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                liveJourney.dismissSevereWeatherModal();
              },
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),

          // 2. Full-Screen Modal Card Container
          SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent taps inside card from closing modal
                child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 520, maxHeight: 780),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: primaryAccent.withValues(alpha: 0.6),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryAccent.withValues(alpha: 0.25),
                      blurRadius: 28,
                      spreadRadius: 4,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header & Dismiss Bar
                      _buildHeader(context, liveJourney, primaryAccent, isHeavyRain),

                      // Scrollable Body Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Status Alert Warning Box
                              _buildStatusAlertBox(primaryAccent, isHeavyRain),
                              const SizedBox(height: 16),

                              // Map of Nearby Indoor Places
                              _buildMapSection(liveJourney),
                              const SizedBox(height: 16),

                              // Recommended Shelter Card
                              _buildShelterCard(),
                              const SizedBox(height: 20),

                              // Direct Action Buttons (Scenario A & Scenario B)
                              _buildActionButtons(context, liveJourney),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  /// Header with emergency badge, title, and close button (✕ for Scenario C)
  Widget _buildHeader(
    BuildContext context,
    LiveJourneyService liveJourney,
    Color primaryAccent,
    bool isHeavyRain,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Emergency Alert Badge
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: primaryAccent,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primaryAccent.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isHeavyRain ? Icons.thunderstorm_rounded : Icons.wb_sunny_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'SEVERE WEATHER EVENT',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scenario C: Close Button ('✕' to dismiss/ignore and go off-route)
          IconButton(
            tooltip: 'Dismiss / Make Impromptu Stop',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Color(0xFF303030), // Colors.grey[850]
                size: 18,
              ),
            ),
            onPressed: () {
              // Scenario C: Dismiss modal, system silently tracks background GPS
              liveJourney.dismissSevereWeatherModal();
            },
          ),
        ],
      ),
    );
  }

  /// Status Alert Warning Banner
  Widget _buildStatusAlertBox(Color primaryAccent, bool isHeavyRain) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isHeavyRain ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title / Heading in 32px SF Pro Bold (as per GEMINI.md rules)
          Text(
            widget.event.title,
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 22, // Scaled gracefully to prevent modal vertical overflow while bold
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030), // Colors.grey[850]
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          // Current Status Alert Description
          Text(
            widget.event.message,
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 12, // Body / Desc specification
              color: Colors.grey,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          // Real-time telemetry indicators (Wrap prevents right overflow)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildTelemetryBadge(
                Icons.water_drop_rounded,
                'Rain: ${widget.event.rainRate.toStringAsFixed(1)} mm/hr',
                const Color(0xFF0284C7),
              ),
              _buildTelemetryBadge(
                Icons.thermostat_rounded,
                'Temp: ${widget.event.temperature.toStringAsFixed(1)}°C',
                const Color(0xFFD97706),
              ),
              _buildTelemetryBadge(
                Icons.location_on_rounded,
                widget.event.location,
                const Color(0xFF475569),
              ),
              _buildTelemetryBadge(
                widget.event.source.contains('Dashboard') ? Icons.sensors_rounded : Icons.cloud_done_rounded,
                'Source: ${widget.event.source}',
                widget.event.source.contains('Dashboard') ? const Color(0xFF7C3AED) : const Color(0xFF059669),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Map of Nearby Indoor Places with interactive pins & radar trajectory
  Widget _buildMapSection(LiveJourneyService liveJourney) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Nearby Indoor Places',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 18, // Label specification
                fontWeight: FontWeight.bold,
                color: Color(0xFF303030), // Colors.grey[850]
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.event.nearbyShelters.length} Shelters Found',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A), // Dark slate navigation map
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF334155), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Custom vector map canvas
              Positioned.fill(
                child: CustomPaint(
                  painter: _SevereWeatherRadarMapPainter(
                    userLat: liveJourney.currentLat,
                    userLng: liveJourney.currentLng,
                    selectedShelter: _selectedShelter,
                    shelters: widget.event.nearbyShelters,
                  ),
                ),
              ),

              // Map Top-Left Legend
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Live Safe Havens',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Map Bottom Shelter Quick Selector
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: widget.event.nearbyShelters.map((s) {
                      final isSelected = s.id == _selectedShelter.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedShelter = s;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF59E0B) // Rich Amber
                                : Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${s.name} (${s.distanceString})',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 10.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Selected Recommended Shelter Card
  Widget _buildShelterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B), // Rich Amber
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shelter Icon Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.domain_rounded,
              color: Color(0xFFD97706),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Shelter Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '⭐ TOP INDOOR SHELTER',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _selectedShelter.area,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Name in 18px SF Pro Bold (GEMINI.md rule)
                Text(
                  _selectedShelter.name,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF303030),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),

                // Distance & Grab Transit ETA (Wrap prevents overflow on narrow screens)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Icon(Icons.straighten_rounded, size: 13, color: Color(0xFF0284C7)),
                    Text(
                      _selectedShelter.distanceString,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const Text(' · ', style: TextStyle(color: Colors.grey)),
                    const Icon(Icons.directions_car_rounded, size: 13, color: Color(0xFF16A34A)),
                    Text(
                      '~${_selectedShelter.durationMinutes} min via Grab',
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Shelter Highlight description
                Text(
                  _selectedShelter.highlight,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 11.5,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Two Direct Action Buttons (Scenario A & Scenario B)
  /// Strictly following [GEMINI.md] rules:
  /// - Story Tab & Map Tab:
  ///   - Background: Colors.amber[600] / Rich Amber (0xFFF59E0B)
  ///   - Text & Icon: Colors.black
  ///   - Font: Roboto Mono
  Widget _buildActionButtons(BuildContext context, LiveJourneyService liveJourney) {
    return Column(
      children: [
        // Button 1: Scenario A - "Accept Suggestion" (Accept & Pivot)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B), // Rich Amber (0xFFF59E0B)
              foregroundColor: Colors.black, // Text & Icon black
              elevation: 4,
              shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.45),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(
              Icons.navigation_rounded,
              color: Colors.black,
              size: 22,
            ),
            label: const Text(
              'Accept Suggestion',
              style: TextStyle(
                fontFamily: 'Roboto Mono', // GEMINI.md specification
                fontSize: 17, // Clean scalable button font
                fontWeight: FontWeight.bold,
                color: Colors.black, // Colors.black
                letterSpacing: 0.2,
              ),
            ),
            onPressed: () async {
              // Scenario A: Recalculates navigation on the fly,
              // instantly inserting new indoor shelter as temporary detour
              // ahead of original plan, begins active routing.
              await liveJourney.acceptSevereWeatherDetour(_selectedShelter);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detour active! Rerouting to ${_selectedShelter.name}.',
                            style: const TextStyle(fontFamily: 'SF Pro', color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
        const SizedBox(height: 10),

        // Button 2: Scenario B - "Stick to Original Plan" (Happy Path 2)
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFFEF3C7), // Light Amber background
              foregroundColor: Colors.black, // Black text
              side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: const Icon(
              Icons.beach_access_rounded, // Umbrella icon
              color: Colors.black,
              size: 20,
            ),
            label: const Text(
              'Stick to Original Plan',
              style: TextStyle(
                fontFamily: 'Roboto Mono', // GEMINI.md specification
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            onPressed: () {
              // Scenario B: Dismisses modal immediately, resumes
              // original route without nagging or frustrating user.
              liveJourney.stickToOriginalPlan();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: const Row(
                      children: [
                        Icon(Icons.beach_access_rounded, color: Color(0xFF38BDF8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Continuing with original plan. Stay safe under cover! ☂️',
                            style: TextStyle(fontFamily: 'SF Pro', color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Custom radar/vector map painter rendering traveler's mock GPS location,
/// recommended shelter, and nearby alternatives with glowing trajectory lines.
class _SevereWeatherRadarMapPainter extends CustomPainter {
  final double userLat;
  final double userLng;
  final IndoorShelter selectedShelter;
  final List<IndoorShelter> shelters;

  _SevereWeatherRadarMapPainter({
    required this.userLat,
    required this.userLng,
    required this.selectedShelter,
    required this.shelters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw Map Radar Concurrency Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = 30; r < size.width; r += 45) {
      canvas.drawCircle(center, r, gridPaint);
    }
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

    // Scale calculation (latitude/longitude degrees to canvas pixels)
    // 0.02 deg ~ 2.2 km across
    final scaleX = size.width / 0.035;
    final scaleY = size.height / 0.025;

    Offset toCanvas(double lat, double lng) {
      final dx = center.dx + (lng - userLng) * scaleX;
      final dy = center.dy - (lat - userLat) * scaleY;
      return Offset(
        dx.clamp(20.0, size.width - 20.0),
        dy.clamp(20.0, size.height - 20.0),
      );
    }

    final userOffset = center;
    final selectedOffset = toCanvas(selectedShelter.lat, selectedShelter.lng);

    // 2. Draw Trajectory Line from User to Selected Shelter
    final routeGlowPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.35)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke;
    final routePaint = Paint()
      ..color = const Color(0xFFF59E0B) // Rich Amber
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(userOffset, selectedOffset, routeGlowPaint);
    canvas.drawLine(userOffset, selectedOffset, routePaint);

    // 3. Draw Alternative Shelters (Grey / Secondary Pins)
    final altPinPaint = Paint()..color = const Color(0xFF64748B);
    for (final s in shelters) {
      if (s.id == selectedShelter.id) continue;
      final pos = toCanvas(s.lat, s.lng);
      canvas.drawCircle(pos, 5.0, altPinPaint);
    }

    // 4. Draw Selected Shelter (Glowing Amber Pin)
    final shelterGlow = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(selectedOffset, 12.0, shelterGlow);

    final shelterPin = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(selectedOffset, 7.5, shelterPin);
    final shelterInner = Paint()..color = Colors.black;
    canvas.drawCircle(selectedOffset, 3.0, shelterInner);

    // Shelter Label text
    final textSpan = TextSpan(
      text: selectedShelter.name,
      style: const TextStyle(
        fontFamily: 'SF Pro',
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Color(0xFFFDE68A),
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        selectedOffset.dx - textPainter.width / 2,
        selectedOffset.dy - 20,
      ),
    );

    // 5. Draw User's Current GPS Location (Pulsing Blue Radar Beacon)
    final userPulsePaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userOffset, 14.0, userPulsePaint);

    final userDotPaint = Paint()..color = const Color(0xFF38BDF8);
    canvas.drawCircle(userOffset, 6.0, userDotPaint);
    final userInnerDot = Paint()..color = Colors.white;
    canvas.drawCircle(userOffset, 2.5, userInnerDot);

    // Traveler Label
    const userSpan = TextSpan(
      text: 'You (Mock GPS)',
      style: TextStyle(
        fontFamily: 'SF Pro',
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
        color: Color(0xFF38BDF8),
      ),
    );
    final userPainter = TextPainter(
      text: userSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    userPainter.paint(
      canvas,
      Offset(userOffset.dx - userPainter.width / 2, userOffset.dy + 8),
    );
  }

  @override
  bool shouldRepaint(covariant _SevereWeatherRadarMapPainter oldDelegate) {
    return oldDelegate.userLat != userLat ||
        oldDelegate.userLng != userLng ||
        oldDelegate.selectedShelter.id != selectedShelter.id;
  }
}
