import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/firebase_service.dart';

class RankInfoScreen extends StatelessWidget {
  final UserRank currentRank;
  final int completedRoutes;

  const RankInfoScreen({
    super.key,
    required this.currentRank,
    required this.completedRoutes,
  });

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
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.black, size: 16),
          ),
        ),
        title: const Text(
          'Explorer Ranks',
          style: TextStyle(
            color: Color(0xFF303030), // Colors.grey[850]
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current Rank Header Card
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
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      currentRank.icon,
                      size: 48,
                      color: currentRank.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'YOUR RANK',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentMintTeal,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentRank.displayName,
                    style: const TextStyle(
                      fontSize: 24, // Optimized heading size
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentRank.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12, // Spec Body/Desc: 12px
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Completed Routes: $completedRoutes',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            
            const Text(
              'All Rank Tiers',
              style: TextStyle(
                fontSize: 18, // Spec Label: 18px
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDarkNavy,
              ),
            ),
            const SizedBox(height: 16),
            
            // List of Ranks
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: UserRank.values.length,
              itemBuilder: (context, index) {
                final r = UserRank.values[index];
                final isCurrent = r == currentRank;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrent ? AppColors.secondaryRoyalBlue : const Color(0xFFF1F7FA),
                      width: isCurrent ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: r.color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          r.icon,
                          size: 28,
                          color: r.color,
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
                                    r.displayName,
                                    style: const TextStyle(
                                      fontSize: 14, // Spec Normal: 14px
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDarkNavy,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryRoyalBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Current',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.secondaryRoyalBlue,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Requirements: ${r.requiredRoutes == 0 ? "None (Starter)" : "Complete ${r.requiredRoutes} routes"}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.secondaryRoyalBlue,
                                  fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              r.description,
                              style: const TextStyle(
                                fontSize: 12, // Spec Body/Desc: 12px
                                color: AppColors.textGrey,
                                height: 1.4,
                              ),
                            ),
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
