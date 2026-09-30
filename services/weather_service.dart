import 'dart:convert';
import 'package:http/http.dart' as http;

class HourlyForecast {
  final DateTime time;
  final double temp2m;
  final double temp80m;
  final double wind10m;
  final double wind80m;
  final int precipProb;
  final String condition;
  final String description;
  final double apparentTemp;
  final double uvIndex;

  HourlyForecast({
    required this.time,
    required this.temp2m,
    required this.temp80m,
    required this.wind10m,
    required this.wind80m,
    required this.precipProb,
    required this.condition,
    required this.description,
    this.apparentTemp = 0.0,
    this.uvIndex = 0.0,
  });
}

class WeatherData {
  final double temp;
  final double feelsLike;
  final double tempMin;
  final double tempMax;
  final int humidity;
  final double windSpeed; // in km/h
  final double windSpeed80m; // in km/h at 80m
  final double temp80m; // in °C at 80m
  final int visibility; // in meters (mocked or retrieved)
  final String condition; // e.g. "Rain", "Clear", "Clouds"
  final String description; // e.g. "moderate rain"
  final DateTime sunrise;
  final DateTime sunset;
  final String cityName;

  // New parameters
  final double uvIndex;
  final double precipitationHours;
  final int precipitationProbabilityMax;
  
  // 24-hour timeline items
  final List<HourlyForecast> hourlyForecast;
  
  // Metadata
  final DateTime lastUpdated;

  WeatherData({
    required this.temp,
    required this.feelsLike,
    required this.tempMin,
    required this.tempMax,
    required this.humidity,
    required this.windSpeed,
    required this.windSpeed80m,
    required this.temp80m,
    required this.visibility,
    required this.condition,
    required this.description,
    required this.sunrise,
    required this.sunset,
    required this.cityName,
    required this.uvIndex,
    required this.precipitationHours,
    required this.precipitationProbabilityMax,
    required this.hourlyForecast,
    required this.lastUpdated,
  });

  bool get isRainy {
    final cond = condition.toLowerCase();
    return cond.contains('rain') || 
           cond.contains('drizzle') || 
           cond.contains('thunderstorm');
  }

  /// Evaluates weather conditions specifically for a given time window (e.g. 14:00 - 16:00)
  ({
    double maxTemp,
    double maxFeelsLike,
    double maxUv,
    int maxPrecipProb,
    bool isPeakHeat,
    bool isRainRisk,
  }) getWeatherForTimeRange(int startHour, int endHour) {
    final matching = hourlyForecast.where((h) {
      final hour = h.time.hour;
      return hour >= startHour && hour <= endHour;
    }).toList();

    if (matching.isEmpty) {
      final isMidday = (startHour >= 11 && startHour <= 15) || (endHour >= 12 && endHour <= 15);
      return (
        maxTemp: tempMax,
        maxFeelsLike: feelsLike,
        maxUv: uvIndex,
        maxPrecipProb: precipitationProbabilityMax,
        isPeakHeat: isMidday && (tempMax > 33.0 || uvIndex > 6.0),
        isRainRisk: precipitationProbabilityMax >= 45,
      );
    }

    double maxT = matching.map((h) => h.temp2m).reduce((a, b) => a > b ? a : b);
    double maxApp = matching.map((h) => h.apparentTemp > 0 ? h.apparentTemp : h.temp2m + 4.0).reduce((a, b) => a > b ? a : b);
    double maxUv = matching.map((h) => h.uvIndex).reduce((a, b) => a > b ? a : b);
    int maxP = matching.map((h) => h.precipProb).reduce((a, b) => a > b ? a : b);

    final isMiddayHours = (startHour >= 11 && startHour <= 15) || (endHour >= 12 && endHour <= 15);
    final heatThresholdMet = maxT > 33.0 || maxUv > 6.0 || (isMiddayHours && (maxT > 33.0 || maxUv > 6.0));

    return (
      maxTemp: maxT,
      maxFeelsLike: maxApp,
      maxUv: maxUv,
      maxPrecipProb: maxP,
      isPeakHeat: heatThresholdMet,
      isRainRisk: maxP >= 45,
    );

  }

  factory WeatherData.mockRainy() {
    final now = DateTime.now();
    final mockHourly = List.generate(24, (i) {
      final hourTime = DateTime(now.year, now.month, now.day, i);
      return HourlyForecast(
        time: hourTime,
        temp2m: 25.0 + (i % 5),
        temp80m: 23.0 + (i % 5),
        wind10m: 10.0 + i,
        wind80m: 12.0 + i,
        precipProb: i % 2 == 0 ? 80 : 20,
        condition: i % 2 == 0 ? 'Rain' : 'Clouds',
        description: i % 2 == 0 ? 'moderate rain' : 'cloudy skies',
        apparentTemp: 28.0 + (i % 5),
        uvIndex: (i >= 11 && i <= 15) ? 9.0 : 2.0,
      );
    });

    return WeatherData(
      temp: 29.0,
      feelsLike: 32.0,
      tempMin: 25.0,
      tempMax: 30.0,
      humidity: 85,
      windSpeed: 9.7,
      windSpeed80m: 12.5,
      temp80m: 27.2,
      visibility: 4000, 
      condition: 'Rain',
      description: 'moderate rain',
      sunrise: now.copyWith(hour: 7, minute: 12),
      sunset: now.copyWith(hour: 19, minute: 36),
      cityName: 'George Town',
      uvIndex: 8.5,
      precipitationHours: 10.0,
      precipitationProbabilityMax: 93,
      hourlyForecast: mockHourly,
      lastUpdated: now,
    );
  }
}

class ForecastDay {
  final DateTime date;
  final double tempMin;
  final double tempMax;
  final String condition;

  ForecastDay({
    required this.date,
    required this.tempMin,
    required this.tempMax,
    required this.condition,
  });
}

class WeatherService {
  // Map WMO weather code to condition string
  String _mapWmoToCondition(int weatherCode) {
    if (weatherCode == 0) return 'Clear';
    if (weatherCode >= 1 && weatherCode <= 3) return 'Clouds';
    if (weatherCode == 45 || weatherCode == 48) return 'Clouds'; // Fog
    
    // Rainy codes (Drizzle, Rain, Showers, Thunderstorms)
    final rainyCodes = [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 85, 86, 95, 96, 99];
    if (rainyCodes.contains(weatherCode)) {
      return 'Rain';
    }
    return 'Clouds';
  }

  // Map WMO weather code to description string
  String _mapWmoToDescription(int weatherCode) {
    switch (weatherCode) {
      case 0: return 'sunny clear sky';
      case 1: return 'mainly clear';
      case 2: return 'partly cloudy';
      case 3: return 'overcast clouds';
      case 45: case 48: return 'foggy mist';
      case 51: case 53: case 55: return 'light drizzle';
      case 61: return 'light rain';
      case 63: return 'moderate rain';
      case 65: return 'heavy rain';
      case 80: case 81: case 82: return 'rain showers';
      case 95: case 96: case 99: return 'thunderstorm';
      default: return 'cloudy skies';
    }
  }

  // Fetch weather data for a specific location in Penang (defaulting to George Town)
  Future<WeatherData> fetchWeather({
    double latitude = 5.4141,
    double longitude = 100.3288,
    String cityName = 'George Town',
  }) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude&longitude=$longitude'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_hours,precipitation_probability_max'
      '&hourly=temperature_2m,apparent_temperature,uv_index,weather_code,precipitation_probability,temperature_80m,wind_speed_10m,wind_speed_80m'
      '&timezone=Asia/Singapore'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final current = data['current'];
        final daily = data['daily'];
        final hourly = data['hourly'];

        final int code = current['weather_code'] as int;
        
        // Parse Sunrise/Sunset ISO8601 strings
        final DateTime sunriseTime = DateTime.parse(daily['sunrise'][0]);
        final DateTime sunsetTime = DateTime.parse(daily['sunset'][0]);

        // Parse Hourly Forecast Timeline
        final List<HourlyForecast> hourlyForecastList = [];
        final int hourlyCount = (hourly['time'] as List).length;
        
        for (int i = 0; i < (hourlyCount < 24 ? hourlyCount : 24); i++) {
          final DateTime hourTime = DateTime.parse(hourly['time'][i]);
          final double hTemp2m = (hourly['temperature_2m'][i] as num).toDouble();
          final double hTemp80m = (hourly['temperature_80m'][i] as num).toDouble();
          final double hWind10m = (hourly['wind_speed_10m'][i] as num).toDouble();
          final double hWind80m = (hourly['wind_speed_80m'][i] as num).toDouble();
          final int hPrecipProb = hourly['precipitation_probability'][i] as int;
          final int hCode = hourly['weather_code'][i] as int;
          final double hApparent = hourly['apparent_temperature'] != null && (hourly['apparent_temperature'] as List).length > i
              ? (hourly['apparent_temperature'][i] as num).toDouble()
              : hTemp2m + 4.0;
          final double hUv = hourly['uv_index'] != null && (hourly['uv_index'] as List).length > i
              ? (hourly['uv_index'][i] as num).toDouble()
              : 0.0;

          hourlyForecastList.add(
            HourlyForecast(
              time: hourTime,
              temp2m: hTemp2m,
              temp80m: hTemp80m,
              wind10m: hWind10m,
              wind80m: hWind80m,
              precipProb: hPrecipProb,
              condition: _mapWmoToCondition(hCode),
              description: _mapWmoToDescription(hCode),
              apparentTemp: hApparent,
              uvIndex: hUv,
            ),
          );
        }

        // Find active hourly index matching current hour to read 80m heights
        final now = DateTime.now();
        final int currentHourIndex = hourlyForecastList.indexWhere((h) => h.time.hour == now.hour);
        final int activeIndex = currentHourIndex != -1 ? currentHourIndex : 0;
        final double wind80m = hourlyForecastList[activeIndex].wind80m;
        final double temp80m = hourlyForecastList[activeIndex].temp80m;

        return WeatherData(
          temp: (current['temperature_2m'] as num).toDouble(),
          feelsLike: (current['apparent_temperature'] as num).toDouble(),
          tempMin: (daily['temperature_2m_min'][0] as num).toDouble(),
          tempMax: (daily['temperature_2m_max'][0] as num).toDouble(),
          humidity: current['relative_humidity_2m'] as int,
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          windSpeed80m: wind80m,
          temp80m: temp80m,
          visibility: 10000, // mock to 10km
          condition: _mapWmoToCondition(code),
          description: _mapWmoToDescription(code),
          sunrise: sunriseTime,
          sunset: sunsetTime,
          cityName: cityName,
          uvIndex: (daily['uv_index_max'][0] as num).toDouble(),
          precipitationHours: (daily['precipitation_hours'][0] as num).toDouble(),
          precipitationProbabilityMax: daily['precipitation_probability_max'][0] as int,
          hourlyForecast: hourlyForecastList,
          lastUpdated: now,
        );
      } else {
        throw Exception('Failed to load weather data from Open-Meteo');
      }
    } catch (e) {
      // Rethrow to let the UI display the fallback screen
      rethrow;
    }
  }

  // Fetch 7-day forecast from Open-Meteo API response
  Future<List<ForecastDay>> fetchForecastData() async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=5.4141&longitude=100.3288'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min'
      '&timezone=Asia/Singapore'
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daily = data['daily'];
        
        final List<ForecastDay> forecastList = [];
        final int daysCount = (daily['time'] as List).length;

        for (int i = 0; i < daysCount; i++) {
          final DateTime date = DateTime.parse(daily['time'][i]);
          final double min = (daily['temperature_2m_min'][i] as num).toDouble();
          final double max = (daily['temperature_2m_max'][i] as num).toDouble();
          final int code = daily['weather_code'][i] as int;

          forecastList.add(
            ForecastDay(
              date: date,
              tempMin: min,
              tempMax: max,
              condition: _mapWmoToCondition(code),
            ),
          );
        }
        return forecastList;
      }
    } catch (e) {
      // Ignore and handle fallback below
    }

    // Fallback static forecast if request fails
    final List<ForecastDay> list = [];
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      list.add(
        ForecastDay(
          date: today.add(Duration(days: i)),
          tempMin: 25.0 + (i % 2),
          tempMax: 30.0 + (i % 3),
          condition: i % 2 == 0 ? 'Rain' : 'Clear',
        ),
      );
    }
    return list;
  }

  // Synchronous forecast generator based on current weather parameters (used in UI builders)
  List<ForecastDay> fetchForecast(WeatherData current) {
    final List<ForecastDay> list = [];
    final today = DateTime.now();
    
    for (int i = 0; i < 7; i++) {
      final forecastDate = today.add(Duration(days: i));
      double offsetMin = (i * 0.3) % 2 - 1.0;
      double offsetMax = (i * 0.4) % 2 - 1.0;
      
      String cond = current.condition;
      if (i > 0) {
        if (i % 3 == 0) {
          cond = 'Clouds';
        } else if (i % 3 == 1) {
          cond = 'Clear';
        } else {
          cond = 'Rain';
        }
      }

      list.add(
        ForecastDay(
          date: forecastDate,
          tempMin: current.tempMin + offsetMin,
          tempMax: current.tempMax + offsetMax,
          condition: cond,
        ),
      );
    }
    return list;
  }
}
