import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryManager {
  static const String _storageKey = 'discover_recent_searches';
  static final ValueNotifier<List<String>> recentSearchesNotifier = ValueNotifier<List<String>>([]);

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_storageKey) ?? [];
      recentSearchesNotifier.value = list;
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  static Future<void> addSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = List.from(recentSearchesNotifier.value);
      
      // Remove existing duplicate (case-insensitive)
      list.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
      // Insert at the front
      list.insert(0, clean);
      // Keep up to 10 in storage
      if (list.length > 10) {
        list = list.sublist(0, 10);
      }

      await prefs.setStringList(_storageKey, list);
      recentSearchesNotifier.value = list;
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  static Future<void> removeSearch(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = List.from(recentSearchesNotifier.value);
      list.removeWhere((item) => item.toLowerCase() == query.toLowerCase());

      await prefs.setStringList(_storageKey, list);
      recentSearchesNotifier.value = list;
    } catch (e) {
      debugPrint('Error removing search history item: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      recentSearchesNotifier.value = [];
    } catch (e) {
      debugPrint('Error clearing search history: $e');
    }
  }
}
