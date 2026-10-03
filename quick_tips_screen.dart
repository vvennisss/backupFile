import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../theme.dart';

class QuickTipsScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String weatherCondition;

  const QuickTipsScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.weatherCondition,
  });

  @override
  State<QuickTipsScreen> createState() => _QuickTipsScreenState();
}

class TipItem {
  final String text;
  final bool isHeader;
  final String category; // 'hydration', 'clothing', 'exercise', 'intro', or 'other'
  TipItem(this.text, this.isHeader, this.category);
}

class _QuickTipsScreenState extends State<QuickTipsScreen> {
  String _rawTipsText = '';
  bool _isLoading = true;
  bool _hasError = false;
  HttpClient? _client;

  @override
  void initState() {
    super.initState();
    _loadCachedTips();
  }

  @override
  void dispose() {
    _client?.close(force: true);
    super.dispose();
  }

  String _normalizeWeatherCondition(String condition) {
    final cond = condition.toLowerCase();
    
    if (cond.contains('rain') || cond.contains('drizzle') || cond.contains('thunderstorm') || cond.contains('shower')) {
      return 'rain';
    }
    if (cond.contains('cloud') || cond.contains('overcast') || cond.contains('fog')) {
      return 'cloudy';
    }
    return 'sunny';
  }

  Future<void> _loadCachedTips() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedTips = prefs.getString('cached_lifestyle_tips');
    final cachedWeatherCondition = prefs.getString('cached_weather_condition');
    final normalizedCondition = _normalizeWeatherCondition(widget.weatherCondition);
    
    // Check if cache is valid (same weather condition category, ignoring date as requested)
    if (cachedTips != null && cachedWeatherCondition == normalizedCondition) {
      setState(() {
        _rawTipsText = cachedTips;
        _isLoading = false;
      });
    } else {
      _fetchLifestyleTips();
    }
  }

  Future<void> _saveTipsToCache(String tips) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    final normalizedCondition = _normalizeWeatherCondition(widget.weatherCondition);
    
    await prefs.setString('cached_lifestyle_tips', tips);
    await prefs.setString('cached_tips_date', todayStr);
    await prefs.setString('cached_weather_condition', normalizedCondition);
  }

  String _getStaticFallback(String normalizedCondition) {
    if (normalizedCondition == 'rain') {
      return "### Preparation and Safety\n- Carry Umbrella: Keep a compact umbrella or raincoat handy.\n- Dry Packing: Secure your mobile devices in waterproof bags.\n\n### Travel and Route Planning\n- Indoor Sightseeing: Visit museums, galleries, or indoor cafes.\n- Watch Your Step: Slippery pathways; walk with extra care.\n\n### Warm Comfort Food\n- Hot Soups: Try warm local dishes like piping hot Penang Laksa.";
    } else {
      return "### Hydration and Diet\n- Stay Hydrated: Drink plenty of water throughout the day.\n- Eat Light: Consume fresh fruits and cooling foods.\n\n### Clothing and Sun Protection\n- Sun Protection: Apply SPF 30+ sunscreen and wear sunglasses.\n- Light Clothes: Wear loose-fitting, breathable cotton fabrics.\n\n### Exercise and Activity\n- Seek Shade: Avoid outdoor training under direct mid-day sun.\n- Rest Well: Pace yourself during outdoor sightseeing walks.";
    }
  }

  Future<String> _fetchFromGemini() async {
    if (AppConfig.geminiApiKey.isEmpty || AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      throw Exception('Gemini API key is not configured');
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${AppConfig.geminiModel}:generateContent'
      '?key=${AppConfig.geminiApiKey}'
    );

    final normalized = _normalizeWeatherCondition(widget.weatherCondition);
    final isRainy = normalized == 'rain';
    
    final prompt = "You are 'Kia Kia Penang AI' - a smart travel guide assistant for Penang, Malaysia. "
        "Generate weather-based lifestyle tips for a user currently in Penang. "
        "The current weather condition is: ${widget.weatherCondition} (at coordinates: latitude ${widget.latitude}, longitude ${widget.longitude}). "
        "Please provide action-oriented, personalized tips for:\n"
        "${isRainy 
          ? '1. Preparation and Safety\n2. Travel and Route Planning\n3. Warm Comfort Food' 
          : '1. Hydration and Diet\n2. Clothing and Sun Protection\n3. Exercise and Activity'}\n\n"
        "Format the output strictly as Markdown, like this:\n"
        "### ${isRainy ? 'Preparation and Safety' : 'Hydration and Diet'}\n"
        "- [Tip 1]\n"
        "- [Tip 2]\n\n"
        "### ${isRainy ? 'Travel and Route Planning' : 'Clothing and Sun Protection'}\n"
        "- [Tip 1]\n"
        "- [Tip 2]\n\n"
        "### ${isRainy ? 'Warm Comfort Food' : 'Exercise and Activity'}\n"
        "- [Tip 1]\n"
        "- [Tip 2]\n\n"
        "Keep it concise and relevant to the Penang weather. Do not add any extra greeting, markdown blocks, or explanation. Only return the markdown text.";

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'parts': [
              {
                'text': prompt
              }
            ]
          }
        ]
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      final String responseText = data['candidates'][0]['content']['parts'][0]['text'].toString().trim();
      if (responseText.isNotEmpty) {
        return responseText;
      }
    }
    throw Exception('Gemini returned status code ${response.statusCode}');
  }

  Future<void> _fetchLifestyleTips() async {
    _rawTipsText = '';
    _client = HttpClient();
    final url = Uri.parse(
      '${AppConfig.backendBaseUrl}/api/lifestyle-tips?lat=${widget.latitude}&lon=${widget.longitude}'
    );

    try {
      final request = await _client!.getUrl(url).timeout(const Duration(seconds: 5));
      final response = await request.close();

      if (response.statusCode == 200) {
        setState(() {
          _isLoading = false;
        });

        String tempText = '';
        await for (final String line in response.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr.isEmpty) continue;

            try {
              final parsed = json.decode(jsonStr);
              if (parsed['type'] == 'token') {
                final token = parsed['text'] as String;
                setState(() {
                  _rawTipsText += token;
                });
                tempText += token;
              } else if (parsed['type'] == 'done') {
                await _saveTipsToCache(tempText);
                break;
              }
            } catch (_) {
              // Ignore decoding issues for malformed/partial lines
            }
          }
        }
        return; // Success, stop here
      } else {
        throw HttpException('Server returned status code ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching streaming tips from backend: $e. Trying Gemini API...');
      
      try {
        final geminiTips = await _fetchFromGemini();
        if (mounted) {
          setState(() {
            _rawTipsText = geminiTips;
            _isLoading = false;
            _hasError = false;
          });
          await _saveTipsToCache(geminiTips);
        }
      } catch (geminiErr) {
        debugPrint('Error fetching from Gemini: $geminiErr. Using static fallback...');
        final normalized = _normalizeWeatherCondition(widget.weatherCondition);
        final staticTips = _getStaticFallback(normalized);
        if (mounted) {
          setState(() {
            _rawTipsText = staticTips;
            _isLoading = false;
            _hasError = true;
          });
          await _saveTipsToCache(staticTips);
        }
      }
    } finally {
      _client?.close();
    }
  }

  List<TipItem> _parseTips(String rawText) {
    if (rawText.isEmpty) return [];
    final List<TipItem> list = [];
    final lines = rawText.split('\n');
    String currentCategory = 'intro';

    for (var line in lines) {
      var cleaned = line.trim();
      if (cleaned.isEmpty) continue;

      // Check if line represents a header
      bool isHeader = cleaned.startsWith('#') ||
          (cleaned.endsWith(':') && cleaned.length < 40) ||
          cleaned.toLowerCase().contains('hydration and diet') ||
          cleaned.toLowerCase().contains('clothing and sun') ||
          cleaned.toLowerCase().contains('exercise and activity') ||
          cleaned.toLowerCase().contains('preparation and safety') ||
          cleaned.toLowerCase().contains('travel and route') ||
          cleaned.toLowerCase().contains('warm comfort');

      if (isHeader) {
        // Clean headers: remove markdown characters, asterisks, leading numbering
        cleaned = cleaned.replaceAll('*', '');
        cleaned = cleaned.replaceAll(RegExp(r'^#+\s*'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        cleaned = cleaned.trim();
        if (cleaned.endsWith(':')) {
          cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        }

        final lower = cleaned.toLowerCase();
        if (lower.contains('hydration') || lower.contains('diet')) {
          currentCategory = 'hydration';
        } else if (lower.contains('clothing') || lower.contains('sun')) {
          currentCategory = 'clothing';
        } else if (lower.contains('exercise') || lower.contains('activity')) {
          currentCategory = 'exercise';
        } else {
          currentCategory = 'other';
        }

        list.add(TipItem(cleaned, true, currentCategory));
      } else {
        // Clean regular tips: remove any leading asterisks, numberings, list dashes
        cleaned = cleaned.replaceAll('*', '');
        cleaned = cleaned.replaceFirst(RegExp(r'^\d+[\.\)]\s*'), '');
        cleaned = cleaned.replaceFirst(RegExp(r'^[\-\*\u2022]\s*'), '');
        cleaned = cleaned.trim();

        if (cleaned.isNotEmpty) {
          final lower = cleaned.toLowerCase();
          String itemCat = currentCategory;
          if (lower.contains('based on the current') || lower.contains('here are some actionable')) {
            itemCat = 'intro';
          }
          list.add(TipItem(cleaned, false, itemCat));
        }
      }
    }
    return list;
  }

  Gradient? _getCardGradient(String category) {
    if (category == 'hydration') {
      return const LinearGradient(
        colors: [Color(0xFFE3F2FD), Color(0xFFE0F7FA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (category == 'clothing') {
      return const LinearGradient(
        colors: [Color(0xFFFFFDE7), Color(0xFFFFF9C4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (category == 'exercise') {
      return const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final parsedItems = _parseTips(_rawTipsText);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Lifestyle Tips',
          style: TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-time weather recommendations designed for your current location.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          CircularProgressIndicator(color: AppColors.secondaryRoyalBlue),
                          SizedBox(height: 20),
                          Text(
                            'Generating personalized tips...',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : parsedItems.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for server response...',
                            style: TextStyle(color: AppColors.textGrey),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: parsedItems.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              if (_hasError) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.amber.shade200, width: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 24),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Offline mode: Displaying default lifestyle advice.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }

                            final item = parsedItems[index - 1];

                            if (item.isHeader) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
                                child: Text(
                                  item.text,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryDarkNavy,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              );
                            }

                            final isIntro = item.category == 'intro';
                            final cardGradient = _getCardGradient(item.category);

                            // Render recommendation as a styled card with dynamic gradients and icons
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardGradient == null ? Colors.white : null,
                                gradient: cardGradient,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                                border: cardGradient == null
                                    ? Border.all(color: const Color(0xFFF1F7FA), width: 1.5)
                                    : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: isIntro
                                          ? const Color(0xFFFFF8E1)
                                          : const Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isIntro
                                          ? Icons.lightbulb_outline_rounded
                                          : Icons.check_rounded,
                                      color: isIntro ? Colors.amber.shade800 : Colors.green,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      item.text,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.45,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
