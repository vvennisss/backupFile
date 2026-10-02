import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../theme.dart';
import '../services/saved_places_manager.dart';
import '../services/places_service.dart';
import 'main_navigation.dart';
import 'map_screen.dart';
import 'street_view_selection_dialog.dart';
import '../widgets/app_image_widget.dart';

class DetailScreen extends StatefulWidget {
  final String title;
  final String area;
  final String businessHours;
  final String description;
  final String imagePath;
  final String? placeInformationJson;
  final String? coordinatesJson;
  final String? address;
  final bool? hasStreetView;
  final String? mapillaryImageId;
  final String? placeId;
  final String? rawHoursText;
  final List<String>? searchKeywords;
  final String? primaryCategory;
  final List<String>? subCategories;

  const DetailScreen({
    super.key,
    required this.title,
    required this.area,
    required this.businessHours,
    required this.description,
    required this.imagePath,
    this.placeInformationJson,
    this.coordinatesJson,
    this.address,
    this.hasStreetView,
    this.mapillaryImageId,
    this.placeId,
    this.rawHoursText,
    this.searchKeywords,
    this.primaryCategory,
    this.subCategories,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _isFavorite = false;
  bool _isHoursExpanded = false;
  late String _title;
  late String _area;
  late String _businessHours;
  late String _description;
  late String _imagePath;
  String? _placeInformationJson;
  String? _address;
  bool _hasStreetView = false;
  // ignore: unused_field
  String? _mapillaryImageId;
  String? _placeId;
  List<double>? _coords;
  String? _rawHoursText;
  List<String> _searchKeywords = [];
  String? _primaryCategory;
  List<String> _subCategories = [];
  String? _website;

  @override
  void initState() {
    super.initState();
    _isFavorite = SavedPlacesManager.isSaved(widget.title);
    _title = widget.title;
    _area = widget.area;
    _businessHours = widget.businessHours;
    _description = widget.description;
    _imagePath = AppImageWidget.extractRealUrl(widget.imagePath);
    if (_imagePath.startsWith('/images/')) {
      _imagePath = '${AppConfig.backendBaseUrl}$_imagePath';
    }
    _placeInformationJson = widget.placeInformationJson;
    if (widget.placeInformationJson != null) {
      try {
        final info = json.decode(widget.placeInformationJson!);
        if (info is Map && info['website'] != null) {
          _website = info['website']?.toString();
        }
      } catch (_) {}
    }
    _address = widget.address;
    if (_address != null && _address!.trim().isNotEmpty) {
      final verifiedArea = PlacesService().resolveAreaFromAddress(_address!, _area);
      if (verifiedArea.isNotEmpty && verifiedArea != 'Penang') {
        _area = verifiedArea;
      }
    }
    _hasStreetView = widget.hasStreetView ?? false;
    _mapillaryImageId = widget.mapillaryImageId;
    _placeId = widget.placeId;
    _rawHoursText = widget.rawHoursText;
    _searchKeywords = widget.searchKeywords != null ? List<String>.from(widget.searchKeywords!) : [];
    _primaryCategory = widget.primaryCategory;
    _subCategories = widget.subCategories != null ? List<String>.from(widget.subCategories!) : [];

    if (widget.coordinatesJson != null) {
      try {
        _coords = List<double>.from(json.decode(widget.coordinatesJson!));
      } catch (_) {}
    }

    if (_imagePath.isEmpty || _imagePath == 'no_image_found') {
      _resolvePlaceImage();
    }

    // Always fetch latest authoritative details directly from MongoDB places_new collection
    _loadPlaceDetailsFromMongoDB();
  }

  Future<void> _loadPlaceDetailsFromMongoDB() async {
    try {
      final details = await PlacesService().fetchPlaceDetails(
        _title,
        placeId: _placeId,
      );

      if (details != null && mounted) {
        setState(() {
          if (details['title'] != null && details['title'].toString().isNotEmpty) {
            _title = details['title'].toString();
          }
          if (details['address'] != null && details['address'].toString().isNotEmpty) {
            _address = details['address'].toString();
          }
          if (details['area'] != null && details['area'].toString().isNotEmpty) {
            _area = details['area'].toString();
          }
          if (_address != null && _address!.trim().isNotEmpty) {
            final verifiedArea = PlacesService().resolveAreaFromAddress(_address!, _area);
            if (verifiedArea.isNotEmpty && verifiedArea != 'Penang') {
              _area = verifiedArea;
            }
          }
          // Requirement 1: Make sure description is showing description not summary
          if (details['description'] != null && details['description'].toString().trim().isNotEmpty) {
            _description = details['description'].toString().trim();
          }
          if (details['imagePath'] != null &&
              details['imagePath'].toString().isNotEmpty &&
              details['imagePath'] != 'no_image_found') {
            _imagePath = details['imagePath'].toString();
          }
          // Requirement 2: Business hours refers to opening_hours
          if (details['businessHours'] != null && details['businessHours'].toString().isNotEmpty) {
            _businessHours = details['businessHours'].toString();
          }
          if (details['placeInformationJson'] != null &&
              details['placeInformationJson'].toString().isNotEmpty) {
            _placeInformationJson = details['placeInformationJson'].toString();
          }
          if (details['website'] != null && details['website'].toString().isNotEmpty) {
            _website = details['website'].toString();
          } else if (details['placeInformationJson'] != null) {
            try {
              final info = json.decode(details['placeInformationJson'].toString());
              if (info is Map && info['website'] != null) {
                _website = info['website']?.toString();
              }
            } catch (_) {}
          }
          if (details['hasStreetView'] == true) {
            _hasStreetView = true;
          }
          if (details['mapillaryImageId'] != null) {
            _mapillaryImageId = details['mapillaryImageId'].toString();
          }
          if (details['id'] != null && details['id'].toString().isNotEmpty) {
            _placeId = details['id'].toString();
          }
          // Requirement 3: tags for raw_hours_text & search_keywords
          if (details['rawHoursText'] != null && details['rawHoursText'].toString().trim().isNotEmpty) {
            _rawHoursText = details['rawHoursText'].toString().trim();
          }
          if (details['searchKeywords'] is List) {
            _searchKeywords = (details['searchKeywords'] as List).map((e) => e.toString()).toList();
          } else if (details['searchKeywords'] is String && details['searchKeywords'].toString().trim().isNotEmpty) {
            try {
              final decoded = json.decode(details['searchKeywords']);
              if (decoded is List) {
                _searchKeywords = decoded.map((e) => e.toString()).toList();
              } else {
                _searchKeywords = [details['searchKeywords'].toString()];
              }
            } catch (_) {
              _searchKeywords = [details['searchKeywords'].toString()];
            }
          }
          // Requirement 5: primaryCategory and subCategories for price level filtering
          if (details['primaryCategory'] != null && details['primaryCategory'].toString().isNotEmpty) {
            _primaryCategory = details['primaryCategory'].toString();
          }
          if (details['subCategories'] is List) {
            _subCategories = List<String>.from(details['subCategories']);
          }
          if (details['coordinates'] is List) {
            final c = details['coordinates'] as List;
            if (c.length >= 2) {
              _coords = [
                (c[0] as num).toDouble(),
                (c[1] as num).toDouble(),
              ];
            }
          }
        });
      } else {
        if (_imagePath.isEmpty || _imagePath == 'no_image_found') {
          _resolvePlaceImage();
        }
      }
    } catch (_) {
      if (_imagePath.isEmpty || _imagePath == 'no_image_found') {
        _resolvePlaceImage();
      }
    }
  }

  Future<void> _resolvePlaceImage() async {
    try {
      final photo = await PlacesService().fetchPhotoForPlace(_title, area: _area);
      if (mounted && photo.isNotEmpty && photo != 'no_image_found') {
        setState(() {
          _imagePath = photo;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Stack(
        children: [
          // 1. Destination Image at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.45,
            child: _imagePath == 'no_image_found'
                ? Container(
                    color: AppColors.primaryDarkNavy,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(
                          Icons.landscape,
                          color: AppColors.accentMintTeal,
                          size: 64,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading Image...',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : AppImageWidget(
                    imagePath: _imagePath,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    iconSize: 64,
                  ),
          ),

          // 2. Back Button (overlayed)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.black,
                  size: 18,
                ),
              ),
            ),
          ),

          // Visit Website Button (top right overlay, round icon only with full solid gradient orange)
          if (_isValidWebsite(_website))
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: GestureDetector(
                onTap: () => _launchUrl(_website!),
                child: Container(
                  width: 55, //checkpoint
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Colors.white,
                    size: 35, //checkpoint
                  ),
                ),
              ),
            ),

          // 3. Floating Detail Card at the bottom
          Positioned(
            top: screenHeight * 0.4,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Favorite Heart Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isFavorite = !_isFavorite;
                              if (_isFavorite) {
                                SavedPlacesManager.savePlace({
                                  'title': _title,
                                  'area': _area,
                                  'businessHours': _businessHours,
                                  'description': _description,
                                  'imagePath': _imagePath,
                                  'category': 'Attraction',
                                });
                              } else {
                                SavedPlacesManager.unsavePlace(_title);
                              }
                            });
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _isFavorite
                                  ? AppColors.deepOrange.withValues(alpha: 0.1)
                                  : AppColors.grey.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? AppColors.deepOrange : AppColors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Area information
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/search-result-page-location-pin-icon.png', //checkPoint
                          width: 26,
                          height: 26,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _area,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryRoyalBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Business hours
                    _buildBusinessHoursSection(),
                    const Divider(height: 32, thickness: 1),

                    // Description Header
                    const Text(
                      "About this place",
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Description text
                    Text(
                      _description,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 15,
                        height: 1.6,
                        color: AppColors.textDark,
                      ),
                    ),

                    // 1. Move all tags to show under the place description
                    _buildTagsSection(),

                    // Hint sentence below tags when top-right website button is available
                    if (_isValidWebsite(_website)) ...[
                      const SizedBox(height: 8),
                      const Text(
                        "Tap the top-right website icon to explore and learn more about this place.",
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],

                    _buildAddressSection(),
                    _buildActionButtonsSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessHoursSection() {
    // Attempt to parse business hours JSON
    Map<String, String>? parsedHours;
    try {
      final decoded = json.decode(_businessHours);
      if (decoded is Map && decoded.isNotEmpty) {
        parsedHours = decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    } catch (_) {
      // Keep it null for plain string
    }

    if (parsedHours == null) {
      // Plain string fallback
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/search-result-page-business-hours-clock-icon.png',
            width: 26,
            height: 26,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Hours: $_businessHours",
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      );
    }

    // Let's get today's hours and determine current open/closed status
    final now = DateTime.now();
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final todayName = weekdays[now.weekday - 1];
    
    final status = _getHoursStatus(parsedHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isHoursExpanded = !_isHoursExpanded;
            });
          },
          child: Row(
            children: [
              Image.asset(
                'assets/images/search-result-page-business-hours-clock-icon.png',
                width: 26,
                height: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                    ),
                    children: [
                      const TextSpan(text: "Hours: "),
                      TextSpan(
                        text: status.statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: status.isOpen ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      TextSpan(text: status.timeText),
                    ],
                  ),
                ),
              ),
              Icon(
                _isHoursExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: AppColors.textGrey,
              ),
            ],
          ),
        ),
        if (_isHoursExpanded) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: weekdays.map((day) {
                final dayHours = parsedHours![day] ?? 'Closed';
                final isToday = day == todayName;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${day[0].toUpperCase()}${day.substring(1)}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.black : AppColors.textGrey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        dayHours,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? AppColors.black : AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }



  HoursStatus _getHoursStatus(Map<String, String> parsedHours) {
    final now = DateTime.now();
    final currentDayIndex = now.weekday - 1; // 0 = Monday, 6 = Sunday
    final weekdays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    final weekdayAbbrs = ['Mon', 'Tues', 'Wed', 'Thurs', 'Fri', 'Sat', 'Sun'];
    
    final currentDay = weekdays[currentDayIndex];
    final todayHoursStr = parsedHours[currentDay];
    
    final currentTime = TimeOfDay(hour: now.hour, minute: now.minute);
    
    // Check if open 24 hours
    if (todayHoursStr != null && todayHoursStr.toLowerCase().contains('24 hours')) {
      return HoursStatus(isOpen: true, statusText: 'Open', timeText: ' • Open 24 Hours');
    }
    
    if (todayHoursStr != null && todayHoursStr.toLowerCase() != 'closed') {
      final range = _parseTimeRange(todayHoursStr);
      if (range != null) {
        if (_isTimeInRange(currentTime, range)) {
          final closeStr = todayHoursStr.split(RegExp(r'[–\-]'))[1].trim();
          return HoursStatus(isOpen: true, statusText: 'Open', timeText: ' • Closes $closeStr');
        }
      }
    }
    
    // Closed case - find next open time
    // 1. Check if opens later today
    if (todayHoursStr != null && todayHoursStr.toLowerCase() != 'closed') {
      final range = _parseTimeRange(todayHoursStr);
      if (range != null) {
        final currentMinutes = currentTime.hour * 60 + currentTime.minute;
        final openMinutes = range.open.hour * 60 + range.open.minute;
        if (currentMinutes < openMinutes) {
          final openStr = todayHoursStr.split(RegExp(r'[–\-]'))[0].trim();
          return HoursStatus(isOpen: false, statusText: 'Closed', timeText: ' • Opens $openStr Today');
        }
      }
    }
    
    // 2. Check future days (up to 7 days ahead)
    for (int i = 1; i <= 7; i++) {
      final targetIndex = (currentDayIndex + i) % 7;
      final targetDay = weekdays[targetIndex];
      final targetHoursStr = parsedHours[targetDay];
      
      if (targetHoursStr != null && targetHoursStr.toLowerCase() != 'closed') {
        if (targetHoursStr.toLowerCase().contains('24 hours')) {
          return HoursStatus(isOpen: false, statusText: 'Closed', timeText: ' • Opens 24 Hours ${weekdayAbbrs[targetIndex]}');
        }
        final range = _parseTimeRange(targetHoursStr);
        if (range != null) {
          final openStr = targetHoursStr.split(RegExp(r'[–\-]'))[0].trim();
          final dayName = weekdayAbbrs[targetIndex];
          return HoursStatus(isOpen: false, statusText: 'Closed', timeText: ' • Opens $openStr $dayName');
        }
      }
    }
    
    return HoursStatus(isOpen: false, statusText: 'Closed', timeText: '');
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final cleaned = timeStr.replaceAll(RegExp(r'[\u202f\u00a0\s]+'), ' ').toLowerCase().trim();
    // 1. Check 12-hour format with am/pm (e.g. "10:00 am", "6 pm")
    final match12 = RegExp(r'^(\d+)(?::(\d+))?\s*(am|pm)$').firstMatch(cleaned);
    if (match12 != null) {
      var hour = int.parse(match12.group(1)!);
      final minute = match12.group(2) != null ? int.parse(match12.group(2)!) : 0;
      final ampm = match12.group(3)!;
      if (ampm == 'pm' && hour < 12) {
        hour += 12;
      } else if (ampm == 'am' && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    }

    // 2. Check 24-hour format (e.g. "10:00", "18:00")
    final match24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);
    if (match24 != null) {
      final hour = int.parse(match24.group(1)!);
      final minute = int.parse(match24.group(2)!);
      if (hour >= 0 && hour < 24 && minute >= 0 && minute < 60) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return null;
  }

  TimeRange? _parseTimeRange(String rangeStr) {
    final parts = rangeStr.split(RegExp(r'[–\-]'));
    if (parts.length != 2) return null;
    
    final open = _parseTimeOfDay(parts[0]);
    final close = _parseTimeOfDay(parts[1]);
    
    if (open != null && close != null) {
      return TimeRange(open, close);
    }
    return null;
  }

  bool _isTimeInRange(TimeOfDay current, TimeRange range) {
    final currentMinutes = current.hour * 60 + current.minute;
    final openMinutes = range.open.hour * 60 + range.open.minute;
    var closeMinutes = range.close.hour * 60 + range.close.minute;
    
    if (closeMinutes < openMinutes) {
      closeMinutes += 24 * 60;
      if (currentMinutes < openMinutes) {
        return (currentMinutes + 24 * 60) <= closeMinutes;
      }
    }
    
    return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $urlString');
    }
  }

  Widget _buildTagsSection() {
    final cleanHours = _rawHoursText?.trim();
    final hasRawHours = cleanHours != null &&
        cleanHours.isNotEmpty &&
        cleanHours != 'Check online' &&
        cleanHours.length <= 40;

    final List<String> distinctKeywords = [];
    final Set<String> seen = {};
    for (final raw in _searchKeywords) {
      // Split by pipe '|' or comma ',' in case multiple keywords are bundled in one string
      final parts = raw.split(RegExp(r'[,|]'));
      for (final part in parts) {
        final clean = part.trim();
        if (clean.isNotEmpty && !seen.contains(clean.toLowerCase())) {
          seen.add(clean.toLowerCase());
          distinctKeywords.add(clean);
        }
      }
    }

    if (!hasRawHours && distinctKeywords.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxTagWidth = constraints.maxWidth;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasRawHours)
                Container(
                  constraints: BoxConstraints(maxWidth: maxTagWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE), // Light blue background
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBAE6FD)), // Subtle light blue border
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          cleanHours,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ...distinctKeywords.map((kw) {
                return Container(
                  constraints: BoxConstraints(maxWidth: maxTagWidth),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tag_rounded,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          kw,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowPriceLevel() {
    final allowedCategories = [
      'cafe',
      'cafes',
      'food',
      'dining',
      'dessert',
      'desserts',
      'pastry',
      'pastries',
      'souvenir',
      'souvenirs',
      'workshop',
      'workshops',
      'shopping',
      'market',
      'markets',
    ];

    bool checkMatch(String? text) {
      if (text == null || text.trim().isEmpty) return false;
      final lower = text.toLowerCase();
      return allowedCategories.any((cat) => lower.contains(cat));
    }

    if (checkMatch(_primaryCategory)) return true;
    for (final sub in _subCategories) {
      if (checkMatch(sub)) return true;
    }
    return false;
  }

  bool _isValidWebsite(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final trimmed = url.trim();
    final lower = trimmed.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    // Reject Google Maps / Search links that do not lead to actual venue website
    if (lower.contains('maps.google.') ||
        lower.contains('google.com/maps') ||
        lower.contains('goo.gl/maps') ||
        lower.contains('maps.app.goo.gl') ||
        lower.contains('google.com/search') ||
        lower.contains('google.com/place')) {
      return false;
    }
    return true;
  }

  Widget _buildAddressSection() {
    final hasAddress = _address != null && _address!.trim().isNotEmpty;
    final displayAddress = hasAddress
        ? _address!.trim()
        : (_area.isNotEmpty ? '$_area, Penang, Malaysia' : 'Penang, Malaysia');

    Map<String, dynamic> info = {};
    if (_placeInformationJson != null) {
      try {
        info = json.decode(_placeInformationJson!);
      } catch (_) {}
    }

    final rating = info['rating'];
    final reviewsCount = info['reviews_count'] ?? info['review_count'];
    final priceLevel = info['price_level'] ?? info['priceLevel'];
    final phone = info['phone'];

    final hasRating = rating != null && rating.toString().isNotEmpty;
    final canShowPrice = _shouldShowPriceLevel();
    final hasPrice = canShowPrice && priceLevel != null && priceLevel.toString().trim().isNotEmpty;
    final hasPhone = phone != null && phone.toString().trim().isNotEmpty;

    final hasTableData = hasRating || hasPrice || hasPhone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32, thickness: 1),
        // Requirement 4: change place information to "Address"
        const Text(
          "Address",
          style: TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.black,
          ),
        ),
        const SizedBox(height: 8),
        // Requirement 4: address data got from MongoDB is show like description font style
        Text(
          displayAddress,
          style: const TextStyle(
            fontFamily: 'SF Pro',
            fontSize: 15,
            height: 1.6,
            color: AppColors.textDark,
          ),
        ),
        if (hasTableData) ...[
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FixedColumnWidth(110),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              if (hasRating)
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Rating",
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            reviewsCount != null &&
                                    reviewsCount.toString().isNotEmpty &&
                                    reviewsCount.toString() != '0'
                                ? "${rating.toString()} (${reviewsCount.toString()} reviews)"
                                : rating.toString(),
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              // Requirement 5: only show price level for specified categories with Price level label
              if (hasPrice)
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Price level",
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        priceLevel.toString(),
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 15,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              if (hasPhone)
                TableRow(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Phone",
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        phone.toString(),
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 15,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtonsSection() {
    final bool hasCoords = _coords != null && _coords!.length == 2;
    if (!_hasStreetView && !hasCoords) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        if (_hasStreetView || hasCoords) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                final double lat = hasCoords ? _coords![1] : 0.0;
                final double lng = hasCoords ? _coords![0] : 0.0;
                StreetViewSelectionDialog.openGoogleStreetView(
                  context,
                  lat,
                  lng,
                  title: _title,
                  hasStreetView: _hasStreetView,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304FFE), // Colors.indigoAccent[700] per GEMINI.md
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.panorama_photosphere, color: Colors.white),
              label: Text(
                _hasStreetView ? "360° Street View" : "Explore Photos & 360°",
                style: const TextStyle(
                  fontFamily: 'Roboto Mono',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (hasCoords) const SizedBox(height: 12),
        ],
        if (hasCoords) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                // Switch tab to Map (index 2)
                MainNavigation.selectedTabNotifier.value = 2;
                // Focus the coordinates on Map
                MainNavigation.mapFocusNotifier.value = MapLocation(
                  name: _title,
                  lat: _coords![1], // latitude is index 1
                  lng: _coords![0], // longitude is index 0
                  description: _description,
                );
                // Pop back to root to reveal MainNavigation with Map Tab active
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryRoyalBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.map),
              label: const Text(
                "Open in Map",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class TimeRange {
  final TimeOfDay open;
  final TimeOfDay close;
  TimeRange(this.open, this.close);
}

class HoursStatus {
  final bool isOpen;
  final String statusText;
  final String timeText;
  HoursStatus({required this.isOpen, required this.statusText, required this.timeText});
}
