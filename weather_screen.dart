import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/weather_service.dart';
import 'quick_tips_screen.dart';
import 'weather_forecast_screen.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final WeatherService _weatherService = WeatherService();
  late Future<WeatherData> _weatherFuture;
  int? _selectedHourlyIndex;

  String _selectedCityName = 'George Town';
  double _selectedLat = 5.4141;
  double _selectedLng = 100.3288;

  final List<Map<String, dynamic>> _locations = [
    {'name': 'George Town', 'lat': 5.4141, 'lng': 100.3288},
    {'name': 'Bayan Lepas', 'lat': 5.2951, 'lng': 100.2595},
    {'name': 'Ayer Itam', 'lat': 5.4012, 'lng': 100.2780},
    {'name': 'Tanjung Bungah', 'lat': 5.4659, 'lng': 100.2817},
    {'name': 'Balik Pulau', 'lat': 5.3516, 'lng': 100.2369},
    {'name': 'Batu Ferringhi', 'lat': 5.4748, 'lng': 100.2483},
    {'name': 'Butterworth', 'lat': 5.3991, 'lng': 100.3638},
    {'name': 'Bukit Mertajam', 'lat': 5.3633, 'lng': 100.4562},
    {'name': 'Seberang Jaya', 'lat': 5.3912, 'lng': 100.4011},
    {'name': 'Kepala Batas', 'lat': 5.5173, 'lng': 100.4267},
    {'name': 'Simpang Ampat', 'lat': 5.2818, 'lng': 100.4789},
    {'name': 'Nibong Tebal', 'lat': 5.1691, 'lng': 100.4772},
  ];

  @override
  void initState() {
    super.initState();
    _weatherFuture = _weatherService.fetchWeather(
      latitude: _selectedLat,
      longitude: _selectedLng,
      cityName: _selectedCityName,
    );
  }

  void _refreshWeather() {
    setState(() {
      _weatherFuture = _weatherService.fetchWeather(
        latitude: _selectedLat,
        longitude: _selectedLng,
        cityName: _selectedCityName,
      );
      _selectedHourlyIndex = null; // reset selection to current hour
    });
  }

  void _changeLocation(String cityName, double lat, double lng) {
    setState(() {
      _selectedCityName = cityName;
      _selectedLat = lat;
      _selectedLng = lng;
      _weatherFuture = _weatherService.fetchWeather(
        latitude: lat,
        longitude: lng,
        cityName: cityName,
      );
      _selectedHourlyIndex = null;
    });
  }

  void _showLocationSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Text(
                      'Select Penang Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final loc = _locations[index];
                        final isSelected = loc['name'] == _selectedCityName;
                        return ListTile(
                          leading: Icon(
                            Icons.location_on_rounded,
                            color: isSelected ? const Color(0xFF304FFE) : Colors.white30,
                            size: 26,
                          ),
                          title: Text(
                            '${loc['name']}, Penang',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 18,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: Color(0xFF304FFE), size: 24)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            _changeLocation(loc['name'], loc['lat'], loc['lng']);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getWeatherIconPath(String condition) {
    switch (condition) {
      case 'Rain':
        return 'assets/images/weatherScreen-rainyDay-icon.png';
      case 'Clouds':
        return 'assets/images/weatherScreen-cloudyDay-icon.png';
      case 'Clear':
      default:
        return 'assets/images/weatherScreen-sunnyDay-icon.png';
    }
  }

  String _getUvRiskLabel(double uv) {
    if (uv < 3) return 'Low';
    if (uv < 6) return 'Moderate';
    if (uv < 8) return 'High';
    if (uv < 11) return 'Very High';
    return 'Extreme';
  }

  Color _getUvColor(double uv) {
    if (uv < 3) return Colors.greenAccent;
    if (uv < 6) return Colors.yellowAccent;
    if (uv < 8) return Colors.orangeAccent;
    if (uv < 11) return Colors.redAccent;
    return Colors.purpleAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
      ),
      body: FutureBuilder<WeatherData>(
        future: _weatherFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SizedBox.expand(
              child: Image.asset(
                'assets/images/penang-weather-loading-waitingServer-animation-gif.gif',
                fit: BoxFit.cover,
              ),
            );
          }
          if (snapshot.hasError) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 80,
                        color: Colors.white60,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Weather Details',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Unable to retrieve live weather forecasts at this moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () async {
                          final url = Uri.parse("https://www.google.com/search?q=GeorgeTown%2C+Penang+weather+today");
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF304FFE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.open_in_browser_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Search on Google',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final forecast = _weatherService.fetchForecast(data);

          // Select current hour index by default
          if (_selectedHourlyIndex == null) {
            final now = DateTime.now();
            final idx = data.hourlyForecast.indexWhere((h) => h.time.hour == now.hour);
            _selectedHourlyIndex = idx != -1 ? idx : 0;
          }

          final selectedHour = data.hourlyForecast[_selectedHourlyIndex!];
          final backgroundGradient = _getBackgroundGradient(selectedHour.condition);

          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: SizedBox(
              width: 79,
              height: 79,
              child: FloatingActionButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuickTipsScreen(
                        latitude: _selectedLat,
                        longitude: _selectedLng,
                        weatherCondition: selectedHour.condition,
                      ),
                    ),
                  );
                },
                backgroundColor: Colors.lightBlue.withOpacity(0.3),
                elevation: 0,
                shape: const CircleBorder(),
                child: Image.asset('assets/images/lightBulb-icon.png', width: 51, height: 51),
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            body: Container(
              decoration: BoxDecoration(
                gradient: backgroundGradient,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Header with update time
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () => _showLocationSelector(context),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${data.cityName}, Penang',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 27,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: Colors.white70,
                                      size: 28,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Last updated: ${DateFormat('hh:mm a').format(data.lastUpdated)}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _refreshWeather,
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 2. Large dynamic weather illustration & selected temperature
                    Center(
                      child: Column(
                        children: [
                          AnimatedScale(
                            scale: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: Image.asset(
                              _getWeatherIconPath(selectedHour.condition),
                              width: 200,
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${selectedHour.temp2m.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 76,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            selectedHour.description.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3. Core summary metrics cards row (Wind, Humidity, Rain Prob)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricColumn(
                            iconPath: 'assets/images/weatherScreen-Wind-icon.png',
                            label: 'Wind',
                            value: '${selectedHour.wind10m.round()} km/h',
                          ),
                          Container(width: 1, height: 40, color: Colors.white12),
                          _buildMetricColumn(
                            iconPath: 'assets/images/weatherScreen-water-icon.png',
                            label: 'Humidity',
                            value: '${data.humidity}%',
                          ),
                          Container(width: 1, height: 40, color: Colors.white12),
                          _buildMetricColumn(
                            iconPath: 'assets/images/weatherScreen-umbrella-icon.png',
                            label: 'Rain Prob',
                            value: '${selectedHour.precipProb}%',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 4. Interactive hourly timeline slider
                    _buildHourlyTimeline(data),
                    const SizedBox(height: 28),

                    // 5. Grid cards for advanced details
                    const Text(
                      'Advanced Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      childAspectRatio: 1.15,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildAdvancedMetricCard(
                          title: 'Wind Speeds',
                          subtitle: '10m vs 80m Heights',
                          iconPath: 'assets/images/weatherScreen-Wind-icon.png',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('10m: ${selectedHour.wind10m.round()} km/h', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('80m: ${selectedHour.wind80m.round()} km/h', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                            ],
                          ),
                        ),
                        _buildAdvancedMetricCard(
                          title: 'Temperature',
                          subtitle: 'Min & Max Today',
                          iconPath: 'assets/images/weatherScreen-temparature-icon.png',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Min: ${data.tempMin.round()}°C', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Max: ${data.tempMax.round()}°C', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        _buildAdvancedMetricCard(
                          title: 'Precipitation',
                          subtitle: 'Probability & Hours',
                          iconPath: 'assets/images/weatherScreen-umbrella-icon.png',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Prob: ${selectedHour.precipProb}%', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('Duration: ${data.precipitationHours} hrs', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                            ],
                          ),
                        ),
                        _buildAdvancedMetricCard(
                          title: 'UV Index',
                          subtitle: 'Max Level Today',
                          iconPath: 'assets/images/weatherScreen-sunnyDay-icon.png',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${data.uvIndex} UVI', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _getUvRiskLabel(data.uvIndex),
                                style: TextStyle(color: _getUvColor(data.uvIndex), fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Sunrise & Sunset Wide Card
                    _buildWideMetricCard(
                      title: 'Sunrise & Sunset',
                      iconPath: 'assets/images/weatherScreen-hotSun-icon.png',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.wb_sunny_rounded, color: Colors.amber, size: 28),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sunrise', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    DateFormat('hh:mm a').format(data.sunrise),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.nights_stay_rounded, color: Colors.lightBlueAccent, size: 28),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Sunset', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  Text(
                                    DateFormat('hh:mm a').format(data.sunset),
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Min/Max Temperature Curve Card
                    _buildWideMetricCard(
                      title: 'Temperature Boundaries (2m)',
                      iconPath: 'assets/images/weatherScreen-temparature-icon.png',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${data.tempMin.round()}°C', style: const TextStyle(color: Colors.white, fontSize: 15)),
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              height: 6,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.blueAccent, Colors.orangeAccent],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Text('${data.tempMax.round()}°C', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // 6. 7-Day Weather Forecast Button Card
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WeatherForecastScreen(forecast: forecast),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 24),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text(
                                      '7-Day Weather Forecast',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'View daily details & outlook',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          )
          );
        },
      ),
    );
  }

  Widget _buildHourlyTimeline(WeatherData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hourly Timeline',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: data.hourlyForecast.length,
            itemBuilder: (context, index) {
              final hour = data.hourlyForecast[index];
              final isSelected = _selectedHourlyIndex == index;
              final timeString = DateFormat('hh a').format(hour.time);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedHourlyIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF304FFE) : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.12),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF304FFE).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Image.asset(
                        _getWeatherIconPath(hour.condition),
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                      Text(
                        '${hour.temp2m.round()}°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildMetricColumn({
    required String iconPath,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Image.asset(iconPath, width: 34, height: 34, fit: BoxFit.contain),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedMetricCard({
    required String title,
    required String subtitle,
    required String iconPath,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(iconPath, width: 32, height: 32, fit: BoxFit.contain),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildWideMetricCard({
    required String title,
    required String iconPath,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(iconPath, width: 32, height: 32, fit: BoxFit.contain),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  LinearGradient _getBackgroundGradient(String condition) {
    final cond = condition.toLowerCase();
    
    // Rainy day: grey and dark gradient
    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('thunderstorm') || cond.contains('shower')) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF11171A), // Charcoal dark
          Color(0xFF263238), // Slate grey
          Color(0xFF37474F), // Light slate
        ],
      );
    }
    
    // Cloudy day: dark blue gradient
    if (cond.contains('cloud') || cond.contains('overcast') || cond.contains('fog')) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0A192F), // Deep space blue
          Color(0xFF172A45), // Navy blue
          Color(0xFF304863), // Cloudy sky grey-blue
        ],
      );
    }
    
    // Sunny/Clear day: blue gradient
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF0D47A1), // Royal blue
        Color(0xFF1976D2), // Medium blue
        Color(0xFF42A5F5), // Light blue
      ],
    );
  }
}
