import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';

class WeatherForecastScreen extends StatelessWidget {
  final List<ForecastDay> forecast;

  const WeatherForecastScreen({
    super.key,
    required this.forecast,
  });

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
        title: const Text(
          '7-Day Forecast',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            physics: const BouncingScrollPhysics(),
            itemCount: forecast.length,
            itemBuilder: (context, index) {
              final day = forecast[index];
              final dateString = DateFormat('dd MMM').format(day.date);
              final weekdayString = index == 0
                  ? 'Today'
                  : index == 1
                      ? 'Tomorrow'
                      : DateFormat('EEEE').format(day.date);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                ),
                child: Row(
                  children: [
                    // Day name & Date
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekdayString,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateString,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Weather icon & Condition name
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Image.asset(
                            _getWeatherIconPath(day.condition),
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            day.condition,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Min / Max temperature
                    Expanded(
                      flex: 3,
                      child: Text(
                        '${day.tempMin.round()}° / ${day.tempMax.round()}°',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
