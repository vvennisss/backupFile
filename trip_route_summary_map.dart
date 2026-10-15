import 'dart:math';
import 'package:flutter/material.dart';
import '../services/saved_trip_plans_manager.dart';

class TripRouteSummaryMap extends StatefulWidget {
  final List<Map<String, double>> routeCoordinates; // [{lat: ..., lng: ...}]
  final List<SavedPlanStop> stops;
  final double totalDistanceKm;
  final double height;
  final bool showOverlays;

  const TripRouteSummaryMap({
    super.key,
    required this.routeCoordinates,
    required this.stops,
    required this.totalDistanceKm,
    this.height = 280,
    this.showOverlays = true,
  });

  @override
  State<TripRouteSummaryMap> createState() => _TripRouteSummaryMapState();
}

class _TripRouteSummaryMapState extends State<TripRouteSummaryMap> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B), // Deep Slate Navy
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Interactive Canvas with CustomPainter
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.0,
              child: CustomPaint(
                painter: _TripRoutePainter(
                  routeCoordinates: widget.routeCoordinates,
                  stops: widget.stops,
                ),
                size: Size.infinite,
              ),
            ),
          ),

          if (widget.showOverlays) ...[
            // 2. Top-Left Badge: Driving Trail Path
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.route_rounded, color: Color(0xFF38BDF8), size: 14),
                    SizedBox(width: 5),
                    Text(
                      'Car Driving Path',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE0F2FE),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Top-Right Badge: Total Distance & Stops Count
            Positioned(
              top: 14,
              right: 14,
              child: Container(
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
                      '${widget.stops.length} Stops · ${widget.totalDistanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
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

            // 4. Bottom-Right Tip: Pinch to Zoom
            Positioned(
              bottom: 12,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pinch_rounded, color: Colors.white70, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'Pinch to zoom',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 9.5,
                        color: Colors.white70,
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
}

class _TripRoutePainter extends CustomPainter {
  final List<Map<String, double>> routeCoordinates;
  final List<SavedPlanStop> stops;

  _TripRoutePainter({
    required this.routeCoordinates,
    required this.stops,
  });

  // Distinct marker badge colors matching media_1791996816389.png
  static const List<Color> markerColors = [
    Color(0xFF10B981), // Green (Stop 1)
    Color(0xFFF97316), // Orange (Stop 2)
    Color(0xFF0EA5E9), // Sky Blue (Stop 3)
    Color(0xFF14B8A6), // Teal (Stop 4)
    Color(0xFF8B5CF6), // Purple (Stop 5)
    Color(0xFFEC4899), // Pink (Stop 6)
    Color(0xFFF59E0B), // Amber (Stop 7)
    Color(0xFF6366F1), // Indigo (Stop 8)
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw subtle background watermark diamond pattern matching attached image
    _drawDiamondWatermark(canvas, size);

    if (routeCoordinates.isEmpty && stops.isEmpty) return;

    // 2. Compute bounding box for projection
    double minLat = 90.0, maxLat = -90.0;
    double minLng = 180.0, maxLng = -180.0;

    void updateBounds(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    for (final pt in routeCoordinates) {
      updateBounds(pt['lat']!, pt['lng']!);
    }
    for (final st in stops) {
      updateBounds(st.lat, st.lng);
    }

    // Safety checks
    if (minLat == maxLat) {
      minLat -= 0.01;
      maxLat += 0.01;
    }
    if (minLng == maxLng) {
      minLng -= 0.01;
      maxLng += 0.01;
    }

    // Padding inside the canvas
    const padding = 34.0;
    final drawWidth = size.width - 2 * padding;
    final drawHeight = size.height - 2 * padding;

    // Aspect ratio preservation
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final double scaleX = drawWidth / lngSpan;
    final double scaleY = drawHeight / latSpan;
    final double scale = min(scaleX, scaleY);

    final offsetX = padding + (drawWidth - (lngSpan * scale)) / 2;
    final offsetY = padding + (drawHeight - (latSpan * scale)) / 2;

    Offset toPixel(double lat, double lng) {
      final x = offsetX + (lng - minLng) * scale;
      // Invert Y axis for map projection (North up)
      final y = offsetY + (maxLat - lat) * scale;
      return Offset(x, y);
    }

    // 3. Draw light blue road path line ("like car path 这样的")
    final List<Offset> pathOffsets = [];
    final pointsToDraw = routeCoordinates.isNotEmpty
        ? routeCoordinates
        : stops.map((s) => {'lat': s.lat, 'lng': s.lng}).toList();

    for (final pt in pointsToDraw) {
      pathOffsets.add(toPixel(pt['lat']!, pt['lng']!));
    }

    if (pathOffsets.length >= 2) {
      final roadPath = Path()..moveTo(pathOffsets.first.dx, pathOffsets.first.dy);
      for (int i = 1; i < pathOffsets.length; i++) {
        roadPath.lineTo(pathOffsets[i].dx, pathOffsets[i].dy);
      }

      // Pass 1: Outer glowing cyan aura
      final paintGlow = Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.38)
        ..strokeWidth = 8.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(roadPath, paintGlow);

      // Pass 2: Vibrant light-blue car road line
      final paintCore = Paint()
        ..color = const Color(0xFF38BDF8)
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(roadPath, paintCore);

      // Pass 3: Crisp center highlight
      final paintHighlight = Paint()
        ..color = const Color(0xFFE0F2FE)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(roadPath, paintHighlight);
    }

    // 4. Draw numbered stop pin badges: (1), (2), (3)...
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final pos = toPixel(stop.lat, stop.lng);
      final badgeColor = markerColors[i % markerColors.length];

      // Outer drop shadow
      canvas.drawCircle(
        pos + const Offset(0, 2),
        13.5,
        Paint()..color = Colors.black.withValues(alpha: 0.45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
      );

      // Marker Circle Fill
      canvas.drawCircle(pos, 12.0, Paint()..color = badgeColor);

      // Marker White Border Ring
      canvas.drawCircle(
        pos,
        12.0,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Number inside badge: "1", "2", ...
      final numberText = '${i + 1}';
      final tp = TextPainter(
        text: TextSpan(
          text: numberText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - (tp.width / 2), pos.dy - (tp.height / 2)));

      // Optional stop label tag below pin
      _drawStopLabel(canvas, pos, stop.placeName, i);
    }
  }

  void _drawStopLabel(Canvas canvas, Offset pos, String name, int index) {
    final cleanName = name.length > 14 ? '${name.substring(0, 12)}..' : name;
    final tp = TextPainter(
      text: TextSpan(
        text: cleanName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Alternate label position: top or bottom to avoid overlap
    final isTop = index % 2 == 1;
    final labelY = isTop ? pos.dy - 25 : pos.dy + 15;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, labelY + (tp.height / 2)),
        width: tp.width + 10,
        height: tp.height + 6,
      ),
      const Radius.circular(6),
    );

    // Pill background
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.85),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    tp.paint(canvas, Offset(pos.dx - (tp.width / 2), labelY + 3));
  }

  void _drawDiamondWatermark(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const spacing = 40.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing) {
        final path = Path()
          ..moveTo(x, y - 10)
          ..lineTo(x + 10, y)
          ..lineTo(x, y + 10)
          ..lineTo(x - 10, y)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TripRoutePainter oldDelegate) {
    return oldDelegate.routeCoordinates != routeCoordinates || oldDelegate.stops != stops;
  }
}
