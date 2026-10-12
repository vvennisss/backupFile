import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme.dart';
import '../services/stamps_service.dart';
import '../controllers/trip_controller.dart';
import 'draft_plan_screen.dart';
import 'main_navigation.dart';

// Export DigitalStamp, StampsService, and kPredefined28DigitalStamps for external references
export '../services/stamps_service.dart' show DigitalStamp, StampsService, kPredefined28DigitalStamps;

// --- CUSTOM PERFORATED STAMP CLIPPER ---
class StampClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);

    const double radius = 4.0;
    const double diameter = radius * 2;
    const double gap = 6.0;

    // Top Edge
    double x = 0.0;
    while (x < size.width) {
      path.lineTo(x, 0);
      x += gap;
      if (x + diameter > size.width) break;
      path.arcToPoint(
        Offset(x + diameter, 0),
        radius: const Radius.circular(radius),
        clockwise: false,
      );
      x += diameter;
    }
    path.lineTo(size.width, 0);

    // Right Edge
    double y = 0.0;
    while (y < size.height) {
      path.lineTo(size.width, y);
      y += gap;
      if (y + diameter > size.height) break;
      path.arcToPoint(
        Offset(size.width, y + diameter),
        radius: const Radius.circular(radius),
        clockwise: false,
      );
      y += diameter;
    }
    path.lineTo(size.width, size.height);

    // Bottom Edge
    x = size.width;
    while (x > 0) {
      path.lineTo(x, size.height);
      x -= gap;
      if (x - diameter < 0) break;
      path.arcToPoint(
        Offset(x - diameter, size.height),
        radius: const Radius.circular(radius),
        clockwise: false,
      );
      x -= diameter;
    }
    path.lineTo(0, size.height);

    // Left Edge
    y = size.height;
    while (y > 0) {
      path.lineTo(0, y);
      y -= gap;
      if (y - diameter < 0) break;
      path.arcToPoint(
        Offset(0, y - diameter),
        radius: const Radius.circular(radius),
        clockwise: false,
      );
      y -= diameter;
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// --- STUDIO SCREEN (TAB 4) ---
class StudioScreen extends StatefulWidget {
  const StudioScreen({super.key});

  @override
  State<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends State<StudioScreen> {
  late final PageController _pageController;
  double _pageOffset = 0.0;

  @override
  void initState() {
    super.initState();
    StampsService.initCache();
    _pageController = PageController(
      viewportFraction: 0.68,
      initialPage: 0,
    )..addListener(() {
        if (mounted) {
          setState(() {
            _pageOffset = _pageController.page ?? 0.0;
          });
        }
      });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: StreamBuilder<List<DigitalStamp>>(
          stream: StampsService.streamStamps(),
          initialData: StampsService.cachedStamps.isNotEmpty ? StampsService.cachedStamps : null,
          builder: (context, snapshot) {
            final allStamps = snapshot.data ?? StampsService.cachedStamps;
            final isLoading = allStamps.isEmpty && snapshot.connectionState == ConnectionState.waiting;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // --- TITLE SECTION ---
                  const Text(
                    'Digital Passport',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030), // Colors.grey[850]
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'My Stamp Collections Preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryRoyalBlue.withOpacity(0.85),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- HORIZONTAL CAROUSEL ---
                  if (isLoading)
                    Container(
                      height: 230,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF304FFE)),
                      ),
                    )
                  else if (allStamps.isEmpty)
                    _buildEmptyUnlockedState(context)
                  else
                    _buildStampsCarousel(allStamps),

                  const SizedBox(height: 24),

                  // --- VIEW ALL BUTTON ---
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StampsCollectionScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF304FFE), // Colors.indigoAccent[700]
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: const Color(0xFF304FFE).withOpacity(0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // --- PHOTO STUDIO TITLE ---
                  const Text(
                    'Photo Studio',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030), // Colors.grey[850]
                    ),
                  ),
                  const SizedBox(height: 12),

                  // --- GRADIENT STUDIO CARD ---
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PhotoStudioScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE0F7FA), // Soft blue-teal
                            Color(0xFFF3E5F5), // Soft lavender-pink
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -16,
                            bottom: -16,
                            child: Icon(
                              Icons.camera_enhance_rounded,
                              size: 110,
                              color: const Color(0xFF304FFE).withOpacity(0.08),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Start your photo creation here',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDarkNavy.withOpacity(0.85),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Personalize your Penang trip with custom backgrounds, stickers, and memory templates!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: const [
                                    Text(
                                      'Enter Studio',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF304FFE),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: Color(0xFF304FFE),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Empty state when no stamps are in the database
  Widget _buildEmptyUnlockedState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF304FFE).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.collections_bookmark_rounded,
              size: 34,
              color: Color(0xFF304FFE),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Digital Passport Ready',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF303030), // Colors.grey[850]
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Visit attractions and cultural spots across Penang to unlock digital stamps in your passport!',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Carousel for stamps preview:
  /// - Unlocked stamps: shown crisp, vibrant and unblurred.
  /// - Locked stamps: exact stamp image is blurred with a stylish lock badge.
  Widget _buildStampsCarousel(List<DigitalStamp> stamps) {
    return SizedBox(
      height: 230,
      child: PageView.builder(
        controller: _pageController,
        itemCount: stamps.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final stamp = stamps[index];

          // Calculation of scale animation based on PageView scroll offset
          double scale = 1.0;
          if (_pageController.position.haveDimensions) {
            double value = _pageOffset - index;
            scale = (1.0 - (value.abs() * 0.15)).clamp(0.82, 1.0);
          } else {
            scale = index == 0 ? 1.0 : 0.82;
          }

          return Transform.scale(
            scale: scale,
            child: _buildStampCarouselCard(stamp),
          );
        },
      ),
    );
  }

  Widget _buildStampCarouselCard(DigitalStamp stamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: stamp.isUnlocked
              ? stamp.color.withOpacity(0.35)
              : Colors.grey.shade200,
          width: stamp.isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Perforated stamp outline container (Blurred if locked)
          Stack(
            alignment: Alignment.center,
            children: [
              ClipPath(
                clipper: StampClipper(),
                child: Container(
                  width: 100,
                  height: 100,
                  color: stamp.isUnlocked
                      ? stamp.color.withOpacity(0.12)
                      : Colors.grey.shade200,
                  child: stamp.isUnlocked
                      // Unlocked stamp: Crisp image
                      ? (stamp.imageUrl.isNotEmpty
                          ? Image.network(
                              stamp.imageUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildStampIconContent(stamp, size: 54, iconSize: 28),
                            )
                          : _buildStampIconContent(stamp, size: 54, iconSize: 28))
                      // Locked stamp preview: Blur of the exact stamp
                      : ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
                          child: stamp.imageUrl.isNotEmpty
                              ? Image.network(
                                  stamp.imageUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildStampIconContent(stamp, size: 54, iconSize: 28),
                                )
                              : _buildStampIconContent(stamp, size: 54, iconSize: 28),
                        ),
                ),
              ),

              // Overlay lock badge for locked preview
              if (!stamp.isUnlocked)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stamp.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: stamp.isUnlocked ? Colors.black : const Color(0xFF424242),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            stamp.isUnlocked
                ? (stamp.date.isNotEmpty ? 'Collected: ${stamp.date}' : 'Collected')
                : 'Locked • Tap to reveal',
            style: TextStyle(
              fontSize: 11,
              fontWeight: stamp.isUnlocked ? FontWeight.normal : FontWeight.w600,
              color: stamp.isUnlocked ? Colors.grey : const Color(0xFF304FFE),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  static Widget _buildStampIconContent(DigitalStamp stamp, {double size = 54, double iconSize = 28}) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: stamp.color,
          shape: BoxShape.circle,
        ),
        width: size,
        height: size,
        child: Icon(
          stamp.icon,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}

// =========================================================================
// --- STAMPS COLLECTION SCREEN (VIEW ALL FROM FIRESTORE) ---
// =========================================================================
enum StampSortMode {
  defaultOrder,
  aToZ,
  zToA,
}

class StampsCollectionScreen extends StatefulWidget {
  const StampsCollectionScreen({super.key});

  @override
  State<StampsCollectionScreen> createState() => _StampsCollectionScreenState();
}

class _StampsCollectionScreenState extends State<StampsCollectionScreen> {
  StampSortMode _sortMode = StampSortMode.defaultOrder;
  int _sparkQuoteTapCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
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
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text(
          'My Stamps',
          style: TextStyle(
            color: Color(0xFF303030),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<DigitalStamp>>(
        stream: StampsService.streamStamps(),
        initialData: StampsService.cachedStamps.isNotEmpty ? StampsService.cachedStamps : null,
        builder: (context, snapshot) {
          final rawStamps = snapshot.data ?? StampsService.cachedStamps;

          if (rawStamps.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF304FFE)),
              ),
            );
          }

          if (snapshot.hasError && rawStamps.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load stamps',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF303030)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (rawStamps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.collections_bookmark_outlined, size: 54, color: Colors.grey),
                  SizedBox(height: 12),
                  Text(
                    'No stamps available yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF303030)),
                  ),
                ],
              ),
            );
          }

          // Clone list so sorting does not mutate the cached instance directly
          final stamps = List<DigitalStamp>.from(rawStamps);
          if (_sortMode == StampSortMode.aToZ) {
            stamps.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
          } else if (_sortMode == StampSortMode.zToA) {
            stamps.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
          } else {
            stamps.sort((a, b) => a.order.compareTo(b.order));
          }

          final unlockedCount = stamps.where((s) => s.isUnlocked).length;
          final totalCount = stamps.length;
          final progressPercent = totalCount > 0 ? (unlockedCount / totalCount).clamp(0.0, 1.0) : 0.0;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- HIGHLY VISUAL COLLECTION PROGRESS DASHBOARD ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: _buildVisualProgressCard(unlockedCount, totalCount, progressPercent),
                ),
              ),

              // --- SORT HEADER & SORT A TO Z BUTTON BAR ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Title on Left, Sort Buttons on Right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            '28 Penang Landmarks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF303030),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Right: Sort Mode Controls
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Default (1–28) Button -> Left Icon Only
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _sortMode = StampSortMode.defaultOrder;
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: _sortMode == StampSortMode.defaultOrder
                                        ? const Color(0xFF304FFE)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _sortMode == StampSortMode.defaultOrder
                                          ? const Color(0xFF304FFE)
                                          : Colors.grey.shade300,
                                      width: 1.2,
                                    ),
                                    boxShadow: _sortMode == StampSortMode.defaultOrder
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF304FFE).withOpacity(0.28),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Icon(
                                    Icons.format_list_numbered_rounded,
                                    size: 16,
                                    color: _sortMode == StampSortMode.defaultOrder
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // 2. AZ Button
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (_sortMode == StampSortMode.aToZ) {
                                      _sortMode = StampSortMode.zToA;
                                    } else {
                                      _sortMode = StampSortMode.aToZ;
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (_sortMode == StampSortMode.aToZ || _sortMode == StampSortMode.zToA)
                                        ? const Color(0xFF304FFE)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF304FFE),
                                      width: 1.2,
                                    ),
                                    boxShadow: (_sortMode == StampSortMode.aToZ || _sortMode == StampSortMode.zToA)
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF304FFE).withOpacity(0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _sortMode == StampSortMode.zToA ? 'ZA' : 'AZ',
                                        style: TextStyle(
                                          fontFamily: 'Roboto Mono',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: (_sortMode == StampSortMode.aToZ || _sortMode == StampSortMode.zToA)
                                              ? Colors.white
                                              : const Color(0xFF304FFE),
                                        ),
                                      ),
                                      if (_sortMode == StampSortMode.aToZ || _sortMode == StampSortMode.zToA) ...[
                                        const SizedBox(width: 2),
                                        Icon(
                                          _sortMode == StampSortMode.aToZ
                                              ? Icons.arrow_downward_rounded
                                              : Icons.arrow_upward_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // Bottom Row: Blue guidance text + Sort mode hint
                      Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF304FFE)),
                          const SizedBox(width: 4),
                          const Text(
                            'Tap to view / know more',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF304FFE),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '• ${_sortMode == StampSortMode.aToZ ? "A to Z" : _sortMode == StampSortMode.zToA ? "Z to A" : "Default 1–28"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // --- GRID OF ALL STAMPS ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final stamp = stamps[index];
                      return _buildGridStampCard(context, stamp, index, _sortMode);
                    },
                    childCount: stamps.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Highly visual, modern collection progress dashboard card
  Widget _buildVisualProgressCard(int unlockedCount, int totalCount, double progressPercent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF304FFE).withOpacity(0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF304FFE).withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. TOP HEADER: TITLE ONLY (REMOVED '0/28 collected tag')
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF304FFE).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  color: Color(0xFF304FFE),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Collection Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. SPARK (YELLOW BIRD MASCOT STAMPING) IN FULL HORIZONTAL & "SPARK SAYS" UNDERNEATH
          GestureDetector(
            onTap: () {
              setState(() {
                _sparkQuoteTapCount++;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFFFFBEB),
                    Color(0xFFFEF3C7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Full Horizontal Yellow Bird Stamping GIF
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.asset(
                        'assets/yellow-bird-stamping.gif',
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // "Spark says" section underneath the GIF
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Spark says',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('🐥', style: TextStyle(fontSize: 12)),
                            const Spacer(),
                            const Text(
                              'Tap to interact',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFFD97706),
                                fontWeight: FontWeight.w500,
                                fontFamily: 'SF Pro',
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Icon(Icons.touch_app_rounded, size: 12, color: Color(0xFFD97706)),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Text(
                          _getSparkMessage(unlockedCount, totalCount),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF78350F),
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 3. THICK GRADIENT LINEAR PROGRESS BAR WITH MILESTONES
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Passport Milestones',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  Text(
                    '$unlockedCount of $totalCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF304FFE),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Gradient Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      // Background Track
                      Container(
                        height: 12,
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      // Animated Gradient Progress Fill
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progressPercent),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, animValue, _) {
                          final currentFill = barWidth * animValue.clamp(0.0, 1.0);
                          return Container(
                            height: 12,
                            width: currentFill,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF304FFE),
                                  Color(0xFF2979FF),
                                  Color(0xFF00B0FF),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF304FFE).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 8),

              // 4 Milestone labels (0, 7, 14, 21, 28)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMilestoneMarker('0', unlockedCount >= 0),
                  _buildMilestoneMarker('7 (25%)', unlockedCount >= 7),
                  _buildMilestoneMarker('14 (50%)', unlockedCount >= 14),
                  _buildMilestoneMarker('21 (75%)', unlockedCount >= 21),
                  _buildMilestoneMarker('28 (100% 🏅)', unlockedCount >= 28),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 4. LANDMARK GUIDANCE CALLOUT
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF304FFE).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF304FFE).withOpacity(0.12), width: 1),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  size: 18,
                  color: Color(0xFF304FFE),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap any landmark stamp below to view location details, audio stories & history.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF303030),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Dynamic cheerful messages from Spark the Yellow Bird Mascot
  String _getSparkMessage(int unlockedCount, int totalCount) {
    if (_sparkQuoteTapCount > 0) {
      final extraQuotes = [
        "Stamp, stamp, stamp! 🐾 Penang's street art & heritage are waiting for you!",
        "Did you know? Penang has the most heritage clan jetties in Southeast Asia!",
        "I've got my ink pad ready! Tap any stamp below to plan your next visit! 🗺️",
        "Every landmark has a unique story and audio guide! Tap any stamp to listen!",
      ];
      return extraQuotes[_sparkQuoteTapCount % extraQuotes.length];
    }
    if (unlockedCount == 0) {
      return "Chirp! I'm Spark! 🐥 Visit George Town landmarks to stamp your digital passport and collect all 28!";
    } else if (unlockedCount < 7) {
      return "Chirp chirp! Stamping is my passion! You've stamped $unlockedCount of $totalCount with me! Keep going! 🌟";
    } else if (unlockedCount < 14) {
      return "Awesome! You've unlocked $unlockedCount stamps! Halfway to the milestone badge! 🏛️";
    } else if (unlockedCount < 21) {
      return "Over halfway there! $unlockedCount stamps collected! You're a true Penang explorer! 🎒";
    } else if (unlockedCount < 28) {
      return "Almost done! Only ${totalCount - unlockedCount} more stamps to complete the whole collection! 🚀";
    } else {
      return "Hooray! 🎉 You completed all 28 digital stamps! You're officially a Penang Master Explorer!";
    }
  }

  Widget _buildMilestoneMarker(String label, bool isReached) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
        color: isReached ? const Color(0xFF304FFE) : Colors.grey.shade500,
      ),
    );
  }

  Widget _buildGridStampCard(BuildContext context, DigitalStamp stamp, int index, StampSortMode sortMode) {
    return GestureDetector(
      onTap: () {
        StampDetailHelper.showStampDetailBottomSheet(context, stamp);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: stamp.isUnlocked
                ? stamp.color.withOpacity(0.35)
                : Colors.grey.shade200,
            width: stamp.isUnlocked ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Top Row: Number / Index Badge and Unlock Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (sortMode == StampSortMode.aToZ || sortMode == StampSortMode.zToA)
                        ? '#${index + 1}'
                        : '#${stamp.order > 0 ? stamp.order : index + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (stamp.isUnlocked)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 15),
                  )
                else
                  Icon(Icons.lock_outline_rounded, color: Colors.grey.shade400, size: 14),
              ],
            ),
            const SizedBox(height: 6),

            // Perforated Stamp with Image (Blurred if locked)
            Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: StampClipper(),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: stamp.isUnlocked
                        ? stamp.color.withOpacity(0.12)
                        : Colors.grey.shade200,
                    child: stamp.isUnlocked
                        ? (stamp.imageUrl.isNotEmpty
                            ? Image.network(
                                stamp.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildInnerIcon(stamp),
                              )
                            : _buildInnerIcon(stamp))
                        : ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                            child: stamp.imageUrl.isNotEmpty
                                ? Image.network(
                                    stamp.imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        _buildInnerIcon(stamp),
                                  )
                                : _buildInnerIcon(stamp),
                          ),
                  ),
                ),

                // Center lock overlay if locked
                if (!stamp.isUnlocked)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 17,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Stamp Name / Title
            Text(
              stamp.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: stamp.isUnlocked ? const Color(0xFF303030) : const Color(0xFF505050),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),

            // Location / Locked Status
            Text(
              stamp.isUnlocked ? stamp.location : 'Locked',
              style: TextStyle(
                fontSize: 11,
                fontWeight: stamp.isUnlocked ? FontWeight.normal : FontWeight.w600,
                color: stamp.isUnlocked ? Colors.grey : const Color(0xFF304FFE),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildInnerIcon(DigitalStamp stamp) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: stamp.isUnlocked ? stamp.color : Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
        width: 44,
        height: 44,
        child: Icon(
          stamp.isUnlocked ? stamp.icon : Icons.lock_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// =========================================================================
// --- STAMP DETAIL BOTTOM SHEET WITH AUDIO TTS ---
// =========================================================================
class StampDetailModalSheet extends StatefulWidget {
  final DigitalStamp stamp;

  const StampDetailModalSheet({super.key, required this.stamp});

  @override
  State<StampDetailModalSheet> createState() => _StampDetailModalSheetState();
}

class _StampDetailModalSheetState extends State<StampDetailModalSheet> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingAudio = false;
  int _currentOffset = 0;
  int _lastSpeakingStartOffset = 0;
  late final String _fullTextToRead;

  @override
  void initState() {
    super.initState();
    final stamp = widget.stamp;
    _fullTextToRead = '${stamp.title}. Located in ${stamp.location}. ${stamp.description}. Unlock requirement: ${stamp.unlockRequirement}.';
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setProgressHandler((String text, int start, int end, String word) {
        _currentOffset = _lastSpeakingStartOffset + start;
      });
      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
            _currentOffset = 0;
            _lastSpeakingStartOffset = 0;
          });
        }
      });
      _flutterTts.setPauseHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      });
      _flutterTts.setErrorHandler((_) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _flutterTts.stop();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _toggleAudio() async {
    if (_isPlayingAudio) {
      try {
        await _flutterTts.stop();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    } else {
      setState(() {
        _isPlayingAudio = true;
      });

      // Resume reading from the exact point where user previously stopped
      int startIdx = _currentOffset;
      if (startIdx >= _fullTextToRead.length) {
        startIdx = 0;
        _currentOffset = 0;
      }
      _lastSpeakingStartOffset = startIdx;
      final textToRead = _fullTextToRead.substring(startIdx);

      try {
        final result = await _flutterTts.speak(textToRead);
        if (result == 0 && mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isPlayingAudio = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio service requires a full app restart (rebuild) after adding flutter_tts.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _restartAudio() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    setState(() {
      _currentOffset = 0;
      _lastSpeakingStartOffset = 0;
      _isPlayingAudio = false;
    });
    await _toggleAudio();
  }

  @override
  Widget build(BuildContext context) {
    final stamp = widget.stamp;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF303030)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 4),

                  // Large Stamp perforations visual (blurred if locked)
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipPath(
                        clipper: StampClipper(),
                        child: Container(
                          width: 140,
                          height: 140,
                          color: stamp.isUnlocked
                              ? stamp.color.withOpacity(0.12)
                              : Colors.grey.shade200,
                          child: stamp.isUnlocked
                              ? (stamp.imageUrl.isNotEmpty
                                  ? Image.network(
                                      stamp.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          StampDetailHelper._buildLargeStampIcon(stamp),
                                    )
                                  : StampDetailHelper._buildLargeStampIcon(stamp))
                              : ImageFiltered(
                                  imageFilter: ui.ImageFilter.blur(sigmaX: 9.0, sigmaY: 9.0),
                                  child: stamp.imageUrl.isNotEmpty
                                      ? Image.network(
                                          stamp.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              StampDetailHelper._buildLargeStampIcon(stamp),
                                        )
                                      : StampDetailHelper._buildLargeStampIcon(stamp),
                                ),
                        ),
                      ),
                      if (!stamp.isUnlocked)
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Stamp Title
                  Text(
                    stamp.title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF303030),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Text(
                    stamp.location,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF304FFE),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Audio Read-Aloud / Resume Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Material(
                        color: _isPlayingAudio ? const Color(0xFFFFEBEE) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: _toggleAudio,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isPlayingAudio
                                      ? Icons.stop_circle_rounded
                                      : (_currentOffset > 0 ? Icons.play_arrow_rounded : Icons.volume_up_rounded),
                                  color: _isPlayingAudio ? const Color(0xFFDC2626) : const Color(0xFF304FFE),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isPlayingAudio
                                      ? 'Stop Reading'
                                      : (_currentOffset > 0 ? 'Resume Audio' : 'Listen to Stamp Info'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isPlayingAudio ? const Color(0xFFDC2626) : const Color(0xFF304FFE),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_currentOffset > 0 && !_isPlayingAudio) ...[
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: _restartAudio,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.replay_rounded, size: 16, color: Colors.grey.shade700),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Restart',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Stamp Description / Information
                  Text(
                    stamp.description,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),

                  // Status Badge (Unlocked vs Locked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: stamp.isUnlocked
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: stamp.isUnlocked
                            ? Colors.green.shade200
                            : Colors.orange.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          stamp.isUnlocked
                              ? Icons.check_circle_rounded
                              : Icons.lock_outline_rounded,
                          color: stamp.isUnlocked
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                          size: 24,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          stamp.isUnlocked
                              ? (stamp.date.isNotEmpty
                                  ? 'Collected on ${stamp.date}! You have unlocked this stamp.'
                                  : 'You have unlocked this stamp!')
                              : 'Unlock Requirement:\n${stamp.unlockRequirement}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: stamp.isUnlocked
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                            fontWeight: FontWeight.bold,
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // --- "I WANT TO VISIT" BUTTON ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        StampDetailHelper._handleWantToVisit(context, stamp);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF304FFE),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0xFF304FFE).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_location_alt_rounded, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'I Want to Visit',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
        ],
      ),
    );
  }
}

// =========================================================================
// --- STAMP DETAIL HELPER & DISTANT TRIP SUGGESTIONS ---
// =========================================================================
class StampDetailHelper {
  static void showStampDetailBottomSheet(BuildContext context, DigitalStamp stamp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StampDetailModalSheet(stamp: stamp),
    );
  }

  static Widget _buildLargeStampIcon(DigitalStamp stamp) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: stamp.isUnlocked ? stamp.color : Colors.grey.shade400,
          shape: BoxShape.circle,
        ),
        width: 80,
        height: 80,
        child: Icon(
          stamp.isUnlocked ? stamp.icon : Icons.lock_rounded,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  /// Handle "I want to visit" action:
  /// Directly adds/slots place into user's plan without mascot/dialog warnings.
  static void _handleWantToVisit(BuildContext context, DigitalStamp stamp) {
    _executeAddPlaceToPlan(context, stamp);
  }

  /// Execute adding place to plan, update sequence numbering, distance & transit time, and notify user
  static void _executeAddPlaceToPlan(BuildContext context, DigitalStamp stamp) {
    final controller = TripController();
    final hasActive = controller.hasActiveTrip && controller.activeTrip != null;

    final place = ItineraryPlace(
      id: 'stamp_${stamp.id}',
      name: stamp.title,
      area: stamp.location,
      description: stamp.description,
      lat: stamp.lat,
      lng: stamp.lng,
      category: 'Heritage',
      estimatedStayMinutes: 60,
      icon: stamp.icon,
    );

    // addPlaceToPlan automatically:
    // - Slots place as next stop if active trip exists
    // - Appends to draft plan if no active trip
    // - Recalculates contiguous order/sequence
    // - Recalculates distance and transit time between consecutive stops
    controller.addPlaceToPlan(place, notifyChat: true);

    // Close bottom sheet
    Navigator.pop(context);

    // Determine stop position for informative notification
    final currentList = hasActive ? controller.activeTrip!.places : controller.draftItinerary;
    final assignedIndex = currentList.indexWhere((p) => p.name.toLowerCase() == stamp.title.toLowerCase());
    final stopNumber = assignedIndex != -1 ? assignedIndex + 1 : currentList.length;

    // Send user in-app notification via floating SnackBar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasActive
                        ? 'Slotted as Next Stop (#$stopNumber) 📍'
                        : 'Added to Draft Plan (#$stopNumber) 🗺️',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stamp.title} • Route, distance & transit times updated',
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                      fontFamily: 'SF Pro',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View Plan',
          textColor: const Color(0xFFFFEA00),
          onPressed: () {
            if (hasActive) {
              // Open active trip companion on Story Tab
              MainNavigation.selectedTabNotifier.value = 1;
            } else {
              // Open Draft Plan screen directly
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DraftPlanScreen(controller: controller),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

// =========================================================================
// --- PHOTO STUDIO SCREEN (UNDER DEVELOPMENT) ---
// =========================================================================
class PhotoStudioScreen extends StatelessWidget {
  const PhotoStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 16),
          ),
        ),
        title: const Text(
          'Photo Studio',
          style: TextStyle(
            color: Color(0xFF303030),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0F7FA), Color(0xFFF3E5F5)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 54,
                  color: Color(0xFF304FFE),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Photo Studio',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF303030),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Under Development',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'We are building custom photo filters, stamps overlays, and beautiful trip memory template creators. Stay tuned!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
