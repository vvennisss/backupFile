import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedPlacesManager {
  static const String _storageKey = 'kiapenang_saved_places';

  // ValueNotifier to broadcast changes to any listener widget (Discover, Profile, Detail, etc.)
  static final ValueNotifier<List<Map<String, String>>> savedPlacesNotifier =
      ValueNotifier<List<Map<String, String>>>([]);

  static List<Map<String, String>> get savedPlaces => savedPlacesNotifier.value;

  /// Helper to convert titles into a clean Firestore document ID
  static String _docIdFor(String title) {
    return title
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Initialize and load saved places from SharedPreferences cache first,
  /// then sync with Firebase Firestore if a user is logged in.
  static Future<void> init() async {
    // 1. Load from local cache for immediate UI availability
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_storageKey) ?? [];
      final List<Map<String, String>> loaded = [];
      for (final raw in rawList) {
        try {
          final decoded = json.decode(raw);
          if (decoded is Map) {
            loaded.add(Map<String, String>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v?.toString() ?? '')),
            ));
          }
        } catch (e) {
          debugPrint('Error parsing cached saved place: $e');
        }
      }
      savedPlacesNotifier.value = loaded;
    } catch (e) {
      debugPrint('Error loading saved places from cache: $e');
    }

    // 2. Sync with Firestore if logged in
    await syncWithFirestore();
  }

  /// Syncs saved places with Cloud Firestore:
  /// - Downloads cloud places for the current authenticated user
  /// - Merges them with local places
  /// - Uploads local places to Firestore if missing remotely
  /// - Updates local SharedPreferences cache
  static Future<void> syncWithFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedPlaces');

      final snapshot = await collection.get();
      final currentLocal = List<Map<String, String>>.from(savedPlacesNotifier.value);
      final List<Map<String, String>> mergedPlaces = [];
      final Set<String> processedTitles = {};

      // 1. Process places retrieved from Firestore
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final title = (data['title'] ?? '').toString().trim();
          if (title.isNotEmpty) {
            final place = <String, String>{
              'title': title,
              'area': (data['area'] ?? 'Penang').toString(),
              'businessHours': (data['businessHours'] ?? 'Check online').toString(),
              'description': (data['description'] ?? '').toString(),
              'imagePath': (data['imagePath'] ?? 'no_image_found').toString(),
              'category': (data['category'] ?? 'Attraction').toString(),
            };
            mergedPlaces.add(place);
            processedTitles.add(title.toLowerCase());
          }
        } catch (e) {
          debugPrint('Error parsing Firestore saved place ${doc.id}: $e');
        }
      }

      // 2. Upload any local places that don't yet exist in Firestore
      for (final localPlace in currentLocal) {
        final title = (localPlace['title'] ?? '').trim();
        if (title.isNotEmpty && !processedTitles.contains(title.toLowerCase())) {
          final docId = _docIdFor(title);
          final placeData = {
            'title': localPlace['title'] ?? '',
            'area': localPlace['area'] ?? 'Penang',
            'businessHours': localPlace['businessHours'] ?? 'Check online',
            'description': localPlace['description'] ?? '',
            'imagePath': localPlace['imagePath'] ?? 'no_image_found',
            'category': localPlace['category'] ?? 'Attraction',
            'savedAt': FieldValue.serverTimestamp(),
          };

          await collection.doc(docId).set(placeData);
          mergedPlaces.add(localPlace);
          processedTitles.add(title.toLowerCase());
        }
      }

      // 3. Update notifier & persistent local SharedPreferences cache
      savedPlacesNotifier.value = mergedPlaces;
      await _persistToSharedPreferences(mergedPlaces);

      // 4. Update totalSavedPlaces counter on the user document in Firestore
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlaces': mergedPlaces.length,
        }, SetOptions(merge: true));
      } catch (_) {}
    } catch (e) {
      debugPrint('Error syncing saved places with Firestore: $e');
    }
  }

  /// Helper to write places list to SharedPreferences
  static Future<void> _persistToSharedPreferences(List<Map<String, String>> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encodedList = places.map((p) => json.encode(p)).toList();
      await prefs.setStringList(_storageKey, encodedList);
    } catch (e) {
      debugPrint('Error persisting saved places to SharedPreferences: $e');
    }
  }

  /// Save a place details map (updates state immediately, writes SharedPreferences and Firestore)
  static Future<void> savePlace(Map<String, String> place) async {
    if (place['title'] == null || place['title']!.trim().isEmpty) return;

    final trimmedTitle = place['title']!.trim();
    final exists = savedPlacesNotifier.value.any(
      (p) => p['title']?.toLowerCase() == trimmedTitle.toLowerCase(),
    );

    if (exists) return;

    final updated = [...savedPlacesNotifier.value, place];
    savedPlacesNotifier.value = updated;

    // 1. Persist to SharedPreferences
    await _persistToSharedPreferences(updated);

    // 2. Persist to Firebase Firestore if logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docId = _docIdFor(trimmedTitle);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedPlaces')
            .doc(docId)
            .set({
          'title': place['title'] ?? '',
          'area': place['area'] ?? 'Penang',
          'businessHours': place['businessHours'] ?? 'Check online',
          'description': place['description'] ?? '',
          'imagePath': place['imagePath'] ?? 'no_image_found',
          'category': place['category'] ?? 'Attraction',
          'savedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlaces': updated.length,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving place to Firestore: $e');
    }
  }

  /// Remove a place by title (updates state immediately, removes from SharedPreferences and Firestore)
  static Future<void> unsavePlace(String title) async {
    final trimmedTitle = title.trim();
    final updated = savedPlacesNotifier.value
        .where((p) => p['title']?.toLowerCase() != trimmedTitle.toLowerCase())
        .toList();

    savedPlacesNotifier.value = updated;

    // 1. Persist to SharedPreferences
    await _persistToSharedPreferences(updated);

    // 2. Delete from Firebase Firestore if logged in
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final docId = _docIdFor(trimmedTitle);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('savedPlaces')
            .doc(docId)
            .delete();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalSavedPlaces': updated.length,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error unsaving place from Firestore: $e');
    }
  }

  /// Check if a place is saved
  static bool isSaved(String title) {
    return savedPlacesNotifier.value.any(
      (p) => p['title']?.toLowerCase() == title.trim().toLowerCase(),
    );
  }

  /// Clear local places on user logout
  static Future<void> clearOnLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      savedPlacesNotifier.value = [];
    } catch (e) {
      debugPrint('Error clearing saved places on logout: $e');
    }
  }
}
