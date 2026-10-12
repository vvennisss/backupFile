import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class OllamaService {
  // Method to query the Ollama model and return structured JSON
  Future<Map<String, String>> queryDestination(String prompt) async {
    final systemPrompt = 
        "You are 'Kia Kia Penang AI' - a smart travel guide assistant for Penang, Malaysia. "
        "The user will search for a place or write a query (in English or Malay). "
        "You must return the travel details about this place in Penang in JSON format. "
        "Regardless of the user's language, the JSON values must be in English. "
        "The JSON MUST have exactly these keys:\n"
        "1. \"title\": The name of the place in Penang.\n"
        "2. \"area\": The area it is located in (e.g. George Town, Air Itam, Bayan Lepas, Batu Ferringhi, Pulau Tikus, etc.).\n"
        "3. \"businessHours\": The typical operating hours (e.g. 9:00 AM - 6:00 PM daily).\n"
        "4. \"description\": A rich description of what the place is, its significance, and visitor info (100-150 words).\n"
        "Do not include any conversational intro/outro text, markdown wrapper, or extra characters. Only return valid JSON.";

    final url = Uri.parse('${AppConfig.ollamaBaseUrl}/api/generate');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': AppConfig.ollamaModel,
          'prompt': prompt,
          'system': systemPrompt,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final responseText = (data['response'] as String).trim();
        
        // Try parsing JSON directly
        try {
          // If response text has markdown code blocks, strip them
          String cleanJson = responseText;
          if (cleanJson.contains('```')) {
            cleanJson = cleanJson.split('```').firstWhere((element) => element.contains('{'));
            if (cleanJson.startsWith('json')) {
              cleanJson = cleanJson.substring(4);
            }
          }
          final decoded = json.decode(cleanJson.trim());
          return {
            'title': decoded['title']?.toString() ?? prompt,
            'area': decoded['area']?.toString() ?? 'Penang',
            'businessHours': decoded['businessHours']?.toString() ?? 'Check online',
            'description': decoded['description']?.toString() ?? responseText,
          };
        } catch (e) {
          // Fallback if parsing fails but request succeeded
          return {
            'title': prompt,
            'area': 'Penang',
            'businessHours': 'Check online',
            'description': responseText,
          };
        }
      } else {
        return _queryGemini(prompt, systemPrompt);
      }
    } catch (e) {
      // In case Ollama is not running, fallback to Gemini
      return _queryGemini(prompt, systemPrompt);
    }
  }

  // Gemini API fallback query method
  Future<Map<String, String>> _queryGemini(String prompt, String systemPrompt) async {
    if (AppConfig.geminiApiKey.isEmpty || AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      return _getFallbackJSON(prompt);
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent'
      '?key=${AppConfig.geminiApiKey}'
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'contents': [
            {
              'parts': [
                {
                  'text': '$systemPrompt\n\nUser request: $prompt'
                }
              ]
            }
          ],
          'generationConfig': {
            'responseMimeType': 'application/json'
          }
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final String responseText = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
        
        try {
          final decoded = json.decode(responseText);
          return {
            'title': decoded['title']?.toString() ?? prompt,
            'area': decoded['area']?.toString() ?? 'Penang',
            'businessHours': decoded['businessHours']?.toString() ?? 'Check online',
            'description': decoded['description']?.toString() ?? responseText,
          };
        } catch (e) {
          return {
            'title': prompt,
            'area': 'Penang',
            'businessHours': 'Check online',
            'description': responseText,
          };
        }
      }
    } catch (e) {
      // Ignore and use local mock fallback
    }

    return _getFallbackJSON(prompt);
  }

  // Generates structured local responses when the local/cloud Ollama server is offline
  Map<String, String> _getFallbackJSON(String query) {
    final cleanQuery = query.toLowerCase().trim();
    
    if (cleanQuery.contains('kek lok si') || cleanQuery.contains('tokong')) {
      return {
        'title': 'Kek Lok Si Temple',
        'area': 'Air Itam',
        'businessHours': '8:30 AM - 5:30 PM',
        'description': 'Kek Lok Si is the largest Buddhist temple in Malaysia, located in Air Itam, Penang. It features a magnificent 7-tier pagoda (Pagoda of Rama VI) and a 30.2-meter bronze statue of Guanyin, the Goddess of Mercy. It is a major pilgrimage center and a stunning cultural landmark.',
      };
    } else if (cleanQuery.contains('penang hill') || cleanQuery.contains('bukit bendera')) {
      return {
        'title': 'Penang Hill (Bukit Bendera)',
        'area': 'Air Itam',
        'businessHours': '6:30 AM - 10:00 PM',
        'description': 'Penang Hill is the oldest British hill station in Southeast Asia, offering panoramic views of George Town and the mainland. You can reach the top via the Penang Hill Funicular Railway, which climbs the steepest tunnel track in the world.',
      };
    } else if (cleanQuery.contains('street art') || cleanQuery.contains('seni jalanan') || cleanQuery.contains('mural')) {
      return {
        'title': 'George Town Street Art',
        'area': 'George Town',
        'businessHours': '24 Hours Open',
        'description': 'Penang is world-famous for its interactive wall murals, spearheaded by Ernest Zacharevic in 2012. Popular murals include \'Little Children on a Bicycle\' and \'Boy on a Chair\'. You can explore them by walking or renting a trishaw around Lebuh Armenian and Chulia street.',
      };
    } else if (cleanQuery.contains('escape') || cleanQuery.contains('theme park') || cleanQuery.contains('taman tema')) {
      return {
        'title': 'ESCAPE Penang',
        'area': 'Teluk Bahang',
        'businessHours': '10:00 AM - 6:00 PM (Closed Mon)',
        'description': 'ESCAPE Penang is an outdoor adventure theme park located in Teluk Bahang. It holds the Guinness World Record for the longest tube water slide (1,111m) and the longest zip coaster (1,135m). It features climbing, zip-lining, water slides, and obstacle courses set in nature.',
      };
    } else {
      // Default fallback
      return {
        'title': query[0].toUpperCase() + query.substring(1),
        'area': 'George Town, Penang',
        'businessHours': '9:00 AM - 6:00 PM',
        'description': 'This is a popular attraction located in the heart of Penang. Visitors can explore the local historical heritage, experience the vibrant culture, and sample traditional street food in the surrounding area. (Note: Ollama server is offline, showing standard travel guide details).',
      };
    }
  }

  /// Queries Gemma 4 Cloud (gemma4:cloud) via Ollama to generate tailored weather lifestyle tips for an area in Penang
  Future<List<Map<String, dynamic>>?> generateMetroWeatherTips({
    required String cityName,
    required double temp,
    required double feelsLike,
    required double uvIndex,
    required int humidity,
    required int precipProb,
    required String condition,
    required String description,
  }) async {
    final systemPrompt =
        "You are 'Metro' (a cheerful blue bird mascot, 麦德罗), the official local weather companion for Kia Kia Penang, Malaysia. "
        "Based on live microclimate weather in $cityName, Penang, generate 3 tailored lifestyle tips. "
        "Categories must be chosen from: 'sunscreen', 'umbrella', 'drink_water', 'light_clothes', 'sunglasses'. "
        "Return ONLY a valid JSON array of 3 objects with keys: "
        "\"category\", \"headline\" (under 8 words), \"metroDialogue\" (25-38 words in Metro's friendly companion voice mentioning $cityName), \"localHack\" (Penang local tip mentioning spots in or around $cityName). "
        "No markdown, no explanation, only raw JSON array.";

    final prompt =
        "Live weather in $cityName, Penang:\n"
        "- Temp: ${temp.round()}°C (Feels like: ${feelsLike.round()}°C)\n"
        "- UV Index: $uvIndex\n"
        "- Humidity: $humidity%\n"
        "- Rain Probability: $precipProb%\n"
        "- Condition: $condition ($description)\n"
        "Generate 3 tips for $cityName:";

    final url = Uri.parse('${AppConfig.ollamaBaseUrl}/api/generate');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': AppConfig.ollamaModel, // gemma4:cloud
          'system': systemPrompt,
          'prompt': prompt,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final responseText = (data['response'] as String).trim();
        String cleanJson = responseText;
        if (cleanJson.contains('```')) {
          final parts = cleanJson.split('```');
          for (final part in parts) {
            final trimmed = part.trim();
            if (trimmed.startsWith('[') || trimmed.contains('[{')) {
              cleanJson = trimmed;
              break;
            }
          }
          if (cleanJson.startsWith('json')) {
            cleanJson = cleanJson.substring(4);
          }
        }
        final startIndex = cleanJson.indexOf('[');
        final endIndex = cleanJson.lastIndexOf(']');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          cleanJson = cleanJson.substring(startIndex, endIndex + 1);
        }
        final decoded = json.decode(cleanJson.trim());
        if (decoded is List && decoded.isNotEmpty) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {
      // In case of timeout or offline, return null for seamless fallback
    }
    return null;
  }
}
