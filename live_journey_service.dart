import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'saved_trip_plans_manager.dart';

/// Service managing real-time live journey simulation, two-way dashboard synchronization,
/// mock car GPS progress, live weather, dynamic traffic incidents, and arrival detection.
class LiveJourneyService extends ChangeNotifier {
  static final LiveJourneyService instance = LiveJourneyService._internal();
  LiveJourneyService._internal();

  bool _isJourneyActive = false;
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

  // Weather & Traffic Telemetry from Dashboard
  String _weatherCondition = 'sunny'; // 'sunny', 'rainy', 'cloudy', 'thunderstorm'
  double _weatherTemp = 32.0;
  int _weatherHumidity = 70;
  String _weatherLocation = 'George Town';
  String? _activeIncident;
  String _virtualTimeString = '10:00:00 AM';
  List<Map<String, dynamic>> _dashboardStops = [];
  String? _overrideCurrentStopName;

  Timer? _ticker;
  Timer? _dashboardPollTimer;
  bool _dashboardConnected = false;
  String _activeDashboardHost = 'http://10.3.244.78:4000';

  final List<String> _candidateHosts = [
    'http://10.3.244.78:4000',
    'http://10.0.2.2:4000',
    'http://127.0.0.1:4000',
    'http://localhost:4000',
  ];

  // Getters
  bool get isJourneyActive => _isJourneyActive;
  SavedTripPlan? get activePlan => _activePlan;
  int get currentStopIndex => _currentStopIndex;
  bool get isArrived => _isArrived;
  bool get isPaused => _isPaused;
  String get travelMode => _travelMode;
  int get speedMultiplier => _speedMultiplier;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  double get remainingDistanceMeters => _remainingDistanceMeters;
  int get remainingSeconds => _remainingSeconds;
  bool get dashboardConnected => _dashboardConnected;
  String get activeDashboardHost => _activeDashboardHost;

  String get weatherCondition => _weatherCondition;
  double get weatherTemp => _weatherTemp;
  int get weatherHumidity => _weatherHumidity;
  String get weatherLocation => _weatherLocation;
  String? get activeIncident => _activeIncident;
  String get virtualTimeString => _virtualTimeString;
  List<Map<String, dynamic>> get dashboardStops => _dashboardStops;

  bool get isRainyWeather =>
      _weatherCondition == 'rainy' || _weatherCondition == 'thunderstorm';

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
    return _activePlan!.stops.first.placeName;
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

  /// Start Live Journey for the specified plan
  Future<void> startJourney(SavedTripPlan plan) async {
    _activePlan = plan;
    _isJourneyActive = true;
    _isPaused = false;
    _isArrived = false;
    _speedMultiplier = 1;
    _activeIncident = null;

    if (plan.stops.isNotEmpty) {
      if (plan.stops.length > 1) {
        _currentStopIndex = 1;
        final origin = plan.stops[0];
        final target = plan.stops[1];
        _startLegLat = origin.lat;
        _startLegLng = origin.lng;
        _currentLat = origin.lat;
        _currentLng = origin.lng;
        _targetLat = target.lat;
        _targetLng = target.lng;
      } else {
        _currentStopIndex = 0;
        final target = plan.stops[0];
        _startLegLat = 5.4140;
        _startLegLng = 100.3280;
        _currentLat = _startLegLat;
        _currentLng = _startLegLng;
        _targetLat = target.lat;
        _targetLng = target.lng;
      }

      _totalLegDistanceMeters = _calculateHaversineDistance(_startLegLat, _startLegLng, _targetLat, _targetLng);
      if (_totalLegDistanceMeters < 300) _totalLegDistanceMeters = 1850;
      _remainingDistanceMeters = _totalLegDistanceMeters;
      _remainingSeconds = (_remainingDistanceMeters / (_travelMode == 'driving' ? 9.7 : 1.3)).round();
    }

    notifyListeners();

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
    notifyListeners();
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
    _currentLat = _targetLat;
    _currentLng = _targetLng;
    _isArrived = true;
    notifyListeners();
  }

  /// Advance to the next stop on the itinerary
  void advanceToNextStop() {
    if (_activePlan == null || _activePlan!.stops.isEmpty) return;
    if (_currentStopIndex < _activePlan!.stops.length - 1) {
      _currentStopIndex++;
      _isArrived = false;
      _startLegLat = _currentLat;
      _startLegLng = _currentLng;
      final target = _activePlan!.stops[_currentStopIndex];
      _targetLat = target.lat;
      _targetLng = target.lng;
      _overrideCurrentStopName = target.placeName;

      _totalLegDistanceMeters = _calculateHaversineDistance(_startLegLat, _startLegLng, _targetLat, _targetLng);
      if (_totalLegDistanceMeters < 300) _totalLegDistanceMeters = 1500;
      _remainingDistanceMeters = _totalLegDistanceMeters;
      _remainingSeconds = (_remainingDistanceMeters / (_travelMode == 'driving' ? 9.5 : 1.3)).round();

      // Notify dashboard to visit target stop
      controlSimulation('visitStop', _currentStopIndex);
      notifyListeners();
    } else {
      _isArrived = true;
      notifyListeners();
    }
  }

  /// Sync itinerary stops to the Simulation Dashboard HTTP API
  Future<bool> syncToDashboard(SavedTripPlan plan) async {
    final payload = json.encode({
      'planTitle': plan.cleanTitle,
      'stops': plan.stops.map((s) => s.toJson()).toList(),
    });

    for (final host in _candidateHosts) {
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
      case 'rain_cleared':
        _activeIncident = null;
        _weatherCondition = 'cloudy';
        _weatherTemp = 30;
        break;
      default:
        _activeIncident = '⚡ Incident: $scenarioId simulated';
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

      final baseMps = _travelMode == 'driving' ? 9.7 : 1.3;
      final traveledThisTick = baseMps * _speedMultiplier;

      if (_remainingDistanceMeters > traveledThisTick) {
        _remainingDistanceMeters -= traveledThisTick;
        _remainingSeconds = max(0, (_remainingDistanceMeters / baseMps).round());

        final fraction = progressPercentage;
        _currentLat = _startLegLat + (_targetLat - _startLegLat) * fraction;
        _currentLng = _startLegLng + (_targetLng - _startLegLng) * fraction;
      } else {
        _remainingDistanceMeters = 0;
        _remainingSeconds = 0;
        _currentLat = _targetLat;
        _currentLng = _targetLng;
        _isArrived = true;
      }

      notifyListeners();
    });
  }

  /// Polls dashboard simulation state & weather every 1.5 seconds
  void _startDashboardPolling() {
    _dashboardPollTimer?.cancel();
    _dashboardPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (!_isJourneyActive) return;

      // 1. Poll Simulation State
      for (final host in _candidateHosts) {
        try {
          final stateUrl = Uri.parse('$host/api/simulation/state');
          final stateRes = await http.get(stateUrl).timeout(const Duration(milliseconds: 1200));

          if (stateRes.statusCode == 200) {
            final data = json.decode(utf8.decode(stateRes.bodyBytes));
            if (data['code'] == 200 && data['data'] != null) {
              final sim = data['data'];
              _dashboardConnected = true;
              _activeDashboardHost = host;

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
              if (sim['currentStopIndex'] != null) {
                _currentStopIndex = (sim['currentStopIndex'] as num).toInt();
              }
              if (sim['activeIncident'] != null) {
                _activeIncident = sim['activeIncident']?.toString();
              } else if (sim['activeIncident'] == null && _activeIncident != null && _activeIncident!.contains('Alert')) {
                // Keep cleared
              }
              if (sim['virtualTimeString'] != null) {
                _virtualTimeString = sim['virtualTimeString'].toString();
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
              if (sim['isStaying'] == true || _remainingDistanceMeters <= 10) {
                _isArrived = true;
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
