import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyMyScheduleScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const FacultyMyScheduleScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<FacultyMyScheduleScreen> createState() =>
      _FacultyMyScheduleScreenState();
}

class _FacultyMyScheduleScreenState extends State<FacultyMyScheduleScreen> {
  List<dynamic> _myEntries = [];
  bool _isLoading = true;
  bool _isMarkingDayLeave = false;

  static const TextStyle classHighlightStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A237E), // dark indigo
  );

  static const List<String> _weekDayCodes = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  String get _todayCode => _weekDayCodes[DateTime.now().weekday - 1];

  String get _todayDateStr {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchMySchedule();
  }

  // Since we don't have a direct "my schedule" API, we fetch all classes,
  // then all timetables, and filter entries where faculty_id matches this
  // faculty specifically - not just any entry with a course assigned.
  Future<void> _fetchMySchedule() async {
    setState(() => _isLoading = true);
    List<dynamic> allEntries = [];

    try {
      final classesUrl = Uri.parse(
        'http://127.0.0.1:5000/classes/${widget.collegeId}',
      );
      final classesResponse = await http.get(classesUrl);
      final classes = jsonDecode(classesResponse.body);

      for (var cls in classes) {
        final ttUrl = Uri.parse(
          'http://127.0.0.1:5000/timetable/${cls['class_id']}',
        );
        final ttResponse = await http.get(ttUrl);
        final entries = jsonDecode(ttResponse.body);

        for (var entry in entries) {
          // Only periods this specific faculty actually teaches - not
          // every filled period in the class.
          if (entry['course_id'] != null &&
              entry['faculty_id'] == widget.facultyId) {
            entry['class_id'] = cls['class_id'];
            entry['class_name'] =
                '${cls['year']} - ${cls['department']} - ${cls['section']}';
            allEntries.add(entry);
          }
        }
      }

      setState(() {
        _myEntries = allEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markLeave(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/mark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'entry_id': entryId,
          'leave_date': _todayDateStr,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave marked! Slot highlighted for others.'),
            ),
          );
        }
        _fetchMySchedule();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  Future<void> _unmarkLeave(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/unmark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'faculty_id': widget.facultyId, 'entry_id': entryId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Leave unmarked.')
                  : (data['error'] ?? 'Could not unmark leave.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
        _fetchMySchedule();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  void _confirmMarkFullDayLeave() {
    if (_todayCode == 'SUN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No classes scheduled for Sunday.')),
      );
      return;
    }

    final todaysCount = _myEntries
        .where((e) => e['day_of_week'] == _todayCode)
        .length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Full Day Leave'),
        content: Text(
          todaysCount == 0
              ? 'You have no periods scheduled today ($_todayCode).'
              : 'Mark all $todaysCount of your periods today ($_todayCode) as '
                    'leave? Each will open up for a substitute to volunteer, '
                    'and you can still send swap requests for any of them '
                    'individually if you\'d rather trade than leave it open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (todaysCount > 0)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _markFullDayLeave();
              },
              child: const Text('Mark Full Day Leave'),
            ),
        ],
      ),
    );
  }

  Future<void> _markFullDayLeave() async {
    setState(() => _isMarkingDayLeave = true);
    final url = Uri.parse('http://127.0.0.1:5000/mark_day_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'leave_date': _todayDateStr,
          'day_of_week': _todayCode,
        }),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Full day leave marked.')),
        );
      }
      _fetchMySchedule();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
    setState(() => _isMarkingDayLeave = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        actions: [
          IconButton(
            icon: _isMarkingDayLeave
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.event_busy),
            tooltip: 'Mark Full Day Leave',
            onPressed: _isMarkingDayLeave ? null : _confirmMarkFullDayLeave,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myEntries.isEmpty
          ? const Center(child: Text('No classes assigned to you yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myEntries.length,
              itemBuilder: (context, index) {
                final entry = _myEntries[index];
                final isOpen = entry['status_color'] == 'open_leave';
                return Card(
                  color: isOpen ? Colors.orange.shade50 : null,
                  child: ListTile(
                    title: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: entry['class_name'],
                            style: classHighlightStyle,
                          ),
                          TextSpan(text: ' - ${entry['course_name']}'),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      '${entry['day_of_week']} Period ${entry['period_no']}',
                    ),
                    trailing: isOpen
                        ? TextButton(
                            onPressed: () => _unmarkLeave(entry['entry_id']),
                            child: const Text('Unmark Leave'),
                          )
                        : TextButton(
                            onPressed: () => _markLeave(entry['entry_id']),
                            child: const Text('Mark Leave'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
