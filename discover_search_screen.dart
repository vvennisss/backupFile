import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/places_service.dart';
import '../services/saved_places_manager.dart';
import '../services/search_history_manager.dart';
import 'detail_screen.dart';
import 'discover_screen.dart';
import '../widgets/app_image_widget.dart';

/// Full-screen search page opened when tapping the search bar in Discover Screen.
class DiscoverSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const DiscoverSearchScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<DiscoverSearchScreen> createState() => _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends State<DiscoverSearchScreen> {
  final PlacesService _placesService = PlacesService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, String>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  final List<String> _popularCategories = [
    'Historic Buildings',
    'Clan Houses',
    'Provincial Association',
    'Clan Jetties',
    'Monuments',
    'Places of Worship',
    'Local Souvenirs',
  ];

  @override
  void initState() {
    super.initState();
    SearchHistoryManager.init();

    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialQuery!.trim();
      _performSearch(widget.initialQuery!.trim());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }

    _searchController.addListener(_onSearchInputChanged);
  }

  void _onSearchInputChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchInputChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch([String? queryOverride]) async {
    if (queryOverride != null && queryOverride.isNotEmpty) {
      _searchController.text = queryOverride;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }

    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Unfocus keyboard on search submit
    _focusNode.unfocus();

    // Record in search history
    SearchHistoryManager.addSearch(query);

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _placesService.searchMultiplePlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            // 1. TOP FULL SCREEN SEARCH BAR HEADER
            _buildTopSearchBar(),
            const SizedBox(height: 14),

            // 2. BODY CONTENT
            Expanded(
              child: _buildBodyContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Search Bar Row: Back Button + Rounded Input Field
  Widget _buildTopSearchBar() {
    final bool hasText = _searchController.text.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Back button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppColors.primaryDarkNavy,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Search Field Container
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 10),
                    child: Image.asset(
                      'assets/images/discoverTab-search-icon.png',
                      width: 26,
                      height: 26,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        color: AppColors.textDark,
                        fontSize: 15,
                      ),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _performSearch(),
                      decoration: const InputDecoration(
                        hintText: 'Where can we take you?',
                        hintStyle: TextStyle(
                          fontFamily: 'SF Pro',
                          color: AppColors.textGrey,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                    child: hasText
                        ? IconButton(
                            key: const ValueKey('search_clear_btn'),
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.grey.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textDark,
                                size: 16,
                              ),
                            ),
                            onPressed: _clearSearch,
                          )
                        : const SizedBox(
                            key: ValueKey('empty_clear_space'),
                            width: 12,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryDarkNavy,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching Penang destinations...',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return _buildInitialSearchSuggestions();
    }

    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }

    return _buildSearchResultsList();
  }

  /// Initial suggestions view: Recent Searches + Popular Categories
  Widget _buildInitialSearchSuggestions() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. RECENT SEARCHES
          ValueListenableBuilder<List<String>>(
            valueListenable: SearchHistoryManager.recentSearchesNotifier,
            builder: (context, list, _) {
              if (list.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Searches',
                        style: TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF303030), // Colors.grey[850]
                        ),
                      ),
                      TextButton(
                        onPressed: () => SearchHistoryManager.clearAll(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Clear All',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13,
                            color: Color(0xFF304FFE), // indigoAccent[700]
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: list.map((query) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _performSearch(query),
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: AppColors.grey.withValues(alpha: 0.22),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  size: 15,
                                  color: AppColors.textGrey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  query,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 13,
                                    color: AppColors.primaryDarkNavy,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () => SearchHistoryManager.removeSearch(query),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: AppColors.textGrey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // 2. DISCOVER PENANG CATEGORIES
          const Text(
            'Discover Categories',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030), // Colors.grey[850]
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap any category to quickly explore attractions in Penang:',
            style: TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _popularCategories.map((category) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _performSearch(category),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF304FFE).withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.travel_explore_rounded,
                          size: 15,
                          color: Color(0xFF304FFE),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDarkNavy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Empty State when no places match query
  Widget _buildNoResultsState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 38,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No results for "${_searchController.text}"',
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF303030),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for clan house, temple, cafe, beach, or nature.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 13,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: ['Clan Houses', 'Temples', 'Cafes', 'Nature'].map((suggestion) {
                return ActionChip(
                  label: Text(suggestion),
                  labelStyle: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 12,
                    color: Color(0xFF304FFE),
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.white,
                  side: BorderSide(color: const Color(0xFF304FFE).withValues(alpha: 0.3)),
                  onPressed: () => _performSearch(suggestion),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Search Results List
  Widget _buildSearchResultsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Count Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Search Results',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030), // Colors.grey[850]
                ),
              ),
              Text(
                '${_searchResults.length} places found',
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        // List of Cards
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                            hasStreetView: item['hasStreetView'] == 'true',
                            mapillaryImageId: item['mapillaryImageId']?.toString(),
                            placeId: item['id']?.toString() ?? item['_id']?.toString(),
                            rawHoursText: item['rawHoursText'],
                            primaryCategory: item['primaryCategory'] ?? category,
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
                            color: Colors.black.withValues(alpha: 0.04),
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
                            height: 140,
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
                                // Title and Save Heart
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF303030),
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
                                const SizedBox(height: 8),

                                // Category Tag & Area
                                Row(
                                  children: [
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
                                              fontFamily: 'SF Pro',
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: tagColor.text,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (area.isNotEmpty && area != 'Penang') ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 14,
                                        color: AppColors.textGrey,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        area,
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 12,
                                          color: AppColors.textGrey,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Description Summary
                                Text(
                                  description,
                                  style: const TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
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
    );
  }
}
