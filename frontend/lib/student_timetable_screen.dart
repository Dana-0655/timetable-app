import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'date_helpers.dart';
import 'class_info_dialog.dart';
import 'weekly_matrix_grid_widget.dart';
import 'session_manager.dart';

class StudentTimetableScreen extends StatefulWidget {
  final int classId;
  final String className; // e.g. "2nd - AIML - A" (year - department - section)

  const StudentTimetableScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _entries = [];
  List<dynamic> _updates = [];
  bool _isLoading = true;
  bool _is2DView = false;
  String? _errorMessage;

  Timer? _refreshTimer;

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  late final TabController _tabController;

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

    _loadSavedViewMode();
    _fetchTimetable();
    _fetchUpdates();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchTimetable();
      _fetchUpdates();
    });
  }

  Future<void> _loadSavedViewMode() async {
    final saved2D = await SessionManager.getPreferredViewMode('student');
    if (mounted) {
      setState(() {
        _is2DView = saved2D;
      });
    }
  }


  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUpdates() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/class_updates/${widget.classId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _updates = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  IconData _iconForUpdate(String type) {
    switch (type) {
      case 'substitute_confirmed':
        return Icons.event_available;
      case 'free_period':
        return Icons.free_breakfast;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForUpdate(String type) {
    switch (type) {
      case 'substitute_confirmed':
        return Colors.green;
      case 'free_period':
        return Colors.orange;
      case 'swap':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showUpdatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recent Updates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _updates.isEmpty
                  ? const Center(child: Text('No recent updates.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final u = _updates[index];
                        return ListTile(
                          leading: Icon(
                            _iconForUpdate(u['type']),
                            color: _colorForUpdate(u['type']),
                          ),
                          title: Text(u['message']),
                          subtitle: Text(u['created_at']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchTimetable() async {
    final url = Uri.parse('http://127.0.0.1:5000/timetable/${widget.classId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _entries = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Could not load timetable.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
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

  Color _colorForEntry(dynamic entry) {
    switch (entry['status_color']) {
      case 'open_leave':
        return Colors.red.shade100;
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
  Widget _buildPeriodCard(dynamic entry) {
    final isSwapped = entry['status_color'] == 'swapped';
    final timeRange = _timeRange(entry);
    final periodLabel = 'Period ${entry['period_no']}';

    return Card(
      color: _colorForEntry(entry),
      child: Stack(
        children: [
          Padding(
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
                        entry['course_name'] ?? 'Unassigned',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry['faculty_name'] ?? 'No faculty',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry['course_id'] != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => _showCourseInfo(entry['course_id']),
                  ),
              ],
            ),
          ),
          if (isSwapped)
            Positioned(
              top: 6,
              right: 6,
              child: Tooltip(
                message: 'Swapped period',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
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
        title: Text(
          widget.className,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: _is2DView
            ? null
            : TabBar(
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
        actions: [
          IconButton(
            icon: Icon(_is2DView ? Icons.view_agenda : Icons.grid_view),
            tooltip: _is2DView ? 'Switch to Daily View' : 'Switch to 2D Matrix Grid',
            onPressed: () {
              setState(() {
                _is2DView = !_is2DView;
              });
              SessionManager.savePreferredViewMode('student', _is2DView);
            },

          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Class Details',
            onPressed: () => showClassInfoDialog(
              context,
              classId: widget.classId,
              className: widget.className,
              canEdit: false, // students are always read-only
            ),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Recent Updates',
                onPressed: _showUpdatesSheet,
              ),
              if (_updates.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_updates.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _is2DView
          ? WeeklyMatrixGridWidget(
              classId: widget.classId,
              className: widget.className,
              userRole: 'student',
              currentFacultyId: 0,
            )
          : TabBarView(

              controller: _tabController,
              children: _days.map((day) {
                final dayEntries =
                    _entries.where((e) => e['day_of_week'] == day).toList()
                      ..sort(
                        (a, b) => a['period_no'].compareTo(b['period_no']),
                      );

                if (dayEntries.isEmpty) {
                  final isSunday = day == 'SUN';
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
                                : 'Timetable not available yet.',
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
                          ] else ...[
                            const SizedBox(height: 6),
                            const Text(
                              'Please check back later.',
                              style: TextStyle(color: Colors.black54),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
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
                );
              }).toList(),
            ),
    );
  }
}
