import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'schedule_builder_screen.dart';
import 'date_helpers.dart';

class TimetableGridScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int facultyId;
  final int collegeId;
  final bool isCC;

  const TimetableGridScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.facultyId,
    required this.collegeId,
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

  void _confirmMarkHoliday(String day) {
    final dateStr = DateHelpers.isoForDayCode(day);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Holiday'),
        content: Text(
          'Mark $day ($dateStr) as a holiday? The schedule for this date '
          'will be hidden from students and teaching faculty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markHoliday(dateStr);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _markHoliday(String dateStr) async {
    final url = Uri.parse('http://127.0.0.1:5000/mark_holiday');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'college_id': widget.collegeId,
          'holiday_date': dateStr,
        }),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Holiday marked!')
                  : (data['error'] ?? 'Could not mark holiday.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) _fetchHolidays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  void _confirmUnmarkHoliday(int holidayId, String day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Holiday'),
        content: Text(
          'Unmark $day as a holiday? The schedule will show again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _unmarkHoliday(holidayId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _unmarkHoliday(int holidayId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_holiday');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'holiday_id': holidayId}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Holiday removed.')));
        }
        _fetchHolidays();
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
        return Colors.orange.shade100;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
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
                      final holidayInfo = _holidayMap[dateStr] as Map?;
                      final holidayReason = holidayInfo?['reason'];
                      final holidayId = holidayInfo?['holiday_id'];

                      final dayEntries =
                          _entries
                              .where((e) => e['day_of_week'] == day)
                              .toList()
                            ..sort(
                              (a, b) =>
                                  a['period_no'].compareTo(b['period_no']),
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
                                      Text(
                                        widget.isCC
                                            ? 'Sunday is usually a holiday.'
                                            : 'Sunday - Holiday',
                                        style: const TextStyle(
                                          color: Colors.black54,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                    ] else if (!widget.isCC) ...[
                                      const Icon(
                                        Icons.event_busy,
                                        size: 40,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No schedule set for this day yet.',
                                        style: TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                    // Only CC can build the schedule from
                                    // here - teaching faculty using this
                                    // screen just to swap don't get this.
                                    if (widget.isCC) ...[
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
                                      const SizedBox(height: 12),
                                      if (holidayId != null)
                                        OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.wb_sunny,
                                            size: 18,
                                          ),
                                          label: const Text('Remove Holiday'),
                                          onPressed: () =>
                                              _confirmUnmarkHoliday(
                                                holidayId as int,
                                                day,
                                              ),
                                        )
                                      else
                                        OutlinedButton.icon(
                                          icon: const Icon(
                                            Icons.beach_access,
                                            size: 18,
                                          ),
                                          label: const Text('Mark Holiday'),
                                          onPressed: () =>
                                              _confirmMarkHoliday(day),
                                        ),
                                    ],
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
                          if (widget.isCC)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: holidayId != null
                                    ? TextButton.icon(
                                        icon: const Icon(
                                          Icons.wb_sunny,
                                          color: Colors.orange,
                                        ),
                                        label: const Text(
                                          'Remove Holiday',
                                          style: TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                        onPressed: () => _confirmUnmarkHoliday(
                                          holidayId as int,
                                          day,
                                        ),
                                      )
                                    : TextButton.icon(
                                        icon: const Icon(
                                          Icons.beach_access,
                                          color: Colors.orange,
                                        ),
                                        label: const Text(
                                          'Mark Holiday',
                                          style: TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                        onPressed: () =>
                                            _confirmMarkHoliday(day),
                                      ),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: dayEntries.length,
                              itemBuilder: (context, index) {
                                final entry = dayEntries[index];
                                final tappable = _isTappable(entry);
                                final isSwapped =
                                    entry['status_color'] == 'swapped';
                                return Opacity(
                                  opacity:
                                      _swapMode &&
                                          !tappable &&
                                          _selectedMyEntry != entry
                                      ? 0.4
                                      : 1.0,
                                  child: Card(
                                    color: _colorForEntry(entry),
                                    child: Stack(
                                      children: [
                                        ListTile(
                                          title: Text(
                                            'Period ${entry['period_no']}',
                                          ),
                                          subtitle: Text(
                                            '${entry['course_name'] ?? 'Unassigned'} • '
                                            '${entry['faculty_name'] ?? 'No faculty'}',
                                          ),
                                          onTap: tappable
                                              ? () => _onEntryTap(entry)
                                              : null,
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
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      entry['swap_id'] != null
                                                      ? Color.alphaBlend(
                                                          Colors.black26,
                                                          _colorForSwapId(
                                                            entry['swap_id']
                                                                as int,
                                                          ),
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
                                      ],
                                    ),
                                  ),
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
