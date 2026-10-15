import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/completed_trip_summary.dart';

/// Service responsible for rendering, saving, and exporting travel trail maps to phone storage and social media
class TrailShareService {
  /// Captures any widget wrapped in a RepaintBoundary with the given GlobalKey as high-resolution PNG bytes
  static Future<Uint8List?> captureWidgetToPng(GlobalKey repaintKey, {double pixelRatio = 3.0}) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('⚠️ [TRAIL SHARE] RenderRepaintBoundary not found for key');
        return null;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('⚠️ [TRAIL SHARE] Error capturing widget to PNG: $e');
      return null;
    }
  }

  /// Saves the captured PNG bytes directly into the user's phone Gallery / Photos app (and fallback storage)
  static Future<String?> saveTrailImageToPhone({
    required Uint8List pngBytes,
    required String trailTitle,
    Directory? customTargetDir,
  }) async {
    try {
      final sanitizedTitle = trailTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_\u4e00-\u9fa5]'), '_');
      final fileName = 'KiaPenang_Trail_${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.png';

      // 1. Primary method on mobile (Android & iOS): Save to system Photo Gallery via Gal
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(pngBytes, flush: true);

          final hasAccess = await Gal.hasAccess();
          if (!hasAccess) {
            await Gal.requestAccess();
          }

          await Gal.putImage(tempFile.path, album: 'KiaPenang');
          debugPrint('📸 [TRAIL SHARE] Successfully saved trail image to Phone Gallery via Gal: ${tempFile.path}');
          return 'Phone Gallery (KiaPenang Album)';
        } catch (galError) {
          debugPrint('⚠️ [TRAIL SHARE] Gal save error: $galError. Falling back to local storage.');
        }
      }

      // 2. Fallback to local storage (e.g. Pictures / Documents / External storage)
      Directory? targetDir = customTargetDir;

      if (targetDir == null && !kIsWeb) {
        try {
          targetDir = await getExternalStorageDirectory();
        } catch (_) {}
      }

      targetDir ??= await getApplicationDocumentsDirectory();

      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(pngBytes, flush: true);
      debugPrint('📸 [TRAIL SHARE] Saved trail image to local file: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('⚠️ [TRAIL SHARE] Error saving trail image to phone: $e');
      return null;
    }
  }

  /// Exports the captured trail PNG image along with formatted text to Social Media apps via native system share sheet
  static Future<bool> exportTrailToSocialMedia({
    required Uint8List pngBytes,
    required TravelPlanRoute plan,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = plan.title.replaceAll(RegExp(r'[^a-zA-Z0-9_\u4e00-\u9fa5]'), '_');
      final filePath = '${tempDir.path}/Penang_Trail_$sanitizedTitle.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      final shareText = '🚗 My Penang Travel Trail: "${plan.title}"\n'
          '📍 ${plan.stops.length} stops visited · ${plan.distance} km · ${plan.duration}\n'
          'Captured with Kia Kia Penang! 🌸✨\n'
          '#KiaPenang #PenangTravel #TravelTrail #PenangHeritage';

      final xFile = XFile(file.path, mimeType: 'image/png');
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: shareText,
          subject: 'My Penang Travel Trail - ${plan.title}',
        ),
      );

      debugPrint('🚀 [TRAIL SHARE] Exported trail to social media sheet. Result: ${result.status}');
      return true;
    } catch (e) {
      debugPrint('⚠️ [TRAIL SHARE] Error exporting to social media: $e');
      return false;
    }
  }
}
