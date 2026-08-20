import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'swap_color_utils.dart';
import 'date_helpers.dart';
import 'schedule_builder_screen.dart';

// TODO: replace with your existing base URL constant (e.g. ApiConfig.baseUrl)
const String _kApiBase = "http://127.0.0.1:5000";

class VercelBarsTimetableWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole; // 'faculty', 'cc', or 'admin'
  final int? currentFacultyId;
  final List<dynamic> entries;
  final String department;
  final String roomNo;
  final Map<int, int> swapColorIndex;
  final Function(dynamic entry)? onCellTap;
  final VoidCallback? onRefreshNeeded;

  const VercelBarsTimetableWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.entries,
    required this.department,
    required this.roomNo,
    required this.swapColorIndex,
    this.userRole = 'student',
    this.currentFacultyId,
    this.onCellTap,
    this.onRefreshNeeded,
  });

  @override
  State<VercelBarsTimetableWidget> createState() =>
      _VercelBarsTimetableWidgetState();
}

class _VercelBarsTimetableWidgetState extends State<VercelBarsTimetableWidget> {
  late String _selectedDay = _todayShortCode();
  Map<String, dynamic> _holidays = {};
  bool _holidaySubmitting = false;
  int _weekOffset = 0; // 0 = current week, 1 = next week, -1 = previous week

  // ---- Swap mode state ----
  bool _swapModeOn = false;
  Map<String, dynamic>? _swapSourceEntry; // first tapped cell
  bool _swapSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    final url = Uri.parse('$_kApiBase/holidays_for_class_week/${widget.classId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _holidays = Map<String, dynamic>.from(jsonDecode(response.body));
        });
      }
    } catch (_) {}
  }

  bool get _canToggleHoliday => _isAdmin || widget.userRole == 'cc';

  Future<void> _toggleHoliday(String dayCode) async {
    if (!_canToggleHoliday || _holidaySubmitting) return;
    final isoDate = DateHelpers.isoForDayCode(dayCode, weekOffset: _weekOffset);
    final isCustomHoliday = _holidays.containsKey(isoDate);

    setState(() => _holidaySubmitting = true);
    try {
      if (isCustomHoliday) {
        final holidayId = _holidays[isoDate]['holiday_id'];
        final res = await http.post(
          Uri.parse('$_kApiBase/delete_holiday'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'holiday_id': holidayId}),
        );
        if (res.statusCode == 200) {
          _showSnack('Unmarked $dayCode as holiday.');
        }
      } else {
        final res = await http.post(
          Uri.parse('$_kApiBase/mark_holiday'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'class_id': widget.classId,
            'holiday_date': isoDate,
            'reason': 'Declared Holiday',
          }),
        );
        if (res.statusCode == 200) {
          _showSnack('Marked $dayCode as holiday!');
        } else {
          final body = jsonDecode(res.body);
          _showSnack(body['error'] ?? 'Could not mark holiday.');
        }
      }
      await _fetchHolidays();
      widget.onRefreshNeeded?.call();
    } catch (e) {
      _showSnack('Network error updating holiday state.');
    } finally {
      if (mounted) setState(() => _holidaySubmitting = false);
    }
  }

  Widget _buildHolidayToggle() {
    final currentIso = DateHelpers.isoForDayCode(_selectedDay, weekOffset: _weekOffset);
    final isCustomHoliday = _holidays.containsKey(currentIso);

    return InkWell(
      onTap: (_selectedDay == 'SUN' || _holidaySubmitting)
          ? null
          : () => _toggleHoliday(_selectedDay),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isCustomHoliday ? Colors.orange.shade600 : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCustomHoliday ? Colors.orange.shade600 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_holidaySubmitting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                isCustomHoliday ? Icons.beach_access_rounded : Icons.beach_access_outlined,
                size: 16,
                color: isCustomHoliday ? Colors.white : const Color(0xFF475569),
              ),
            const SizedBox(width: 6),
            Text(
              isCustomHoliday ? 'Holiday Set' : 'Holiday',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isCustomHoliday ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRescheduleToggle() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ScheduleBuilderScreen(
              classId: widget.classId,
              className: widget.className,
              dayOfWeek: _selectedDay,
            ),
          ),
        ).then((_) {
          widget.onRefreshNeeded?.call();
          _fetchHolidays();
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit_calendar_rounded,
              size: 16,
              color: Color(0xFF475569),
            ),
            SizedBox(width: 6),
            Text(
              'Schedule',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _todayShortCode() {
    const weekdayToCode = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return weekdayToCode[DateTime.now().weekday - 1];
  }

  final List<Map<String, String>> _days = const [
    {'short': 'MON', 'full': 'Monday'},
    {'short': 'TUE', 'full': 'Tuesday'},
    {'short': 'WED', 'full': 'Wednesday'},
    {'short': 'THU', 'full': 'Thursday'},
    {'short': 'FRI', 'full': 'Friday'},
    {'short': 'SAT', 'full': 'Saturday'},
    {'short': 'SUN', 'full': 'Sunday'},
  ];

  List<dynamic> _getEntriesForDay(String dayShort) {
    final list = widget.entries
        .where((e) => e['day_of_week'] == dayShort)
        .toList();

    final Map<int, dynamic> byPeriod = {};
    for (final e in list) {
      final p = e['period_no'] as int? ?? 0;
      final existing = byPeriod[p];
      if (existing == null) {
        byPeriod[p] = e;
      } else {
        final existingHasCourse = existing['course_name'] != null;
        final newHasCourse = e['course_name'] != null;
        if (!existingHasCourse && newHasCourse) {
          byPeriod[p] = e;
        }
      }
    }

    final deduped = byPeriod.values.toList();
    deduped.sort(
      (a, b) =>
          (a['period_no'] as int? ?? 0).compareTo(b['period_no'] as int? ?? 0),
    );
    return deduped;
  }

  // ---- Swap mode eligibility ----

  bool get _isAdmin => widget.userRole == 'admin';
  bool get _isFacultyOrCC =>
      widget.userRole == 'faculty' || widget.userRole == 'cc';

  bool get _teachesInThisTimetable {
    if (widget.currentFacultyId == null) return false;
    return widget.entries.any(
      (e) => e['faculty_id'] == widget.currentFacultyId,
    );
  }

  bool get _canUseSwapMode {
    if (_isAdmin) return true;
    if (_isFacultyOrCC) return _teachesInThisTimetable;
    return false;
  }

  bool _isSwappableEntry(Map<String, dynamic> entry) {
    if (entry['entry_type'] == 'break') return false;
    if (entry['course_name'] == null) return false; // unassigned slot
    if (entry['faculty_id'] == null) return false; // no owning faculty
    return true;
  }

  void _toggleSwapMode() {
    setState(() {
      _swapModeOn = !_swapModeOn;
      _swapSourceEntry = null;
    });
  }

  void _handleSwapTap(Map<String, dynamic> entry) {
    if (!_isSwappableEntry(entry)) {
      _showSnack('This slot can\'t be swapped — it has no assigned course.');
      return;
    }

    // Faculty/CC can only pick their OWN periods as the source.
    if (_isFacultyOrCC && _swapSourceEntry == null) {
      if (entry['faculty_id'] != widget.currentFacultyId) {
        _showSnack('You can only start a swap from your own period.');
        return;
      }
    }

    if (_swapSourceEntry == null) {
      setState(() => _swapSourceEntry = entry);
      return;
    }

    // Tapping the same cell again deselects it.
    if (_swapSourceEntry!['entry_id'] == entry['entry_id']) {
      setState(() => _swapSourceEntry = null);
      return;
    }

    // Faculty/CC can't target one of their own other periods.
    if (_isFacultyOrCC && entry['faculty_id'] == widget.currentFacultyId) {
      _showSnack('Pick a period taught by a different faculty to swap with.');
      return;
    }

    _showSwapConfirmDialog(_swapSourceEntry!, entry);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSwapConfirmDialog(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('Confirm Swap Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwapPreviewRow(
              'From',
              source['course_name'] ?? '',
              source['faculty_name'] ?? '',
              '${source['day_of_week']} • Period ${source['period_no']}',
            ),
            const SizedBox(height: 12),
            const Icon(Icons.swap_vert_rounded, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            _buildSwapPreviewRow(
              'With',
              target['course_name'] ?? '',
              target['faculty_name'] ?? '',
              '${target['day_of_week']} • Period ${target['period_no']}',
            ),
            const SizedBox(height: 16),
            Text(
              _isAdmin
                  ? 'This will send a swap request that ${target['faculty_name']} still needs to approve.'
                  : 'A swap request will be sent to ${target['faculty_name']} for approval.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitSwapRequest(source, target);
    } else {
      setState(() => _swapSourceEntry = null);
    }
  }

  Widget _buildSwapPreviewRow(
    String label,
    String course,
    String faculty,
    String slot,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            course,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            faculty,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          Text(
            slot,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSwapRequest(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) async {
    setState(() => _swapSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse('$_kApiBase/send_swap_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requester_faculty_id': source['faculty_id'],
          'requester_entry_id': source['entry_id'],
          'target_faculty_id': target['faculty_id'],
          'target_entry_id': target['entry_id'],
        }),
      );

      if (response.statusCode == 200) {
        _showSnack('Swap request sent!');
        widget.onRefreshNeeded?.call();
      } else {
        final body = jsonDecode(response.body);
        _showSnack(body['error'] ?? 'Failed to send swap request.');
      }
    } catch (e) {
      _showSnack('Network error — could not send swap request.');
    } finally {
      if (mounted) {
        setState(() {
          _swapSubmitting = false;
          _swapSourceEntry = null;
        });
      }
    }
  }

  // ---- Existing color/badge helpers (unchanged) ----

  Color _getStatusBgColor(String? colorType, {int? swapId}) {
    switch (colorType) {
      case 'open_leave':
        return const Color(0xFFFEF2F2);
      case 'confirmed_cover':
        return const Color(0xFFECFDF5);
      case 'swapped':
        return swapId != null
            ? swapFillColor(
                widget.swapColorIndex,
                swapId,
                fallback: const Color(0xFFF0F9FF),
              )
            : const Color(0xFFF0F9FF);
      default:
        return Colors.white;
    }
  }

  Color _getStatusBorderColor(String? colorType, {int? swapId}) {
    switch (colorType) {
      case 'open_leave':
        return const Color(0xFFFCA5A5);
      case 'confirmed_cover':
        return const Color(0xFF6EE7B7);
      case 'swapped':
        return swapId != null
            ? swapBorderColor(
                widget.swapColorIndex,
                swapId,
                fallback: const Color(0xFF7DD3FC),
              )
            : const Color(0xFF7DD3FC);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  Widget _buildStatusBadge(
    String? colorType,
    String? facultyName, {
    int? swapId,
  }) {
    switch (colorType) {
      case 'open_leave':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'ABSENT • OPEN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case 'confirmed_cover':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 12,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                'COVERED: ${facultyName ?? "Substitute"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case 'swapped':
        final badgeColor = swapId != null
            ? swapBorderColor(
                widget.swapColorIndex,
                swapId,
                fallback: const Color(0xFF0EA5E9),
              )
            : const Color(0xFF0EA5E9);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'SWAPPED',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'SCHEDULED',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = _getEntriesForDay(_selectedDay);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Day tabs + Swap Mode toggle (top-right) ----
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      // Left Arrow: Before Monday (Past Weeks)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message: 'Previous Week',
                          child: InkWell(
                            onTap: () {
                              setState(() => _weekOffset--);
                              _fetchHolidays();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),

                      ..._days.map((day) {
                        final isSelected = _selectedDay == day['short'];
                        final dayIso = DateHelpers.isoForDayCode(day['short']!, weekOffset: _weekOffset);
                        final isDayHoliday = _holidays.containsKey(dayIso) || day['short'] == 'SUN';

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: isSelected,
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      day['short']!,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : const Color(0xFF475569),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isDayHoliday) ...[
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.beach_access_rounded,
                                        size: 11,
                                        color: isSelected ? Colors.amber.shade300 : Colors.orange.shade600,
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  DateHelpers.labelForDayCode(day['short']!, weekOffset: _weekOffset),
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: isSelected ? Colors.white70 : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                            selectedColor: const Color(0xFF0F172A),
                            backgroundColor: const Color(0xFFF8FAFC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDay = day['short']!);
                              }
                            },
                          ),
                        );
                      }),

                      // Right Arrow: After Sunday (Future Weeks)
                      Padding(
                        padding: const EdgeInsets.only(left: 2, right: 8),
                        child: Tooltip(
                          message: 'Next / Future Week',
                          child: InkWell(
                            onTap: () {
                              setState(() => _weekOffset++);
                              _fetchHolidays();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_weekOffset != 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.today_rounded, size: 14),
                            label: Text(
                              'Reset to Today (${DateHelpers.weekRangeLabel(weekOffset: _weekOffset)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: () {
                              setState(() => _weekOffset = 0);
                              _fetchHolidays();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_canToggleHoliday) ...[
                const SizedBox(width: 8),
                _buildHolidayToggle(),
              ],
              if (_canUseSwapMode) ...[
                const SizedBox(width: 8),
                _buildSwapModeToggle(),
              ],
              if (_isAdmin || _isFacultyOrCC) ...[
                const SizedBox(width: 8),
                _buildRescheduleToggle(),
              ],
            ],
          ),

          if (_swapModeOn) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF0EA5E9),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _swapSourceEntry == null
                          ? (_isAdmin
                                ? 'Swap Mode: tap a period, then tap another to swap them.'
                                : 'Swap Mode: tap one of your own periods to start.')
                          : 'Selected ${_swapSourceEntry!['course_name']} (P${_swapSourceEntry!['period_no']}) — now tap the period to swap with.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          Builder(
            builder: (context) {
              final selectedIso = DateHelpers.isoForDayCode(_selectedDay, weekOffset: _weekOffset);
              final isCurrentHoliday =
                  _holidays.containsKey(selectedIso) || _selectedDay == 'SUN';

              if (dayEntries.isEmpty || isCurrentHoliday) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isCurrentHoliday
                        ? const Color(0xFFFFF7ED)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrentHoliday
                          ? const Color(0xFFFDBA74)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isCurrentHoliday
                            ? Icons.beach_access_rounded
                            : Icons.calendar_today_outlined,
                        size: 40,
                        color: isCurrentHoliday
                            ? Colors.orange.shade400
                            : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isCurrentHoliday
                            ? (_selectedDay == 'SUN'
                                ? 'Sunday is usually a holiday.'
                                : 'This day is marked as a holiday.')
                            : 'No schedule entries set for this day.',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isCurrentHoliday && (_isAdmin || _isFacultyOrCC)) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_chart, size: 16),
                          label: const Text('Schedule Special Class'),
                          onPressed: () => widget.onCellTap?.call(null),
                        ),
                      ],
                      if (dayEntries.isEmpty && !isCurrentHoliday && (_isAdmin || _isFacultyOrCC)) ...[
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: Text('Make Schedule for $_selectedDay'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleBuilderScreen(
                                  classId: widget.classId,
                                  className: widget.className,
                                  dayOfWeek: _selectedDay,
                                ),
                              ),
                            ).then((_) {
                              widget.onRefreshNeeded?.call();
                              _fetchHolidays();
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dayEntries.length,
                itemBuilder: (context, index) {
                final entry = dayEntries[index];
                final isBreak = entry['entry_type'] == 'break';
                final courseName =
                    entry['course_name'] ??
                    (isBreak ? (entry['label'] ?? 'BREAK') : 'Unassigned Slot');
                final facultyName =
                    entry['faculty_name'] ?? 'No Faculty Assigned';
                final statusColor = entry['status_color'] ?? 'normal';
                final swapId = entry['swap_id'] as int?;
                final startTime = entry['start_time'] ?? '00:00';
                final endTime = entry['end_time'] ?? '00:00';
                final periodNo = entry['period_no'] ?? (index + 1);
                final isSelectedAsSource =
                    _swapModeOn &&
                    _swapSourceEntry != null &&
                    _swapSourceEntry!['entry_id'] == entry['entry_id'];

                if (isBreak) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.coffee_rounded,
                            size: 18,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (startTime != '00:00')
                                Text(
                                  '$startTime - $endTime',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return InkWell(
                  onTap: () {
                    if (_swapModeOn) {
                      _handleSwapTap(Map<String, dynamic>.from(entry));
                    } else {
                      widget.onCellTap?.call(entry);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(statusColor, swapId: swapId),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelectedAsSource
                            ? const Color(0xFF0EA5E9)
                            : _getStatusBorderColor(
                                statusColor,
                                swapId: swapId,
                              ),
                        width: isSelectedAsSource ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelectedAsSource
                              ? const Color(0xFF0EA5E9).withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: isSelectedAsSource ? 12 : 8,
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
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PERIOD $periodNo',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (startTime != '00:00') ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.access_time_rounded,
                                          size: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$startTime - $endTime',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (isSelectedAsSource)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'SELECTED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              _buildStatusBadge(
                                statusColor,
                                facultyName,
                                swapId: swapId,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Text(
                          courseName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                facultyName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (widget.roomNo.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.meeting_room_rounded,
                                      size: 12,
                                      color: Color(0xFF6D28D9),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Room ${widget.roomNo}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        ],
      ),
    );
  }

  Widget _buildSwapModeToggle() {
    return InkWell(
      onTap: _swapSubmitting ? null : _toggleSwapMode,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _swapModeOn
              ? const Color(0xFF0EA5E9)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _swapModeOn
                ? const Color(0xFF0EA5E9)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_swapSubmitting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: _swapModeOn ? Colors.white : const Color(0xFF475569),
              ),
            const SizedBox(width: 6),
            Text(
              'Swap',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _swapModeOn ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
