import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/completed_trip_summary.dart';
import 'completed_trails_manager.dart';
import 'route_polyline_service.dart';
import 'saved_trip_plans_manager.dart';

/// Service managing real-time live journey simulation, two-way dashboard synchronization,
/// mock car GPS progress, live weather, dynamic traffic incidents, and arrival detection.
class LiveJourneyService extends ChangeNotifier {
  static final LiveJourneyService instance = LiveJourneyService._internal();
  LiveJourneyService._internal();

  bool _isJourneyActive = false;
  bool _isTripCompleted = false;
  CompletedTripSummary? _completedTripSummary;
  SavedTripPlan? _activePlan;
  int _currentStopIndex = 0;
  bool _isArrived = false;
  bool _isPaused = false;
  String _travelMode = 'driving'; // 'driving' or 'walking'
  int _speedMultiplier = 1;

  double _currentLat = 5.4140;
  double _currentLng = 100.3280;
  double _startLegLat = 5.4140;
  double _startLegLng = 100.3280;
  double _targetLat = 5.3999;
  double _targetLng = 100.2750;

  double _totalLegDistanceMeters = 3200;
  double _remainingDistanceMeters = 3200;
  int _remainingSeconds = 360;
  int _legPlannedTransitMinutes = 10;
  int _testLegTotalSeconds = 10;
  double _testLegRemainingSeconds = 10.0;

  // Weather & Traffic Telemetry from Dashboard
  String _weatherCondition = 'sunny'; // 'sunny', 'rainy', 'cloudy', 'thunderstorm'
  double _weatherTemp = 32.0;
  int _weatherHumidity = 70;
  String _weatherLocation = 'George Town';
  String? _activeIncident;
  Timer? _incidentDismissTimer;
  String? _lastDismissedIncident;
  DateTime? _lastDismissedTime;
  int _pendingStopOverstayMinutes = 0;

  String _virtualTimeString = '2026-10-17, 03:30:00 PM';
  DateTime? _virtualClock;
  List<Map<String, dynamic>> _dashboardStops = [];
  String? _overrideCurrentStopName;
  final List<DepartureRecord> _departureRecords = [];

  Timer? _ticker;
  Timer? _dashboardPollTimer;
  bool _dashboardConnected = false;
  String _activeDashboardHost = 'http://10.0.2.2:4000';

  List<String> get _candidateHosts {
    final hosts = <String>[];
    try {
      final backendUri = Uri.parse(AppConfig.backendBaseUrl);
      if (backendUri.host.isNotEmpty) {
        hosts.add('http://${backendUri.host}:4000');
      }
    } catch (_) {}
    try {
      final companionUri = Uri.parse(AppConfig.companionWebBaseUrl);
      if (companionUri.host.isNotEmpty) {
        hosts.add('http://${companionUri.host}:4000');
      }
    } catch (_) {}
    hosts.addAll([
      'http://10.0.2.2:4000',
      'http://127.0.0.1:4000',
      'http://localhost:4000',
      'http://10.3.242.102:4000',
      'http://10.3.244.78:4000',
    ]);
    return hosts.toSet().toList();
  }

  // Getters
  bool get isJourneyActive => _isJourneyActive;
  bool get isTripCompleted => _isTripCompleted;
  CompletedTripSummary? get completedTripSummary => _completedTripSummary;
  SavedTripPlan? get activePlan => _activePlan;
  int get currentStopIndex => _currentStopIndex;
  bool get isArrived => _isArrived;
  bool get isPaused => _isPaused;
  String get travelMode => _travelMode;
  int get speedMultiplier => _speedMultiplier;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get totalLegDistanceMeters => _totalLegDistanceMeters;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  int get remainingSeconds => _remainingSeconds;
  int get legPlannedTransitMinutes => _legPlannedTransitMinutes;
  int get testLegTotalSeconds => _testLegTotalSeconds;
  double get testLegRemainingSeconds => _testLegRemainingSeconds;
  bool get dashboardConnected => _dashboardConnected;
  String get activeDashboardHost => _activeDashboardHost;

  String get weatherCondition => _weatherCondition;
  double get weatherTemp => _weatherTemp;
  int get weatherHumidity => _weatherHumidity;
  String get weatherLocation => _weatherLocation;
  String? get activeIncident => _activeIncident;
  String get virtualTimeString => _virtualTimeString;
  DateTime? get virtualClock => _virtualClock;
  int get pendingStopOverstayMinutes => _pendingStopOverstayMinutes;
  List<Map<String, dynamic>> get dashboardStops => _dashboardStops;
  List<DepartureRecord> get departureRecords => List.unmodifiable(_departureRecords);
  DepartureRecord? get latestDepartureRecord => _departureRecords.isNotEmpty ? _departureRecords.last : null;

  DepartureRecord? getDepartureRecordForStop(int stopIndex) {
    for (final r in _departureRecords.reversed) {
      if (r.fromStopIndex == stopIndex) return r;
    }
    return null;
  }

  DepartureRecord? getArrivalRecordForStop(int stopIndex) {
    for (final r in _departureRecords.reversed) {
      if (r.toStopIndex == stopIndex) return r;
    }
    return null;
  }

  bool get isRainyWeather =>
      _weatherCondition == 'rainy' || _weatherCondition == 'thunderstorm';

  bool _useMockLocation = true;
  String? _customOriginName;

  bool get useMockLocation => _useMockLocation;

  void setUseMockLocation(bool val) {
    _useMockLocation = val;
    notifyListeners();
  }

  SavedPlanStop? get currentStop {
    if (_activePlan == null || _activePlan!.stops.isEmpty) return null;
    if (_currentStopIndex < _activePlan!.stops.length) {
      return _activePlan!.stops[_currentStopIndex];
    }
    return _activePlan!.stops.last;
  }

  String get currentStopName {
    if (_overrideCurrentStopName != null && _overrideCurrentStopName!.isNotEmpty) {
      return _overrideCurrentStopName!;
    }
    if (_dashboardStops.isNotEmpty && _currentStopIndex < _dashboardStops.length) {
      final s = _dashboardStops[_currentStopIndex];
      return (s['nameEn'] ?? s['name'] ?? currentStop?.placeName ?? 'Penang Attraction').toString();
    }
    return currentStop?.placeName ?? 'Penang Destination';
  }

  String get currentArea {
    if (_dashboardStops.isNotEmpty && _currentStopIndex < _dashboardStops.length) {
      final s = _dashboardStops[_currentStopIndex];
      final area = s['area'];
      if (area != null && area.toString().isNotEmpty) return area.toString();
    }
    return currentStop?.area ?? 'George Town';
  }

  String get originStopName {
    if (_activePlan == null || _activePlan!.stops.isEmpty) return 'Departure Origin';
    if (_currentStopIndex > 0 && _currentStopIndex < _activePlan!.stops.length) {
      return _activePlan!.stops[_currentStopIndex - 1].placeName;
    }
    return _customOriginName ?? (_useMockLocation ? 'Starting Hotel' : 'Current Location');
  }

  String get targetStopName => currentStopName;

  /// Calculate distance traveled percentage (0.0 to 1.0)
  double get progressPercentage {
    if (_totalLegDistanceMeters <= 0) return 1.0;
    final progress = (_totalLegDistanceMeters - _remainingDistanceMeters) / _totalLegDistanceMeters;
    return progress.clamp(0.0, 1.0);
  }

  /// Change active dashboard host URL (e.g. if tester inputs custom LAN IP)
  void setDashboardHost(String host) {
    var cleanHost = host.trim();
    if (!cleanHost.startsWith('http://') && !cleanHost.startsWith('https://')) {
      cleanHost = 'http://$cleanHost';
    }
    _activeDashboardHost = cleanHost;
    if (!_candidateHosts.contains(cleanHost)) {
      _candidateHosts.insert(0, cleanHost);
    }
    notifyListeners();
  }

  /// Formats DateTime into a clean virtual clock string matching dashboard: "2026-10-17, 03:30:00 PM"
  static String formatVirtualClock(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final hourStr = hour12.toString().padLeft(2, '0');
    final minStr = dt.minute.toString().padLeft(2, '0');
    final secStr = dt.second.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$y-$m-$d, $hourStr:$minStr:$secStr $ampm';
  }

  /// Parses virtual clock string (e.g. "2026-10-14, 09:30:00 AM") back into DateTime
  static DateTime? parseVirtualClock(String str) {
    if (str.trim().isEmpty) return null;
    try {
      final match = RegExp(
        r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2}),?\s*(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(AM|PM)$',
        caseSensitive: false,
      ).firstMatch(str.trim());
      if (match != null) {
        final y = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final d = int.parse(match.group(3)!);
        int h = int.parse(match.group(4)!);
        final min = int.parse(match.group(5)!);
        final sec = match.group(6) != null ? int.parse(match.group(6)!) : 0;
        final isPm = match.group(7)!.toUpperCase() == 'PM';
        if (isPm && h < 12) h += 12;
        if (!isPm && h == 12) h = 0;
        return DateTime(y, m, d, h, min, sec);
      }
      return DateTime.tryParse(str);
    } catch (_) {
      return null;
    }
  }

  /// Parses scheduled travel date and start time from a SavedTripPlan
  /// Handles formats like "2026-10-17, 03:30PM - 08:00PM" or "17 Oct 2026", "09:00 AM - 05:00 PM"
  static DateTime parsePlanScheduledDateTime(SavedTripPlan plan) {
    DateTime date = plan.savedAt;

    // 1. Parse date from travelDateRange (e.g. "2026-10-17 to 2026-10-17" or "2026-10-17")
    final ymdMatch = RegExp(r'(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})').firstMatch(plan.travelDateRange);
    if (ymdMatch != null) {
      final y = int.parse(ymdMatch.group(1)!);
      final m = int.parse(ymdMatch.group(2)!);
      final d = int.parse(ymdMatch.group(3)!);
      date = DateTime(y, m, d);
    } else {
      const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
      final textMatch = RegExp(r'(\d{1,2})\s+([a-zA-Z]{3,9})\s+(\d{4})').firstMatch(plan.travelDateRange);
      if (textMatch != null) {
        final d = int.parse(textMatch.group(1)!);
        final mStr = textMatch.group(2)!.substring(0, 3).toLowerCase();
        final y = int.parse(textMatch.group(3)!);
        final mIdx = months.indexOf(mStr);
        if (mIdx != -1) {
          date = DateTime(y, mIdx + 1, d);
        }
      }
    }

    // 2. Parse time from travelSchedule or first stop timeSlot (e.g. "03:30PM - 08:00PM")
    String timeStr = plan.travelSchedule;
    if (timeStr.isEmpty || (timeStr == '09:00 AM – 05:00 PM' && plan.stops.isNotEmpty && plan.stops.first.timeSlot.isNotEmpty)) {
      timeStr = plan.stops.first.timeSlot;
    }

    final splitParts = timeStr.split(RegExp(r'[-–—至到]'));
    final startStr = splitParts.isNotEmpty ? splitParts[0].trim() : timeStr.trim();

    int hour = 15;
    int minute = 30; // Default 03:30 PM matching user's travel time specification

    final cleanStr = startStr.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final match12 = RegExp(r'^(\d{1,2})(?:[:.](\d{2}))?(am|pm)$').firstMatch(cleanStr);
    if (match12 != null) {
      int h = int.parse(match12.group(1)!);
      final m = match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final isPm = match12.group(3) == 'pm';
      if (isPm && h < 12) h += 12;
      if (!isPm && h == 12) h = 0;
      hour = h;
      minute = m;
    } else {
      final match24 = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(startStr.trim());
      if (match24 != null) {
        hour = int.parse(match24.group(1)!);
        minute = int.parse(match24.group(2)!);
      }
    }

    return DateTime(date.year, date.month, date.day, hour, minute, 0);
  }

  /// Manually update virtual clock and sync with dashboard
  void setVirtualClock(DateTime dt) {
    _virtualClock = dt;
    _virtualTimeString = formatVirtualClock(dt);
    controlSimulation('setVirtualTime', dt.toIso8601String());
    notifyListeners();
  }

  /// Parses stay duration string (e.g. "60 min", "45 mins", "1.5 hours", "1 hr") into integer minutes
  static int parseStayMinutes(String stayDurationStr) {
    if (stayDurationStr.trim().isEmpty) return 45;
    final clean = stayDurationStr.toLowerCase().trim();

    double hours = 0;
    final hrMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h)\b').firstMatch(clean);
    if (hrMatch != null) {
      hours = double.tryParse(hrMatch.group(1)!) ?? 0;
    }

    int mins = 0;
    final minMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?|m)\b').firstMatch(clean);
    if (minMatch != null) {
      mins = int.tryParse(minMatch.group(1)!) ?? 0;
    }

    if (hours > 0 || mins > 0) {
      return (hours * 60).round() + mins;
    }

    final digitMatch = RegExp(r'(\d+)').firstMatch(clean);
    if (digitMatch != null) {
      return int.tryParse(digitMatch.group(1)!) ?? 45;
    }

    return 45;
  }

  /// Extracts overstay / wait delay minutes from active incident string or dashboard trigger
  static int extractOverstayMinutes(String? incident) {
    if (incident == null || incident.trim().isEmpty) return 0;
    final lower = incident.toLowerCase();

    // Ignore transit-only incidents (traffic jams, road closures, detours, off-track)
    if (lower.contains('traffic') ||
        lower.contains('congestion') ||
        lower.contains('road closure') ||
        lower.contains('detour') ||
        lower.contains('off-track') ||
        lower.contains('heatwave') ||
        lower.contains('resequenced')) {
      return 0;
    }

    // Must match overstay, waiting, sheltering, rain cleared, delay keywords
    final hasOverstayKeyword = lower.contains('overstay') ||
        lower.contains('stayed') ||
        lower.contains('lingering') ||
        lower.contains('photo') ||
        lower.contains('delay') ||
        lower.contains('wait') ||
        lower.contains('shelter') ||
        lower.contains('cleared') ||
        lower.contains('resume') ||
        lower.contains('避雨') ||
        lower.contains('等待') ||
        lower.contains('超时') ||
        lower.contains('放晴');

    if (!hasOverstayKeyword) {
      return 0;
    }

    // Explicit common duration keywords
    if (lower.contains('1 hour') ||
        lower.contains('1 hr') ||
        lower.contains('60 min') ||
        lower.contains('60min') ||
        lower.contains('60m') ||
        lower.contains('_60') ||
        lower.contains('60分钟')) {
      return 60;
    }
    if (lower.contains('30 min') ||
        lower.contains('30min') ||
        lower.contains('30m') ||
        lower.contains('_30') ||
        lower.contains('30分钟')) {
      return 30;
    }
    if (lower.contains('20 min') ||
        lower.contains('20min') ||
        lower.contains('20m') ||
        lower.contains('_20') ||
        lower.contains('20分钟')) {
      return 20;
    }
    if (lower.contains('15 min') ||
        lower.contains('15min') ||
        lower.contains('15m') ||
        lower.contains('_15') ||
        lower.contains('15分钟')) {
      return 15;
    }
    if (lower.contains('10 min') ||
        lower.contains('10min') ||
        lower.contains('10m') ||
        lower.contains('_10') ||
        lower.contains('10分钟')) {
      return 10;
    }

    final match = RegExp(r'\+?(\d+)\s*(?:min|mins|m|分钟)\b').firstMatch(lower);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 15;
    }

    final zhMatch = RegExp(r'(?:等待|避雨|超时|逗留)\s*(\d+)\s*(?:分钟|分|m)?').firstMatch(lower);
    if (zhMatch != null) {
      return int.tryParse(zhMatch.group(1)!) ?? 15;
    }

    return 15;
  }

  /// Parses planned departure time from a stop's timeSlot (e.g. "10:15 AM - 11:20 AM" -> 11:20 AM on baseDate)
  static DateTime? parsePlannedDepartTime(SavedPlanStop stop, DateTime baseDate) {
    final slot = stop.timeSlot.trim();
    if (slot.isEmpty) return null;

    final parts = slot.split(RegExp(r'\s+[-–—至到]\s+|\s*[-–—至到]\s*(?=[0-9]{1,2}:)|(?<=[ap]m)\s*[-–—至到]\s*|[至到]', caseSensitive: false));
    final departStr = parts.length >= 2 ? parts[1].trim() : parts[0].trim();

    // 1. Try 12-hour format with optional seconds: e.g. "12:22 PM", "04:20:23 PM"
    final match12 = RegExp(r'(\d{1,2})[:.](\d{2})(?:[:.]\d{2})?\s*(am|pm)', caseSensitive: false).firstMatch(departStr);
    if (match12 != null) {
      int h = int.parse(match12.group(1)!);
      final m = int.parse(match12.group(2)!);
      final isPm = match12.group(3)!.toLowerCase() == 'pm';
      if (isPm && h < 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m, 0);
    }

    // 2. Try 24-hour format: e.g. "14:30"
    final match24 = RegExp(r'\b(\d{1,2})[:.](\d{2})\b').firstMatch(departStr);
    if (match24 != null) {
      final h = int.parse(match24.group(1)!);
      final m = int.parse(match24.group(2)!);
      return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m, 0);
    }

    return null;
  }

  /// Parses planned arrival time from a stop's timeSlot (e.g. "11:45 AM - 12:22 PM" -> 11:45 AM on baseDate)
  static DateTime? parsePlannedArriveTime(SavedPlanStop stop, DateTime baseDate) {
    final slot = stop.timeSlot.trim();
    if (slot.isEmpty) return null;

    final parts = slot.split(RegExp(r'\s+[-–—至到]\s+|\s*[-–—至到]\s*(?=[0-9]{1,2}:)|(?<=[ap]m)\s*[-–—至到]\s*|[至到]', caseSensitive: false));
    final arriveStr = parts.isNotEmpty ? parts[0].trim() : slot;

    // 1. Try 12-hour format with optional seconds: e.g. "11:45 AM", "04:00:23 PM"
    final match12 = RegExp(r'(\d{1,2})[:.](\d{2})(?:[:.]\d{2})?\s*(am|pm)', caseSensitive: false).firstMatch(arriveStr);
    if (match12 != null) {
      int h = int.parse(match12.group(1)!);
      final m = int.parse(match12.group(2)!);
      final isPm = match12.group(3)!.toLowerCase() == 'pm';
      if (isPm && h < 12) h += 12;
      if (!isPm && h == 12) h = 0;
      return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m, 0);
    }

    // 2. Try 24-hour format: e.g. "11:45"
    final match24 = RegExp(r'\b(\d{1,2})[:.](\d{2})\b').firstMatch(arriveStr);
    if (match24 != null) {
      final h = int.parse(match24.group(1)!);
      final m = int.parse(match24.group(2)!);
      return DateTime(baseDate.year, baseDate.month, baseDate.day, h, m, 0);
    }

    return null;
  }

  /// Calculates planned transit minutes for a leg between stops or from origin
  static int calculatePlannedTransitMinutes({
    required double distanceMeters,
    DateTime? fromTime,
    DateTime? toTime,
  }) {
    if (fromTime != null && toTime != null && toTime.isAfter(fromTime)) {
      final diff = toTime.difference(fromTime).inMinutes;
      if (diff >= 1 && diff <= 180) {
        return diff;
      }
    }
    // Fallback: estimate from road driving distance (approx 30 km/h = 500 meters/min)
    final mins = (distanceMeters / 500.0).round();
    return max(1, mins);
  }

  /// Start Live Journey for the specified plan
  Future<void> startJourney(
    SavedTripPlan plan, {
    bool? useMockLocation,
    double? customStartLat,
    double? customStartLng,
    String? customOriginName,
    DateTime? customStartTime,
  }) async {
    _activePlan = plan;
    _isJourneyActive = true;
    _isTripCompleted = false;
    _completedTripSummary = null;
    _isPaused = false;
    _isArrived = false;
    _speedMultiplier = 1;
    _activeIncident = null;
    _pendingStopOverstayMinutes = 0;
    _overrideCurrentStopName = null;
    if (useMockLocation != null) {
      _useMockLocation = useMockLocation;
    }

    // Initialize mock virtual travel clock
    if (customStartTime != null) {
      _virtualClock = customStartTime;
    } else {
      _virtualClock = parsePlanScheduledDateTime(plan);
    }
    _virtualTimeString = formatVirtualClock(_virtualClock!);

    if (plan.stops.isNotEmpty) {
      _currentStopIndex = 0;
      final target = plan.stops[0];

      if (customStartLat != null && customStartLng != null) {
        _startLegLat = customStartLat;
        _startLegLng = customStartLng;
        _customOriginName = customOriginName;
      } else if (_useMockLocation) {
        final hotel = MockHotelRegistry.findForArea(target.area);
        _startLegLat = hotel.lat;
        _startLegLng = hotel.lng;
        _customOriginName = hotel.hotelName;
      } else {
        _startLegLat = 5.4140;
        _startLegLng = 100.3280;
        _customOriginName = customOriginName ?? 'Current Location';
      }

      _currentLat = _startLegLat;
      _currentLng = _startLegLng;
      _targetLat = target.lat;
      _targetLng = target.lng;

      _totalLegDistanceMeters = _calculateHaversineDistance(_startLegLat, _startLegLng, _targetLat, _targetLng);
      if (_totalLegDistanceMeters < 300) _totalLegDistanceMeters = 1500;
      _remainingDistanceMeters = _totalLegDistanceMeters;

      // Calculate planned transit minutes (e.g. 10 mins)
      final stop0Arrive = parsePlannedArriveTime(target, _virtualClock!);
      final plannedTransitMins = calculatePlannedTransitMinutes(
        distanceMeters: _totalLegDistanceMeters,
        fromTime: _virtualClock,
        toTime: stop0Arrive,
      );
      _legPlannedTransitMinutes = plannedTransitMins;
      // Convert planned transit minutes into test seconds (10 mins -> 10 sec, 20 mins -> 20 sec)
      _testLegTotalSeconds = max(3, plannedTransitMins);
      _testLegRemainingSeconds = _testLegTotalSeconds.toDouble();
      _remainingSeconds = _legPlannedTransitMinutes * 60;
    }

    // Record initial Leg 0 Departure (from Hotel/Origin to Stop 1)
    _departureRecords.clear();
    final originName = _customOriginName ?? (_useMockLocation ? 'Starting Hotel' : 'Current Location');
    final plannedStartTime = parsePlanScheduledDateTime(plan);
    final initVariance = _virtualClock!.difference(plannedStartTime).inMinutes;

    String initSummary;
    String initExplanation;
    if (initVariance == 0) {
      initSummary = 'On Schedule (±0 min)';
      initExplanation = 'Departed origin ($originName) right on schedule.';
    } else if (initVariance > 0) {
      initSummary = '+$initVariance min Late';
      initExplanation = 'Started trip journey $initVariance min later than planned schedule.';
    } else {
      initSummary = '$initVariance min Early';
      initExplanation = 'Started trip journey ${initVariance.abs()} min earlier than planned schedule.';
    }

    final plannedArrive = plan.stops.isNotEmpty ? parsePlannedArriveTime(plan.stops[0], _virtualClock!) : null;

    final initialRecord = DepartureRecord(
      fromStopIndex: -1,
      fromPlaceName: originName,
      toStopIndex: 0,
      toPlaceName: plan.stops.isNotEmpty ? plan.stops[0].placeName : 'First Destination',
      actualDepartTime: _virtualClock!,
      plannedDepartTime: plannedStartTime,
      plannedStayMinutes: 0,
      overstayMinutes: 0,
      actualStayMinutes: 0,
      varianceMinutes: initVariance,
      varianceSummary: initSummary,
      explanation: initExplanation,
      plannedArriveTime: plannedArrive,
    );
    _departureRecords.add(initialRecord);

    notifyListeners();

    // Cache active running trip plan in local SharedPreferences for ADB sync & app restarts
    await _saveActiveTripToPrefs();

    // 1. Sync stops to Node.js Simulation Dashboard
    await syncToDashboard(plan);

    // 2. Start mock movement ticker
    _startMovementTicker();

    // 3. Start rapid dashboard polling (weather, traffic, telemetry)
    _startDashboardPolling();
  }

  /// Stop or reset Live Journey
  void stopJourney() {
    _isJourneyActive = false;
    _isArrived = false;
    _ticker?.cancel();
    _dashboardPollTimer?.cancel();
    _incidentDismissTimer?.cancel();
    _incidentDismissTimer = null;
    _activeIncident = null;
    _pendingStopOverstayMinutes = 0;
    _overrideCurrentStopName = null;
    _lastDismissedIncident = null;
    _lastDismissedTime = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('kiapenang_active_trip_plan');
    }).catchError((_) {});
    notifyListeners();
  }

  /// Completes and ends the active trip when user is at the final stop
  Future<CompletedTripSummary?> endAndCompleteTrip() async {
    if (_activePlan == null || _activePlan!.stops.isEmpty) return null;

    // 1. Ensure arrival at current (last) stop is fully recorded
    _isArrived = true;
    _recordArrivalAtCurrentStop();

    // 2. Finalize last stop in departure records if not already completed
    final lastIdx = _currentStopIndex;
    final lastStop = _activePlan!.stops[lastIdx];
    final lastStayMins = parseStayMinutes(lastStop.stayDuration);
    final lastOverstay = _pendingStopOverstayMinutes > 0
        ? _pendingStopOverstayMinutes
        : extractOverstayMinutes(_activeIncident);
    final totalLastStay = lastStayMins + lastOverstay;

    final arrRec = getArrivalRecordForStop(lastIdx);
    final baseArrive = arrRec?.actualArriveTime ?? _virtualClock ?? DateTime.now();
    final finalClock = baseArrive.add(Duration(minutes: totalLastStay));
    _virtualClock = finalClock;
    _virtualTimeString = formatVirtualClock(finalClock);

    // If no departure record exists for departing last stop, add concluding record
    if (getDepartureRecordForStop(lastIdx) == null) {
      final plannedDepart = parsePlannedDepartTime(lastStop, baseArrive);
      int varianceMins = 0;
      if (plannedDepart != null) {
        varianceMins = finalClock.difference(plannedDepart).inMinutes;
      }
      final varianceSummary = varianceMins == 0
          ? 'On Schedule (±0 min)'
          : (varianceMins > 0 ? '+$varianceMins min Late' : '${varianceMins.abs()} min Early');

      final finalRecord = DepartureRecord(
        fromStopIndex: lastIdx,
        fromPlaceName: lastStop.placeName,
        toStopIndex: lastIdx + 1,
        toPlaceName: 'Trail Conclusion',
        actualDepartTime: finalClock,
        plannedDepartTime: plannedDepart,
        plannedStayMinutes: lastStayMins,
        overstayMinutes: lastOverstay,
        actualStayMinutes: totalLastStay,
        varianceMinutes: varianceMins,
        varianceSummary: varianceSummary,
        explanation: lastOverstay > 0
            ? 'Completed trip with +$lastOverstay min overstay/waiting delay at ${lastStop.placeName}.'
            : 'Concluded trip journey on schedule at ${lastStop.placeName}.',
        actualArriveTime: baseArrive,
      );
      _departureRecords.add(finalRecord);
    }

    // 3. Calculate trip statistics
    final startTime = _departureRecords.isNotEmpty
        ? _departureRecords.first.actualDepartTime
        : (_virtualClock ?? DateTime.now());
    final endTime = finalClock;
    final totalTripDurationMinutes = max(1, endTime.difference(startTime).inMinutes);
    final int hours = totalTripDurationMinutes ~/ 60;
    final int minutes = totalTripDurationMinutes % 60;
    final durationStr = hours > 0 ? '$hours hrs $minutes mins' : '$minutes mins';

    int totalStayMins = 0;
    int totalOverstayMins = 0;
    for (final r in _departureRecords) {
      totalStayMins += r.actualStayMinutes;
      totalOverstayMins += r.overstayMinutes;
    }

    // 4. Build stop coordinates list for road-following path
    final List<Map<String, double>> stopCoords = [];
    if (_startLegLat != 0.0 && _startLegLng != 0.0) {
      stopCoords.add({'lat': _startLegLat, 'lng': _startLegLng});
    }
    for (final s in _activePlan!.stops) {
      stopCoords.add({'lat': s.lat, 'lng': s.lng});
    }

    // 5. Fetch realistic driving car path coordinates (OSRM with Catmull-Rom spline fallback)
    final roadCoords = await RoutePolylineService.fetchDrivingCarPath(stops: stopCoords);
    final totalDistanceKm = RoutePolylineService.calculateTotalDistanceKm(roadCoords);

    // Format date string (e.g. "Oct 15, 2026")
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[startTime.month - 1]} ${startTime.day.toString().padLeft(2, '0')}, ${startTime.year}';

    // 6. Build CompletedTripSummary
    final summary = CompletedTripSummary(
      planId: _activePlan!.id,
      planTitle: _activePlan!.cleanTitle,
      travelDateRange: _activePlan!.travelDateRange,
      totalDistanceKm: double.parse(totalDistanceKm.toStringAsFixed(1)),
      totalDurationStr: durationStr,
      startTime: startTime,
      endTime: endTime,
      totalStayMinutes: totalStayMins,
      totalOverstayMinutes: totalOverstayMins,
      stops: List.from(_activePlan!.stops),
      departureRecords: List.from(_departureRecords),
      routeCoordinates: roadCoords,
    );

    // 7. Save into CompletedTrailsManager (persisted to SharedPreferences for TravelPlansScreen)
    final trailRoute = TravelPlanRoute(
      planId: _activePlan!.id,
      title: _activePlan!.cleanTitle,
      date: dateStr,
      distance: double.parse(totalDistanceKm.toStringAsFixed(1)),
      duration: durationStr,
      stops: _activePlan!.stops.map((s) => s.placeName).toList(),
      routePoints: roadCoords,
      stopDetails: List.from(_activePlan!.stops),
    );
    await CompletedTrailsManager.addCompletedTrail(trailRoute);
    await CompletedTrailsManager.saveCompletedSummary(summary);

    // Mark plan as completed in SavedTripPlansManager and clear selected plan ID
    await SavedTripPlansManager.markPlanCompleted(_activePlan!.id);
    SavedTripPlansManager.setSelectedPlanId(null);

    // 8. Update service state
    _isTripCompleted = true;
    _completedTripSummary = summary;
    _isJourneyActive = false;
    _ticker?.cancel();
    _dashboardPollTimer?.cancel();
    _incidentDismissTimer?.cancel();
    _pendingStopOverstayMinutes = 0;

    // Remove active running trip plan from prefs so it doesn't resume as unfinished
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('kiapenang_active_trip_plan');
    } catch (_) {}

    // Pause / complete simulation on dashboard
    controlSimulation('pause');
    controlSimulation('setVirtualTime', finalClock.toIso8601String());

    notifyListeners();
    return summary;
  }

  /// Resets completed trip state so user can plan another trip
  Future<void> resetCompletedTrip() async {
    _isTripCompleted = false;
    _completedTripSummary = null;
    _activePlan = null;
    SavedTripPlansManager.setSelectedPlanId(null);
    await CompletedTrailsManager.clearCompletedSummary();
    stopJourney();
    notifyListeners();
  }

  /// Helper to handle an incident received from polling or triggered locally
  void _onNewIncidentReceived(String incidentText) {
    if (incidentText.isEmpty) {
      clearActiveIncident(fromDashboard: true);
      return;
    }

    // Ignore if user recently dismissed this identical incident in the last 35 seconds
    if (_lastDismissedIncident == incidentText &&
        _lastDismissedTime != null &&
        DateTime.now().difference(_lastDismissedTime!).inSeconds < 35) {
      return;
    }

    // Capture overstay minutes so departure calculation stays 100% accurate even after banner dismisses
    final overstay = extractOverstayMinutes(incidentText);
    if (overstay > 0) {
      _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, overstay);
    }

    if (_activeIncident != incidentText) {
      _activeIncident = incidentText;
      notifyListeners();
    }

    _scheduleIncidentAutoDismiss();
  }

  /// Automatically clears the incident label after 30 seconds
  void _scheduleIncidentAutoDismiss() {
    _incidentDismissTimer?.cancel();
    _incidentDismissTimer = Timer(const Duration(seconds: 30), () {
      clearActiveIncident();
    });
  }

  /// Clears active incident banner and notifies dashboard to clear
  void clearActiveIncident({bool fromDashboard = false}) {
    _incidentDismissTimer?.cancel();
    _incidentDismissTimer = null;
    if (_activeIncident != null) {
      _lastDismissedIncident = _activeIncident;
      _lastDismissedTime = DateTime.now();
      _activeIncident = null;
      notifyListeners();
    }
    if (!fromDashboard) {
      controlSimulation('clearIncident');
    }
  }

  /// Pause / Resume movement
  void togglePause() {
    _isPaused = !_isPaused;
    controlSimulation(_isPaused ? 'pause' : 'play');
    notifyListeners();
  }

  /// Set simulation speed multiplier (1x, 5x, 20x)
  void setSpeedMultiplier(int speed) {
    _speedMultiplier = speed;
    controlSimulation('setSpeed', speed);
    notifyListeners();
  }

  /// Set travel mode ('driving' or 'walking')
  void setTravelMode(String mode) {
    _travelMode = mode;
    controlSimulation('setMode', mode);
    notifyListeners();
  }

  /// Instant arrival at current stop (Teleport)
  void arriveNow() {
    if (!_isJourneyActive) return;
    _remainingDistanceMeters = 0;
    _remainingSeconds = 0;
    _testLegRemainingSeconds = 0;
    _currentLat = _targetLat;
    _currentLng = _targetLng;
    _isArrived = true;
    _recordArrivalAtCurrentStop();
    _syncLiveStatusToDashboard();
    notifyListeners();
  }

  /// Advance to the next stop on the itinerary
  void advanceToNextStop() {
    if (_activePlan == null || _activePlan!.stops.isEmpty) return;
    if (_currentStopIndex < _activePlan!.stops.length - 1) {
      final departingStop = _activePlan!.stops[_currentStopIndex];
      final nextStop = _activePlan!.stops[_currentStopIndex + 1];

      // 1. Calculate Stay Duration & Overstay
      final plannedStayMins = parseStayMinutes(departingStop.stayDuration);
      final overstayMins = _pendingStopOverstayMinutes > 0
          ? _pendingStopOverstayMinutes
          : extractOverstayMinutes(_activeIncident);
      final totalStayMins = plannedStayMins + overstayMins;

      // 2. Advance simulated virtual clock by stay duration + overstay
      final previousClock = _virtualClock ?? DateTime.now();
      final arrRecord = getArrivalRecordForStop(_currentStopIndex);
      final baseArriveTime = arrRecord?.actualArriveTime;

      DateTime newClock;
      if (baseArriveTime != null) {
        // Departure should be at least (baseArriveTime + totalStayMins)
        final targetDepart = baseArriveTime.add(Duration(minutes: totalStayMins));
        if (previousClock.isAfter(targetDepart)) {
          newClock = previousClock;
        } else {
          newClock = targetDepart;
        }
      } else {
        newClock = previousClock.add(Duration(minutes: totalStayMins));
      }
      _virtualClock = newClock;
      _virtualTimeString = formatVirtualClock(newClock);

      // Effective stay and overstay calculation based on actual arrival to departure
      final effectiveStayMins = baseArriveTime != null
          ? max(totalStayMins, newClock.difference(baseArriveTime).inMinutes)
          : totalStayMins;
      final effectiveOverstayMins = max(overstayMins, effectiveStayMins - plannedStayMins);

      // 3. Compute planned departure time & variance
      final plannedDepart = parsePlannedDepartTime(departingStop, previousClock);
      int varianceMinutes = 0;
      if (plannedDepart != null) {
        varianceMinutes = newClock.difference(plannedDepart).inMinutes;
      }

      String varianceSummary;
      if (varianceMinutes == 0) {
        varianceSummary = 'On Schedule (±0 min)';
      } else if (varianceMinutes > 0) {
        varianceSummary = '+$varianceMinutes min Late';
      } else {
        varianceSummary = '$varianceMinutes min Early';
      }

      // 4. Detailed explanation of why there is a difference ("为什么会差")
      String explanation;
      if (effectiveOverstayMins > 0) {
        explanation = 'Overstayed +$effectiveOverstayMins min at ${departingStop.placeName} (actual stay: $effectiveStayMins min vs planned $plannedStayMins min).';
        if (_activeIncident != null && _activeIncident!.isNotEmpty) {
          explanation += ' Incident: $_activeIncident';
        }
      } else if (varianceMinutes > 0) {
        explanation = 'Departed $varianceMinutes min behind plan due to accumulated journey delays along itinerary.';
      } else if (varianceMinutes < 0) {
        explanation = 'Departed ${varianceMinutes.abs()} min ahead of schedule, providing extra leeway for next stops.';
      } else {
        explanation = 'Departed on time according to planned itinerary (completed $plannedStayMins min stay).';
      }

      final nextPlannedArrive = parsePlannedArriveTime(nextStop, newClock);

      final record = DepartureRecord(
        fromStopIndex: _currentStopIndex,
        fromPlaceName: departingStop.placeName,
        toStopIndex: _currentStopIndex + 1,
        toPlaceName: nextStop.placeName,
        actualDepartTime: newClock,
        plannedDepartTime: plannedDepart,
        plannedStayMinutes: plannedStayMins,
        overstayMinutes: effectiveOverstayMins,
        actualStayMinutes: effectiveStayMins,
        varianceMinutes: varianceMinutes,
        varianceSummary: varianceSummary,
        explanation: explanation,
        incidentTriggered: effectiveOverstayMins > 0 ? (_activeIncident ?? 'Wait/Overstay +${effectiveOverstayMins}m') : null,
        plannedArriveTime: nextPlannedArrive,
      );
      _departureRecords.add(record);

      // Clear consumed overstay incident so it does not affect future stops
      if (effectiveOverstayMins > 0) {
        _pendingStopOverstayMinutes = 0;
        clearActiveIncident();
      }

      // Sync new virtual clock to dashboard immediately
      controlSimulation('setVirtualTime', newClock.toIso8601String());

      _currentStopIndex++;
      _isArrived = false;
      _startLegLat = _currentLat;
      _startLegLng = _currentLng;
      _targetLat = nextStop.lat;
      _targetLng = nextStop.lng;
      _overrideCurrentStopName = nextStop.placeName;

      _totalLegDistanceMeters = _calculateHaversineDistance(_startLegLat, _startLegLng, _targetLat, _targetLng);
      if (_totalLegDistanceMeters < 300) _totalLegDistanceMeters = 1500;
      _remainingDistanceMeters = _totalLegDistanceMeters;

      // Calculate planned transit minutes between departing stop depart time and next stop arrive time
      final nextArrive = parsePlannedArriveTime(nextStop, newClock);
      final prevPlannedDepart = parsePlannedDepartTime(departingStop, previousClock);
      final plannedTransitMins = calculatePlannedTransitMinutes(
        distanceMeters: _totalLegDistanceMeters,
        fromTime: prevPlannedDepart ?? previousClock,
        toTime: nextArrive,
      );
      _legPlannedTransitMinutes = plannedTransitMins;
      // Convert planned transit minutes into test seconds (10 mins -> 10 sec, 20 mins -> 20 sec)
      _testLegTotalSeconds = max(3, plannedTransitMins);
      _testLegRemainingSeconds = _testLegTotalSeconds.toDouble();
      _remainingSeconds = _legPlannedTransitMinutes * 60;

      // Update cached active trip plan with new currentStopIndex, virtual time, and departure records
      _saveActiveTripToPrefs();

      // Notify dashboard to visit target stop
      controlSimulation('visitStop', _currentStopIndex);
      notifyListeners();
    } else {
      _isArrived = true;
      _recordArrivalAtCurrentStop();
      notifyListeners();
    }
  }

  /// Records destination arrival timing, planned arrival comparison, and variance
  void _recordArrivalAtCurrentStop() {
    if (_virtualClock == null || _activePlan == null || _activePlan!.stops.isEmpty) return;
    final current = currentStop;
    if (current == null) return;

    final plannedArrive = parsePlannedArriveTime(current, _virtualClock!);
    final actualArrive = _virtualClock!;
    int arriveDiff = 0;
    if (plannedArrive != null) {
      arriveDiff = actualArrive.difference(plannedArrive).inMinutes;
    }
    final arriveSummary = arriveDiff == 0
        ? 'On Schedule (±0 min)'
        : (arriveDiff > 0 ? '+$arriveDiff min Late' : '${arriveDiff.abs()} min Early');

    if (_departureRecords.isNotEmpty && _departureRecords.last.toStopIndex == _currentStopIndex) {
      final lastRec = _departureRecords.last;
      _departureRecords[_departureRecords.length - 1] = lastRec.copyWith(
        actualArriveTime: actualArrive,
        plannedArriveTime: plannedArrive ?? lastRec.plannedArriveTime,
        arriveVarianceMinutes: arriveDiff,
        arriveVarianceSummary: arriveSummary,
      );
    } else {
      final originName = _currentStopIndex > 0 ? _activePlan!.stops[_currentStopIndex - 1].placeName : originStopName;
      final plannedDepart = plannedArrive != null ? plannedArrive.subtract(const Duration(minutes: 15)) : _virtualClock;
      final record = DepartureRecord(
        fromStopIndex: _currentStopIndex - 1,
        fromPlaceName: originName,
        toStopIndex: _currentStopIndex,
        toPlaceName: current.placeName,
        actualDepartTime: _virtualClock!,
        plannedDepartTime: plannedDepart,
        plannedStayMinutes: parseStayMinutes(current.stayDuration),
        actualStayMinutes: parseStayMinutes(current.stayDuration),
        varianceMinutes: 0,
        varianceSummary: 'On Schedule (±0 min)',
        explanation: 'Dynamic detour stop visited.',
        actualArriveTime: actualArrive,
        plannedArriveTime: plannedArrive,
        arriveVarianceMinutes: arriveDiff,
        arriveVarianceSummary: arriveSummary,
      );
      _departureRecords.add(record);
    }
    _saveActiveTripToPrefs();
  }

  /// Centralized persistence of active trip state to SharedPreferences
  Future<void> _saveActiveTripToPrefs() async {
    if (_activePlan == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final activePayload = {
        'id': _activePlan!.id,
        'title': _activePlan!.cleanTitle,
        'travelDateRange': _activePlan!.travelDateRange,
        'travelSchedule': _activePlan!.travelSchedule,
        'travelArea': _activePlan!.displayArea,
        'virtualStartTime': _virtualClock?.toIso8601String() ?? _virtualTimeString,
        'currentStopIndex': _currentStopIndex,
        'startLat': _startLegLat,
        'startLng': _startLegLng,
        'originName': _customOriginName,
        'departureRecords': _departureRecords.map((r) => r.toJson()).toList(),
        'stops': _activePlan!.stops.map((s) => s.toJson()).toList(),
      };
      await prefs.setString('kiapenang_active_trip_plan', json.encode(activePayload));
      await prefs.setString('kiapenang_selected_plan_id', _activePlan!.id);
    } catch (e) {
      debugPrint('Error caching active trip plan: $e');
    }
  }

  bool _isSyncingToDashboard = false;

  /// Sync itinerary stops to the Simulation Dashboard HTTP API
  Future<bool> syncToDashboard(SavedTripPlan plan) async {
    if (_isSyncingToDashboard) return false;
    _isSyncingToDashboard = true;
    try {
      final payload = json.encode({
        'planId': plan.id,
        'planTitle': plan.cleanTitle,
        'travelDateRange': plan.travelDateRange,
        'travelSchedule': plan.travelSchedule,
        'travelArea': plan.displayArea,
        'stops': plan.stops.map((s) => {
          ...s.toJson(),
          'stayMinutes': parseStayMinutes(s.stayDuration),
        }).toList(),
        'virtualStartTime': _virtualClock?.toIso8601String() ?? _virtualTimeString,
        'currentStopIndex': _currentStopIndex,
        'isArrived': _isArrived,
        'startLat': _startLegLat,
        'startLng': _startLegLng,
        'originName': _customOriginName,
      });

      final targetHosts = <String>[];
      if (_activeDashboardHost.isNotEmpty) {
        targetHosts.add(_activeDashboardHost);
      }
      targetHosts.addAll(_candidateHosts);
      final orderedHosts = targetHosts.toSet().toList();

      for (final host in orderedHosts) {
        try {
          final syncUrl = Uri.parse('$host/api/simulation/sync-from-phone');
          final res = await http.post(
            syncUrl,
            headers: {'Content-Type': 'application/json'},
            body: payload,
          ).timeout(const Duration(milliseconds: 1500));

          if (res.statusCode == 200) {
            debugPrint('🛰️ [LIVE JOURNEY] Successfully synced plan to dashboard at $host');
            _dashboardConnected = true;
            _activeDashboardHost = host;

            // Trigger dashboard 'play'
            try {
              final playUrl = Uri.parse('$host/api/simulation/control');
              await http.post(
                playUrl,
                headers: {'Content-Type': 'application/json'},
                body: json.encode({'action': 'play'}),
              ).timeout(const Duration(milliseconds: 1000));
            } catch (_) {}

            notifyListeners();
            return true;
          }
        } catch (_) {
          // Try next candidate
        }
      }

      _dashboardConnected = false;
      notifyListeners();
      return false;
    } finally {
      _isSyncingToDashboard = false;
    }
  }

  /// Sends control command to the dashboard ('play', 'pause', 'setSpeed', 'setMode', etc.)
  Future<bool> controlSimulation(String action, [dynamic value]) async {
    try {
      final url = Uri.parse('$_activeDashboardHost/api/simulation/control');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': action, 'value': value}),
      ).timeout(const Duration(milliseconds: 1200));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Pushes real-time journey transit telemetry & status to Dashboard to ensure zero status mismatch
  Future<void> _syncLiveStatusToDashboard() async {
    if (!_dashboardConnected && _activeDashboardHost.isEmpty) return;
    try {
      final url = Uri.parse('$_activeDashboardHost/api/simulation/control');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'updateJourneyState',
          'value': {
            'currentStopIndex': _currentStopIndex,
            'isArrived': _isArrived,
            'currentLat': _currentLat,
            'currentLng': _currentLng,
            'remainingDistanceMeters': _remainingDistanceMeters,
            'remainingDurationSeconds': _remainingSeconds,
            'virtualTimeString': _virtualTimeString,
          }
        }),
      ).timeout(const Duration(milliseconds: 800));
    } catch (_) {}
  }

  /// TESTER MOCK: Inject or mock weather data into the app AND pass to the dashboard
  Future<bool> injectWeather({
    required String condition,
    required double temp,
    int humidity = 70,
    String location = 'George Town',
  }) async {
    // 1. Immediately update local app state
    _weatherCondition = condition;
    _weatherTemp = temp;
    _weatherHumidity = humidity;
    _weatherLocation = location;
    notifyListeners();

    // 2. Broadcast to Dashboard
    try {
      final url = Uri.parse('$_activeDashboardHost/api/weather');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'condition': condition,
          'temperature': temp,
          'humidity': humidity,
          'location': location,
        }),
      ).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// TESTER MOCK: Inject or mock traffic / incidents into the app AND pass to the dashboard
  Future<bool> injectIncident(String scenarioId) async {
    // 1. Immediately simulate in app
    switch (scenarioId) {
      case 'traffic_jam':
        _activeIncident = '🚗 Traffic Jam: Heavy congestion (+15 min ETA)';
        _remainingSeconds += 900;
        break;
      case 'road_closure':
        _activeIncident = '🚧 Road Closure: Obstacle ahead, detour reroute applied (+280m)';
        _remainingDistanceMeters += 280;
        _remainingSeconds += 240;
        break;
      case 'rain_stick_plan':
        _weatherCondition = 'rainy';
        _weatherTemp = 26;
        _activeIncident = '🌧️ Rain Alert: Sticking to plan with umbrella';
        break;
      case 'rain_indoor_backup':
        _weatherCondition = 'thunderstorm';
        _weatherTemp = 25;
        _travelMode = 'driving';
        _activeIncident = '🏢 Rain Alert: Grab rerouting to nearest indoor mall';
        break;
      case 'food_detour':
        _activeIncident = '🍽️ Food Detour: Rerouted for Lorong Selamat Char Koay Teow';
        break;
      case 'overstay':
      case 'overstay_15':
        _activeIncident = '📸 Overstay Alert: +15 mins extra stay taking photos & lingering';
        _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, 15);
        break;
      case 'overstay_30':
        _activeIncident = '📸 Overstay Alert: +30 mins extended stay exploring venue';
        _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, 30);
        break;
      case 'overstay_60':
        _activeIncident = '📸 Overstay Alert: +60 mins extended stay (+1 Hour)';
        _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, 60);
        break;
      case 'rain_wait_out':
        _weatherCondition = 'rainy';
        _weatherTemp = 26;
        _activeIncident = '☕ Rain Alert: Sheltered from rain for 10 mins (避雨等待 10 分钟)';
        _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, 10);
        break;
      case 'rain_cleared':
        _weatherCondition = 'cloudy';
        _weatherTemp = 30;
        _activeIncident = '☀️ Rain Cleared: Rain stopped after 20m wait; resuming trip (等待20分钟放晴恢复)';
        _pendingStopOverstayMinutes = max(_pendingStopOverstayMinutes, 20);
        break;
      default:
        _activeIncident = '⚡ Incident: $scenarioId simulated';
    }
    if (_activeIncident != null && _activeIncident!.isNotEmpty) {
      _scheduleIncidentAutoDismiss();
    }
    notifyListeners();

    // 2. Broadcast to Dashboard
    try {
      final url = Uri.parse('$_activeDashboardHost/api/simulation/incident');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'scenarioId': scenarioId}),
      ).timeout(const Duration(milliseconds: 1500));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Internal simulation movement ticker running every 1 second
  void _startMovementTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isJourneyActive || _isPaused || _isArrived) return;

      final stepTestSeconds = 1.0 * _speedMultiplier;
      _testLegRemainingSeconds -= stepTestSeconds;

      if (_testLegRemainingSeconds <= 0) {
        _testLegRemainingSeconds = 0;
        _remainingDistanceMeters = 0;
        _remainingSeconds = 0;
        _currentLat = _targetLat;
        _currentLng = _targetLng;
        _isArrived = true;

        // Advance virtual clock for remaining time
        if (_virtualClock != null) {
          _virtualClock = _virtualClock!.add(Duration(seconds: (stepTestSeconds * 60).round()));
          _virtualTimeString = formatVirtualClock(_virtualClock!);
        }

        _recordArrivalAtCurrentStop();
        _syncLiveStatusToDashboard();
        notifyListeners();
        return;
      }

      // Progress fraction along this leg (0.0 to 1.0)
      final fraction = (1.0 - (_testLegRemainingSeconds / _testLegTotalSeconds)).clamp(0.0, 1.0);
      _remainingDistanceMeters = max(0.0, _totalLegDistanceMeters * (1.0 - fraction));

      // Display remaining transit minutes in UI
      _remainingSeconds = max(0, (_legPlannedTransitMinutes * 60 * (1.0 - fraction)).round());

      // Live GPS coordinates moving along the route
      _currentLat = _startLegLat + (_targetLat - _startLegLat) * fraction;
      _currentLng = _startLegLng + (_targetLng - _startLegLng) * fraction;

      // Virtual clock advances: 1 test second = 1 virtual minute (60 seconds) scaled by speedMultiplier!
      if (_virtualClock != null) {
        _virtualClock = _virtualClock!.add(Duration(seconds: (stepTestSeconds * 60).round()));
        _virtualTimeString = formatVirtualClock(_virtualClock!);
      }

      _syncLiveStatusToDashboard();
      notifyListeners();
    });
  }

  /// Polls dashboard simulation state & weather every 1.5 seconds
  void _startDashboardPolling() {
    _dashboardPollTimer?.cancel();
    _dashboardPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!_isJourneyActive) return;

      // 1. Poll Simulation State
      final pollHosts = <String>[];
      if (_activeDashboardHost.isNotEmpty) {
        pollHosts.add(_activeDashboardHost);
      }
      pollHosts.addAll(_candidateHosts);
      final orderedPollHosts = pollHosts.toSet().toList();

      for (final host in orderedPollHosts) {
        try {
          final stateUrl = Uri.parse('$host/api/simulation/state');
          final stateRes = await http.get(stateUrl).timeout(const Duration(milliseconds: 1200));

          if (stateRes.statusCode == 200) {
            final data = json.decode(utf8.decode(stateRes.bodyBytes));
            if (data['code'] == 200 && data['data'] != null) {
              final sim = data['data'];
              _dashboardConnected = true;
              _activeDashboardHost = host;

              // If the app has an active journey and the dashboard is running a different plan,
              // automatically sync the active journey plan to the dashboard so dashboard always tracks the active trip!
              if (_isJourneyActive && _activePlan != null) {
                final dashTitle = (sim['planTitle'] ?? '').toString();
                if (dashTitle.isNotEmpty &&
                    dashTitle != _activePlan!.cleanTitle &&
                    !dashTitle.contains(_activePlan!.cleanTitle) &&
                    !dashTitle.contains('Detour')) {
                  debugPrint('🛰️ [LIVE JOURNEY] Dashboard plan mismatch ("$dashTitle" != "${_activePlan!.cleanTitle}"). Auto-syncing active plan to dashboard...');
                  syncToDashboard(_activePlan!);
                  return;
                }
              }

              // Synchronize stops (including dynamically added Detour stops) from Dashboard to User App
              if (_isJourneyActive && _activePlan != null && sim['stops'] != null && sim['stops'] is List) {
                final rawDashStops = List<Map<String, dynamic>>.from(sim['stops']);
                _dashboardStops = rawDashStops;

                bool stopsDiffer = rawDashStops.length != _activePlan!.stops.length;
                if (!stopsDiffer) {
                  for (int i = 0; i < rawDashStops.length; i++) {
                    final dName = (rawDashStops[i]['nameEn'] ?? rawDashStops[i]['name'] ?? rawDashStops[i]['placeName'])?.toString() ?? '';
                    if (dName.isNotEmpty && dName != _activePlan!.stops[i].placeName) {
                      stopsDiffer = true;
                      break;
                    }
                  }
                }

                if (stopsDiffer) {
                  debugPrint('🔄 [LIVE JOURNEY] Detour/Stops updated from dashboard (${rawDashStops.length} stops vs active plan ${_activePlan!.stops.length}). Syncing into active plan...');
                  final List<SavedPlanStop> updatedStops = [];
                  for (int i = 0; i < rawDashStops.length; i++) {
                    final d = rawDashStops[i];
                    final dName = (d['nameEn'] ?? d['name'] ?? d['placeName'] ?? 'Penang Attraction').toString();

                    final existingIndex = _activePlan!.stops.indexWhere((s) => s.placeName == dName);
                    if (existingIndex != -1) {
                      final existing = _activePlan!.stops[existingIndex];
                      updatedStops.add(SavedPlanStop(
                        stopNumber: i + 1,
                        placeName: existing.placeName,
                        area: existing.area,
                        category: existing.category,
                        timeSlot: existing.timeSlot,
                        stayDuration: existing.stayDuration,
                        pennyTip: existing.pennyTip,
                        adjustmentReason: existing.adjustmentReason,
                        isAdjusted: existing.isAdjusted,
                        imageUrl: existing.imageUrl,
                        address: existing.address,
                        lat: existing.lat,
                        lng: existing.lng,
                      ));
                    } else {
                      final isDetour = dName.contains('[Detour]') || dName.contains('[改道]') || d['isDetour'] == true;
                      final lat = (d['lat'] as num?)?.toDouble() ?? 5.414;
                      final lng = (d['lng'] as num?)?.toDouble() ?? 100.328;
                      final area = (d['area'] ?? _activePlan!.displayArea).toString();
                      final stayMinutes = (d['stayMinutes'] as num?)?.toInt() ?? 20;
                      final stayDuration = d['stayDuration']?.toString() ?? '$stayMinutes mins';
                      final timeSlot = d['timeSlot']?.toString() ?? '${_virtualTimeString.split(',').last.trim()} - Live';

                      updatedStops.add(SavedPlanStop(
                        stopNumber: i + 1,
                        placeName: dName,
                        area: area,
                        category: isDetour ? 'Detour Cafe / Hawker' : (d['category']?.toString() ?? 'Attraction'),
                        timeSlot: timeSlot,
                        stayDuration: stayDuration,
                        pennyTip: isDetour
                            ? '✨ Dynamic detour added from Live Dashboard!'
                            : 'Popular stop along your updated route.',
                        adjustmentReason: isDetour ? 'Added via Live Dashboard Detour' : 'Itinerary Reroute',
                        isAdjusted: true,
                        lat: lat,
                        lng: lng,
                      ));
                    }
                  }

                  _activePlan = _activePlan!.copyWith(stops: updatedStops);
                  _saveActiveTripToPrefs();
                }

                // Sync currentStopIndex
                if (sim['currentStopIndex'] != null) {
                  final dashIndex = (sim['currentStopIndex'] as num).toInt();
                  final bool dashIsArrived = sim['isStaying'] == true ||
                      (dashIndex < rawDashStops.length && rawDashStops[dashIndex]['status'] == 'ARRIVED');

                  if (dashIndex != _currentStopIndex && (stopsDiffer || dashIndex > _currentStopIndex || dashIsArrived)) {
                    _currentStopIndex = dashIndex.clamp(0, _activePlan!.stops.length - 1);
                    final current = _activePlan!.stops[_currentStopIndex];
                    _targetLat = current.lat;
                    _targetLng = current.lng;
                    _overrideCurrentStopName = current.placeName;

                    if (_currentStopIndex > 0) {
                      final prev = _activePlan!.stops[_currentStopIndex - 1];
                      _startLegLat = prev.lat;
                      _startLegLng = prev.lng;
                    }

                    if (dashIsArrived) {
                      _isArrived = true;
                      _remainingDistanceMeters = 0;
                      _remainingSeconds = 0;
                      _testLegRemainingSeconds = 0;
                      _currentLat = _targetLat;
                      _currentLng = _targetLng;
                      _recordArrivalAtCurrentStop();
                    } else {
                      _isArrived = false;
                      _totalLegDistanceMeters = _calculateHaversineDistance(_startLegLat, _startLegLng, _targetLat, _targetLng);
                      if (_totalLegDistanceMeters < 300) _totalLegDistanceMeters = 1500;
                      _remainingDistanceMeters = _totalLegDistanceMeters;
                      _testLegTotalSeconds = max(3, _legPlannedTransitMinutes);
                      _testLegRemainingSeconds = _testLegTotalSeconds.toDouble();
                    }
                    _saveActiveTripToPrefs();
                  }
                }
              }

              // Only pull distance/GPS from dashboard if app is not actively driving the leg
              if (!_isJourneyActive || _isArrived) {
                if (sim['remainingDistanceMeters'] != null) {
                  final d = (sim['remainingDistanceMeters'] as num).toDouble();
                  if (d >= 0) _remainingDistanceMeters = d;
                }
                if (sim['totalDistanceMeters'] != null) {
                  final tot = (sim['totalDistanceMeters'] as num).toDouble();
                  if (tot > 0) _totalLegDistanceMeters = tot;
                }
                if (sim['remainingDurationSeconds'] != null) {
                  final s = (sim['remainingDurationSeconds'] as num).toInt();
                  if (s >= 0) _remainingSeconds = s;
                }
                if (sim['currentLat'] != null && sim['currentLng'] != null) {
                  _currentLat = (sim['currentLat'] as num).toDouble();
                  _currentLng = (sim['currentLng'] as num).toDouble();
                }
              }

              if (sim['activeIncident'] != null) {
                final incStr = sim['activeIncident']?.toString() ?? '';
                if (incStr.isNotEmpty) {
                  _onNewIncidentReceived(incStr);
                } else if (_activeIncident != null) {
                  clearActiveIncident(fromDashboard: true);
                }
              } else if (_activeIncident != null) {
                clearActiveIncident(fromDashboard: true);
              }
              if (sim['playbackSpeed'] != null) {
                final spd = (sim['playbackSpeed'] as num).toInt();
                if (spd > 0) _speedMultiplier = spd;
              }
              if (sim['isPlaying'] != null) {
                _isPaused = !(sim['isPlaying'] as bool);
              }
              // Only sync virtual clock from dashboard if app is paused or arrived
              if (_isPaused || _isArrived) {
                if (sim['virtualTimeString'] != null) {
                  final dashTimeStr = sim['virtualTimeString'].toString();
                  _virtualTimeString = dashTimeStr;
                  final parsed = parseVirtualClock(dashTimeStr);
                  if (parsed != null) {
                    _virtualClock = parsed;
                  }
                }
              }
              if (sim['travelMode'] != null) {
                _travelMode = sim['travelMode'].toString();
              }
              if (sim['stops'] != null && sim['stops'] is List) {
                _dashboardStops = List<Map<String, dynamic>>.from(sim['stops']);
                if (_currentStopIndex < _dashboardStops.length) {
                  final cur = _dashboardStops[_currentStopIndex];
                  _overrideCurrentStopName = (cur['nameEn'] ?? cur['name'])?.toString();
                }
              }
              // CRUCIAL: Do NOT let dashboard polling falsely overwrite _isArrived while app is actively traveling!
              if (_isJourneyActive && !_isArrived && _testLegRemainingSeconds > 0) {
                // App is driving, keep _isArrived = false
              } else if (sim['isStaying'] == true ||
                  (_dashboardStops.isNotEmpty && _currentStopIndex < _dashboardStops.length && _dashboardStops[_currentStopIndex]['status'] == 'ARRIVED') ||
                  _remainingDistanceMeters <= 10) {
                if (!_isArrived) {
                  _isArrived = true;
                  _remainingDistanceMeters = 0;
                  _remainingSeconds = 0;
                  _testLegRemainingSeconds = 0;
                  _currentLat = _targetLat;
                  _currentLng = _targetLng;
                  _recordArrivalAtCurrentStop();
                }
              } else {
                _isArrived = false;
              }

              // 2. Poll Weather from same working host
              try {
                final weatherUrl = Uri.parse('$host/api/weather');
                final weatherRes = await http.get(weatherUrl).timeout(const Duration(milliseconds: 800));
                if (weatherRes.statusCode == 200) {
                  final wData = json.decode(utf8.decode(weatherRes.bodyBytes));
                  if (wData['data'] != null) {
                    final w = wData['data'];
                    if (w['condition'] != null) _weatherCondition = w['condition'].toString();
                    if (w['temperature'] != null) _weatherTemp = (w['temperature'] as num).toDouble();
                    if (w['humidity'] != null) _weatherHumidity = (w['humidity'] as num).toInt();
                    if (w['location'] != null) _weatherLocation = w['location'].toString();
                  }
                }
              } catch (_) {}

              notifyListeners();
              return;
            }
          }
        } catch (_) {
          // Continue to next candidate
        }
      }

      _dashboardConnected = false;
      notifyListeners();
    });
  }

  /// Haversine distance formula in meters
  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742000 * asin(sqrt(a)); // 2 * R * 1000
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _dashboardPollTimer?.cancel();
    super.dispose();
  }
}

/// Model representing a predefined top hotel in a Penang area for mocking real-time location
class MockHotelLocation {
  final String area;
  final String hotelName;
  final double lat;
  final double lng;

  const MockHotelLocation({
    required this.area,
    required this.hotelName,
    required this.lat,
    required this.lng,
  });
}

/// Registry of Penang hotels mapped to each area with verified GPS coordinates:
/// 1. Georgetown, Eastern & Oriental Hotel (5.4233, 100.3359)
/// 2. Batu Ferringhi, Rasa Sayang Resort & Spa by Shangri-La (5.4781, 100.2536)
/// 3. Gurney Drive, Ascott Gurney Penang (5.4318, 100.3192)
/// 4. Air Itam, Harris Hotel & Conventions Sunshine Penang (5.3988, 100.2874)
/// 5. Teluk Bahang, Angsana Teluk Bahang (5.4622, 100.2200)
/// 6. Balik Pulau, Audi Guest House (5.3122, 100.2068)
/// 7. Bayan Lepas, Amari SPICE Penang (5.3302, 100.2813)
/// 8. Tanjung Bungah, Hompton by the Beach Penang (5.4635, 100.3052)
/// 9. Butterworth, Crowne Plaza Penang Straits City (5.4042, 100.3683)
class MockHotelRegistry {
  static const List<MockHotelLocation> hotels = [
    // 1. Georgetown, Eastern & Oriental Hotel
    MockHotelLocation(
      area: 'Georgetown',
      hotelName: 'Eastern & Oriental Hotel',
      lat: 5.4233,
      lng: 100.3359,
    ),
    // 2. Batu Ferringhi, Rasa Sayang Resort & Spa by Shangri-La
    MockHotelLocation(
      area: 'Batu Ferringhi',
      hotelName: 'Rasa Sayang Resort & Spa by Shangri-La',
      lat: 5.4781,
      lng: 100.2536,
    ),
    // 3. Gurney Drive, Ascott Gurney Penang
    MockHotelLocation(
      area: 'Gurney Drive',
      hotelName: 'Ascott Gurney Penang',
      lat: 5.4318,
      lng: 100.3192,
    ),
    // 4. Air Itam, Harris Hotel & Conventions Sunshine Penang
    MockHotelLocation(
      area: 'Air Itam',
      hotelName: 'Harris Hotel & Conventions Sunshine Penang',
      lat: 5.3988,
      lng: 100.2874,
    ),
    // 5. Teluk Bahang, Angsana Teluk Bahang
    MockHotelLocation(
      area: 'Teluk Bahang',
      hotelName: 'Angsana Teluk Bahang',
      lat: 5.4622,
      lng: 100.2200,
    ),
    // 6. Balik Pulau, Audi Guest House
    MockHotelLocation(
      area: 'Balik Pulau',
      hotelName: 'Audi Guest House',
      lat: 5.3122,
      lng: 100.2068,
    ),
    // 7. Bayan Lepas, Amari SPICE Penang
    MockHotelLocation(
      area: 'Bayan Lepas',
      hotelName: 'Amari SPICE Penang',
      lat: 5.3302,
      lng: 100.2813,
    ),
    // 8. Tanjung Bungah, Hompton by the Beach Penang
    MockHotelLocation(
      area: 'Tanjung Bungah',
      hotelName: 'Hompton by the Beach Penang',
      lat: 5.4635,
      lng: 100.3052,
    ),
    // 9. Butterworth, Crowne Plaza Penang Straits City
    MockHotelLocation(
      area: 'Butterworth',
      hotelName: 'Crowne Plaza Penang Straits City',
      lat: 5.4042,
      lng: 100.3683,
    ),
  ];

  /// Finds the corresponding mock hotel based on the stop's area name
  static MockHotelLocation findForArea(String? areaName) {
    if (areaName == null || areaName.trim().isEmpty) {
      return hotels[0]; // Georgetown default
    }
    final normalized = areaName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

    if (normalized.contains('ferringhi')) {
      return hotels[1];
    } else if (normalized.contains('gurney')) {
      return hotels[2];
    } else if (normalized.contains('airitam') ||
        normalized.contains('ayeritam') ||
        normalized.contains('itam')) {
      return hotels[3];
    } else if (normalized.contains('telukbahang') ||
        normalized.contains('bahang')) {
      return hotels[4];
    } else if (normalized.contains('balikpulau') ||
        normalized.contains('pulau')) {
      return hotels[5];
    } else if (normalized.contains('bayanlepas') ||
        normalized.contains('spice') ||
        normalized.contains('lepas')) {
      return hotels[6];
    } else if (normalized.contains('tanjungbungah') ||
        normalized.contains('bungah') ||
        normalized.contains('tanjongbungah') ||
        normalized.contains('tanjungtokong') ||
        normalized.contains('tokong')) {
      return hotels[7];
    } else if (normalized.contains('butterworth') ||
        normalized.contains('seberang') ||
        normalized.contains('perai')) {
      return hotels[8];
    } else {
      return hotels[0]; // Default: Georgetown (Eastern & Oriental Hotel)
    }
  }
}

/// Model representing departure & arrival info and schedule variance from a previous location to a destination
class DepartureRecord {
  final int fromStopIndex; // index of origin stop (-1 for starting hotel/origin, 0 for stop 1, etc.)
  final String fromPlaceName; // e.g. "Armenian Street Murals" or "Hotel Jen George Town"
  final int toStopIndex; // index of destination stop (e.g. 0 for stop 1, 1 for stop 2, etc.)
  final String toPlaceName; // e.g. "Chew Jetty"
  final DateTime actualDepartTime; // The virtual/simulated departure time
  final DateTime? plannedDepartTime; // The planned departure time from the itinerary
  final int plannedStayMinutes; // Scheduled stay duration in minutes (e.g. 65 min)
  final int overstayMinutes; // Overstay duration in minutes (e.g. 15 min if overstay occurred)
  final int actualStayMinutes; // Total stay: plannedStayMinutes + overstayMinutes
  final int varianceMinutes; // actualDepartTime - plannedDepartTime (positive = late, negative = early)
  final String varianceSummary; // e.g. "+15 min Late", "On Schedule (±0 min)", "-10 min Early"
  final String explanation; // Plain explanation of why it differed ("为什么会差")
  final String? incidentTriggered; // The incident trigger string (if any)

  // Arrival Timing & Variance
  final DateTime? actualArriveTime; // The virtual/simulated arrival time at destination
  final DateTime? plannedArriveTime; // The planned arrival time from itinerary
  final int? arriveVarianceMinutes; // actualArriveTime - plannedArriveTime
  final String? arriveVarianceSummary; // e.g. "+21 min Late", "On Schedule", "5 min Early"

  const DepartureRecord({
    required this.fromStopIndex,
    required this.fromPlaceName,
    required this.toStopIndex,
    required this.toPlaceName,
    required this.actualDepartTime,
    this.plannedDepartTime,
    required this.plannedStayMinutes,
    this.overstayMinutes = 0,
    required this.actualStayMinutes,
    required this.varianceMinutes,
    required this.varianceSummary,
    required this.explanation,
    this.incidentTriggered,
    this.actualArriveTime,
    this.plannedArriveTime,
    this.arriveVarianceMinutes,
    this.arriveVarianceSummary,
  });

  DepartureRecord copyWith({
    int? fromStopIndex,
    String? fromPlaceName,
    int? toStopIndex,
    String? toPlaceName,
    DateTime? actualDepartTime,
    DateTime? plannedDepartTime,
    int? plannedStayMinutes,
    int? overstayMinutes,
    int? actualStayMinutes,
    int? varianceMinutes,
    String? varianceSummary,
    String? explanation,
    String? incidentTriggered,
    DateTime? actualArriveTime,
    DateTime? plannedArriveTime,
    int? arriveVarianceMinutes,
    String? arriveVarianceSummary,
  }) {
    return DepartureRecord(
      fromStopIndex: fromStopIndex ?? this.fromStopIndex,
      fromPlaceName: fromPlaceName ?? this.fromPlaceName,
      toStopIndex: toStopIndex ?? this.toStopIndex,
      toPlaceName: toPlaceName ?? this.toPlaceName,
      actualDepartTime: actualDepartTime ?? this.actualDepartTime,
      plannedDepartTime: plannedDepartTime ?? this.plannedDepartTime,
      plannedStayMinutes: plannedStayMinutes ?? this.plannedStayMinutes,
      overstayMinutes: overstayMinutes ?? this.overstayMinutes,
      actualStayMinutes: actualStayMinutes ?? this.actualStayMinutes,
      varianceMinutes: varianceMinutes ?? this.varianceMinutes,
      varianceSummary: varianceSummary ?? this.varianceSummary,
      explanation: explanation ?? this.explanation,
      incidentTriggered: incidentTriggered ?? this.incidentTriggered,
      actualArriveTime: actualArriveTime ?? this.actualArriveTime,
      plannedArriveTime: plannedArriveTime ?? this.plannedArriveTime,
      arriveVarianceMinutes: arriveVarianceMinutes ?? this.arriveVarianceMinutes,
      arriveVarianceSummary: arriveVarianceSummary ?? this.arriveVarianceSummary,
    );
  }

  Map<String, dynamic> toJson() => {
    'fromStopIndex': fromStopIndex,
    'fromPlaceName': fromPlaceName,
    'toStopIndex': toStopIndex,
    'toPlaceName': toPlaceName,
    'actualDepartTime': actualDepartTime.toIso8601String(),
    'plannedDepartTime': plannedDepartTime?.toIso8601String(),
    'plannedStayMinutes': plannedStayMinutes,
    'overstayMinutes': overstayMinutes,
    'actualStayMinutes': actualStayMinutes,
    'varianceMinutes': varianceMinutes,
    'varianceSummary': varianceSummary,
    'explanation': explanation,
    'incidentTriggered': incidentTriggered,
    'actualArriveTime': actualArriveTime?.toIso8601String(),
    'plannedArriveTime': plannedArriveTime?.toIso8601String(),
    'arriveVarianceMinutes': arriveVarianceMinutes,
    'arriveVarianceSummary': arriveVarianceSummary,
  };

  factory DepartureRecord.fromJson(Map<String, dynamic> json) => DepartureRecord(
    fromStopIndex: (json['fromStopIndex'] as num?)?.toInt() ?? 0,
    fromPlaceName: (json['fromPlaceName'] ?? '').toString(),
    toStopIndex: (json['toStopIndex'] as num?)?.toInt() ?? 1,
    toPlaceName: (json['toPlaceName'] ?? '').toString(),
    actualDepartTime: DateTime.tryParse(json['actualDepartTime']?.toString() ?? '') ?? DateTime.now(),
    plannedDepartTime: json['plannedDepartTime'] != null ? DateTime.tryParse(json['plannedDepartTime'].toString()) : null,
    plannedStayMinutes: (json['plannedStayMinutes'] as num?)?.toInt() ?? 0,
    overstayMinutes: (json['overstayMinutes'] as num?)?.toInt() ?? 0,
    actualStayMinutes: (json['actualStayMinutes'] as num?)?.toInt() ?? 0,
    varianceMinutes: (json['varianceMinutes'] as num?)?.toInt() ?? 0,
    varianceSummary: (json['varianceSummary'] ?? 'On Schedule').toString(),
    explanation: (json['explanation'] ?? '').toString(),
    incidentTriggered: json['incidentTriggered']?.toString(),
    actualArriveTime: json['actualArriveTime'] != null ? DateTime.tryParse(json['actualArriveTime'].toString()) : null,
    plannedArriveTime: json['plannedArriveTime'] != null ? DateTime.tryParse(json['plannedArriveTime'].toString()) : null,
    arriveVarianceMinutes: (json['arriveVarianceMinutes'] as num?)?.toInt(),
    arriveVarianceSummary: json['arriveVarianceSummary']?.toString(),
  );
}

