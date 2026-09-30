import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models/place.dart';
import 'mapillary_viewer_screen.dart';

class StreetViewSelectionDialog {
  /// Displays the modal bottom sheet allowing users to choose between Google Maps & Mapillary
  static void show(BuildContext context, Place place) {
    final bool hasMapillary = place.mapillaryImageId != null && place.mapillaryImageId!.trim().isNotEmpty;

    // If no Mapillary 360 view exists, directly launch Google Maps Street View
    if (!hasMapillary) {
      openGoogleStreetView(context, place.lat, place.lng);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                // Title & Description
                Text(
                  'Choose Street View Mode',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[850],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select your preferred 360° viewing experience.',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),

                // Option 1: Google Maps Deep Link
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF304FFE).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.open_in_new,
                      color: Color(0xFF304FFE),
                      size: 24,
                    ),
                  ),
                  title: Text(
                    'Option 1: Open in Google Maps',
                    style: TextStyle(
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey[850],
                    ),
                  ),
                  subtitle: const Text(
                    'Launches official Google Maps Street View in external app.',
                    style: TextStyle(fontFamily: 'SF Pro', fontSize: 12, color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    openGoogleStreetView(context, place.lat, place.lng);
                  },
                ),
                
                if (hasMapillary) ...[
                  const Divider(height: 16),

                  // Option 2: Mapillary In-App Viewer
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEA00).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.panorama_photosphere,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      'Option 2: View In-App (Mapillary)',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey[850],
                      ),
                    ),
                    subtitle: const Text(
                      'Interactive 360° street view with gyroscope motion control.',
                      style: TextStyle(fontFamily: 'SF Pro', fontSize: 12, color: Colors.grey),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapillaryViewerScreen(
                            placeTitle: place.title,
                            mapillaryImageId: place.mapillaryImageId!,
                            clientToken: AppConfig.mapillaryClientToken,
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Launches Google Maps Universal Link with pano action using LaunchMode.externalApplication
  static Future<void> openGoogleStreetView(BuildContext context, double lat, double lng) async {
    final String urlString =
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng&pitch=0&fov=80';
    final Uri uri = Uri.parse(urlString);

    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Google Maps: $e')),
        );
      }
    }
  }
}
