import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';
import 'date_helpers.dart';

class AdminTimetableViewScreen extends StatefulWidget {
  final int classId;
  final String className;
  final bool isReadOnly;

  const AdminTimetableViewScreen({
    super.key,
    required this.classId,
    required this.className,
    this.isReadOnly = false,
  });

  @override
  State<AdminTimetableViewScreen> createState() =>
      _AdminTimetableViewScreenState();
}

class _AdminTimetableViewScreenState extends State<AdminTimetableViewScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  Map<String, dynamic> _holidayMap = {}; // "YYYY-MM-DD" -> reason

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final todayCode =
        DateHelpers.weekDayCodes[DateTime.now().weekday - 1]; // may be 'SUN'
    var initialIndex = _days.indexOf(todayCode);
    if (initialIndex == -1) initialIndex = 0; // Sunday -> default to Monday
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

  Future<void> _showCourseInfo(int courseId) async {
    final url = Uri.parse('http://127.0.0.1:5000/course_detail/$courseId');
    try {
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final faculty = data['faculty'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(data['course_name']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course Code: ${data['course_code']}'),
                const SizedBox(height: 12),
                if (faculty != null) ...[
                  const Text(
                    'Faculty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Name: ${faculty['name']}'),
                  Text('Email: ${faculty['email']}'),
                  Text('Expertise: ${faculty['subject_expertise']}'),
                ] else
                  const Text('No faculty assigned yet.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  static const List<Color> _swapPalette = [
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFF8BBD0),
    Color(0xFFD1C4E9),
    Color(0xFFFFCCBC),
    Color(0xFFB2DFDB),
    Color(0xFFDCEDC8),
  ];

  Color _colorForSwapId(int swapId) {
    return _swapPalette[swapId % _swapPalette.length];
  }

  Color _colorForEntry(dynamic entry) {
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

  void _confirmDeleteSlot(int entryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text('Are you sure you want to delete this slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSlot(entryId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSlot(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_timetable_entry');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'entry_id': entryId}),
      );
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  void _confirmDeleteDay(String day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $day Schedule'),
        content: Text(
          'This will delete ALL periods and breaks for $day. Are you sure?',
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
              await _deleteDay(day);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDay(String day) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_day_schedule');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': widget.classId, 'day_of_week': day}),
      );
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - Timetable'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _days.map((d) {
            final isToday = DateHelpers.isToday(d);
            return Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    d,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                  Text(
                    DateHelpers.labelForDayCode(d),
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) {
                final dateStr = DateHelpers.isoForDayCode(day);
                final holidayReason = _holidayMap[dateStr];

                // Read-only viewers: a marked holiday fully replaces the
                // schedule for this date, even if periods exist.
                if (holidayReason != null && widget.isReadOnly) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.beach_access,
                            size: 48,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Holiday',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            holidayReason.toString().isEmpty
                                ? 'No classes today.'
                                : holidayReason.toString(),
                            style: const TextStyle(color: Colors.black54),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final dayEntries =
                    _entries.where((e) => e['day_of_week'] == day).toList()
                      ..sort(
                        (a, b) => a['period_no'].compareTo(b['period_no']),
                      );

                if (dayEntries.isEmpty) {
                  final isSunday = day == 'SUN';

                  if (widget.isReadOnly) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSunday ? Icons.weekend : Icons.event_busy,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isSunday
                                  ? 'Sunday - Holiday'
                                  : 'No schedule set for this day yet.',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (isSunday) ...[
                              const SizedBox(height: 6),
                              const Text(
                                'No classes scheduled today.',
                                style: TextStyle(color: Colors.black54),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return Center(
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
                            isSunday ? 'Add Schedule Anyway' : 'Make Schedule',
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScheduleBuilderScreen(
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
                  );
                }

                return Column(
                  children: [
                    if (holidayReason != null)
                      Container(
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
                      ),
                    if (!widget.isReadOnly)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete Day Schedule',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () => _confirmDeleteDay(day),
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: dayEntries.length,
                        itemBuilder: (context, index) {
                          final entry = dayEntries[index];
                          final isBreakEntry = entry['entry_type'] == 'break';
                          final isFilled = isBreakEntry
                              ? entry['label'] != null
                              : entry['course_name'] != null;

                          return Card(
                            color: isBreakEntry
                                ? Colors.grey.shade200
                                : _colorForEntry(entry),
                            child: ListTile(
                              leading: Icon(
                                isBreakEntry
                                    ? Icons.free_breakfast
                                    : Icons.book,
                              ),
                              title: Text(
                                isBreakEntry
                                    ? (entry['label'] ??
                                          'Break (tap to set up)')
                                    : (entry['course_name'] ??
                                          'Period ${entry['period_no']} (tap to set up)'),
                              ),
                              subtitle: Text(
                                isFilled
                                    ? '${entry['start_time'] ?? ''} - ${entry['end_time'] ?? ''}'
                                          '${!isBreakEntry ? ' • ${entry['faculty_name'] ?? 'No faculty assigned'}' : ''}'
                                    : (widget.isReadOnly
                                          ? 'Not scheduled'
                                          : 'Tap to fill in details'),
                              ),
                              trailing: widget.isReadOnly
                                  ? (isFilled && !isBreakEntry
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.info_outline,
                                              size: 20,
                                            ),
                                            onPressed: () => _showCourseInfo(
                                              entry['course_id'],
                                            ),
                                          )
                                        : null)
                                  : isFilled
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 20,
                                          ),
                                          onPressed: () async {
                                            final result = await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    FillSlotScreen(
                                                      entryId:
                                                          entry['entry_id'],
                                                      entryType:
                                                          entry['entry_type'],
                                                      isEdit: true,
                                                      existingCourseName:
                                                          entry['course_name'],
                                                      existingLabel:
                                                          entry['label'],
                                                      existingStartTime:
                                                          entry['start_time'],
                                                      existingEndTime:
                                                          entry['end_time'],
                                                    ),
                                              ),
                                            );
                                            if (result == true)
                                              _fetchTimetable();
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            size: 20,
                                            color: Colors.red,
                                          ),
                                          onPressed: () => _confirmDeleteSlot(
                                            entry['entry_id'],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Icon(Icons.edit),
                              onTap: widget.isReadOnly || isFilled
                                  ? null
                                  : () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FillSlotScreen(
                                            entryId: entry['entry_id'],
                                            entryType: entry['entry_type'],
                                          ),
                                        ),
                                      );
                                      if (result == true) _fetchTimetable();
                                    },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
