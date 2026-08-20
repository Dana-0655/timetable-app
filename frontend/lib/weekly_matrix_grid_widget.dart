import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';
import 'swap_color_utils.dart';
import 'date_helpers.dart';

// TODO: replace with your existing base URL constant if you have one
const String _kApiBase = "http://127.0.0.1:5000";

class WeeklyMatrixGridWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole;
  final int currentFacultyId;
  final bool canEdit;
  final VoidCallback? onTimetableChanged;
  final Map<int, int> swapColorIndex;
  final Function(dynamic entry)? onCellTap;
  final List<dynamic>? entries;

  const WeeklyMatrixGridWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.userRole,
    required this.currentFacultyId,
    required this.swapColorIndex,
    this.canEdit = true,
    this.onTimetableChanged,
    this.onCellTap,
    this.entries,
  });

  @override
  State<WeeklyMatrixGridWidget> createState() => _WeeklyMatrixGridWidgetState();
}

class _WeeklyMatrixGridWidgetState extends State<WeeklyMatrixGridWidget> {
  bool _isLoading = true;
  List<dynamic> _entries = [];
  Map<String, dynamic> _holidays = {};
  bool _holidaySubmitting = false;
  int _weekOffset = 0; // 0 = current week, 1 = next week, -1 = previous week
  final List<String> _days = const [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  // ---- Swap mode state (new — doesn't touch existing state) ----
  bool _swapModeOn = false;
  Map<String, dynamic>? _swapSourceEntry;
  bool _swapSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.entries != null) {
      _entries = widget.entries!;
      _isLoading = false;
      _fetchHolidays();
    } else {
      _fetchTimetable();
    }
  }

  @override
  void didUpdateWidget(WeeklyMatrixGridWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries != null) {
      setState(() {
        _entries = widget.entries!;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTimetable() async {
    setState(() => _isLoading = true);
    await Future.wait([_fetchEntries(), _fetchHolidays()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchEntries() async {
    final url = widget.userRole == 'faculty_my_schedule'
        ? Uri.parse('$_kApiBase/faculty_timetable/${widget.currentFacultyId}')
        : Uri.parse('$_kApiBase/timetable/${widget.classId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _entries = jsonDecode(response.body);
      }
    } catch (_) {}
  }

  Future<void> _fetchHolidays() async {
    if (widget.classId == 0) return;
    final url = Uri.parse(
      '$_kApiBase/holidays_for_class_week/${widget.classId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        _holidays = Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (_) {}
  }

  bool get _canToggleHoliday {
    if (!widget.canEdit) return false;
    return _isAdmin || widget.userRole == 'cc';
  }

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
          _showSwapSnack('Unmarked $dayCode as holiday.');
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
          _showSwapSnack('Marked $dayCode as holiday!');
        } else {
          final body = jsonDecode(res.body);
          _showSwapSnack(body['error'] ?? 'Could not mark holiday.');
        }
      }
      await _fetchHolidays();
      widget.onTimetableChanged?.call();
    } catch (e) {
      _showSwapSnack('Network error updating holiday state.');
    } finally {
      if (mounted) setState(() => _holidaySubmitting = false);
    }
  }

  void _confirmMarkFacultyDayLeave(String dayCode) {
    final isoDate = DateHelpers.isoForDayCode(dayCode, weekOffset: _weekOffset);
    final dayLabel = DateHelpers.labelForDayCode(dayCode, weekOffset: _weekOffset);

    final dayEntriesCount = _entries
        .where((e) => e['day_of_week'] == dayCode)
        .length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.beach_access_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Text('Mark Full Day Absent ($dayCode)'),
          ],
        ),
        content: Text(
          dayEntriesCount == 0
              ? 'You have no assigned periods on $dayCode ($dayLabel).'
              : 'Mark all $dayEntriesCount of your assigned periods on $dayCode ($dayLabel) as absent/leave? Slots will open up for substitutes to volunteer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (dayEntriesCount > 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade800,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _markFacultyDayLeave(dayCode, isoDate);
              },
              child: const Text('Mark Absent'),
            ),
        ],
      ),
    );
  }

  Future<void> _markFacultyDayLeave(String dayCode, String isoDate) async {
    try {
      final response = await http.post(
        Uri.parse('$_kApiBase/mark_day_leave'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.currentFacultyId,
          'leave_date': isoDate,
          'day_of_week': dayCode,
        }),
      );
      if (response.statusCode == 200) {
        _showSwapSnack('Marked full day leave for $dayCode ($isoDate)!');
        await _fetchEntries();
        widget.onTimetableChanged?.call();
      }
    } catch (e) {
      _showSwapSnack('Network error marking full day leave.');
    }
  }

  Color _getCellColor(dynamic entry, bool isMySubject) {
    if (entry == null) return Colors.grey.shade50;
    if (entry['entry_type'] == 'break') return Colors.amber.shade50;
    if (isMySubject) return const Color(0xFFE8F5E9);

    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        return Colors.red.shade100;
      case 'confirmed_cover':
        return Colors.green.shade100;
      case 'swapped':
        return entry['swap_id'] != null
            ? swapFillColor(widget.swapColorIndex, entry['swap_id'] as int)
            : Colors.blue.shade50;
      default:
        return Colors.white;
    }
  }

  Color _getBorderColor(dynamic entry, bool isMySubject) {
    if (entry == null) return Colors.grey.shade300;
    if (entry['entry_type'] == 'break') return Colors.amber.shade300;
    if (isMySubject) return Colors.green.shade400;

    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        return Colors.red.shade400;
      case 'confirmed_cover':
        return Colors.green.shade400;
      case 'swapped':
        return entry['swap_id'] != null
            ? swapBorderColor(widget.swapColorIndex, entry['swap_id'] as int)
            : Colors.blue.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  void _handleCellTap(dynamic entry, String day, int periodNo) {
    if (widget.onCellTap != null) {
      widget.onCellTap!(entry);
      return;
    }
    if (!widget.canEdit) return;

    if (entry != null && entry['entry_type'] != 'break') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FillSlotScreen(
            entryId: entry['entry_id'],
            entryType: entry['entry_type'] ?? 'class',
            isEdit: true,
            existingCourseName: entry['course_name'],
            existingLabel: entry['label'],
            existingStartTime: entry['start_time'],
            existingEndTime: entry['end_time'],
          ),
        ),
      ).then((val) {
        _fetchTimetable();
        widget.onTimetableChanged?.call();
      });
    } else if (entry == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleBuilderScreen(
            classId: widget.classId,
            className: widget.className,
            dayOfWeek: day,
          ),
        ),
      ).then((val) {
        _fetchTimetable();
        widget.onTimetableChanged?.call();
      });
    }
  }

  // =====================================================================
  // NEW: Swap mode logic (added — no existing methods above were changed)
  // =====================================================================

  bool get _isAdmin => widget.userRole == 'admin';
  bool get _isFacultyOrCC =>
      widget.userRole == 'faculty' || widget.userRole == 'cc';

  bool get _teachesInThisTimetable {
    if (widget.currentFacultyId <= 0) return false;
    return _entries.any((e) => e['faculty_id'] == widget.currentFacultyId);
  }

  bool get _canUseSwapMode {
    if (!widget.canEdit) return false;
    if (_isAdmin) return true;
    if (_isFacultyOrCC) return _teachesInThisTimetable;
    return false;
  }

  bool _isSwappableEntry(dynamic entry) {
    if (entry == null) return false;
    if (entry['entry_type'] == 'break') return false;
    if (entry['course_name'] == null) return false;
    if (entry['faculty_id'] == null) return false;
    return true;
  }

  void _toggleSwapMode() {
    setState(() {
      _swapModeOn = !_swapModeOn;
      _swapSourceEntry = null;
    });
  }

  void _handleSwapTap(dynamic entry) {
    if (!_isSwappableEntry(entry)) {
      _showSwapSnack(
        'This slot can\'t be swapped — it has no assigned course.',
      );
      return;
    }
    final entryMap = Map<String, dynamic>.from(entry as Map);

    if (_isFacultyOrCC && _swapSourceEntry == null) {
      if (entryMap['faculty_id'] != widget.currentFacultyId) {
        _showSwapSnack('You can only start a swap from your own period.');
        return;
      }
    }

    if (_swapSourceEntry == null) {
      setState(() => _swapSourceEntry = entryMap);
      return;
    }

    if (_swapSourceEntry!['entry_id'] == entryMap['entry_id']) {
      setState(() => _swapSourceEntry = null);
      return;
    }

    if (_isFacultyOrCC && entryMap['faculty_id'] == widget.currentFacultyId) {
      _showSwapSnack(
        'Pick a period taught by a different faculty to swap with.',
      );
      return;
    }

    _showSwapConfirmDialog(_swapSourceEntry!, entryMap);
  }

  void _showSwapSnack(String message) {
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
        _showSwapSnack('Swap request sent!');
        widget.onTimetableChanged?.call();
      } else {
        final body = jsonDecode(response.body);
        _showSwapSnack(body['error'] ?? 'Failed to send swap request.');
      }
    } catch (e) {
      _showSwapSnack('Network error — could not send swap request.');
    } finally {
      if (mounted) {
        setState(() {
          _swapSubmitting = false;
          _swapSourceEntry = null;
        });
      }
    }
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

  Widget _buildSwapModeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // END new swap mode logic
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 48,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              const Text(
                'No timetable entries available for this class.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              if (widget.canEdit) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('Make / Build Schedule'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScheduleBuilderScreen(
                          classId: widget.classId,
                          className: widget.className,
                          dayOfWeek: 'MON',
                        ),
                      ),
                    ).then((_) {
                      _fetchTimetable();
                      widget.onTimetableChanged?.call();
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      );
    }

    int maxPeriod = 1;
    for (var e in _entries) {
      final p = e['period_no'];
      if (p != null && p is int && p > maxPeriod) {
        maxPeriod = p;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- NEW: Swap Mode toggle row, top-right ----
        if (_canUseSwapMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildSwapModeToggle()],
            ),
          ),
        if (_canUseSwapMode && _swapModeOn) _buildSwapModeBanner(),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(140.0),
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  children: [
                    TableRow(
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(7),
                        ),
                      ),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          child: const Text(
                            'Day',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        for (int p = 1; p <= maxPeriod; p++)
                          Container(
                            padding: const EdgeInsets.all(10),
                            alignment: Alignment.center,
                            child: Text(
                              'Period $p',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),

                    // ---- Navigation Row: Above Monday (Previous Week) ----
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() => _weekOffset--);
                            _fetchHolidays();
                          },
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Prev Week',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (int p = 1; p <= maxPeriod; p++)
                          Container(
                            height: 38,
                            alignment: Alignment.center,
                            child: p == 1
                                ? Text(
                                    _weekOffset == 0
                                        ? 'Current Week (${DateHelpers.weekRangeLabel(weekOffset: 0)})'
                                        : '${DateHelpers.weekRangeLabel(weekOffset: _weekOffset)} (${_weekOffset > 0 ? "+$_weekOffset W" : "$_weekOffset W"})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0369A1),
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),

                    for (String day in _days)
                      TableRow(
                        children: [
                          Builder(
                            builder: (context) {
                              final isoDate = DateHelpers.isoForDayCode(
                                day,
                                weekOffset: _weekOffset,
                              );
                              final isCustomHoliday = _holidays.containsKey(
                                isoDate,
                              );
                              final isHoliday = isCustomHoliday || day == 'SUN';

                              return Container(
                                height: 90,
                                padding: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                color: isHoliday
                                    ? Colors.orange.shade50
                                    : Colors.indigo.shade50.withValues(
                                        alpha: 0.4,
                                      ),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            day,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isHoliday
                                                  ? Colors.orange.shade900
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            DateHelpers.labelForDayCode(
                                              day,
                                              weekOffset: _weekOffset,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isHoliday
                                                  ? Colors.orange.shade700
                                                  : Colors.indigo.shade400,
                                            ),
                                          ),
                                          if (isHoliday) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'HOLIDAY',
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (widget.userRole == 'faculty_my_schedule' && day != 'SUN')
                                       Positioned(
                                         left: 2,
                                         bottom: 2,
                                         child: InkWell(
                                           onTap: () => _confirmMarkFacultyDayLeave(day),
                                           borderRadius: BorderRadius.circular(12),
                                           child: Padding(
                                             padding: const EdgeInsets.all(2.0),
                                             child: Tooltip(
                                               message: 'Mark Full Day Absent ($day)',
                                               child: Icon(
                                                 Icons.beach_access_rounded,
                                                 size: 18,
                                                 color: Colors.orange.shade800,
                                               ),
                                             ),
                                           ),
                                         ),
                                       )
                                     else if (_canToggleHoliday && day != 'SUN')
                                      Positioned(
                                        left: 2,
                                        bottom: 2,
                                        child: InkWell(
                                          onTap: () => _toggleHoliday(day),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Tooltip(
                                              message: isCustomHoliday
                                                  ? 'Unmark Holiday'
                                                  : 'Mark as Holiday',
                                              child: Icon(
                                                isCustomHoliday
                                                    ? Icons.beach_access_rounded
                                                    : Icons
                                                          .beach_access_outlined,
                                                size: 16,
                                                color: isCustomHoliday
                                                    ? Colors.orange.shade700
                                                    : Colors.indigo.shade400,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (isHoliday)
                                      Positioned(
                                        left: 2,
                                        bottom: 2,
                                        child: Padding(
                                          padding: const EdgeInsets.all(2.0),
                                          child: Icon(
                                            Icons.beach_access_rounded,
                                            size: 16,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    if (widget.canEdit)
                                      Positioned(
                                        right: 2,
                                        bottom: 2,
                                        child: InkWell(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ScheduleBuilderScreen(
                                                      classId: widget.classId,
                                                      className:
                                                          widget.className,
                                                      dayOfWeek: day,
                                                    ),
                                              ),
                                            ).then((_) {
                                              _fetchTimetable();
                                              widget.onTimetableChanged?.call();
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(2.0),
                                            child: Tooltip(
                                              message:
                                                  'Reschedule Periods & Breaks ($day)',
                                              child: const Icon(
                                                Icons.edit_calendar_rounded,
                                                size: 16,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),

                          for (int p = 1; p <= maxPeriod; p++)
                            Builder(
                              builder: (context) {
                                final isoDate = DateHelpers.isoForDayCode(
                                  day,
                                  weekOffset: _weekOffset,
                                );
                                final isHoliday =
                                    _holidays.containsKey(isoDate) ||
                                    day == 'SUN';
                                final entry = _entries.firstWhere(
                                  (e) =>
                                      e['day_of_week'] == day &&
                                      e['period_no'] == p,
                                  orElse: () => null,
                                );

                                if (entry == null) {
                                  return InkWell(
                                    onTap: () => _handleCellTap(null, day, p),
                                    child: Container(
                                      height: 90,
                                      color: isHoliday
                                          ? Colors.orange.shade50
                                          : Colors.grey.shade50,
                                      alignment: Alignment.center,
                                      child: isHoliday
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.beach_access_rounded,
                                                  size: 16,
                                                  color: Colors.orange.shade400,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  widget.canEdit
                                                      ? 'Holiday\n(Tap for special class)'
                                                      : 'Holiday',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        Colors.orange.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            )
                                          : Text(
                                              widget.canEdit
                                                  ? 'Free Period\n(Tap to add)'
                                                  : 'Free Period',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                    ),
                                  );
                                }

                                final isBreak = entry['entry_type'] == 'break';
                                final isOpenLeave =
                                    entry['status_color'] == 'open_leave';
                                final isSwapped =
                                    entry['status_color'] == 'swapped';
                                final isMySubject =
                                    widget.currentFacultyId > 0 &&
                                    entry['faculty_id'] ==
                                        widget.currentFacultyId;

                                // NEW: highlight if this cell is the selected swap source
                                final isSelectedAsSource =
                                    _swapModeOn &&
                                    _swapSourceEntry != null &&
                                    _swapSourceEntry!['entry_id'] ==
                                        entry['entry_id'];

                                final title = isBreak
                                    ? (entry['label'] ?? 'BREAK')
                                    : (entry['course_name'] ?? 'Free Period');
                                final faculty = widget.userRole ==
                                        'faculty_my_schedule'
                                    ? (entry['class_name'] ?? '')
                                    : (entry['faculty_name'] ?? '');
                                final room = entry['room_number'] ?? '';

                                return InkWell(
                                  // NEW: route tap through swap handler when swap mode is on,
                                  // otherwise call the original _handleCellTap unchanged.
                                  onTap: () {
                                    if (_swapModeOn && !isBreak) {
                                      _handleSwapTap(entry);
                                    } else {
                                      _handleCellTap(entry, day, p);
                                    }
                                  },
                                  child: Container(
                                    height: 90,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getCellColor(entry, isMySubject),
                                      border: Border.all(
                                        // NEW: blue highlight border when selected as swap source
                                        color: isSelectedAsSource
                                            ? const Color(0xFF0EA5E9)
                                            : _getBorderColor(
                                                entry,
                                                isMySubject,
                                              ),
                                        width: isSelectedAsSource
                                            ? 2.5
                                            : (isMySubject ||
                                                      isOpenLeave ||
                                                      isSwapped
                                                  ? 1.8
                                                  : 0.8),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              title.toUpperCase(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                                color: isBreak
                                                    ? Colors.amber.shade900
                                                    : isOpenLeave
                                                    ? Colors.red.shade900
                                                    : (isMySubject
                                                          ? Colors
                                                                .green
                                                                .shade900
                                                          : Colors.black87),
                                              ),
                                            ),
                                            if (isOpenLeave) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'ABSENT',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ] else if (faculty.isNotEmpty &&
                                                !isBreak) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                faculty,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                            if (room.isNotEmpty &&
                                                !isBreak) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.meeting_room,
                                                    size: 10,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Room: $room',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (isSwapped)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: entry['swap_id'] != null
                                                    ? swapBorderColor(
                                                        widget.swapColorIndex,
                                                        entry['swap_id'] as int,
                                                      )
                                                    : Colors.blue.shade700,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.swap_horiz,
                                                size: 10,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        // NEW: "SELECTED" badge on the chosen source cell
                                        if (isSelectedAsSource)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'SEL',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),

                    // ---- Navigation Row: Below Sunday (Next / Future Week) ----
                    TableRow(
                      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() => _weekOffset++);
                            _fetchHolidays();
                          },
                          child: Container(
                            height: 38,
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  size: 14,
                                  color: Color(0xFF0F172A),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Next Week',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        for (int p = 1; p <= maxPeriod; p++)
                          Container(
                            height: 38,
                            alignment: Alignment.center,
                            child: p == 1 && _weekOffset != 0
                                ? TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.today_rounded,
                                      size: 14,
                                    ),
                                    label: const Text(
                                      'Back to Current Week',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() => _weekOffset = 0);
                                      _fetchHolidays();
                                    },
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
