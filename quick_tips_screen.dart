import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/weather_service.dart';

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
  final String text;
  final String animationAsset;
  final String categoryTitle;

  const TipCardItem({
    required this.text,
    required this.animationAsset,
    required this.categoryTitle,
  });
}

class _CategoryScore {
  final String id;
  final double score;
  final String animationAsset;
  final List<String> tips;
  final String categoryTitle;

  const _CategoryScore({
    required this.id,
    required this.score,
    required this.animationAsset,
    required this.tips,
    required this.categoryTitle,
  });
}

class _QuickTipsScreenState extends State<QuickTipsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<TipCardItem> _activeTips = [];
  bool _isLoading = false;

  // 1. Peak heat/ High UV - Sunglasses
  static const List<String> _sunglassesTips = [
    "High UV detected! Put on sunglasses to protect your eyes while exploring.",
    "Glary sun out there! Throw on your shades before snapping photos at places.",
    "Bright tropical rays today! Bring your sunglasses.",
  ];

  // 2. High humidity - Light clothes
  static const List<String> _lightClothesTips = [
    "Beat Penang's tropical humidity! Wear breathable cotton or linen for places hopping.",
    "Warm and sticky outside! Opt for breezy outfits while travelling.",
    "High humidity alert! Stick to loose clothing so you stay cool while exploring.",
  ];

  // 3. Peak heat/ High UV - Sunscreen
  static const List<String> _sunscreenTips = [
    "UV rays are extra strong today! Apply sunscreen before heading out.",
    "Don't get sunburnt! Reapply sunscreen every 2 hours if you're outdoors.",
    "Intense sun midday! Slather on that sunscreen before exploring outdoor sites.",
  ];

  // 4. Peak heat - Drink water
  static const List<String> _drinkWaterTips = [
    "Stay hydrated! Grab a fresh coconut or sugar cane juice.",
    "Tropical heat is no joke! Keep a water bottle handy while exploring.",
    "Time for a hydration check! Drink extra water or ice-cold Nutmeg juice to cool down.",
  ];

  // 5. Raining - Umbrella
  static const List<String> _umbrellaTips = [
    "Sudden downpour ahead! Grab an umbrella or duck into an indoor spot.",
    "Monsoon showers expected! Keep an umbrella ready.",
    "Rainy day in Penang! Great excuse to relax with a hot cup of Nanyang coffee inside.",
  ];

  @override
  void initState() {
    super.initState();
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
      final data = await WeatherService().fetchWeather(
        latitude: widget.latitude,
        longitude: widget.longitude,
      );
      if (mounted) {
        _evaluateTips(data, null);
      }
    } catch (_) {
      // Fallback evaluation if fetch fails
      if (mounted) {
        _evaluateFallback();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _evaluateFallback() {
    final condition = widget.weatherCondition.toLowerCase();
    final isRainy = condition.contains('rain') ||
        condition.contains('drizzle') ||
        condition.contains('thunderstorm') ||
        condition.contains('shower');

    final candidates = <_CategoryScore>[
      _CategoryScore(
        id: 'umbrella',
        score: isRainy ? 150 : 10,
        animationAsset: 'assets/images/blue-bird-umbrella.gif',
        tips: _umbrellaTips,
        categoryTitle: 'Raining',
      ),
      const _CategoryScore(
        id: 'sunscreen',
        score: 85,
        animationAsset: 'assets/images/blue-bird-remind-apply-sunscreen.gif',
        tips: _sunscreenTips,
        categoryTitle: 'Peak heat / High UV',
      ),
      const _CategoryScore(
        id: 'sunglasses',
        score: 80,
        animationAsset: 'assets/images/blue-bird-sunglasses.gif',
        tips: _sunglassesTips,
        categoryTitle: 'Peak heat / High UV',
      ),
      const _CategoryScore(
        id: 'drink_water',
        score: 90,
        animationAsset: 'assets/images/blue-bird-drink-water.gif',
        tips: _drinkWaterTips,
        categoryTitle: 'Peak heat',
      ),
      const _CategoryScore(
        id: 'light_clothes',
        score: 75,
        animationAsset: 'assets/images/blue-bird-remind-light-clothes.gif',
        tips: _lightClothesTips,
        categoryTitle: 'High humidity',
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
      drinkWaterScore = 110.0;
    } else if (temp >= 31 || feelsLike >= 33) {
      drinkWaterScore = 95.0;
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

    final candidates = <_CategoryScore>[
      _CategoryScore(
        id: 'umbrella',
        score: rainScore,
        animationAsset: 'assets/images/blue-bird-umbrella.gif',
        tips: _umbrellaTips,
        categoryTitle: 'Raining',
      ),
      _CategoryScore(
        id: 'sunscreen',
        score: sunscreenScore,
        animationAsset: 'assets/images/blue-bird-remind-apply-sunscreen.gif',
        tips: _sunscreenTips,
        categoryTitle: 'Peak heat / High UV',
      ),
      _CategoryScore(
        id: 'sunglasses',
        score: sunglassesScore,
        animationAsset: 'assets/images/blue-bird-sunglasses.gif',
        tips: _sunglassesTips,
        categoryTitle: 'Peak heat / High UV',
      ),
      _CategoryScore(
        id: 'drink_water',
        score: drinkWaterScore,
        animationAsset: 'assets/images/blue-bird-drink-water.gif',
        tips: _drinkWaterTips,
        categoryTitle: 'Peak heat',
      ),
      _CategoryScore(
        id: 'light_clothes',
        score: humidityScore,
        animationAsset: 'assets/images/blue-bird-remind-light-clothes.gif',
        tips: _lightClothesTips,
        categoryTitle: 'High humidity',
      ),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));
    _selectTop3(candidates);
  }

  void _selectTop3(List<_CategoryScore> candidates) {
    final top3 = candidates.take(3).toList();
    final hourSeed = DateTime.now().hour;

    final selected = <TipCardItem>[];
    for (int i = 0; i < top3.length; i++) {
      final category = top3[i];
      final tipIdx = (hourSeed + i) % category.tips.length;
      selected.add(
        TipCardItem(
          text: category.tips[tipIdx],
          animationAsset: category.animationAsset,
          categoryTitle: category.categoryTitle,
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
              Color(0xFF1E88E5), // Rich sky blue
              Color(0xFF4FC3F7), // Soft cyan blue
              Color(0xFFB2EBF2), // Pale seafoam cyan
              Color(0xFFDCEDC8), // Soft pastel lime
            ],
            stops: [0.0, 0.35, 0.70, 1.0],
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
                    // Top App Bar with circular back button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
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
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Top Animation Card (Blue Bird GIF)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: currentTip != null
                              ? Image.asset(
                                  currentTip.animationAsset,
                                  key: ValueKey(currentTip.animationAsset),
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bottom White Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 28),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Swipable tips area
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
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(26, 24, 26, 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dear traveller,',
                                            style: GoogleFonts.playfairDisplay(
                                              fontSize: 16,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF5F6F81),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'here is the tips for you',
                                            style: GoogleFonts.playfairDisplay(
                                              fontSize: 16,
                                              fontStyle: FontStyle.italic,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF5F6F81),
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                                child: Text(
                                                  tip.text,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF303030),
                                                    height: 1.45,
                                                  ),
                                                ),
                                              ),
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
                                padding: const EdgeInsets.only(left: 24, right: 24, bottom: 28),
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
      // First tips card: right arrow to go to second tips card
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 52), // Placeholder to balance layout
          _buildDotIndicators(),
          _buildActionButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Next Tip',
            onTap: () => _goToPage(1),
          ),
        ],
      );
    } else if (_currentPage == 1) {
      // Second tips card: 左右 arrow 去前(first tips card) 去后(second tips card)
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Previous Tip',
            onTap: () => _goToPage(0),
          ),
          _buildDotIndicators(),
          _buildActionButton(
            icon: Icons.arrow_forward_rounded,
            tooltip: 'Next Tip',
            onTap: () => _goToPage(2),
          ),
        ],
      );
    } else {
      // The last tips card: 剩下左arrow 和 ‘I got it' button at right side
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Previous Tip',
            onTap: () => _goToPage(1),
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
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF304FFE) : const Color(0xFFCFD8DC),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF304FFE), // Colors.indigoAccent[700]
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildIGotItButton() {
    return Material(
      color: const Color(0xFF304FFE), // Colors.indigoAccent[700]
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Redirect user back to the previous page showing weather information
          Navigator.pop(context);
        },
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: const Text(
            'I got it',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'Roboto Mono',
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
