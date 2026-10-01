import 'package:flutter/material.dart';
import '../theme.dart';
import 'discover_screen.dart';
import 'profile_screen.dart';
import 'map_screen.dart';
import 'studio_screen.dart';
import 'travel_companion_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  // Notifiers for programmatically switching tabs and focusing map locations
  static final ValueNotifier<int> selectedTabNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<MapLocation?> mapFocusNotifier = ValueNotifier<MapLocation?>(null);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  final GlobalKey<DiscoverScreenState> _discoverKey = GlobalKey<DiscoverScreenState>();

  // Screens corresponding to each tab
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DiscoverScreen(key: _discoverKey),
      const TravelCompanionScreen(), // Tab 1: Story Tab (Travel Companion & Itinerary Planning)
      const MapScreen(), // Tab 2: Live Maps
      const StudioScreen(),
      const ProfileScreen(),
    ];
    MainNavigation.selectedTabNotifier.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _selectedIndex = MainNavigation.selectedTabNotifier.value;
      });
    }
  }

  @override
  void dispose() {
    MainNavigation.selectedTabNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final isChatTab = _selectedIndex == 1;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedIndex != 0) {
          MainNavigation.selectedTabNotifier.value = 0;
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: (isKeyboardOpen || isChatTab)
            ? null
            : Container(
                color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1A237E), // Colors.indigo[900]
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabItem(
                  index: 0,
                  iconPath: 'assets/images/navigationBar-discover-icon.png',
                ),
                _buildTabItem(
                  index: 1,
                  iconPath: 'assets/images/navigationBar-map-icon.png',
                ),
                _buildTabItem(
                  index: 2,
                  iconPath: 'assets/images/navigationBar-storyTab-compass-icon.png',
                ),
                _buildTabItem(
                  index: 3,
                  iconPath: 'assets/images/navigationBar-studioTab-bag-icon.png',
                ),
                _buildTabItem(
                  index: 4,
                  iconPath: 'assets/images/navigationBar-profile-icon.png',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String iconPath,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        if (_selectedIndex == index) {
          if (index == 0) {
            _discoverKey.currentState?.resetSearch();
          }
        } else {
          MainNavigation.selectedTabNotifier.value = index;
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        transform: Matrix4.translationValues(0, isSelected ? -16 : 0, 0),
        width: isSelected ? 60 : 50,
        height: isSelected ? 60 : 50,
        decoration: isSelected
            ? const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF304FFE), // Vibrant blue floating circle highlight
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              )
            : null,
        child: Center(
          child: Opacity(
            opacity: isSelected ? 1.0 : 0.65,
            child: Image.asset(
              iconPath,
              width: isSelected ? 45 : 32,
              height: isSelected ? 45 : 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// Simple Placeholder Screen for undeveloped tabs
class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: AppColors.primaryDarkNavy.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              '$title Screen',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDarkNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Under Development',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
