import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/firebase_service.dart';
import '../services/saved_places_manager.dart';
import '../services/auth_service.dart';
import 'saved_places_screen.dart';
import 'travel_plans_screen.dart';
import 'rank_info_screen.dart';
import 'saved_trip_plans_screen.dart';
import 'welcome_screen.dart';
import 'account_details_screen.dart';
import '../services/saved_trip_plans_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    UserProfileManager.loadProfile();
  }

  // Segmented progress bar helper mimicking user uploaded screenshot
  Color _getSegmentColor(int index, int total) {
    final ratio = index / total;
    if (ratio < 0.2) return const Color(0xFF9FA8DA); // Light Purple
    if (ratio < 0.4) return const Color(0xFFEF9A9A); // Light Red
    if (ratio < 0.6) return const Color(0xFFFFCC80); // Light Orange
    if (ratio < 0.8) return const Color(0xFFFFF59D); // Light Yellow
    return const Color(0xFFA5D6A7); // Light Green
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: ValueListenableBuilder<UserProfile>(
          valueListenable: UserProfileManager.profileNotifier,
          builder: (context, profile, child) {
            
            // Active badge goal and progress calculation based on the 5 tiered requirements
            final targetRank = profile.activeBadgeGoal;
            final progressRatio = targetRank.getProgressRatio(profile);
            final nextRankProgressText = targetRank.getProgressSummary(profile);

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title on the left top (GEMINI.md typography: 32px bold)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 20, top: 4),
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF303030), // Colors.grey[850]
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),

                  // 1. TOP AVATAR AND EXPERIENCE BAR HEADER CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFF1F7FA), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Tap on badge to view current rank & rank details
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RankInfoScreen(
                                      currentRank: profile.rank,
                                      completedRoutes: profile.completedRoutes,
                                      userProfile: profile,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: profile.rank.color.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                  border: Border.all(
                                    color: profile.rank.color.withValues(alpha: 0.5),
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    profile.rank.badgeAssetPath,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: profile.rank.color.withValues(alpha: 0.15),
                                      child: Icon(
                                        profile.rank.icon,
                                        size: 36,
                                        color: profile.rank.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Segmented Experience Progress Bar (Expanded to prevent overflow, tap to view progress details)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => RankInfoScreen(
                                        currentRank: profile.rank,
                                        completedRoutes: profile.completedRoutes,
                                        userProfile: profile,
                                      ),
                                    ),
                                  );
                                },
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${targetRank.badgeTitle.toUpperCase()}  ',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textGrey,
                                              fontFamily: 'SF Pro',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${(progressRatio * 100).round()}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: targetRank.color,
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Segmented Progress bar animation (10 segments)
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(begin: 0.0, end: progressRatio),
                                      duration: const Duration(seconds: 1),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, animatedRatio, child) {
                                        final totalSegments = 10;
                                        final activeCount = (animatedRatio * totalSegments).round();
                                        
                                        return Row(
                                          children: List.generate(totalSegments, (idx) {
                                            final isActive = idx < activeCount;
                                            return Container(
                                              width: 6,
                                              height: 14,
                                              margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                              decoration: BoxDecoration(
                                                color: isActive 
                                                    ? _getSegmentColor(idx, totalSegments) 
                                                    : Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(1.5),
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      nextRankProgressText,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textGrey,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'SF Pro',
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  fontSize: 24, // Optimized heading size
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF303030),
                                  fontFamily: 'SF Pro',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RankInfoScreen(
                                      currentRank: profile.rank,
                                      completedRoutes: profile.completedRoutes,
                                      userProfile: profile,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: profile.rank.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: profile.rank.color.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(profile.rank.icon, size: 14, color: profile.rank.color),
                                    const SizedBox(width: 4),
                                    Text(
                                      profile.rank.displayName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: profile.rank.color,
                                        fontFamily: 'SF Pro',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Edit button at the end of the username & rank tag row
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const AccountDetailsScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: AppColors.primaryDarkNavy,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // Joined Date (Body size: 12px)
                        Text(
                          'Joined Penang Travel on ${profile.joinedDate}',
                          style: const TextStyle(
                            fontSize: 12, // Spec Body/Desc: 12px
                            color: AppColors.textGrey,
                            fontFamily: 'SF Pro',
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Active Badge Unlock Milestones Box (Tappable to view progress details)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RankInfoScreen(
                                  currentRank: profile.rank,
                                  completedRoutes: profile.completedRoutes,
                                  userProfile: profile,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Icon(Icons.military_tech_rounded, size: 16, color: targetRank.color),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${targetRank.badgeTitle} Unlock Requirements',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF334155),
                                                fontFamily: 'SF Pro',
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Details',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: targetRank.color,
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.arrow_forward_ios_rounded, size: 10, color: targetRank.color),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...List.generate(targetRank.requirements.length, (i) {
                                  final req = targetRank.requirements[i];
                                  final cur = targetRank.getCurrentValue(profile, i);
                                  final ratio = (cur / req.target).clamp(0.0, 1.0);
                                  final isDone = cur >= req.target;

                                  return Padding(
                                    padding: EdgeInsets.only(
                                      bottom: i < targetRank.requirements.length - 1 ? 10.0 : 0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              req.icon,
                                              size: 14,
                                              color: isDone ? Colors.green.shade600 : AppColors.textGrey,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                req.title,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDone ? Colors.green.shade800 : const Color(0xFF334155),
                                                  fontFamily: 'SF Pro',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${cur % 1 != 0 ? cur.toStringAsFixed(1) : cur.toInt()} / ${req.target % 1 != 0 ? req.target.toStringAsFixed(1) : req.target.toInt()} ${req.unit}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDone ? Colors.green.shade700 : AppColors.textGrey,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                            if (isDone) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.check_circle_rounded, size: 13, color: Colors.green),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: ratio,
                                            minHeight: 5,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isDone ? Colors.green : targetRank.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. GRID METRIC BUTTONS
                  const Text(
                    'Dashboard Options',
                    style: TextStyle(
                      fontSize: 18, // Spec Label: 18px
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkNavy,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.15,
                    children: [
                      // Card 1: Saved Places
                      ValueListenableBuilder<List<Map<String, String>>>(
                        valueListenable: SavedPlacesManager.savedPlacesNotifier,
                        builder: (context, savedList, child) {
                          return _buildGridCard(
                            title: 'Saved Places',
                            subtitle: '${savedList.length} spots saved',
                            icon: Icons.favorite,
                            iconColor: AppColors.deepOrange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SavedPlacesScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Card 2: Penang Achievements
                      _buildGridCard(
                        title: 'Achievements',
                        subtitle: '${profile.distanceTravelled} km explored\n(33% covered)',
                        icon: Icons.emoji_events,
                        iconColor: AppColors.amberOrange,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('You completed 82.5 km of trails in Penang!'),
                            ),
                          );
                        },
                      ),
                      // Card 3: Previous Travel History
                      ValueListenableBuilder<List<SavedTripPlan>>(
                        valueListenable: SavedTripPlansManager.savedPlansNotifier,
                        builder: (context, plans, _) {
                          final expiredCount = plans.where((p) => SavedTripPlansManager.isPlanExpired(p)).length;
                          final totalHistory = profile.completedRoutes + expiredCount;
                          return _buildGridCard(
                            title: 'Trip History',
                            subtitle: expiredCount > 0
                                ? '$totalHistory records ($expiredCount archived)'
                                : '${profile.completedRoutes} routes done',
                            icon: Icons.history_edu_rounded,
                            iconColor: AppColors.secondaryRoyalBlue,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TravelPlansScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                      // Card 4: Saved Trip Plan (Active unexpired plans)
                      ValueListenableBuilder<List<SavedTripPlan>>(
                        valueListenable: SavedTripPlansManager.savedPlansNotifier,
                        builder: (context, plans, child) {
                          final activeCount = plans.where((p) => !SavedTripPlansManager.isPlanExpired(p)).length;
                          return _buildGridCard(
                            title: 'Saved Trip Plan',
                            subtitle: activeCount > 0
                                ? '$activeCount active plan${activeCount == 1 ? '' : 's'}'
                                : '0 active plans',
                            icon: Icons.bookmark_added_rounded,
                            iconColor: const Color(0xFF304FFE), // Spec Indigo Accent
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SavedTripPlansScreen(),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Log Out Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text('Are you sure you want to log out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                // Styled Log out button
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await AuthService.logOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      label: const Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
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

  Widget _buildGridCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F7FA), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const Icon(Icons.arrow_outward_rounded, color: AppColors.textGrey, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14, // Spec Normal: 14px
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkNavy,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11, // Spec Body/Desc: 12px or smaller for compact grid
                    color: AppColors.textGrey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
