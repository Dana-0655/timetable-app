import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';
import 'date_helpers.dart';
import 'weekly_matrix_grid_widget.dart';
import 'session_manager.dart';
import 'admin_timetable_upload_screen.dart';

class AdminTimetableViewScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int collegeId;
  final bool isReadOnly;

  const AdminTimetableViewScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.collegeId,
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
  bool _isGridView = false;
  Map<String, dynamic> _holidayMap = {}; // "YYYY-MM-DD" -> {holiday_id, reason}

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
    _loadSavedViewMode();
    _fetchTimetable();
    _fetchHolidays();
  }

  Future<void> _loadSavedViewMode() async {
    final saved2D = await SessionManager.getPreferredViewMode('admin');
    if (mounted) {
      setState(() {
        _isGridView = saved2D;
      });
    }
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

  String _timeRange(dynamic entry) {
    final start = entry['start_time'];
    final end = entry['end_time'];
    if (start == null || end == null) return '';
    return '$start - $end';
  }

  Widget _buildPeriodCard(dynamic entry) {
    final isFilled = entry['course_name'] != null;
    final timeRange = _timeRange(entry);
    final periodLabel = 'Period ${entry['period_no']}';

    return Card(
      color: _colorForEntry(entry),
      child: InkWell(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
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
                      entry['course_name'] ??
                          'Period ${entry['period_no']} (tap to set up)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isFilled
                          ? (entry['faculty_name'] ?? 'No faculty assigned')
                          : (widget.isReadOnly
                                ? 'Not scheduled'
                                : 'Tap to fill in details'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isReadOnly)
                if (isFilled && entry['course_id'] != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    onPressed: () => _showCourseInfo(entry['course_id']),
                  )
                else
                  const SizedBox.shrink()
              else if (isFilled)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FillSlotScreen(
                              entryId: entry['entry_id'],
                              entryType: entry['entry_type'],
                              isEdit: true,
                              existingCourseName: entry['course_name'],
                              existingLabel: entry['label'],
                              existingStartTime: entry['start_time'],
                              existingEndTime: entry['end_time'],
                            ),
                          ),
                        );
                        if (result == true) _fetchTimetable();
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red,
                      ),
                      onPressed: () => _confirmDeleteSlot(entry['entry_id']),
                    ),
                  ],
                )
              else
                const Icon(Icons.edit, size: 20, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }

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
        title: Text('${widget.className} - Timetable'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_agenda : Icons.grid_view),
            tooltip: _isGridView
                ? 'Switch to List View'
                : 'Switch to Grid View',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
              SessionManager.savePreferredViewMode('admin', _isGridView);
            },
          ),
        ],
        bottom: _isGridView
            ? null
            : TabBar(
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
          : _isGridView
          ? WeeklyMatrixGridWidget(
              classId: widget.classId,
              className: widget.className,
              userRole: 'admin',
              currentFacultyId: 0,
            )
          : TabBarView(
              controller: _tabController,
              children: _days.map((day) {
                final dateStr = DateHelpers.isoForDayCode(day);
                final holidayInfo = _holidayMap[dateStr] as Map?;
                final holidayReason = holidayInfo?['reason'];
                final holidayId = holidayInfo?['holiday_id'];

                if (holidayInfo != null && widget.isReadOnly) {
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
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                          ),
                          label: const Text('Auto-Generate (Upload Excel)'),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Auto-Generate Timetable'),
                                content: const Text(
                                  'Auto-generation schedules all classes in the semester at once using the CP-SAT solver. Proceed to the upload screen?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Click the ✨ icon in the top right to start Auto-Generation.',
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('Go to Uploader'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.beach_access, size: 18),
                          label: const Text('Mark Holiday'),
                          onPressed: () => _confirmMarkHoliday(day),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    if (holidayInfo != null)
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
                          child: Wrap(
                            spacing: 8,
                            children: [
                              if (holidayInfo != null)
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.wb_sunny,
                                    color: Colors.orange,
                                  ),
                                  label: const Text(
                                    'Remove Holiday',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                  onPressed: () => _confirmUnmarkHoliday(
                                    holidayId as int,
                                    day,
                                  ),
                                )
                              else
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.beach_access,
                                    color: Colors.orange,
                                  ),
                                  label: const Text(
                                    'Mark Holiday',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                  onPressed: () => _confirmMarkHoliday(day),
                                ),
                              TextButton.icon(
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
                            ],
                          ),
                        ),
                      ),
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
    );
  }
}
