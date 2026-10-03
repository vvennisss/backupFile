import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme.dart';
import '../services/stamps_service.dart';
import '../controllers/trip_controller.dart';
import 'main_navigation.dart';

// Export DigitalStamp and StampsService for external references
export '../services/stamps_service.dart' show DigitalStamp, StampsService;

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
            child: GestureDetector(
              onTap: () {
                StampDetailHelper.showStampDetailBottomSheet(context, stamp);
              },
              child: _buildStampCarouselCard(stamp),
            ),
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
class StampsCollectionScreen extends StatelessWidget {
  const StampsCollectionScreen({super.key});

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
          final stamps = snapshot.data ?? StampsService.cachedStamps;

          if (stamps.isEmpty && snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF304FFE)),
              ),
            );
          }

          if (snapshot.hasError && stamps.isEmpty) {
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

          if (stamps.isEmpty) {
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

          final unlockedCount = stamps.where((s) => s.isUnlocked).length;
          final totalCount = stamps.length;
          final progressPercent = totalCount > 0 ? (unlockedCount / totalCount) : 0.0;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- HEADER PROGRESS BANNER ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Collection Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF303030),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF304FFE).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unlockedCount / $totalCount Collected',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF304FFE),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF304FFE)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- GRID OF ALL STAMPS ---
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.78,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final stamp = stamps[index];
                      return _buildGridStampCard(context, stamp);
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

  Widget _buildGridStampCard(BuildContext context, DigitalStamp stamp) {
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
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Perforated Stamp with Image (Blurred if locked)
            Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: StampClipper(),
                  child: Container(
                    width: 84,
                    height: 84,
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
                    width: 36,
                    height: 36,
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
                      size: 18,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Stamp Name / Title
            Text(
              stamp.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: stamp.isUnlocked ? const Color(0xFF303030) : const Color(0xFF505050),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

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

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setPitch(1.0);
      _flutterTts.setCompletionHandler(() {
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
      final stamp = widget.stamp;
      final textToRead = '${stamp.title}. Located in ${stamp.location}. ${stamp.description}. Unlock requirement: ${stamp.unlockRequirement}.';
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

                  // Audio Read-Aloud Button
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
                              _isPlayingAudio ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                              color: _isPlayingAudio ? const Color(0xFFDC2626) : const Color(0xFF304FFE),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isPlayingAudio ? 'Stop Reading' : 'Listen to Stamp Info',
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

  /// Handle "I want to visit" action with distance checking & nearby stamp suggestions
  static void _handleWantToVisit(BuildContext context, DigitalStamp stamp) {
    final controller = TripController();

    // 1. Determine current ongoing trip reference point
    double? refLat;
    double? refLng;
    String refName = 'Current Route';
    bool hasOngoingTrip = false;

    if (controller.hasActiveTrip && controller.activeTrip != null && controller.activeTrip!.places.isNotEmpty) {
      final lastPlace = controller.activeTrip!.places.last;
      refLat = lastPlace.lat;
      refLng = lastPlace.lng;
      refName = lastPlace.name;
      hasOngoingTrip = true;
    } else if (controller.draftItinerary.isNotEmpty) {
      final lastPlace = controller.draftItinerary.last;
      refLat = lastPlace.lat;
      refLng = lastPlace.lng;
      refName = lastPlace.name;
      hasOngoingTrip = true;
    }

    // 2. If there is an ongoing trip, check distance to target stamp spot
    if (hasOngoingTrip && refLat != null && refLng != null) {
      final distanceKm = StampsService.calculateDistanceKm(refLat, refLng, stamp.lat, stamp.lng);

      // If spot is too far (> 10 km away from ongoing trip)
      if (distanceKm > 10.0) {
        final nearbyStamps = StampsService.getNearbyStamps(
          lat: refLat,
          lng: refLng,
          excludeStampId: stamp.id,
          maxDistanceKm: 7.0,
        );

        // Show suggestion dialog with nearby stamp spots
        _showDistantTripDialog(
          context,
          stamp,
          distanceKm,
          refName,
          nearbyStamps,
          onConfirmAddOriginal: () {
            _executeAddPlaceToPlan(context, stamp);
          },
        );
        return;
      }
    }

    // 3. Otherwise, add directly to plan
    _executeAddPlaceToPlan(context, stamp);
  }

  /// Execute adding place to plan and show confirmation
  static void _executeAddPlaceToPlan(BuildContext context, DigitalStamp stamp) {
    final controller = TripController();
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

    controller.addPlaceToPlan(place);

    // Close bottom sheet
    Navigator.pop(context);

    // Show success snackbar with shortcut to Story tab (Trip Planner)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF303030),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Added ${stamp.title} to your travel plan! 🗺️',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View Plan',
          textColor: Colors.amberAccent,
          onPressed: () {
            MainNavigation.selectedTabNotifier.value = 1; // Switch to Story Tab (Travel Companion)
          },
        ),
      ),
    );
  }

  /// Show Distance Warning and nearby stamp suggestions modal
  static void _showDistantTripDialog(
    BuildContext context,
    DigitalStamp targetStamp,
    double distanceKm,
    String ongoingStopName,
    List<MapEntry<DigitalStamp, double>> nearbyStamps, {
    required VoidCallback onConfirmAddOriginal,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.76,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.navigation_rounded, color: Colors.orange.shade800, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Location is Far from Route',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF303030),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1), // soft amber
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Text(
                          '${targetStamp.title} is approximately ${distanceKm.toStringAsFixed(1)} km away from your ongoing trip stop ($ongoingStopName). Visiting it now may cause significant travel delays.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.brown.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (nearbyStamps.isNotEmpty) ...[
                        const Text(
                          '💡 Suggested Nearby Spots with Stamps to Collect:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF303030),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...nearbyStamps.take(3).map((entry) {
                          final nearbyStamp = entry.key;
                          final dist = entry.value;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                ClipPath(
                                  clipper: StampClipper(),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    color: nearbyStamp.color.withOpacity(0.15),
                                    child: Icon(nearbyStamp.icon, size: 22, color: nearbyStamp.color),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nearbyStamp.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF303030),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            '${dist.toStringAsFixed(1)} km away',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF304FFE),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            nearbyStamp.isUnlocked ? '• Unlocked' : '• Stamp to collect',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: nearbyStamp.isUnlocked ? Colors.green.shade700 : Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx); // close distant dialog
                                    _executeAddPlaceToPlan(context, nearbyStamp);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF304FFE),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Add This', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                      ],

                      // Add distant spot anyway
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            onConfirmAddOriginal();
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF304FFE), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            'Add ${targetStamp.title} Anyway',
                            style: const TextStyle(
                              color: Color(0xFF304FFE),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
