import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'weekly_matrix_grid_widget.dart';

class TimetableGridScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int facultyId;

  const TimetableGridScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.facultyId,
  });

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  final GlobalKey _matrixKey = GlobalKey();

  Future<void> _markFullDayLeaveAndAutoAllocate() async {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final dayOfWeek = days[now.weekday - 1];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.event_busy, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text('Mark Full-Day Leave'),
          ],
        ),
        content: Text(
          'Mark leave for ALL your classes today ($dateStr, $dayOfWeek)?\n\n'
          '⚡ The Smart Engine will automatically find optimal substitute teachers for each period and notify students, covering faculty, and admins!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark & Auto-Allocate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final url = Uri.parse('http://127.0.0.1:5000/auto_allocate_day_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'leave_date': dateStr,
          'day_of_week': dayOfWeek,
        }),
      );

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚡ ${res["message"]}'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.amberAccent),
            tooltip: '1-Tap Full-Day Auto-Leave & Substitution',
            onPressed: _markFullDayLeaveAndAutoAllocate,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: WeeklyMatrixGridWidget(
          key: _matrixKey,
          classId: widget.classId,
          className: widget.className,
          userRole: 'faculty',
          currentFacultyId: widget.facultyId,
        ),
      ),
    );
  }
}
