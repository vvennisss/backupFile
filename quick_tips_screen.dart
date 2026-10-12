import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../services/ollama_service.dart';

class QuickTipsScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String weatherCondition;
  final WeatherData? weatherData;
  final HourlyForecast? selectedHour;

  const QuickTipsScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.weatherCondition,
    this.weatherData,
    this.selectedHour,
  });

  @override
  State<QuickTipsScreen> createState() => _QuickTipsScreenState();
}

class TipCardItem {
  final String categoryId;
  final String categoryTitle;
  final String categoryEmoji;
  final String headline;
  final String metroDialogue;
  final String triggerReason;
  final String localPenangHack;
  final String animationAsset;
  final Color themeColor;
  final Color badgeBgColor;
  final String weatherMetricChip;

  const TipCardItem({
    required this.categoryId,
    required this.categoryTitle,
    required this.categoryEmoji,
    required this.headline,
    required this.metroDialogue,
    required this.triggerReason,
    required this.localPenangHack,
    required this.animationAsset,
    required this.themeColor,
    required this.badgeBgColor,
    required this.weatherMetricChip,
  });
}

class _CategoryCandidate {
  final String id;
  final double score;
  final String categoryTitle;
  final String categoryEmoji;
  final String headline;
  final List<String> dialogueTemplates;
  final String triggerReason;
  final String localPenangHack;
  final String animationAsset;
  final Color themeColor;
  final Color badgeBgColor;
  final String weatherMetricChip;

  const _CategoryCandidate({
    required this.id,
    required this.score,
    required this.categoryTitle,
    required this.categoryEmoji,
    required this.headline,
    required this.dialogueTemplates,
    required this.triggerReason,
    required this.localPenangHack,
    required this.animationAsset,
    required this.themeColor,
    required this.badgeBgColor,
    required this.weatherMetricChip,
  });
}

class _QuickTipsScreenState extends State<QuickTipsScreen> {
  final PageController _pageController = PageController();
  final OllamaService _ollamaService = OllamaService();
  int _currentPage = 0;
  List<TipCardItem> _activeTips = [];
  bool _isLoading = false;

  late double _currentLat;
  late double _currentLng;
  String _selectedCityName = 'George Town';

  static const List<Map<String, dynamic>> _penangLocations = [
    {'name': 'George Town', 'lat': 5.4141, 'lng': 100.3288, 'desc': 'Heritage Core & Murals'},
    {'name': 'Batu Ferringhi', 'lat': 5.4748, 'lng': 100.2483, 'desc': 'Coastal Beaches & Resorts'},
    {'name': 'Bayan Lepas', 'lat': 5.2951, 'lng': 100.2595, 'desc': 'Airport & Snake Temple'},
    {'name': 'Ayer Itam', 'lat': 5.4012, 'lng': 100.2780, 'desc': 'Kek Lok Si & Penang Hill'},
    {'name': 'Tanjung Bungah', 'lat': 5.4659, 'lng': 100.2817, 'desc': 'Seaside Escapes'},
    {'name': 'Balik Pulau', 'lat': 5.3516, 'lng': 100.2369, 'desc': 'Hills, Countryside & Durian'},
    {'name': 'Butterworth', 'lat': 5.3991, 'lng': 100.3638, 'desc': 'Mainland Harbor & Food'},
    {'name': 'Bukit Mertajam', 'lat': 5.3633, 'lng': 100.4562, 'desc': 'St. Anne & Nature Trails'},
    {'name': 'Seberang Jaya', 'lat': 5.3912, 'lng': 100.4011, 'desc': 'Mainland Commercial Hub'},
    {'name': 'Kepala Batas', 'lat': 5.5173, 'lng': 100.4267, 'desc': 'North Seberang Perai'},
    {'name': 'Simpang Ampat', 'lat': 5.2818, 'lng': 100.4789, 'desc': 'South Seberang Perai'},
    {'name': 'Nibong Tebal', 'lat': 5.1691, 'lng': 100.4772, 'desc': 'Southern Border Town'},
  ];

  @override
  void initState() {
    super.initState();
    _currentLat = widget.latitude;
    _currentLng = widget.longitude;
    _selectedCityName = widget.weatherData?.cityName ?? 'George Town';
    _initTips();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initTips() {
    if (widget.weatherData != null) {
      _evaluateTips(widget.weatherData!, widget.selectedHour);
    } else {
      _loadWeatherAndEvaluate();
    }
  }

  Future<void> _loadWeatherAndEvaluate() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch live Open-Meteo weather API data for the chosen Penang area coordinates
      final data = await WeatherService().fetchWeather(
        latitude: _currentLat,
        longitude: _currentLng,
        cityName: _selectedCityName,
      );

      // 2. Query Gemma 4 Cloud (gemma4:cloud) via Ollama with the specific area weather data
      final double temp = data.temp;
      final double feelsLike = data.feelsLike;
      final double uvIndex = data.uvIndex;
      final int humidity = data.humidity;
      final int precipProb = data.precipitationProbabilityMax;
      final String condition = data.condition;
      final String description = data.description;

      List<Map<String, dynamic>>? aiTips;
      try {
        aiTips = await _ollamaService.generateMetroWeatherTips(
          cityName: _selectedCityName,
          temp: temp,
          feelsLike: feelsLike,
          uvIndex: uvIndex,
          humidity: humidity,
          precipProb: precipProb,
          condition: condition,
          description: description,
        );
      } catch (_) {
        aiTips = null;
      }

      if (mounted) {
        if (aiTips != null && aiTips.length >= 3) {
          _applyGemmaTips(aiTips, data);
        } else {
          _evaluateTips(data, null);
        }
      }
    } catch (_) {
      if (mounted) {
        _evaluateFallback();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyGemmaTips(List<Map<String, dynamic>> aiTips, WeatherData data) {
    final selected = <TipCardItem>[];
    for (int i = 0; i < 3 && i < aiTips.length; i++) {
      final raw = aiTips[i];
      final catId = (raw['category']?.toString() ?? 'sunscreen').toLowerCase();
      final headline = raw['headline']?.toString() ?? 'Stay Comfortable in $_selectedCityName!';
      final dialogue = raw['metroDialogue']?.toString() ?? 'Metro says enjoy your day in $_selectedCityName!';
      final localHack = raw['localHack']?.toString() ?? 'Metro local secret: Explore the local shophouses and eateries!';

      selected.add(_buildTipCardFromGemma(catId, headline, dialogue, localHack, data));
    }

    setState(() {
      _activeTips = selected;
    });
  }

  TipCardItem _buildTipCardFromGemma(
    String catId,
    String headline,
    String dialogue,
    String localHack,
    WeatherData data,
  ) {
    switch (catId) {
      case 'umbrella':
        return TipCardItem(
          categoryId: 'umbrella',
          categoryTitle: 'Rain & Shower Alert',
          categoryEmoji: '☔',
          headline: headline,
          metroDialogue: dialogue,
          triggerReason: 'Rain Probability ${data.precipitationProbabilityMax}% • Island Showers',
          localPenangHack: localHack,
          animationAsset: 'assets/images/blue-bird-umbrella.gif',
          themeColor: const Color(0xFF2563EB),
          badgeBgColor: const Color(0xFFEFF6FF),
          weatherMetricChip: 'Rain ${data.precipitationProbabilityMax}%',
        );
      case 'drink_water':
        return TipCardItem(
          categoryId: 'drink_water',
          categoryTitle: 'Penang Hydration Boost',
          categoryEmoji: '🥥',
          headline: headline,
          metroDialogue: dialogue,
          triggerReason: 'Temperature ${data.temp.round()}°C • Feels Like ${data.feelsLike.round()}°C',
          localPenangHack: localHack,
          animationAsset: 'assets/images/blue-bird-drink-water.gif',
          themeColor: const Color(0xFF059669),
          badgeBgColor: const Color(0xFFECFDF5),
          weatherMetricChip: '${data.temp.round()}°C Heat',
        );
      case 'light_clothes':
        return TipCardItem(
          categoryId: 'light_clothes',
          categoryTitle: 'Breezy Tropical Outfits',
          categoryEmoji: '👕',
          headline: headline,
          metroDialogue: dialogue,
          triggerReason: 'Humidity ${data.humidity}% • Tropical Air',
          localPenangHack: localHack,
          animationAsset: 'assets/images/blue-bird-remind-light-clothes.gif',
          themeColor: const Color(0xFF0284C7),
          badgeBgColor: const Color(0xFFF0F9FF),
          weatherMetricChip: '${data.humidity}% Humid',
        );
      case 'sunglasses':
        return TipCardItem(
          categoryId: 'sunglasses',
          categoryTitle: 'Bright Skies & Eye Care',
          categoryEmoji: '🕶️',
          headline: headline,
          metroDialogue: dialogue,
          triggerReason: 'Bright Sunlight • Coastal Glare',
          localPenangHack: localHack,
          animationAsset: 'assets/images/blue-bird-sunglasses.gif',
          themeColor: const Color(0xFF7C3AED),
          badgeBgColor: const Color(0xFFF5F3FF),
          weatherMetricChip: 'Bright Sun',
        );
      case 'sunscreen':
      default:
        return TipCardItem(
          categoryId: 'sunscreen',
          categoryTitle: 'UV & Sun Protection',
          categoryEmoji: '🧴',
          headline: headline,
          metroDialogue: dialogue,
          triggerReason: 'UV Index ${data.uvIndex.toStringAsFixed(1)} • Strong Sunlight',
          localPenangHack: localHack,
          animationAsset: 'assets/images/blue-bird-remind-apply-sunscreen.gif',
          themeColor: const Color(0xFFEA580C),
          badgeBgColor: const Color(0xFFFFF7ED),
          weatherMetricChip: 'UV ${data.uvIndex.toStringAsFixed(1)}',
        );
    }
  }

  void _showLocationSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.62,
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B), // Dark slate
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag indicator handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF304FFE).withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF60A5FA),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Area in Penang',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                          Text(
                            "Gemma 4 Cloud will generate tips for this area",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontFamily: 'SF Pro',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Colors.white12, height: 1),
              // Locations List
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _penangLocations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final loc = _penangLocations[index];
                    final isSelected = loc['name'] == _selectedCityName;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(ctx);
                        if (!isSelected) {
                          setState(() {
                            _selectedCityName = loc['name'] as String;
                            _currentLat = loc['lat'] as double;
                            _currentLng = loc['lng'] as double;
                            _currentPage = 0;
                          });
                          _loadWeatherAndEvaluate();
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(0);
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF304FFE).withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF304FFE)
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                              color: isSelected ? const Color(0xFF60A5FA) : Colors.white30,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loc['name'] as String,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white70,
                                      fontSize: 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                  Text(
                                    loc['desc'] as String,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFF93C5FD) : Colors.white38,
                                      fontSize: 12,
                                      fontFamily: 'SF Pro',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF304FFE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _evaluateFallback() {
    final condition = widget.weatherCondition.toLowerCase();
    final isRainy = condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunderstorm') ||
        condition.contains('shower');

    final candidates = <_CategoryCandidate>[
      _CategoryCandidate(
        id: 'umbrella',
        score: isRainy ? 150 : 20,
        categoryTitle: 'Rain & Shower Alert',
        categoryEmoji: '☔',
        headline: 'Passing Showers Ahead — Keep Dry with Metro!',
        dialogueTemplates: [
          'Chirp chirp! Metro spotted rain clouds drifting across $_selectedCityName! Pack an umbrella in your daypack so passing tropical showers won\'t interrupt your exploration!',
          'Metro rain alert! If raindrops start falling over $_selectedCityName, duck into a traditional kopitiam for hot Nanyang coffee and crispy toast until the sun returns!',
        ],
        triggerReason: 'Rain Alert • Island Showers Detected',
        localPenangHack:
            'Metro\'s Penang Secret: Sudden rain is the best excuse to duck into a classic kopitiam for hot Hainanese coffee and toasted kaya butter bread!',
        animationAsset: 'assets/images/blue-bird-umbrella.gif',
        themeColor: const Color(0xFF2563EB),
        badgeBgColor: const Color(0xFFEFF6FF),
        weatherMetricChip: 'Rain Alert',
      ),
      _CategoryCandidate(
        id: 'sunscreen',
        score: 95,
        categoryTitle: 'UV & Sun Protection',
        categoryEmoji: '🧴',
        headline: 'Shield Your Skin Under the Penang Sun!',
        dialogueTemplates: const [
          'Chirp! Metro is checking the skies for you: the tropical sun is blazing! Apply broad-spectrum SPF 50+ sunscreen before exploring murals and heritage sites so you don\'t get sunburnt!',
          'Metro sun advisory! UV rays are strong today. Be sure to protect your neck and shoulders, and reapply sunscreen every 2 hours while walking outdoors!',
        ],
        triggerReason: 'High UV Radiation • Tropical Sunshine',
        localPenangHack:
            'Metro\'s Penang Secret: When the midday sun peaks, walk along the shaded "five-foot ways" (kaki lima) of traditional George Town shophouses to stay protected!',
        animationAsset: 'assets/images/blue-bird-remind-apply-sunscreen.gif',
        themeColor: const Color(0xFFEA580C),
        badgeBgColor: const Color(0xFFFFF7ED),
        weatherMetricChip: 'High UV',
      ),
      _CategoryCandidate(
        id: 'drink_water',
        score: 90,
        categoryTitle: 'Penang Hydration Boost',
        categoryEmoji: '🥥',
        headline: 'Beat the Tropical Heat — Sip & Refresh!',
        dialogueTemplates: const [
          'Phew! Metro feels that Penang heat! Exploring heritage trails burns plenty of energy—keep a chilled water bottle handy and take frequent hydration sips!',
          'Metro hydration reminder: The tropical sun drains your energy faster than you think! Drink extra water or cool down with a fresh island juice between temple visits!',
        ],
        triggerReason: 'High Temperature • Tropical Heat',
        localPenangHack:
            'Metro\'s Penang Secret: Cool down like a true Penangite! Grab a freshly cracked pandan coconut or ice-cold Nutmeg juice from local roadside stalls along Kimberley Street!',
        animationAsset: 'assets/images/blue-bird-drink-water.gif',
        themeColor: const Color(0xFF059669),
        badgeBgColor: const Color(0xFFECFDF5),
        weatherMetricChip: '32°C Heat',
      ),
      _CategoryCandidate(
        id: 'light_clothes',
        score: 80,
        categoryTitle: 'Breezy Tropical Outfits',
        categoryEmoji: '👕',
        headline: 'Keep It Breezy in Penang\'s Humidity!',
        dialogueTemplates: const [
          'Chirp! Penang\'s humidity is noticeably sticky today! Metro recommends loose, breathable linen or cotton so you stay airy and cool hopping between heritage alleys!',
          'Metro style tip: Pick lightweight, breezy clothes that catch the coastal winds, especially if you are strolling by Clan Jetties or coastal walkways!',
        ],
        triggerReason: 'High Humidity • Tropical Air',
        localPenangHack:
            'Metro\'s Penang Secret: Breathable cotton and comfortable slip-on shoes are ideal, especially since many Penang temples and clan houses require removing shoes at entry!',
        animationAsset: 'assets/images/blue-bird-remind-light-clothes.gif',
        themeColor: const Color(0xFF0284C7),
        badgeBgColor: const Color(0xFFF0F9FF),
        weatherMetricChip: 'Humid Air',
      ),
      _CategoryCandidate(
        id: 'sunglasses',
        score: 75,
        categoryTitle: 'Bright Skies & Eye Care',
        categoryEmoji: '🕶️',
        headline: 'Shade Your Eyes from Tropical Glare!',
        dialogueTemplates: const [
          'Look at those bright tropical skies! Metro says pop on your UV sunglasses so you can comfortably admire the seaside views and colorful street murals without squinting!',
          'Metro says: Glary coastal rays out there! Wearing UV shades protects your eyes and lets you snap squint-free photos around Penang!',
        ],
        triggerReason: 'Bright Sunlight • Coastal Glare',
        localPenangHack:
            'Metro\'s Penang Secret: Polarized shades make the turquoise sea water at Batu Ferringhi and the coastal strait look even more spectacular in your travel photos!',
        animationAsset: 'assets/images/blue-bird-sunglasses.gif',
        themeColor: const Color(0xFF7C3AED),
        badgeBgColor: const Color(0xFFF5F3FF),
        weatherMetricChip: 'Bright Sun',
      ),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));
    _selectTop3(candidates);
  }

  void _evaluateTips(WeatherData data, HourlyForecast? hour) {
    final double temp = hour?.temp2m ?? data.temp;
    final double feelsLike = data.feelsLike;
    final int humidity = data.humidity;
    final double uvIndex = hour?.uvIndex ?? data.uvIndex;
    final int precipProb = hour?.precipProb ?? data.precipitationProbabilityMax;
    final String condition = (hour?.condition ?? data.condition).toLowerCase();

    final rainKeywords = ['rain', 'drizzle', 'thunderstorm', 'shower', 'storm', 'monsoon'];
    final bool isRainCondition = data.isRainy || rainKeywords.any((k) => condition.contains(k));

    // 1. Raining score
    double rainScore = 0.0;
    if (isRainCondition) {
      rainScore = 150.0 + (precipProb * 0.5);
    } else if (precipProb >= 50) {
      rainScore = 95.0 + precipProb;
    } else if (precipProb >= 30) {
      rainScore = 50.0 + precipProb;
    } else {
      rainScore = precipProb * 0.4;
    }

    // 2. High UV / Sunscreen score
    double sunscreenScore = 0.0;
    if (!isRainCondition) {
      sunscreenScore = uvIndex * 13.0;
      if (temp >= 31) sunscreenScore += 15.0;
      if (uvIndex >= 6) sunscreenScore += 15.0;
      final currentHour = DateTime.now().hour;
      if (currentHour >= 10 && currentHour <= 16) {
        sunscreenScore += 15.0;
      }
    } else {
      sunscreenScore = uvIndex * 4.0;
    }

    // 3. High UV / Sunglasses score
    double sunglassesScore = 0.0;
    if (!isRainCondition) {
      sunglassesScore = uvIndex * 11.5;
      if (condition.contains('clear') || condition.contains('sun')) {
        sunglassesScore += 20.0;
      }
      final currentHour = DateTime.now().hour;
      if (currentHour >= 9 && currentHour <= 17) {
        sunglassesScore += 10.0;
      }
    } else {
      sunglassesScore = uvIndex * 3.5;
    }

    // 4. Peak heat / Drink water score
    double drinkWaterScore = 0.0;
    if (temp >= 33 || feelsLike >= 36) {
      drinkWaterScore = 115.0;
    } else if (temp >= 31 || feelsLike >= 33) {
      drinkWaterScore = 98.0;
    } else if (temp >= 28) {
      drinkWaterScore = 80.0;
    } else {
      drinkWaterScore = 55.0;
    }
    if (!isRainCondition && temp >= 30) {
      drinkWaterScore += 10.0;
    }

    // 5. High humidity / Light clothes score
    double humidityScore = 0.0;
    if (humidity >= 85) {
      humidityScore = 105.0;
    } else if (humidity >= 75) {
      humidityScore = 90.0;
    } else if (humidity >= 65) {
      humidityScore = 75.0;
    } else {
      humidityScore = humidity * 0.85;
    }
    if (temp >= 30 && humidity >= 70) {
      humidityScore += 10.0;
    }

    final candidates = <_CategoryCandidate>[
      _CategoryCandidate(
        id: 'umbrella',
        score: rainScore,
        categoryTitle: 'Rain & Shower Alert',
        categoryEmoji: '☔',
        headline: 'Passing Showers Ahead — Keep Dry with Metro!',
        dialogueTemplates: [
          'Chirp chirp! Metro detected a $precipProb% chance of rain over $_selectedCityName! Keep a lightweight fold-up umbrella in your bag so sudden showers won\'t interrupt your adventures!',
          'Metro rain alert! Monsoon rain clouds are passing through $_selectedCityName. If it starts pouring, duck into a cozy museum or heritage café for hot white coffee until the skies clear!',
          'Hey explorer! Metro sees showers in the forecast for $_selectedCityName ($precipProb%). Slip an umbrella into your daypack so you stay dry while exploring!',
        ],
        triggerReason: 'Rain Probability $precipProb% • Passing Showers',
        localPenangHack:
            'Metro\'s Penang Secret: Sudden rain in George Town is the best excuse to duck into a traditional kopitiam for steaming Hainanese white coffee and crispy kaya butter toast!',
        animationAsset: 'assets/images/blue-bird-umbrella.gif',
        themeColor: const Color(0xFF2563EB),
        badgeBgColor: const Color(0xFFEFF6FF),
        weatherMetricChip: 'Rain $precipProb%',
      ),
      _CategoryCandidate(
        id: 'sunscreen',
        score: sunscreenScore,
        categoryTitle: 'UV & Sun Protection',
        categoryEmoji: '🧴',
        headline: 'Shield Your Skin Under the Penang Sun!',
        dialogueTemplates: [
          'Chirp! Metro is checking the skies for $_selectedCityName: UV Index is sizzling at ${uvIndex.toStringAsFixed(1)}! Don\'t let the tropical rays sunburn your skin. Apply SPF 50+ sunscreen before stepping outside!',
          'Metro sun advisory! UV radiation is intense in $_selectedCityName (${uvIndex.toStringAsFixed(1)} UVI). Remember to protect your face, neck, and arms, and reapply every 2 hours if you\'re touring outdoors!',
          'Hey friend! Metro says the tropical sun is at peak strength (${uvIndex.toStringAsFixed(1)} UVI). Slather on water-resistant sunscreen so your sightseeing stays painless and glowing!',
        ],
        triggerReason: 'UV Index ${uvIndex.toStringAsFixed(1)} • Intense Tropical Rays',
        localPenangHack:
            'Metro\'s Penang Secret: When the sun peaks at midday, walk under the shaded "five-foot ways" (kaki lima) of traditional George Town shophouses to stay protected!',
        animationAsset: 'assets/images/blue-bird-remind-apply-sunscreen.gif',
        themeColor: const Color(0xFFEA580C),
        badgeBgColor: const Color(0xFFFFF7ED),
        weatherMetricChip: 'UV ${uvIndex.toStringAsFixed(1)}',
      ),
      _CategoryCandidate(
        id: 'drink_water',
        score: drinkWaterScore,
        categoryTitle: 'Penang Hydration Boost',
        categoryEmoji: '🥥',
        headline: 'Beat the Tropical Heat — Sip & Refresh!',
        dialogueTemplates: [
          'Phew! Metro feels that heat sizzling in $_selectedCityName at ${temp.round()}°C (feels like ${feelsLike.round()}°C)! Walking heritage trails burns lots of energy—keep a water bottle handy and sip regularly!',
          'Metro hydration reminder: Island heat is real today (${temp.round()}°C)! Replenish your body with plenty of water or grab a cold local beverage between visiting attractions!',
          'Chirp! Metro reminds you to take regular drink breaks while exploring $_selectedCityName. Listen to your body and stay properly hydrated!',
        ],
        triggerReason: 'Temperature ${temp.round()}°C • Feels Like ${feelsLike.round()}°C',
        localPenangHack:
            'Metro\'s Penang Secret: Cool down like a true Penangite! Grab a freshly cracked pandan coconut or ice-cold Nutmeg juice from local roadside stalls along Kimberley Street!',
        animationAsset: 'assets/images/blue-bird-drink-water.gif',
        themeColor: const Color(0xFF059669),
        badgeBgColor: const Color(0xFFECFDF5),
        weatherMetricChip: '${temp.round()}°C Heat',
      ),
      _CategoryCandidate(
        id: 'light_clothes',
        score: humidityScore,
        categoryTitle: 'Breezy Tropical Outfits',
        categoryEmoji: '👕',
        headline: 'Keep It Breezy in Penang\'s Humidity!',
        dialogueTemplates: [
          'Chirp! Humidity in $_selectedCityName is sitting high at $humidity%! Metro recommends loose, breathable linen or airy cotton so you stay dry, fresh, and comfortable!',
          'Metro style tip: Sticky tropical air today ($humidity% humidity)! Wear breezy, light-colored clothes that let the coastal wind through while you explore!',
          'Metro comfort reminder: High humidity alert! Choose lightweight outfits and comfortable walking shoes with breathable socks—your feet will thank you later!',
        ],
        triggerReason: 'Humidity $humidity% • Sticky Island Air',
        localPenangHack:
            'Metro\'s Penang Secret: Light, breathable cotton and slip-on footwear are ideal, especially since many Penang temples and clan houses require removing shoes at entry!',
        animationAsset: 'assets/images/blue-bird-remind-light-clothes.gif',
        themeColor: const Color(0xFF0284C7),
        badgeBgColor: const Color(0xFFF0F9FF),
        weatherMetricChip: '$humidity% Humid',
      ),
      _CategoryCandidate(
        id: 'sunglasses',
        score: sunglassesScore,
        categoryTitle: 'Bright Skies & Eye Care',
        categoryEmoji: '🕶️',
        headline: 'Shade Your Eyes from Tropical Glare!',
        dialogueTemplates: [
          'Look at those bright skies over $_selectedCityName! Metro noticed intense sunshine today. Pop on your UV sunglasses so you can comfortably admire the seaside views without squinting!',
          'Metro says: Glary coastal rays detected! Wearing UV shades prevents eye strain and ensures you take sharp, squint-free photos across Penang!',
          'Chirp! Bright sunny day across the island! Slip on your favorite sunglasses before heading out to coastal walkways or beaches!',
        ],
        triggerReason: 'Bright Sunlight • Coastal Glare',
        localPenangHack:
            'Metro\'s Penang Secret: Polarized sunglasses cut through sea surface glare, making the turquoise water at Batu Ferringhi and Penang Strait look spectacular in your photos!',
        animationAsset: 'assets/images/blue-bird-sunglasses.gif',
        themeColor: const Color(0xFF7C3AED),
        badgeBgColor: const Color(0xFFF5F3FF),
        weatherMetricChip: 'Bright Sun',
      ),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));
    _selectTop3(candidates);
  }

  void _selectTop3(List<_CategoryCandidate> candidates) {
    final top3 = candidates.take(3).toList();
    final hourSeed = DateTime.now().hour;

    final selected = <TipCardItem>[];
    for (int i = 0; i < top3.length; i++) {
      final cat = top3[i];
      final templateIdx = (hourSeed + i) % cat.dialogueTemplates.length;
      selected.add(
        TipCardItem(
          categoryId: cat.id,
          categoryTitle: cat.categoryTitle,
          categoryEmoji: cat.categoryEmoji,
          headline: cat.headline,
          metroDialogue: cat.dialogueTemplates[templateIdx],
          triggerReason: cat.triggerReason,
          localPenangHack: cat.localPenangHack,
          animationAsset: cat.animationAsset,
          themeColor: cat.themeColor,
          badgeBgColor: cat.badgeBgColor,
          weatherMetricChip: cat.weatherMetricChip,
        ),
      );
    }

    setState(() {
      _activeTips = selected;
    });
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _activeTips.length) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Builds a zoomed-in Metro circular avatar focusing on Metro's expressive face
  Widget _buildZoomedMetroAvatar({double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFDBEAFE),
        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Transform.scale(
        scale: 2.2,
        alignment: const Alignment(0.15, -0.68),
        child: Image.asset(
          'assets/blue_bird_mascot.jpg',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            'assets/blue_bird_mascot.png',
            fit: BoxFit.cover,
            errorBuilder: (context2, error2, stackTrace2) =>
                const Icon(Icons.cruelty_free, color: Color(0xFF2563EB), size: 20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTip = _activeTips.isNotEmpty && _currentPage < _activeTips.length
        ? _activeTips[_currentPage]
        : null;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F3E7D), // Deep rich cobalt blue
              Color(0xFF1E60B8), // Vibrant ocean blue
              Color(0xFF4FA0F1), // Clear sky cyan
              Color(0xFFD6F0FF), // Soft morning pastel cyan
            ],
            stops: [0.0, 0.28, 0.68, 1.0],
          ),
        ),
        child: SafeArea(
          child: _isLoading || _activeTips.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar with back button and Area selector button (Tip 1/3 removed!)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF303030),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Interactive Location Selector Pill (Allows changing area for tips!)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _showLocationSelector(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Metro's Tips • Gemma 4 Cloud",
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10.5,
                                              fontFamily: 'SF Pro',
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            _selectedCityName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'SF Pro',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Top Stage: Metro Mascot Animation Stage (Fits the rounded rectangle completely, 不留白!)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        height: 195,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: currentTip != null
                              ? Image.asset(
                                  currentTip.animationAsset,
                                  key: ValueKey<String>(currentTip.animationAsset),
                                  fit: BoxFit.cover, // Fills the rounded rectangle completely with NO whitespace (不留白!)
                                  width: double.infinity,
                                  height: double.infinity,
                                  gaplessPlayback: true,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Image.asset('assets/images/blue-bird-wave.gif', fit: BoxFit.cover),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Card: Metro's Personal Advice & Dialogue
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Swipable PageView for Tips
                              Expanded(
                                child: PageView.builder(
                                  controller: _pageController,
                                  itemCount: _activeTips.length,
                                  onPageChanged: (index) {
                                    setState(() {
                                      _currentPage = index;
                                    });
                                  },
                                  itemBuilder: (context, index) {
                                    final tip = _activeTips[index];
                                    return SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 1. Tag displayed ABOVE Metro with blue tick, aligned at RIGHT
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                                decoration: BoxDecoration(
                                                  color: tip.badgeBgColor,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: tip.themeColor.withValues(alpha: 0.35),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      tip.categoryEmoji,
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      tip.categoryTitle,
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: tip.themeColor,
                                                        fontFamily: 'SF Pro',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          // 2. Metro Profile Row with Zoomed Avatar and Blue Tick below tag
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              // Zoomed-in Metro avatar
                                              _buildZoomedMetroAvatar(size: 40),
                                              const SizedBox(width: 10),

                                              // Metro Name & verified badge
                                              const Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          'Metro',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF1E40AF),
                                                            fontFamily: 'SF Pro',
                                                          ),
                                                        ),
                                                        SizedBox(width: 4),
                                                        Icon(
                                                          Icons.verified_rounded,
                                                          color: Color(0xFF2563EB),
                                                          size: 16,
                                                        ),
                                                      ],
                                                    ),
                                                    SizedBox(height: 1),
                                                    Text(
                                                      'Your Penang Weather Companion',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: Color(0xFF64748B),
                                                        fontFamily: 'SF Pro',
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 12),

                                          // 3. Action Headline
                                          Text(
                                            tip.headline,
                                            style: const TextStyle(
                                              fontSize: 17.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1E293B),
                                              height: 1.25,
                                              fontFamily: 'SF Pro',
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          // 4. Metro's Conversational Dialogue Chat Bubble
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.02),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  margin: const EdgeInsets.only(top: 2, right: 8),
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDBEAFE),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.chat_bubble_outline_rounded,
                                                    color: Color(0xFF2563EB),
                                                    size: 14,
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    tip.metroDialogue,
                                                    style: const TextStyle(
                                                      fontSize: 13.2,
                                                      color: Color(0xFF334155),
                                                      height: 1.4,
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 8),

                                          // 5. Live Trigger Context (Wrapped in Expanded so it never overflows)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.sensors_rounded,
                                                size: 14,
                                                color: Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 5),
                                              Expanded(
                                                child: Text(
                                                  'Triggered by: ${tip.triggerReason}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                    fontFamily: 'SF Pro',
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 8),

                                          // 6. Metro's Penang Local Secret / Hack
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFFBEB),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Icon(
                                                  Icons.lightbulb_rounded,
                                                  color: Color(0xFFD97706),
                                                  size: 15,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: const TextStyle(
                                                        fontSize: 11.5,
                                                        color: Color(0xFF78350F),
                                                        height: 1.35,
                                                        fontFamily: 'SF Pro',
                                                      ),
                                                      children: [
                                                        const TextSpan(
                                                          text: "Metro's Penang Secret: ",
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF92400E),
                                                          ),
                                                        ),
                                                        TextSpan(
                                                          text: tip.localPenangHack.replaceFirst("Metro's Penang Secret: ", ""),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Bottom Navigation Controls
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                                child: _buildBottomNavigation(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    if (_currentPage == 0) {
      // First tip card: Right arrow button
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          _buildDotIndicators(),
          _buildNavButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Next Tip',
            onTap: () => _goToPage(1),
          ),
        ],
      );
    } else if (_currentPage < _activeTips.length - 1) {
      // Middle tip card: Left & Right arrow buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Previous Tip',
            onTap: () => _goToPage(_currentPage - 1),
          ),
          _buildDotIndicators(),
          _buildNavButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Next Tip',
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      );
    } else {
      // Last tip card: Left arrow & 'I got it' button
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Previous Tip',
            onTap: () => _goToPage(_currentPage - 1),
          ),
          _buildIGotItButton(),
        ],
      );
    }
  }

  Widget _buildDotIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(_activeTips.length, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF304FFE) : const Color(0xFFCFD8DC),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF304FFE), // Colors.indigoAccent[700]
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildIGotItButton() {
    return Material(
      color: const Color(0xFF304FFE), // Colors.indigoAccent[700]
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'I got it, Metro!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontFamily: 'Roboto Mono',
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 5),
              Icon(Icons.check_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
