import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../controllers/trip_controller.dart';
import 'itinerary_plan_screen.dart';

class SetTravelDateScreen extends StatefulWidget {
  final TripController controller;
  final bool isManagingExistingSchedule;

  const SetTravelDateScreen({
    super.key,
    required this.controller,
    this.isManagingExistingSchedule = false,
  });

  @override
  State<SetTravelDateScreen> createState() => _SetTravelDateScreenState();
}

class _SetTravelDateScreenState extends State<SetTravelDateScreen> {
  bool _isLoading = false;

  // Selected date state
  late DateTime _selectedStartDate;
  late DateTime _selectedEndDate;
  late DateTime _currentViewMonth;
  bool _isTodaySelected = true;

  // Depart time state: default 08:10 AM (matching wireframe mockup)
  int _selectedHour = 8;
  int _selectedMinute = 10;
  bool _isPm = false;

  // Preferred end trip time state: default depart time + 5 hours
  int _endHour = 1;
  int _endMinute = 10;
  bool _endIsPm = true;
  bool _userManuallyChangedEndTime = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final existingDates = widget.controller.travelDates;
    if (existingDates != null) {
      _selectedStartDate = existingDates.start;
      _selectedEndDate = existingDates.end;
      _isTodaySelected = _isSameDay(_selectedStartDate, now);
      _currentViewMonth = DateTime(_selectedStartDate.year, _selectedStartDate.month, 1);
    } else {
      _selectedStartDate = DateTime(now.year, now.month, now.day);
      _selectedEndDate = DateTime(now.year, now.month, now.day);
      _isTodaySelected = true;
      _currentViewMonth = DateTime(now.year, now.month, 1);
    }

    final existingTime = widget.controller.departTime;
    final hourOfPeriod = existingTime.hourOfPeriod == 0 ? 12 : existingTime.hourOfPeriod;
    _selectedHour = hourOfPeriod;
    _selectedMinute = existingTime.minute;
    _isPm = existingTime.period == DayPeriod.pm;

    final existingEndTime = widget.controller.endTripTime;
    final endHourOfPeriod = existingEndTime.hourOfPeriod == 0 ? 12 : existingEndTime.hourOfPeriod;
    _endHour = endHourOfPeriod;
    _endMinute = existingEndTime.minute;
    _endIsPm = existingEndTime.period == DayPeriod.pm;
  }

  void _syncDefaultEndTimeFromDepart({bool force = false}) {
    if (!force && _userManuallyChangedEndTime) return;
    final departHour24 = _isPm
        ? (_selectedHour == 12 ? 12 : _selectedHour + 12)
        : (_selectedHour == 12 ? 0 : _selectedHour);
    final totalMins = (departHour24 * 60 + _selectedMinute + 5 * 60) % (24 * 60);
    final endHour24 = totalMins ~/ 60;
    final endMin = totalMins % 60;

    _endIsPm = endHour24 >= 12;
    final h12 = endHour24 % 12;
    _endHour = h12 == 0 ? 12 : h12;
    _endMinute = endMin;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _onTodayTapped() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _selectedStartDate = today;
      _selectedEndDate = today;
      _currentViewMonth = DateTime(today.year, today.month, 1);
      _isTodaySelected = true;
    });
  }

  void _showMonthDropdown(BuildContext context) async {
    final now = DateTime.now();
    final months = List.generate(12, (i) {
      return DateTime(now.year, now.month + i, 1);
    });

    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null) return;

    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    final selected = await showMenu<DateTime>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 6,
      items: months.map((m) {
        final isCurrent = m.year == _currentViewMonth.year && m.month == _currentViewMonth.month;
        return PopupMenuItem<DateTime>(
          value: m,
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: isCurrent ? const Color(0xFF304FFE) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              Text(
                DateFormat('MMMM yyyy').format(m),
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? const Color(0xFF304FFE) : const Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );

    if (selected != null) {
      setState(() {
        _currentViewMonth = selected;
        _isTodaySelected = false;
        final isThisMonth = selected.year == now.year && selected.month == now.month;
        final targetDate = isThisMonth ? DateTime(now.year, now.month, now.day) : selected;
        _selectedStartDate = targetDate;
        _selectedEndDate = targetDate;
      });
    }
  }

  void _onDaySelected(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (date.isBefore(today)) return;

    setState(() {
      if (_selectedStartDate == _selectedEndDate && date.isAfter(_selectedStartDate)) {
        _selectedEndDate = date;
      } else {
        _selectedStartDate = date;
        _selectedEndDate = date;
      }
      _isTodaySelected = _isSameDay(_selectedStartDate, today) && _isSameDay(_selectedEndDate, today);
    });
  }

  String _getDateSelectLabel() {
    if (_isTodaySelected) {
      return 'SELECT DATE';
    }
    if (_isSameDay(_selectedStartDate, _selectedEndDate)) {
      return DateFormat('dd MMM yyyy').format(_selectedStartDate);
    }
    return '${DateFormat('dd MMM').format(_selectedStartDate)} - ${DateFormat('dd MMM').format(_selectedEndDate)}';
  }

  void _prevMonth() {
    final now = DateTime.now();
    final currentMonthFirst = DateTime(now.year, now.month, 1);
    final prev = DateTime(_currentViewMonth.year, _currentViewMonth.month - 1, 1);
    if (prev.isBefore(currentMonthFirst)) return;
    setState(() {
      _currentViewMonth = prev;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentViewMonth = DateTime(_currentViewMonth.year, _currentViewMonth.month + 1, 1);
    });
  }

  Future<void> _pickManualTime() async {
    final hour24 = _isPm
        ? (_selectedHour == 12 ? 12 : _selectedHour + 12)
        : (_selectedHour == 12 ? 0 : _selectedHour);
    final initialTime = TimeOfDay(hour: hour24, minute: _selectedMinute);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF304FFE),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedHour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
        _selectedMinute = picked.minute;
        _isPm = picked.period == DayPeriod.pm;
        _syncDefaultEndTimeFromDepart();
      });
    }
  }

  String _formatDepartTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.pm ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  String _formatSelectedDateSpan() {
    if (_isSameDay(_selectedStartDate, _selectedEndDate)) {
      return DateFormat('dd MMM yyyy').format(_selectedStartDate);
    }
    return '${DateFormat('dd MMM yyyy').format(_selectedStartDate)} - ${DateFormat('dd MMM yyyy').format(_selectedEndDate)}';
  }

  Future<void> _pickManualEndTime() async {
    final hour24 = _endIsPm
        ? (_endHour == 12 ? 12 : _endHour + 12)
        : (_endHour == 12 ? 0 : _endHour);
    final initialTime = TimeOfDay(hour: hour24, minute: _endMinute);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF304FFE),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _endHour = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
        _endMinute = picked.minute;
        _endIsPm = picked.period == DayPeriod.pm;
        _userManuallyChangedEndTime = true;
      });
    }
  }

  Future<void> _saveTravelSchedule() async {
    final departHour24 = _isPm
        ? (_selectedHour == 12 ? 12 : _selectedHour + 12)
        : (_selectedHour == 12 ? 0 : _selectedHour);
    final pickedDepartTime = TimeOfDay(hour: departHour24, minute: _selectedMinute);

    final endHour24 = _endIsPm
        ? (_endHour == 12 ? 12 : _endHour + 12)
        : (_endHour == 12 ? 0 : _endHour);
    final pickedEndTime = TimeOfDay(hour: endHour24, minute: _endMinute);

    final pickedDates = DateTimeRange(start: _selectedStartDate, end: _selectedEndDate);

    if (widget.isManagingExistingSchedule) {
      final dateStr = _formatSelectedDateSpan();
      final departTimeStr = _formatDepartTime(pickedDepartTime);
      final endTimeStr = _formatDepartTime(pickedEndTime);

      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Color(0xFF304FFE),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Change Schedule',
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure to change date to $dateStr, depart time $departTimeStr, and preferred end trip time $endTimeStr?',
            style: const TextStyle(
              fontFamily: 'SF Pro',
              fontSize: 14,
              color: Color(0xFF475569),
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF304FFE),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Confirm',
                style: TextStyle(
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    widget.controller.setTravelDates(pickedDates);
    widget.controller.setDepartTime(pickedDepartTime);
    widget.controller.setEndTripTime(pickedEndTime);

    try {
      await widget.controller.saveAndPlanTripForMeNow(
        customDates: pickedDates,
        customDepartTime: pickedDepartTime,
        customEndTime: pickedEndTime,
      );
      widget.controller.markPlanGenerated(true);
    } catch (_) {
      widget.controller.markPlanGenerated(true);
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    if (widget.isManagingExistingSchedule) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ItineraryPlanScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // Top Row with Back Button
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Color(0xFF1E293B),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  if (widget.isManagingExistingSchedule) ...[
                    const SizedBox(width: 14),
                    const Text(
                      'Change Travel Schedule',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ],
              ),

              if (widget.isManagingExistingSchedule)
                const SizedBox(height: 20)
              else ...[
                const SizedBox(height: 12),

                // Center Mascot Illustration
                Center(
                  child: Image.asset(
                    _isLoading
                        ? 'assets/pink-bird-success.gif'
                        : 'assets/pink-bird-happy.gif',
                    width: 130,
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/pink_bird_mascot.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Title & Subtitle (SF Pro / Bold per GEMINI.md)
                const Text(
                  'Your itinerary is being planned...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Share with me your travel dates',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'SF Pro',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.1,
                  ),
                ),

                const SizedBox(height: 24),
              ],

                      // SECTION 1: DATE
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                            color: Color(0xFF303030),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'DATE',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[850],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Date selector chips row (TODAY & SELECT DATE ∨)
                      Row(
                        children: [
                          // TODAY Chip
                          InkWell(
                            onTap: _onTodayTapped,
                            borderRadius: BorderRadius.circular(20),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                color: _isTodaySelected
                                    ? const Color(0xFFFBBF24)
                                    : const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: _isTodaySelected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                'TODAY',
                                style: TextStyle(
                                  fontFamily: 'SF Pro',
                                  fontSize: 13,
                                  fontWeight: _isTodaySelected ? FontWeight.w800 : FontWeight.w600,
                                  color: _isTodaySelected ? Colors.black : const Color(0xFF78350F),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // SELECT DATE ∨ Chip
                          Builder(
                            builder: (chipContext) {
                              return InkWell(
                                onTap: () => _showMonthDropdown(chipContext),
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: !_isTodaySelected
                                        ? const Color(0xFFFBBF24)
                                        : const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: !_isTodaySelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _getDateSelectLabel(),
                                        style: TextStyle(
                                          fontFamily: 'SF Pro',
                                          fontSize: 13,
                                          fontWeight: !_isTodaySelected ? FontWeight.w800 : FontWeight.w600,
                                          color: !_isTodaySelected ? Colors.black : const Color(0xFF78350F),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 18,
                                        color: !_isTodaySelected ? Colors.black : const Color(0xFF78350F),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // CALENDAR PICKER FOR CURRENT MONTH
                      _buildMonthCalendar(now),

                      const SizedBox(height: 22),

                      // SECTION 2: DEPART TIME
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            size: 18,
                            color: Color(0xFF303030),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'DEPART TIME',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[850],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Time Selector Card (Hour, Minute, AM/PM)
                      _buildDepartTimeCard(),

                      const SizedBox(height: 22),

                      // SECTION 3: PREFERRED END TRIP TIME
                      Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 18,
                            color: Color(0xFF303030),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'PREFERRED END TIME',
                            style: TextStyle(
                              fontFamily: 'SF Pro',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[850],
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _userManuallyChangedEndTime = false;
                                _syncDefaultEndTimeFromDepart(force: true);
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: !_userManuallyChangedEndTime
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: !_userManuallyChangedEndTime
                                      ? const Color(0xFFBFDBFE)
                                      : const Color(0xFFCBD5E1),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 11,
                                    color: !_userManuallyChangedEndTime
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    !_userManuallyChangedEndTime ? 'Default (+5h)' : 'Reset (+5h)',
                                    style: TextStyle(
                                      fontFamily: 'SF Pro',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: !_userManuallyChangedEndTime
                                          ? const Color(0xFF2563EB)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // End Time Card
                      _buildEndTimeCard(),

                      const SizedBox(height: 26),

                      // SECTION 4: SAVE TRAVEL SCHEDULE BUTTON
                      _buildSaveButton(),

                      const SizedBox(height: 28),
                    ],
                  ),
                ),
              ),
            );
  }

  // --- MONTH CALENDAR WIDGET ---
  Widget _buildMonthCalendar(DateTime now) {
    final firstDayOfMonth = DateTime(_currentViewMonth.year, _currentViewMonth.month, 1);
    final daysInMonth = DateTime(_currentViewMonth.year, _currentViewMonth.month + 1, 0).day;
    final leadingBlanks = firstDayOfMonth.weekday % 7; // Sunday is 0 blanks
    final weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        children: [
          // Month navigation bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 24, color: Color(0xFF334155)),
                onPressed: _currentViewMonth.isAfter(DateTime(now.year, now.month, 1))
                    ? _prevMonth
                    : null,
              ),
              Text(
                DateFormat('MMMM yyyy').format(_currentViewMonth),
                style: const TextStyle(
                  fontFamily: 'SF Pro',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 24, color: Color(0xFF334155)),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Weekdays row
          Row(
            children: weekdays.map((w) {
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(
                      fontFamily: 'SF Pro',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // Days Grid (standard Rows for foolproof layout inside SingleChildScrollView)
          Builder(
            builder: (context) {
              final totalCells = leadingBlanks + daysInMonth;
              final totalWeeks = (totalCells / 7).ceil();

              return Column(
                children: List.generate(totalWeeks, (weekIdx) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Row(
                      children: List.generate(7, (dayCol) {
                        final cellIndex = weekIdx * 7 + dayCol;
                        if (cellIndex < leadingBlanks || cellIndex >= totalCells) {
                          return const Expanded(child: SizedBox(height: 38));
                        }
                        final day = cellIndex - leadingBlanks + 1;
                        final cellDate = DateTime(_currentViewMonth.year, _currentViewMonth.month, day);
                        final isPast = cellDate.isBefore(today);
                        final isStart = _isSameDay(cellDate, _selectedStartDate);
                        final isEnd = _isSameDay(cellDate, _selectedEndDate);
                        final isSelected = isStart || isEnd;
                        final isInRange =
                            cellDate.isAfter(_selectedStartDate) && cellDate.isBefore(_selectedEndDate);
                        final isToday = _isSameDay(cellDate, today);

                        Color bgColor = Colors.transparent;
                        Color textColor = const Color(0xFF1E293B);
                        FontWeight fontWeight = FontWeight.normal;

                        if (isPast) {
                          textColor = const Color(0xFFCBD5E1);
                        } else if (isSelected) {
                          bgColor = const Color(0xFFFBBF24); // Matching wireframe amber
                          textColor = Colors.black;
                          fontWeight = FontWeight.bold;
                        } else if (isInRange) {
                          bgColor = const Color(0xFFFEF3C7);
                          textColor = const Color(0xFF78350F);
                        } else if (isToday) {
                          fontWeight = FontWeight.bold;
                        }

                        return Expanded(
                          child: InkWell(
                            onTap: isPast ? null : () => _onDaySelected(cellDate),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border: (isToday && !isSelected)
                                    ? Border.all(color: const Color(0xFFFBBF24), width: 1.5)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '$day',
                                  style: TextStyle(
                                    fontFamily: 'SF Pro',
                                    fontSize: 13,
                                    fontWeight: fontWeight,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- DEPART TIME CARD WIDGET ---
  Widget _buildDepartTimeCard() {
    final hourStr = _selectedHour.toString().padLeft(2, '0');
    final minuteStr = _selectedMinute.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hour Stepper Box
          _buildTimeStepper(
            display: '$hourStr h',
            onUp: () {
              setState(() {
                _selectedHour = _selectedHour == 12 ? 1 : _selectedHour + 1;
                _syncDefaultEndTimeFromDepart();
              });
            },
            onDown: () {
              setState(() {
                _selectedHour = _selectedHour == 1 ? 12 : _selectedHour - 1;
                _syncDefaultEndTimeFromDepart();
              });
            },
            onTap: _pickManualTime,
          ),

          // Colon Separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              ':',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // Minute Stepper Box
          _buildTimeStepper(
            display: '$minuteStr m',
            onUp: () {
              setState(() {
                _selectedMinute = (_selectedMinute + 5) % 60;
                _syncDefaultEndTimeFromDepart();
              });
            },
            onDown: () {
              setState(() {
                _selectedMinute = (_selectedMinute - 5 + 60) % 60;
                _syncDefaultEndTimeFromDepart();
              });
            },
            onTap: _pickManualTime,
          ),

          const SizedBox(width: 20),

          // AM / PM Selector Column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPm = false;
                      _syncDefaultEndTimeFromDepart();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isPm ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AM',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        fontWeight: !_isPm ? FontWeight.w800 : FontWeight.w600,
                        color: !_isPm ? const Color(0xFF304FFE) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isPm = true;
                      _syncDefaultEndTimeFromDepart();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isPm ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PM',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        fontWeight: _isPm ? FontWeight.w800 : FontWeight.w600,
                        color: _isPm ? const Color(0xFF304FFE) : const Color(0xFF94A3B8),
                      ),
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

  // --- PREFERRED END TIME CARD WIDGET ---
  Widget _buildEndTimeCard() {
    final hourStr = _endHour.toString().padLeft(2, '0');
    final minuteStr = _endMinute.toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hour Stepper Box
          _buildTimeStepper(
            display: '$hourStr h',
            onUp: () {
              setState(() {
                _endHour = _endHour == 12 ? 1 : _endHour + 1;
                _userManuallyChangedEndTime = true;
              });
            },
            onDown: () {
              setState(() {
                _endHour = _endHour == 1 ? 12 : _endHour - 1;
                _userManuallyChangedEndTime = true;
              });
            },
            onTap: _pickManualEndTime,
          ),

          // Colon Separator
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              ':',
              style: TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ),

          // Minute Stepper Box
          _buildTimeStepper(
            display: '$minuteStr m',
            onUp: () {
              setState(() {
                _endMinute = (_endMinute + 5) % 60;
                _userManuallyChangedEndTime = true;
              });
            },
            onDown: () {
              setState(() {
                _endMinute = (_endMinute - 5 + 60) % 60;
                _userManuallyChangedEndTime = true;
              });
            },
            onTap: _pickManualEndTime,
          ),

          const SizedBox(width: 20),

          // AM / PM Selector Column
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _endIsPm = false;
                      _userManuallyChangedEndTime = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_endIsPm ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'AM',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        fontWeight: !_endIsPm ? FontWeight.w800 : FontWeight.w600,
                        color: !_endIsPm ? const Color(0xFF304FFE) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: () {
                    setState(() {
                      _endIsPm = true;
                      _userManuallyChangedEndTime = true;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _endIsPm ? const Color(0xFFEEF2FF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PM',
                      style: TextStyle(
                        fontFamily: 'SF Pro',
                        fontSize: 14,
                        fontWeight: _endIsPm ? FontWeight.w800 : FontWeight.w600,
                        color: _endIsPm ? const Color(0xFF304FFE) : const Color(0xFF94A3B8),
                      ),
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

  Widget _buildTimeStepper({
    required String display,
    required VoidCallback onUp,
    required VoidCallback onDown,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onUp,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Icon(
              Icons.arrow_drop_up_rounded,
              size: 28,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              display,
              style: const TextStyle(
                fontFamily: 'SF Pro',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onDown,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 28,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  // --- SAVE BUTTON (Matches GEMINI.md Discover Tab style) ---
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF304FFE), // Colors.indigoAccent[700]
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isLoading ? null : _saveTravelSchedule,
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Save Travel Schedule',
                  style: TextStyle(
                    fontFamily: 'Roboto Mono',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
      ),
    );
  }
}
