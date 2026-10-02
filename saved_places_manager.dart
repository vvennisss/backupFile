import 'package:flutter/material.dart';

class SavedPlacesManager {
  // ValueNotifier to broadcast changes to any listener widget (Discover, Profile, Detail)
  static final ValueNotifier<List<Map<String, String>>> savedPlacesNotifier = 
      ValueNotifier<List<Map<String, String>>>([]);

  static List<Map<String, String>> get savedPlaces => savedPlacesNotifier.value;

  // Save a place details map
  static void savePlace(Map<String, String> place) {
    if (place['title'] == null || place['title']!.isEmpty) return;
    
    final exists = savedPlacesNotifier.value.any(
      (p) => p['title']?.toLowerCase() == place['title']?.toLowerCase()
    );
    
    if (!exists) {
      savedPlacesNotifier.value = [...savedPlacesNotifier.value, place];
    }
  }

  // Remove a place by title
  static void unsavePlace(String title) {
    savedPlacesNotifier.value = savedPlacesNotifier.value
        .where((p) => p['title']?.toLowerCase() != title.toLowerCase())
        .toList();
  }

  // Check if a place is saved
  static bool isSaved(String title) {
    return savedPlacesNotifier.value.any(
      (p) => p['title']?.toLowerCase() == title.toLowerCase()
    );
  }
}
