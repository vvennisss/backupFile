import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/weather_service.dart';
import '../services/places_service.dart';
import '../services/saved_places_manager.dart';
import '../services/search_history_manager.dart';
import 'detail_screen.dart';
import 'weather_screen.dart';
import 'service_list_screen.dart';
import 'main_navigation.dart';
import '../widgets/app_image_widget.dart';


class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => DiscoverScreenState();
}

class DiscoverScreenState extends State<DiscoverScreen> {
  final WeatherService _weatherService = WeatherService();
  final PlacesService _placesService = PlacesService();
  
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoadingWeather = true;
  
  // Search state
  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchActive = false;
  
  // Famous Attractions Category selector
  String _selectedCategory = 'Clan Houses';
  final List<String> _categories = [
    'Clan Houses',
    'Provincial Associations',
    'Clan Jetties',
    'Historic Buildings',
    'Monuments',
    'Places of Worship',
    'Nature & Parks'
  ];
  Map<String, List<Map<String, String>>> _categoryAttractionsMap = {};
  bool _isLoadingCategory = false;

  @override
  void initState() {
    super.initState();
    SearchHistoryManager.init();
    _searchController.addListener(_onSearchInputChanged);
    _loadWeather();
    _loadCategoryData(_selectedCategory);
  }

  void _onSearchInputChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _getDbQueryForCategory(String category) {
    switch (category) {
      case 'Clan Houses':
        return 'clan houses';
      case 'Provincial Associations':
        return 'provincial associations';
      case 'Clan Jetties':
        return 'clan jetty';
      case 'Historic Buildings':
        return 'historic buildings';
      case 'Monuments':
        return 'monuments';
      case 'Places of Worship':
        return 'places of worship';
      case 'Nature & Parks':
        return 'nature & parks';
      default:
        return category.toLowerCase();
    }
  }

  Future<void> _loadCategoryData(String category) async {
    if (_categoryAttractionsMap.containsKey(category)) return;

    setState(() {
      _isLoadingCategory = true;
    });

    try {
      final queryStr = _getDbQueryForCategory(category);
      final results = await _placesService.searchMultiplePlaces(queryStr);
      setState(() {
        _categoryAttractionsMap[category] = results;
        _isLoadingCategory = false;
      });
    } catch (e) {
      setState(() {
        _categoryAttractionsMap[category] = [];
        _isLoadingCategory = false;
      });
    }
  }

  Future<void> _loadWeather() async {
    try {
      await _weatherService.fetchWeather();
      setState(() {
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  void _handleSearch([String? queryOverride]) async {
    if (queryOverride != null && queryOverride.isNotEmpty) {
      _searchController.text = queryOverride;
    }
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Record in recent searches
    SearchHistoryManager.addSearch(query);

    setState(() {
      _isSearching = true;
      _isSearchActive = true;
    });

    try {
      final results = await _placesService.searchMultiplePlaces(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void resetSearch() {
    setState(() {
      _searchController.clear();
      _searchResults.clear();
      _isSearchActive = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: _isSearchActive ? _buildSearchScreenLayout() : _buildHomeScreenLayout(),
          ),
          if (_isSearching)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.15),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkNavy,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHomeScreenLayout() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // 1. TOP HEADER (Discover & Weather Icon)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discover',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkNavy,
                  ),
                ),
                Row(
                  children: [
                    // AI Bird Companion Header Action
                    GestureDetector(
                      onTap: () {
                        MainNavigation.selectedTabNotifier.value = 1; // Redirect to Story Tab (Travel Companion)
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Text('🐦', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                      ),
                    ),

                    // Weather Icon
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WeatherScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _isLoadingWeather
                            ? SizedBox(
                                width: 34,
                                height: 34,
                                child: Image.asset(
                                  'assets/images/penang-weather-loading-waitingServer-animation-gif.gif',
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Image.asset(
                                'assets/images/discoverTab-weather-icon.png',
                                width: 34,
                                height: 34,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 2. AI TRAVEL COMPANION BANNER (Redirects to Story Tab)
            GestureDetector(
              onTap: () {
                MainNavigation.selectedTabNotifier.value = 1; // Redirect to Story Tab (Travel Companion)
              },
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 140),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF19244E), Color(0xFF2E45A3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF19244E).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Text Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'AI TRIP COMPANION',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Plan With Bird Companion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap in to start planning your dream Penang itinerary!',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 11.5,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Tap to Start Planning',
                                  style: TextStyle(
                                    color: Color(0xFF19244E),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.5,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Color(0xFF19244E),
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Happy Bird GIF Container (scaled & dynamically cropped 1:1 in solid white circle)
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 88,
                          height: 88,
                          child: Image.asset(
                            'assets/pink-bird-happy.gif',
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/images/pink-bird-happy.gif',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (context, error2, stackTrace2) {
                                  return const Center(
                                    child: Text('🌸🐦', style: TextStyle(fontSize: 36)),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 3. SEARCH BAR SECTION
            _buildSearchBarWidget(),
            const SizedBox(height: 10),
            _buildRecentSearchesWidget(),
            const SizedBox(height: 22),

            // 4. FAMOUS ATTRACTIONS (VIEW PLACES BY CATEGORY)
            _buildFamousAttractions(),
            const SizedBox(height: 24),

            // 5. OTHER INFORMATION TITLE
            const Text(
              'Other Information:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDarkNavy,
              ),
            ),
            const SizedBox(height: 12),

            // 6. SERVICE BUTTONS
            _buildServiceButtons(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBarWidget() {
    final bool hasTextOrActive = _searchController.text.isNotEmpty || _isSearchActive;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(27),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 10),
            child: Image.asset(
              'assets/images/discoverTab-search-icon.png',
              width: 32,
              height: 32,
            ),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textDark, fontSize: 16),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _handleSearch(),
              decoration: const InputDecoration(
                hintText: 'Where can we take you?',
                hintStyle: TextStyle(color: AppColors.textGrey, fontSize: 16),
                border: InputBorder.none,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(
                scale: animation,
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            child: hasTextOrActive
                ? IconButton(
                    key: const ValueKey('animated_clear_button'),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.grey.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textDark,
                        size: 16,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchResults.clear();
                        _isSearchActive = false;
                      });
                    },
                  )
                : const SizedBox(
                    key: ValueKey('empty_clear_space'),
                    width: 16,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesWidget() {
    return ValueListenableBuilder<List<String>>(
      valueListenable: SearchHistoryManager.recentSearchesNotifier,
      builder: (context, list, child) {
        if (list.isEmpty) return const SizedBox.shrink();
        final topTwo = list.take(2).toList();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.history_rounded,
              size: 16,
              color: AppColors.textGrey,
            ),
            const SizedBox(width: 6),
            const Text(
              'Recent:',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: topTwo.map((query) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleSearch(query),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.grey.withOpacity(0.2),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  query,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryDarkNavy,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => SearchHistoryManager.removeSearch(query),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchScreenLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          
          // Fixed Search Bar on top
          _buildSearchBarWidget(),
          const SizedBox(height: 16),

          // Header Row: Search Results title and Back to Home button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search Results',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDarkNavy,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchController.clear();
                    _searchResults.clear();
                    _isSearchActive = false;
                  });
                },
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryRoyalBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Scrollable results below
          Expanded(
            child: _isSearching
                ? const SizedBox.shrink()
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'No results found. Try search coffee, temple, beach, or nature.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          final title = item['title'] ?? 'Unknown Place';
                          final area = item['area'] ?? 'Penang';
                          final hours = item['businessHours'] ?? 'Check online';
                          final description = item['description'] ?? 'No description available.';
                          final imagePath = item['imagePath'] ?? 'no_image_found';
                          final category = item['category'] ?? 'Attraction';

                          return ValueListenableBuilder<List<Map<String, String>>>(
                            valueListenable: SavedPlacesManager.savedPlacesNotifier,
                            builder: (context, savedList, child) {
                              final isSaved = SavedPlacesManager.isSaved(title);

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(
                                        title: title,
                                        area: area,
                                        businessHours: hours,
                                        description: description,
                                        imagePath: imagePath,
                                        placeInformationJson: item['placeInformation'],
                                        coordinatesJson: item['coordinates'],
                                        address: item['address'],
                                        hasStreetView: item['hasStreetView'] == true || item['hasStreetView'] == 'true',
                                        mapillaryImageId: item['mapillaryImageId']?.toString(),
                                        placeId: item['id']?.toString() ?? item['_id']?.toString(),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top: Thumbnail Image
                                       AppImageWidget(
                                         imagePath: imagePath,
                                         height: 130,
                                         width: double.infinity,
                                         fit: BoxFit.cover,
                                         borderRadius: const BorderRadius.only(
                                           topLeft: Radius.circular(16),
                                           topRight: Radius.circular(16),
                                         ),
                                       ),
                                      // Bottom: Content info
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Header Row: Title and Save Heart
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.black,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                GestureDetector(
                                                  onTap: () {
                                                    if (isSaved) {
                                                      SavedPlacesManager.unsavePlace(title);
                                                    } else {
                                                      SavedPlacesManager.savePlace({
                                                        'title': title,
                                                        'area': area,
                                                        'businessHours': hours,
                                                        'description': description,
                                                        'imagePath': imagePath,
                                                        'category': category,
                                                      });
                                                    }
                                                  },
                                                  child: Icon(
                                                    isSaved ? Icons.favorite : Icons.favorite_border,
                                                    color: isSaved ? AppColors.deepOrange : AppColors.textGrey,
                                                    size: 26,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // Category Tag
                                            Builder(
                                              builder: (context) {
                                                final tagColor = getCategoryColor(category);
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: tagColor.background,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    category.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: tagColor.text,
                                                    ),
                                                  ),
                                                );
                                              }
                                            ),
                                            const SizedBox(height: 10),

                                            // Description Summary
                                            Text(
                                              description,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textDark,
                                                height: 1.4,
                                              ),
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // --- VIEW PLACES BY CATEGORY LAYOUT ---
  Widget _buildFamousAttractions() {
    final currentList = _categoryAttractionsMap[_selectedCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'View Places by Category:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDarkNavy,
          ),
        ),
        const SizedBox(height: 12),

        // Category Chips
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = cat.toLowerCase() == _selectedCategory.toLowerCase();

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                  _loadCategoryData(cat);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.secondaryRoyalBlue : AppColors.white,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.white : AppColors.primaryDarkNavy,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),

        // Horizontal List of Attraction Cards
        SizedBox(
          height: 235,
          child: _isLoadingCategory
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryDarkNavy,
                  ),
                )
              : currentList.isEmpty
                  ? const Center(
                      child: Text('No places found for this category.', style: TextStyle(color: AppColors.textGrey)),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentList.length,
                      itemBuilder: (context, index) {
                        final attraction = currentList[index];
                        final title = attraction['title'] ?? 'Unknown Place';
                        final area = attraction['area'] ?? 'Penang';
                        final hours = attraction['businessHours'] ?? 'Check online';
                        final desc = attraction['description'] ?? '';
                        final imagePath = attraction['imagePath'] ?? 'no_image_found';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(
                                  title: title,
                                  area: area,
                                  businessHours: hours,
                                  description: desc,
                                  imagePath: imagePath,
                                  placeInformationJson: attraction['placeInformation'],
                                  coordinatesJson: attraction['coordinates'],
                                  address: attraction['address'],
                                  hasStreetView: attraction['hasStreetView'] == true || attraction['hasStreetView'] == 'true',
                                  mapillaryImageId: attraction['mapillaryImageId']?.toString(),
                                  placeId: attraction['id']?.toString() ?? attraction['_id']?.toString(),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 16, bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Place Image
                                 AppImageWidget(
                                   imagePath: imagePath,
                                   height: 135,
                                   width: 160,
                                   fit: BoxFit.cover,
                                   borderRadius: const BorderRadius.only(
                                     topLeft: Radius.circular(16),
                                     topRight: Radius.circular(16),
                                   ),
                                 ),
                                
                                // Info Text Group
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.black,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'in $area',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textGrey,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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

  // --- SERVICE BUTTONS GRID ---
  Widget _buildServiceButtons() {
    final List<Map<String, String>> services = [
      {
        'title': 'Hotels & Stays',
        'image': 'assets/images/accommodation-hotel-stay-image-button.png',
        'route': 'accommodations',
      },
      {
        'title': 'Car Rentals',
        'image': 'assets/images/carRentals-button-image.png',
        'route': 'car-rentals',
      },
      {
        'title': 'Rapid Buses',
        'image': 'assets/images/rapidPenang-buses-button-image.png',
        'route': 'rapid-buses',
      },
      {
        'title': 'Ferry Service',
        'image': 'assets/images/penang-ferry-service-button-image.png',
        'route': 'ferry-service',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final service = services[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ServiceListScreen(
                  serviceName: service['title']!,
                  serviceRoute: service['route']!,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: DecorationImage(
                image: AssetImage(service['image']!),
                fit: BoxFit.cover,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Top-Right Diagonal Arrow Icon (white circle with blue arrow)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_outward,
                      color: AppColors.secondaryRoyalBlue,
                      size: 18,
                    ),
                  ),
                ),
                // Bottom Text Container (rounded translucent white background)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      service['title']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TagColor {
  final Color background;
  final Color text;
  const TagColor({required this.background, required this.text});
}

TagColor getCategoryColor(String category) {
  final cat = category.toLowerCase().trim();
  
  if (cat.contains('cafe') || 
      cat.contains('food') || 
      cat.contains('beverage') || 
      cat.contains('hawker') || 
      cat.contains('restaurant') || 
      cat.contains('bistro') ||
      cat.contains('bar') ||
      cat.contains('coffee') ||
      cat.contains('confectionery') ||
      cat.contains('ice_cream')) {
    // Warm Orange/Amber theme for food
    return const TagColor(
      background: Color(0xFFFFF3E0), // Amber light
      text: Color(0xFFE65100),       // Deep orange/amber
    );
  }
  
  if (cat.contains('worship') || 
      cat.contains('temple') || 
      cat.contains('mosque') || 
      cat.contains('church')) {
    // Purple theme for religious places
    return const TagColor(
      background: Color(0xFFF3E5F5), // Purple light
      text: Color(0xFF4A148C),       // Deep purple
    );
  }
  
  if (cat.contains('heritage') || 
      cat.contains('history') || 
      cat.contains('historic') || 
      cat.contains('museum') || 
      cat.contains('gallery') || 
      cat.contains('art') || 
      cat.contains('mural') ||
      cat.contains('cultural')) {
    // Indigo/Blue theme for heritage & arts
    return const TagColor(
      background: Color(0xFFE8EAF6), // Indigo light
      text: Color(0xFF1A237E),       // Indigo deep
    );
  }
  
  if (cat.contains('nature') || 
      cat.contains('park') || 
      cat.contains('beach') || 
      cat.contains('outdoor') || 
      cat.contains('adventure') || 
      cat.contains('river') ||
      cat.contains('protected')) {
    // Green/Teal theme for nature & outdoors
    return const TagColor(
      background: Color(0xFFE8F5E9), // Green light
      text: Color(0xFF1B5E20),       // Deep green
    );
  }
  
  if (cat.contains('shopping') || 
      cat.contains('mall') || 
      cat.contains('handicraft') || 
      cat.contains('souvenir')) {
    // Pink/Rose theme for shopping
    return const TagColor(
      background: Color(0xFFFCE4EC), // Pink light
      text: Color(0xFF880E4F),       // Deep pink
    );
  }

  if (cat.contains('wellness') || 
      cat.contains('spa') || 
      cat.contains('beauty')) {
    // Teal/Cyan theme for wellness
    return const TagColor(
      background: Color(0xFFE0F2F1), // Teal light
      text: Color(0xFF004D40),       // Deep teal
    );
  }

  if (cat.contains('hotel') || 
      cat.contains('accommodation') || 
      cat.contains('transit') || 
      cat.contains('hub')) {
    // Cyan/Light Blue theme for transit & accommodation
    return const TagColor(
      background: Color(0xFFE1F5FE), // Light blue
      text: Color(0xFF01579B),       // Dark blue
    );
  }
  
  // General/Default theme (Mint Teal)
  return TagColor(
    background: const Color(0xFFC4E7E5).withOpacity(0.4),
    text: const Color(0xFF253C96),
  );
}
