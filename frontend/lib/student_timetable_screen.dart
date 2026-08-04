import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class StudentTimetableScreen extends StatefulWidget {
  final int classId;
  final String className;
  const StudentTimetableScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchTimetable();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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

  Color _getColorForStatus(String status) {
    switch (status) {
      case 'open_leave':
        return Colors.orange.shade100;
      case 'confirmed_cover':
        return Colors.green.shade100;
      case 'swapped':
        return Colors.blue.shade100;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _entries.isEmpty
          ? const Center(
              child: Text(
                'Timetable not available yet, please check back later.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return Card(
                  color: _getColorForStatus(entry['status_color']),
                  child: ListTile(
                    title: Text(
                      '${entry['day_of_week']} - Period ${entry['period_no']}',
                    ),
                    subtitle: Text(
                      '${entry['course_name'] ?? 'Unassigned'} • ${entry['faculty_name'] ?? 'No faculty'}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}
