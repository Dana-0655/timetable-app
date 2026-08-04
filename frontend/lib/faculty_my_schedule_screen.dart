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

  @override
  void initState() {
    super.initState();
    _fetchMySchedule();
  }

  // Since we don't have a direct "my schedule" API, we fetch all classes,
  // then all timetables, and filter entries where faculty_name matches.
  // For simplicity in this stage, we search across all classes in the college.
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
          if (entry['course_id'] != null) {
            entry['class_id'] = cls['class_id'];
            entry['class_name'] = '${cls['year']} - ${cls['section']}';
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
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final url = Uri.parse('http://127.0.0.1:5000/mark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'entry_id': entryId,
          'leave_date': dateStr,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule')),
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
                    title: Text(
                      '${entry['class_name']} - ${entry['course_name']}',
                    ),
                    subtitle: Text(
                      '${entry['day_of_week']} Period ${entry['period_no']}',
                    ),
                    trailing: isOpen
                        ? const Chip(label: Text('Leave Marked'))
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
