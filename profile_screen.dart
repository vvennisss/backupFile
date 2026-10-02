import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/firebase_service.dart';
import '../services/saved_places_manager.dart';
import '../services/auth_service.dart';
import 'saved_places_screen.dart';
import 'travel_plans_screen.dart';
import 'update_profile_screen.dart';
import 'rank_info_screen.dart';

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
            
            // Calculate progress to next rank
            int current = profile.completedRoutes;
            int nextReq = 0;
            int prevReq = 0;
            String nextRankName = '';
            
            if (profile.rank == UserRank.bronze) {
              nextReq = UserRank.silver.requiredRoutes;
              prevReq = UserRank.bronze.requiredRoutes;
              nextRankName = UserRank.silver.displayName;
            } else if (profile.rank == UserRank.silver) {
              nextReq = UserRank.gold.requiredRoutes;
              prevReq = UserRank.silver.requiredRoutes;
              nextRankName = UserRank.gold.displayName;
            } else if (profile.rank == UserRank.gold) {
              nextReq = UserRank.platinum.requiredRoutes;
              prevReq = UserRank.gold.requiredRoutes;
              nextRankName = UserRank.platinum.displayName;
            }

            double progressRatio = 1.0;
            String nextRankProgressText = 'Max Rank Reached!';
            if (profile.rank != UserRank.platinum) {
              int range = nextReq - prevReq;
              if (range > 0) {
                progressRatio = ((current - prevReq) / range).clamp(0.0, 1.0);
              }
              nextRankProgressText = '${current - prevReq} / $range routes to $nextRankName';
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP AVATAR AND EXPERIENCE BAR HEADER CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.015),
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
                            // Styled Profile Avatar dependent on Rank
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                color: profile.rank.color.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: profile.rank.color, width: 2.5),
                              ),
                              child: Center(
                                child: Icon(
                                  profile.rank.icon,
                                  size: 36,
                                  color: profile.rank.color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Segmented Experience Progress Bar (Expanded to prevent overflow)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'rank progress  ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textGrey,
                                        ),
                                      ),
                                      Text(
                                        profile.rank != UserRank.platinum 
                                            ? '${(progressRatio * 100).round()}%' 
                                            : 'MAX',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryDarkNavy,
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
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // User Name (Heading spec: 32px or smaller for compact layouts)
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 24, // Optimized heading size
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF303030),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Joined Date (Body size: 12px)
                        Text(
                          'Joined Penang Travel on ${profile.joinedDate}',
                          style: const TextStyle(
                            fontSize: 12, // Spec Body/Desc: 12px
                            color: AppColors.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. ACCOUNT DETAILS CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Account Details',
                              style: TextStyle(
                                fontSize: 18, // Spec Label: 18px
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDarkNavy,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UpdateProfileScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: AppColors.primaryDarkNavy,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildDetailRow(label: 'Email', value: profile.email),
                        const SizedBox(height: 8),
                        _buildDetailRow(label: 'Phone', value: profile.phone),
                        const SizedBox(height: 8),
                        _buildDetailRow(label: 'Rank Tier', value: profile.rank.displayName),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. RANK DETAILS CARD (With Expanded to prevent overflow)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDarkNavy, AppColors.secondaryRoyalBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDarkNavy.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(profile.rank.icon, color: profile.rank.color, size: 24),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Current Rank: ${profile.rank.displayName}',
                                style: const TextStyle(
                                  fontSize: 16, // Section Label / header: 16-18px
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.rank.description,
                          style: const TextStyle(
                            fontSize: 12, // Spec Desc: 12px
                            color: Colors.white70,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RankInfoScreen(
                                      currentRank: profile.rank,
                                      completedRoutes: profile.completedRoutes,
                                    ),
                                  ),
                                );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.15),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text(
                              'Compare Rank Tiers',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 4. GRID METRIC BUTTONS
                  const Text(
                    'Dashboard Options',
                    style: TextStyle(
                      fontSize: 18, // Spec Label: 18px
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDarkNavy,
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
                      _buildGridCard(
                        title: 'Trip History',
                        subtitle: '${profile.completedRoutes} routes done',
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
                      ),
                      // Card 4: Travel Preferences
                      _buildGridCard(
                        title: 'Style Profile',
                        subtitle: profile.travelStyles.join(', '),
                        icon: Icons.dashboard_customize_rounded,
                        iconColor: Colors.teal,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UpdateProfileScreen(),
                            ),
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

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14, // Spec Normal: 14px
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDarkNavy.withOpacity(0.7),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14, // Spec Normal: 14px
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDarkNavy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              color: Colors.black.withOpacity(0.01),
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
