// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../services/saved_trip_plans_manager.dart';
import '../services/live_journey_service.dart';
import '../services/location_service.dart';
import '../services/trip_schedule_evaluator.dart';
import 'app_image_widget.dart';

/// Unified workflow to begin a journey for a saved trip plan.
/// Used both from StoryTabScreen ("Begin Live Journey") and SavedTripPlansScreen ("Start Trip").
///
/// Travel date is ALWAYS today (the day user taps start trip/begin journey).
/// Asks user whether to use the default scheduled start time or a new start time.
/// If a new start time is chosen, re-evaluates stop arrival times against opening hours
/// for today and provides 2 to 3 same-category nearby alternatives within 2km if closed.
class JourneyStartWorkflow {
  static Future<void> startJourneyFlow(
    BuildContext context,
    SavedTripPlan plan, {
    VoidCallback? onStarted,
  }) async {
    // 1. Date is automatically today (the day user taps start trip / begin journey)
    final now = DateTime.now();

    // 2. Parse default scheduled start time-of-day
    final scheduledParsed = LiveJourneyService.parsePlanScheduledDateTime(plan);
    final defaultStartTime = DateTime(
      now.year,
      now.month,
      now.day,
      scheduledParsed.hour,
      scheduledParsed.minute,
      0,
    );

    // 3. Prompt user: Default scheduled start time or New start time?
    final chosenStartTime = await showDialog<DateTime>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _StartTimeSelectionDialogContent(
        plan: plan,
        defaultStartTime: defaultStartTime,
        todayDate: now,
      ),
    );

    if (chosenStartTime == null || !context.mounted) return;

    // 4. Resolve starting coordinates (using area hotel if mock location enabled)
    final firstStop = plan.stops.isNotEmpty ? plan.stops.first : null;
    double? startLat;
    double? startLng;
    String? originName;

    if (LiveJourneyService.instance.useMockLocation && firstStop != null) {
      final hotel = MockHotelRegistry.findForArea(firstStop.area);
      startLat = hotel.lat;
      startLng = hotel.lng;
      originName = hotel.hotelName;
    } else {
      final pos = await LocationService().getCurrentPosition(timeLimit: const Duration(seconds: 4));
      startLat = pos?.latitude;
      startLng = pos?.longitude;
      originName = 'Current Location';
    }

    // 5. Check if chosen start time is different from default scheduled time
    final isDifferentFromDefault = chosenStartTime.hour != defaultStartTime.hour ||
        chosenStartTime.minute != defaultStartTime.minute;

    SavedTripPlan effectivePlan = plan;

    if (isDifferentFromDefault) {
      if (!context.mounted) return;

      // Show evaluating loading modal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const _EvaluatingScheduleLoadingDialog(),
      );

      final evaluation = await TripScheduleEvaluator.evaluatePlanSchedule(
        plan: plan,
        startDateTime: chosenStartTime,
        startLat: startLat,
        startLng: startLng,
        useMockLocation: LiveJourneyService.instance.useMockLocation,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // dismiss loading dialog

      if (evaluation.hasConflicts) {
        final resolution = await showDialog<_ConflictResolutionResult>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _ConflictResolutionDialogContent(
            plan: plan,
            evaluation: evaluation,
            chosenStartTime: chosenStartTime,
          ),
        );

        if (resolution == null || !context.mounted) return;

        if (resolution.action == _ConflictAction.changeTime) {
          // Re-trigger start journey flow
          return startJourneyFlow(context, plan, onStarted: onStarted);
        }

        effectivePlan = resolution.updatedPlan;
      }
    }

    if (!context.mounted) return;

    // 6. Set selected plan in SavedTripPlansManager so StoryTabScreen displays this plan
    SavedTripPlansManager.setSelectedPlanId(effectivePlan.id);

    // If effectivePlan has adjusted stops or timing from conflict resolution, persist it
    if (effectivePlan != plan) {
      await SavedTripPlansManager.savePlan(effectivePlan);
    }

    // 7. Begin Live Journey with effective plan and chosen start time
    await LiveJourneyService.instance.startJourney(
      effectivePlan,
      customStartTime: chosenStartTime,
      customStartLat: startLat,
      customStartLng: startLng,
      customOriginName: originName,
    );

    if (!context.mounted) return;

    if (onStarted != null) {
      onStarted();
    }
  }
}

class _StartTimeSelectionDialogContent extends StatefulWidget {
  final SavedTripPlan plan;
  final DateTime defaultStartTime;
  final DateTime todayDate;

  const _StartTimeSelectionDialogContent({
    required this.plan,
    required this.defaultStartTime,
    required this.todayDate,
  });

  @override
  State<_StartTimeSelectionDialogContent> createState() =>
      _StartTimeSelectionDialogContentState();
}

class _StartTimeSelectionDialogContentState
    extends State<_StartTimeSelectionDialogContent> {
  bool _useDefault = true;
  late TimeOfDay _newTime;

  @override
  void initState() {
    super.initState();
    _newTime = TimeOfDay(
      hour: widget.defaultStartTime.hour,
      minute: widget.defaultStartTime.minute,
    );
  }

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekday = days[d.weekday - 1];
    return '${d.day} ${months[d.month - 1]} ${d.year} ($weekday)';
  }

  static String _formatTime(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final defaultFormatted =
        _formatTime(widget.defaultStartTime.hour, widget.defaultStartTime.minute);
    final todayFormatted = _formatDate(widget.todayDate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.access_time_filled_rounded,
                        color: Color(0xFFD97706),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Start Trip Time',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.today_rounded, size: 12, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Travel Date: Today ($todayFormatted)',
                                style: const TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2563EB),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Default Scheduled Time
              GestureDetector(
                onTap: () {
                  setState(() => _useDefault = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _useDefault ? const Color(0xFFFFFBEB) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _useDefault ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                      width: _useDefault ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Radio<bool>(
                        value: true,
                        groupValue: _useDefault,
                        activeColor: const Color(0xFFD97706),
                        onChanged: (val) {
                          if (val != null) setState(() => _useDefault = val);
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Default Scheduled Time',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFB45309)),
                                  const SizedBox(width: 5),
                                  Text(
                                    defaultFormatted,
                                    style: const TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.plan.travelSchedule.isNotEmpty
                                  ? 'Uses original itinerary schedule (${widget.plan.travelSchedule}).'
                                  : 'Uses original planned schedule.',
                              style: const TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Option 2: New Start Time
              GestureDetector(
                onTap: () {
                  setState(() => _useDefault = false);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: !_useDefault ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: !_useDefault ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
                      width: !_useDefault ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Radio<bool>(
                            value: false,
                            groupValue: _useDefault,
                            activeColor: const Color(0xFF2563EB),
                            onChanged: (val) {
                              if (val != null) setState(() => _useDefault = val);
                            },
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'New Start Time',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Enter a new time of day to start today\'s trip.',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (!_useDefault) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: Color(0xFFDBEAFE)),
                        const SizedBox(height: 12),

                        // Time Picker Button
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _newTime,
                            );
                            if (picked != null) {
                              setState(() => _newTime = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 18,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Selected Departure Time',
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 10.5,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _formatTime(_newTime.hour, _newTime.minute),
                                        style: const TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Change',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Notice Info Box
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE).withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_outlined, size: 14, color: Color(0xFF1D4ED8)),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'System will verify if venues are open for today. If closed upon arrival, 2-3 open alternatives within 2km will be suggested.',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 10.5,
                                    color: Color(0xFF1E40AF),
                                    height: 1.25,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Actions Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
                        foregroundColor: Colors.black,
                        elevation: 1,
                        shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        if (_useDefault) {
                          Navigator.of(context).pop(widget.defaultStartTime);
                        } else {
                          final newDt = DateTime(
                            widget.todayDate.year,
                            widget.todayDate.month,
                            widget.todayDate.day,
                            _newTime.hour,
                            _newTime.minute,
                          );
                          Navigator.of(context).pop(newDt);
                        }
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'CONFIRM TIME',
                          style: TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EvaluatingScheduleLoadingDialog extends StatelessWidget {
  const _EvaluatingScheduleLoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF304FFE)),
            SizedBox(height: 18),
            Text(
              'Checking Venue Operating Hours...',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'Verifying estimated arrival times against today\'s official schedules & finding 2km nearby alternatives.',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConflictAction { proceed, changeTime }

class _ConflictResolutionResult {
  final _ConflictAction action;
  final SavedTripPlan updatedPlan;

  const _ConflictResolutionResult({
    required this.action,
    required this.updatedPlan,
  });
}

class _ConflictResolutionDialogContent extends StatefulWidget {
  final SavedTripPlan plan;
  final ScheduleEvaluationResult evaluation;
  final DateTime chosenStartTime;

  const _ConflictResolutionDialogContent({
    required this.plan,
    required this.evaluation,
    required this.chosenStartTime,
  });

  @override
  State<_ConflictResolutionDialogContent> createState() =>
      _ConflictResolutionDialogContentState();
}

class _ConflictResolutionDialogContentState
    extends State<_ConflictResolutionDialogContent> {
  late SavedTripPlan _currentPlan;
  late List<ScheduleConflict> _conflicts;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
    _conflicts = List<ScheduleConflict>.from(widget.evaluation.conflicts);
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${h.toString().padLeft(2, '0')}:$m $ampm';
  }

  Future<void> _swapConflictStop(int conflictIndex, NearbyAlternative alt) async {
    final conflict = _conflicts[conflictIndex];
    final oldStop = _currentPlan.stops[conflict.stopIndex];

    final newStop = SavedPlanStop(
      stopNumber: oldStop.stopNumber,
      placeName: alt.name,
      area: alt.area,
      category: alt.category,
      timeSlot: oldStop.timeSlot,
      stayDuration: oldStop.stayDuration,
      pennyTip: 'Swapped alternative within 2km: ${alt.reason}',
      adjustmentReason: 'Replaced closed stop with nearby ${alt.name}',
      isAdjusted: true,
      imageUrl: alt.imagePath.isNotEmpty ? alt.imagePath : oldStop.imageUrl,
      address: alt.area,
      lat: alt.lat,
      lng: alt.lng,
    );

    final updatedStops = List<SavedPlanStop>.from(_currentPlan.stops);
    updatedStops[conflict.stopIndex] = newStop;
    final updatedPlan = _currentPlan.copyWith(stops: updatedStops);

    await SavedTripPlansManager.savePlan(updatedPlan);

    if (!mounted) return;

    setState(() {
      _currentPlan = updatedPlan;
      _conflicts.removeAt(conflictIndex);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Swapped Stop ${conflict.stopIndex + 1} with ${alt.name}'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(widget.chosenStartTime);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFFECACA))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _conflicts.isNotEmpty
                              ? 'Opening Hours Alert (${_conflicts.length})'
                              : 'All Stops Verified Open!',
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _conflicts.isNotEmpty
                              ? 'At your new start time ($timeStr), some places will not be open today.'
                              : 'Your itinerary is ready for travel at $timeStr.',
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11.5,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _conflicts.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 48),
                            SizedBox(height: 10),
                            Text(
                              'Conflicts Resolved!',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'All venues in your itinerary are verified open for your selected travel start time today.',
                              style: TextStyle(
                                fontFamily: 'SF Pro',
                                fontSize: 12,
                                color: Color(0xFF15803D),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int i = 0; i < _conflicts.length; i++) ...[
                            _buildConflictCard(i, _conflicts[i]),
                            if (i < _conflicts.length - 1) const SizedBox(height: 16),
                          ],
                        ],
                      ),
              ),
            ),

            // Action Buttons Footer
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(
                          _ConflictResolutionResult(
                            action: _ConflictAction.changeTime,
                            updatedPlan: _currentPlan,
                          ),
                        );
                      },
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'CHANGE TIME',
                          style: TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
                        foregroundColor: Colors.black,
                        elevation: 1,
                        shadowColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(
                          _ConflictResolutionResult(
                            action: _ConflictAction.proceed,
                            updatedPlan: _currentPlan,
                          ),
                        );
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _conflicts.isEmpty ? 'START JOURNEY' : 'PROCEED ANYWAY',
                          style: const TextStyle(
                            fontFamily: 'Roboto Mono',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConflictCard(int index, ScheduleConflict conflict) {
    final arrivalStr = _formatTime(conflict.estimatedArrival);
    final departureStr = _formatTime(conflict.estimatedDeparture);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Stop Name & Arrival Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF1F2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Stop ${conflict.stopIndex + 1}',
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conflict.stop.placeName,
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '📍 ${conflict.stop.area} · ${conflict.stop.category}',
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Conflict Explanation & Timing Details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timing Row
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Est. Arrival: $arrivalStr · Depart: $departureStr',
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Notice Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ ${conflict.explanation}',
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                      if (conflict.operatingHours.formattedHours.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Schedule: ${conflict.operatingHours.formattedHours}',
                          style: const TextStyle(
                            fontFamily: 'SF Pro',
                            fontSize: 11,
                            color: Color(0xFF7F1D1D),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Alternatives Section
                Row(
                  children: [
                    const Icon(Icons.explore_outlined, size: 14, color: Color(0xFF1D4ED8)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Nearby Alternatives (Within 2km · ${conflict.stop.category}):',
                        style: const TextStyle(
                          fontFamily: 'SF Pro',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (conflict.alternatives.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'No same-category venues open within 2km were found. You can adjust your start trip time or proceed anyway.',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final alt in conflict.alternatives)
                        _buildAlternativeCard(index, conflict, alt),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeCard(int conflictIndex, ScheduleConflict conflict, NearbyAlternative alt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: alt.imagePath.isNotEmpty
                      ? AppImageWidget(
                          imagePath: alt.imagePath,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: const Color(0xFFE2E8F0),
                          child: const Icon(Icons.place_rounded, color: Color(0xFF94A3B8), size: 26),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alt.name,
                      style: const TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF2563EB)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            alt.formattedDistance,
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF16A34A)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            alt.businessHours.isNotEmpty ? alt.businessHours : 'Open Today',
                            style: const TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 10.5,
                              color: Color(0xFF15803D),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reason Pill & Swap Button
          Row(
            children: [
              Expanded(
                child: Text(
                  alt.reason,
                  style: const TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 10,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B), // Story Tab Rich Amber Accent
                  foregroundColor: Colors.black,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _swapConflictStop(conflictIndex, alt),
                child: const Text(
                  'SWAP STOP',
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
