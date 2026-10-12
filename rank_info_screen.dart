import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/firebase_service.dart';

class RankInfoScreen extends StatefulWidget {
  final UserRank currentRank;
  final int completedRoutes;
  final UserProfile? userProfile;

  const RankInfoScreen({
    super.key,
    required this.currentRank,
    required this.completedRoutes,
    this.userProfile,
  });

  @override
  State<RankInfoScreen> createState() => _RankInfoScreenState();
}

class _RankInfoScreenState extends State<RankInfoScreen> {
  late Set<UserRank> _expandedRanks;

  @override
  void initState() {
    super.initState();
    final profile = widget.userProfile ?? UserProfileManager.profileNotifier.value;
    // By default, only expand the user's current rank, collapse all others
    _expandedRanks = {profile.rank};
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.userProfile ?? UserProfileManager.profileNotifier.value;
    final activeGoal = profile.activeBadgeGoal;
    final currentRank = widget.currentRank;

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
          'Explorer Badges',
          style: TextStyle(
            color: Color(0xFF303030), // Colors.grey[850]
            fontWeight: FontWeight.bold,
            fontSize: 20,
            fontFamily: 'SF Pro',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Current Rank Header Card
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
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        currentRank.badgeAssetPath,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white24,
                          child: Icon(
                            currentRank.icon,
                            size: 48,
                            color: currentRank.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CURRENT RANK TIER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentMintTeal,
                      letterSpacing: 1.5,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentRank.badgeTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Theme: ${currentRank.theme}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'SF Pro',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentRank.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.45,
                      fontFamily: 'SF Pro',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 14, color: activeGoal.color),
                        const SizedBox(width: 6),
                        Text(
                          'Active Goal: ${activeGoal.badgeTitle} (${(activeGoal.getProgressRatio(profile) * 100).round()}%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            
            const Text(
              'Achievement Badges (5 Tiers)',
              style: TextStyle(
                fontSize: 18, // Spec Label: 18px
                fontWeight: FontWeight.bold,
                color: Color(0xFF303030), // Colors.grey[850]
                fontFamily: 'SF Pro',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Unlock achievements by exploring landmarks, nature trails, local produce, and Penang routes.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textGrey,
                fontFamily: 'SF Pro',
              ),
            ),
            const SizedBox(height: 16),
            
            // List of the 5 Ranks
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: UserRank.values.length,
              itemBuilder: (context, index) {
                final r = UserRank.values[index];
                final isCurrent = r == profile.rank;
                final isUnlocked = profile.rank.index >= r.index;
                final isNextGoal = r == activeGoal;
                final tierProgress = r.getProgressRatio(profile);
                final isExpanded = _expandedRanks.contains(r);

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isCurrent 
                          ? r.color 
                          : isNextGoal
                              ? r.color.withOpacity(0.5)
                              : const Color(0xFFF1F7FA),
                      width: isCurrent ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.025),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Header Row (Tappable to toggle expand / collapse)
                      InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () {
                          setState(() {
                            if (_expandedRanks.contains(r)) {
                              _expandedRanks.remove(r);
                            } else {
                              _expandedRanks.add(r);
                            }
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isCurrent ? r.color : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    r.badgeAssetPath,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: r.color.withOpacity(0.1),
                                      child: Icon(
                                        r.icon,
                                        size: 28,
                                        color: r.color,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${index + 1}. ${r.badgeTitle}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF303030),
                                              fontFamily: 'SF Pro',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isCurrent)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: r.color.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: r.color.withOpacity(0.3), width: 1),
                                            ),
                                            child: Text(
                                              'Active Rank',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: r.color,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          )
                                        else if (isUnlocked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.green.shade200, width: 1),
                                            ),
                                            child: const Text(
                                              'Unlocked ✓',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          )
                                        else if (isNextGoal)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                                            ),
                                            child: const Text(
                                              'Next Goal 🎯',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1D4ED8),
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              'Locked 🔒',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade600,
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Progress: ${(tierProgress * 100).round()}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: r.color,
                                            fontFamily: 'SF Pro',
                                          ),
                                        ),
                                        Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons.keyboard_arrow_down_rounded,
                                          color: Colors.grey.shade600,
                                          size: 20,
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

                      // Collapsible Body Section (Expanded only for current rank by default)
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Theme Pill
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Text(
                                  'Theme: ${r.theme}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF475569),
                                    fontFamily: 'SF Pro',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Detailed Unlock Requirements List
                              const Text(
                                'Unlock Requirements:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF334155),
                                  fontFamily: 'SF Pro',
                                ),
                              ),
                              const SizedBox(height: 8),

                              ...List.generate(r.requirements.length, (reqIdx) {
                                final req = r.requirements[reqIdx];
                                final cur = r.getCurrentValue(profile, reqIdx);
                                final reqRatio = (cur / req.target).clamp(0.0, 1.0);
                                final isReqDone = cur >= req.target;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isReqDone ? const Color(0xFFF0FDF4) : const Color(0xFFFAFAFA),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isReqDone ? Colors.green.shade200 : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            req.icon,
                                            size: 15,
                                            color: isReqDone ? Colors.green.shade700 : r.color,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              req.title,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isReqDone ? Colors.green.shade800 : const Color(0xFF1E293B),
                                                fontFamily: 'SF Pro',
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '${cur % 1 != 0 ? cur.toStringAsFixed(1) : cur.toInt()} / ${req.target % 1 != 0 ? req.target.toStringAsFixed(1) : req.target.toInt()} ${req.unit}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isReqDone ? Colors.green.shade700 : AppColors.textGrey,
                                              fontFamily: 'SF Pro',
                                            ),
                                          ),
                                          if (isReqDone) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        req.description,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                          height: 1.35,
                                          fontFamily: 'SF Pro',
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: reqRatio,
                                          minHeight: 4,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            isReqDone ? Colors.green : r.color,
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
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
