import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../theme.dart';

class ItinerarySlidingPanel extends StatefulWidget {
  final VoidCallback onLockAndStartTrip;
  final VoidCallback onStartJourneyOnMap;
  final VoidCallback onSelectDates;

  const ItinerarySlidingPanel({
    super.key,
    required this.onLockAndStartTrip,
    required this.onStartJourneyOnMap,
    required this.onSelectDates,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onLockAndStartTrip,
    required VoidCallback onStartJourneyOnMap,
    required VoidCallback onSelectDates,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ItinerarySlidingPanel(
        onLockAndStartTrip: onLockAndStartTrip,
        onStartJourneyOnMap: onStartJourneyOnMap,
        onSelectDates: onSelectDates,
      ),
    );
  }

  @override
  State<ItinerarySlidingPanel> createState() => _ItinerarySlidingPanelState();
}

class _ItinerarySlidingPanelState extends State<ItinerarySlidingPanel> {
  final TripController _controller = TripController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final places = _controller.draftItinerary;
        final hasPlaces = places.isNotEmpty;
        final hasTimeline = _controller.timeline.isNotEmpty;
        final travelDates = _controller.travelDates;

        return DraggableScrollableSheet(
          initialChildSize: 0.76,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle Bar
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header with Title & Stop Counter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF19244E).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                hasTimeline ? Icons.checklist_rtl_rounded : Icons.format_list_bulleted_rounded,
                                color: const Color(0xFF19244E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hasTimeline ? 'Review & Modify Plan' : 'Draft Itinerary',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF19244E),
                                  ),
                                ),
                                Text(
                                  hasPlaces
                                      ? (hasTimeline
                                          ? '${places.length} stops • Drag to resequence & check warnings'
                                          : '${places.length} stops added')
                                      : 'No stops added yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Action Buttons: Add Stop & Clear
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded,
                                  color: Color(0xFF304FFE)),
                              tooltip: 'Add Stop',
                              onPressed: () => _openPlacePicker(context),
                            ),
                            if (hasPlaces)
                              IconButton(
                                icon: const Icon(Icons.delete_sweep_outlined,
                                    color: Colors.redAccent),
                                tooltip: 'Clear All',
                                onPressed: () {
                                  _controller.clearDraft();
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Travel Date Selector Badge Bar
                  InkWell(
                    onTap: widget.onSelectDates,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: travelDates != null ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: travelDates != null ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 16,
                            color: travelDates != null ? const Color(0xFF1E40AF) : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              travelDates != null
                                  ? 'Travel Dates: ${travelDates.start.toIso8601String().split('T').first} - ${travelDates.end.toIso8601String().split('T').first}'
                                  : '⚠️ No travel dates selected (Tap to pick dates)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: travelDates != null ? const Color(0xFF1E40AF) : const Color(0xFF92400E),
                              ),
                            ),
                          ),
                          Text(
                            travelDates != null ? 'Change' : 'Select',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: travelDates != null ? const Color(0xFF2563EB) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // AI Re-planning Loading Indicator
                  if (_controller.isRecomputingAiPlan)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF304FFE)),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'AI is re-calculating optimal schedule for your changes...',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Interactive AI Plan Decision Choice Banner (When AI re-planning completes)
                  if (_controller.hasPendingPlanDecision)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'AI Re-plan Available for Your Changes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'You updated stops. AI generated an optimized sequence to avoid heat & traffic. Which plan would you like?',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF1E3A8A), height: 1.25),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1D4ED8),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.auto_awesome, size: 13),
                                  label: const Text(
                                    'Use AI Plan',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    _controller.acceptAiPlan();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF1D4ED8), width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () {
                                    _controller.keepUserDecision();
                                  },
                                  child: const Text(
                                    'Keep My Order',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Dynamic Real-time Warning Banner (if any warning flags active)
                  if (hasTimeline && places.any((p) => p.warningFlag != null))
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'System Route & Schedule Warning:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  places.any((p) => p.warningFlag == 'CLOSED')
                                      ? '• One or more venues may be CLOSED on your travel date.'
                                      : '• Outdoor stops scheduled in midday peak heat. Drag to move them to morning or evening!',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF78350F)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const Divider(height: 1, color: Color(0xFFEEEEEE)),

                  // Hint Banner
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF0F7FF),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.swipe_left_rounded, size: 16, color: Color(0xFF1E88E5)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasTimeline
                                ? 'Review Mode: Drag handles to reorder • Swipe left to delete'
                                : 'Draft Mode: Add places and let AI plan your sequence',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Itinerary List with Reorder & Dismissible
                  Expanded(
                    child: hasPlaces
                        ? Theme(
                            data: Theme.of(context).copyWith(
                              canvasColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                            ),
                            child: ReorderableListView.builder(
                              scrollController: scrollController,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                              itemCount: places.length,
                              onReorder: (oldIndex, newIndex) {
                                _controller.reorderDraft(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final place = places[index];

                                return Container(
                                  key: ValueKey('card_${place.id}'),
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: place.warningFlag == 'CLOSED'
                                            ? const Color(0xFFFCA5A5)
                                            : place.warningFlag == 'PEAK_HEAT'
                                                ? const Color(0xFFFDE68A)
                                                : const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        // Stop Number Badge
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF19244E),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Place Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                place.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14.5,
                                                  color: Color(0xFF1E293B),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      place.area,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[700],
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(Icons.schedule, size: 12, color: Colors.grey[500]),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    '${place.estimatedStayMinutes} min',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (place.bestVisitTime != null) ...[
                                                const SizedBox(height: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFEFF6FF),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(
                                                        color: const Color(0xFFBFDBFE),
                                                        width: 0.8),
                                                  ),
                                                  child: Text(
                                                    '⏰ ${place.bestVisitTime}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Color(0xFF1E40AF),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              if (place.warningFlag != null) ...[
                                                const SizedBox(height: 4),
                                                if (place.warningFlag == 'CLOSED')
                                                  Text(
                                                    '⛔ Venue may be closed today',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.red[700],
                                                      fontFamily: 'SF Pro',
                                                    ),
                                                  )
                                                else
                                                  Wrap(
                                                    spacing: 4,
                                                    runSpacing: 3,
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFFF7ED),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: const Color(0xFFFFEDD5)),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.wb_sunny_rounded, size: 10, color: Color(0xFFEA580C)),
                                                            SizedBox(width: 3),
                                                            Text(
                                                              'Apply sunscreen',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFFC2410C),
                                                                fontFamily: 'SF Pro',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFEF3C7),
                                                          borderRadius: BorderRadius.circular(4),
                                                          border: Border.all(color: const Color(0xFFFDE68A)),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.beach_access_rounded, size: 10, color: Color(0xFFD97706)),
                                                            SizedBox(width: 3),
                                                            Text(
                                                              'Take umbrella',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFFB45309),
                                                                fontFamily: 'SF Pro',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        // Red "X" Remove Button
                                        IconButton(
                                          icon: const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Remove stop',
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                                title: const Text('Remove Place', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                content: Text('Are you sure you want to remove ${place.name} from your travel plan?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: const Color(0xFFEF4444),
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      _controller.removePlaceFromDraft(index);
                                                    },
                                                    child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                        const SizedBox(width: 8),

                                        // Drag Handle Icon
                                        ReorderableDragStartListener(
                                          index: index,
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            color: Colors.transparent,
                                            child: const Icon(
                                              Icons.drag_indicator_rounded,
                                              color: Colors.grey,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                              },
                            ),
                          )
                        : _buildEmptyState(context),
                  ),

                  // Bottom Fixed CTA
                  if (hasPlaces)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasTimeline) ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF19244E),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Text('🚀', style: TextStyle(fontSize: 16)),
                                label: const Text(
                                  'Start Journey on Map',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onStartJourneyOnMap();
                                },
                              ),
                              const SizedBox(height: 6),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF304FFE),
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                ),
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Re-optimize & Re-plan Times', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onLockAndStartTrip();
                                },
                              ),
                            ] else ...[
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF19244E),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Text('🚀', style: TextStyle(fontSize: 16)),
                                label: Text(
                                  'Save and Plan Trip for Me Now (${places.length} Stops)',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  widget.onLockAndStartTrip();
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your Draft Itinerary is Empty',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ask the Bird Companion in chat, or pick recommended Penang attractions below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Quick Add Popular Spots:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...kPenangPredefinedPlaces.take(4).map(
                (place) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFE0E7FF),
                    child: Icon(place.icon, color: const Color(0xFF3730A3), size: 18),
                  ),
                  title: Text(
                    place.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(place.area, style: const TextStyle(fontSize: 11)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      backgroundColor: const Color(0xFF304FFE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      _controller.addPlaceToDraft(place);
                    },
                    child: const Text('Add', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  void _openPlacePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filter = '';
        return StatefulBuilder(
          builder: (context, setPickerState) {
            final filtered = kPenangPredefinedPlaces.where((p) {
              final query = filter.toLowerCase();
              return p.name.toLowerCase().contains(query) ||
                  p.area.toLowerCase().contains(query) ||
                  p.category.toLowerCase().contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Add Penang Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: AppColors.primaryDarkNavy,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search attraction, temple, beach...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setPickerState(() {
                        filter = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final place = filtered[index];
                        final isAlreadyInDraft =
                            _controller.draftItinerary.any((p) => p.id == place.id);

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE2E8F0),
                            child: Icon(place.icon, color: const Color(0xFF1E293B)),
                          ),
                          title: Text(
                            place.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                          ),
                          subtitle: Text(
                            '${place.area} • ${place.category}',
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          trailing: isAlreadyInDraft
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF19244E),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _controller.addPlaceToDraft(place);
                                  },
                                  child: const Text('Add'),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

