import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'schedule_builder_screen.dart';
import 'date_helpers.dart';

class TimetableGridScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int facultyId;
  final bool isCC;

  const TimetableGridScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.facultyId,
    this.isCC = true,
  });

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  bool _swapMode = false;
  dynamic _selectedMyEntry;

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  late final TabController _tabController;
  Map<String, dynamic> _holidayMap = {}; // "YYYY-MM-DD" -> reason

  @override
  void initState() {
    super.initState();
    final todayCode = DateHelpers.weekDayCodes[DateTime.now().weekday - 1];
    var initialIndex = _days.indexOf(todayCode);
    if (initialIndex == -1) initialIndex = 0;
    _tabController = TabController(
      length: _days.length,
      initialIndex: initialIndex,
      vsync: this,
    );
    _fetchTimetable();
    _fetchHolidays();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchHolidays() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/holidays_for_class_week/${widget.classId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _holidayMap = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _fetchTimetable() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/timetable/${widget.classId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _entries = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // A fixed palette so each distinct swap pair gets its own consistent
  // color - cycling if there are ever more simultaneous swaps than colors.
  static const List<Color> _swapPalette = [
    Color(0xFFB3E5FC), // light blue
    Color(0xFFC8E6C9), // light green
    Color(0xFFFFF9C4), // light yellow
    Color(0xFFF8BBD0), // light pink
    Color(0xFFD1C4E9), // light purple
    Color(0xFFFFCCBC), // light orange
    Color(0xFFB2DFDB), // teal
    Color(0xFFDCEDC8), // lime
  ];

  Color _colorForSwapId(int swapId) {
    return _swapPalette[swapId % _swapPalette.length];
  }

  Color _colorForEntry(dynamic entry) {
    if (_selectedMyEntry != null &&
        entry['entry_id'] == _selectedMyEntry['entry_id']) {
      return Colors.orange.shade200; // My selected period to give up
    }
    switch (entry['status_color']) {
      case 'open_leave':
        // CC sees red as a clear "tap me to assign a substitute" cue;
        // everyone else keeps the original orange highlight.
        return widget.isCC ? Colors.red.shade100 : Colors.orange.shade100;
      case 'confirmed_cover':
        return Colors.green.shade100;
      case 'swapped':
        return entry['swap_id'] != null
            ? _colorForSwapId(entry['swap_id'] as int)
            : Colors.blue.shade100;
      default:
        return Colors.white;
    }
  }

  bool _isTappable(dynamic entry) {
    if (!_swapMode) return false;
    if (entry['course_id'] == null) return false; // unassigned slot, can't swap

    if (_selectedMyEntry == null) {
      // Step 1: only my own periods are tappable
      return entry['faculty_id'] == widget.facultyId;
    } else {
      // Step 2: only OTHER faculty's periods are tappable (mine is disabled now)
      return entry['faculty_id'] != widget.facultyId;
    }
  }

  void _onEntryTap(dynamic entry) {
    if (!_isTappable(entry)) return;

    if (_selectedMyEntry == null) {
      // Picking my own period
      setState(() {
        _selectedMyEntry = entry;
      });
    } else {
      // Picking target period -> confirm
      _confirmSwap(entry);
    }
  }

  void _confirmSwap(dynamic targetEntry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Swap Request'),
        content: Text(
          'Do you want to request a swap with ${targetEntry['faculty_name']}?\n\n'
          'You give: ${_selectedMyEntry['course_name']} '
          '(${_selectedMyEntry['day_of_week']} P${_selectedMyEntry['period_no']})\n'
          'You get: ${targetEntry['course_name']} '
          '(${targetEntry['day_of_week']} P${targetEntry['period_no']})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendSwapRequest(targetEntry);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSwapRequest(dynamic targetEntry) async {
    final url = Uri.parse('http://127.0.0.1:5000/send_swap_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requester_faculty_id': widget.facultyId,
          'requester_entry_id': _selectedMyEntry['entry_id'],
          'target_faculty_id': targetEntry['faculty_id'],
          'target_entry_id': targetEntry['entry_id'],
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Swap request sent!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
    setState(() {
      _swapMode = false;
      _selectedMyEntry = null;
    });
  }

  /// CC tapped an open (absent, unfilled) slot directly in the grid.
  /// Looks up the underlying leave, then shows the substitute picker —
  /// course faculty for this class are labeled with their course name,
  /// everyone else is labeled "Substitution".
  Future<void> _handleOpenSlotTap(dynamic entry) async {
    final leaveUrl = Uri.parse(
      'http://127.0.0.1:5000/leave_by_entry/${entry['entry_id']}',
    );
    try {
      final leaveResponse = await http.get(leaveUrl);
      if (leaveResponse.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This slot is no longer open.')),
          );
        }
        return;
      }
      final leaveId = jsonDecode(leaveResponse.body)['leave_id'];
      await _showAssignSubstituteDialog(
        leaveId,
        '${entry['day_of_week']} Period ${entry['period_no']}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  Future<void> _showAssignSubstituteDialog(int leaveId, String slotInfo) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/class_faculty_options/${widget.classId}',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> options = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Assign Substitute - $slotInfo'),
          content: SizedBox(
            width: double.maxFinite,
            child: options.isEmpty
                ? const Text('No faculty available.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final f = options[index];
                      final isRelated = f['is_related'] == true;
                      return ListTile(
                        title: Text(
                          f['label'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isRelated
                                ? Colors.blue.shade800
                                : Colors.grey.shade700,
                          ),
                        ),
                        subtitle: Text(f['name']),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _assignSubstitute(leaveId, f['faculty_id']);
                          },
                          child: const Text('Assign'),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _assignSubstitute(int leaveId, int facultyId) async {
    final url = Uri.parse('http://127.0.0.1:5000/invite_substitute');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'leave_id': leaveId, 'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Substitute assigned!')
                  : (data['error'] ?? 'Could not assign substitute.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  String _timeRange(dynamic entry) {
    final start = entry['start_time'];
    final end = entry['end_time'];
    if (start == null || end == null) return '';
    return '$start - $end';
  }

  /// Period card layout:
  /// [small] start–end time · Period N
  /// [bold, dark, larger] Course name
  /// [normal] Faculty name
  ///
  /// Also handles the two interactive modes: swap-mode tap-to-select, and
  /// (outside swap mode) CC tap-to-assign-substitute on a red open slot.
  Widget _buildPeriodCard(dynamic entry) {
    final tappableForSwap = _isTappable(entry);
    final isSwapped = entry['status_color'] == 'swapped';
    final isOpen = entry['status_color'] == 'open_leave';
    final ccCanAssign = !_swapMode && widget.isCC && isOpen;
    final timeRange = _timeRange(entry);
    final periodLabel = 'Period ${entry['period_no']}';

    VoidCallback? onTap;
    if (_swapMode) {
      onTap = tappableForSwap ? () => _onEntryTap(entry) : null;
    } else if (ccCanAssign) {
      onTap = () => _handleOpenSlotTap(entry);
    }

    return Opacity(
      opacity: _swapMode && !tappableForSwap && _selectedMyEntry != entry
          ? 0.4
          : 1.0,
      child: Card(
        color: _colorForEntry(entry),
        child: Stack(
          children: [
            InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeRange.isEmpty
                          ? periodLabel
                          : '$timeRange  •  $periodLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry['course_name'] ?? 'Unassigned',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ccCanAssign
                          ? '${entry['faculty_name'] ?? 'No faculty'} • Absent — tap to assign'
                          : (entry['faculty_name'] ?? 'No faculty'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSwapped)
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: entry['swap_id'] != null
                      ? 'Swapped period (pair #${entry['swap_id']})'
                      : 'Swapped period',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: entry['swap_id'] != null
                          ? Color.alphaBlend(
                              Colors.black26,
                              _colorForSwapId(entry['swap_id'] as int),
                            )
                          : Colors.blue.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.swap_horiz,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (ccCanAssign)
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: 'Tap to assign substitute',
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Break card layout — deliberately minimal, nothing period-related:
  /// [small] start–end time
  /// [bold, dark] Break name
  Widget _buildBreakCard(dynamic entry) {
    final timeRange = _timeRange(entry);
    return Card(
      color: Colors.grey.shade100,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timeRange.isNotEmpty)
              Text(
                timeRange,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            const SizedBox(height: 4),
            Text(
              entry['label'] ?? 'Break',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          IconButton(
            icon: Icon(_swapMode ? Icons.close : Icons.swap_horiz),
            tooltip: _swapMode ? 'Cancel Swap' : 'Start Swap Request',
            onPressed: () {
              setState(() {
                _swapMode = !_swapMode;
                _selectedMyEntry = null;
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _days.map((d) {
            final isToday = DateHelpers.isToday(d);
            return Tab(
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    d,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Text(
                    DateHelpers.labelForDayCode(d),
                    style: TextStyle(
                      fontSize: 10,
                      color: isToday ? Colors.blue : Colors.black54,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: Column(
        children: [
          if (_swapMode)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.all(12),
              child: Text(
                _selectedMyEntry == null
                    ? 'Tap YOUR period to give up'
                    : 'Now tap the period you want instead',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _days.map((day) {
                      final dateStr = DateHelpers.isoForDayCode(day);
                      final holidayReason = _holidayMap[dateStr];

                      final dayEntries =
                          _entries
                              .where((e) => e['day_of_week'] == day)
                              .toList()
                            ..sort(
                              (a, b) =>
                                  a['period_no'].compareTo(b['period_no']),
                            );

                      // Only show the "tap red to assign" hint on a day
                      // that actually has an open slot — not on every day
                      // regardless of whether anything's absent.
                      final hasOpenSlotToday = dayEntries.any(
                        (e) => e['status_color'] == 'open_leave',
                      );

                      Widget? holidayBanner;
                      if (holidayReason != null) {
                        holidayBanner = Container(
                          width: double.infinity,
                          color: Colors.orange.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.beach_access,
                                size: 18,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Marked as a holiday'
                                  '${holidayReason.toString().isEmpty ? '' : ': $holidayReason'}. '
                                  'Students and teaching faculty won\'t see this day\'s schedule.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      Widget? openSlotBanner;
                      if (!_swapMode && widget.isCC && hasOpenSlotToday) {
                        openSlotBanner = Container(
                          width: double.infinity,
                          color: Colors.red.shade50,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: const Text(
                            'Tap a red (open) period to assign a substitute',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }

                      if (dayEntries.isEmpty) {
                        final isSunday = day == 'SUN';
                        return Column(
                          children: [
                            if (holidayBanner != null) holidayBanner,
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isSunday) ...[
                                      const Icon(
                                        Icons.weekend,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Sunday is usually a holiday.',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.add_chart),
                                      label: Text(
                                        isSunday
                                            ? 'Add Schedule Anyway'
                                            : 'Make Schedule',
                                      ),
                                      onPressed: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ScheduleBuilderScreen(
                                                  classId: widget.classId,
                                                  className: widget.className,
                                                  dayOfWeek: day,
                                                ),
                                          ),
                                        );
                                        if (result == true) {
                                          _fetchTimetable();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          if (holidayBanner != null) holidayBanner,
                          if (openSlotBanner != null) openSlotBanner,
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: dayEntries.length,
                              itemBuilder: (context, index) {
                                final entry = dayEntries[index];
                                final isBreak = entry['entry_type'] == 'break';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: isBreak
                                      ? _buildBreakCard(entry)
                                      : _buildPeriodCard(entry),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
