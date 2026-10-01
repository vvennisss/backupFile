import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../theme.dart';

class ContextualStatusBanner extends StatelessWidget {
  final VoidCallback onPlanNewTrip;

  const ContextualStatusBanner({
    super.key,
    required this.onPlanNewTrip,
  });

  void _showCancelConfirmation(BuildContext context, TripController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text(
              'End Journey?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppColors.primaryDarkNavy,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to end your current journey? Your active route will be completed.',
          style: TextStyle(fontSize: 14, color: Color(0xFF424242)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep Going',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              controller.cancelActiveTrip();
            },
            child: const Text(
              'End Trip',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = TripController();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF19244E).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Active indicator pulse
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.navigation_rounded,
              color: Color(0xFF059669),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),

          // Banner Italicized Text
          const Expanded(
            child: Text(
              'You have an ongoing trip, I am now your companion.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
                letterSpacing: 0.1,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // [ 📝 Plan New Trip ] OutlinedButton
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              side: const BorderSide(color: Color(0xFF304FFE), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: const Color(0xFF304FFE).withValues(alpha: 0.06),
            ),
            onPressed: () {
              controller.planNewTrip();
              onPlanNewTrip();
            },
            child: const Text(
              '📝 Plan New Trip',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // Cancel Option: IconButton (stop/X icon)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
            splashRadius: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            tooltip: 'End current trip',
            onPressed: () => _showCancelConfirmation(context, controller),
          ),
        ],
      ),
    );
  }
}
