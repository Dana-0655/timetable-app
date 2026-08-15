import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyClassCoursesScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int facultyId;

  const FacultyClassCoursesScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.facultyId,
  });

  @override
  State<FacultyClassCoursesScreen> createState() =>
      _FacultyClassCoursesScreenState();
}

class _FacultyClassCoursesScreenState extends State<FacultyClassCoursesScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
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

  Future<void> _requestCourse(int courseId) async {
    final url = Uri.parse('http://127.0.0.1:5000/request_course_faculty');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'course_id': courseId,
          'faculty_id': widget.facultyId,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request sent!')));
        }
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
    // The timetable endpoint returns one row per period slot (including
    // breaks and empty periods), and the same course repeats across every
    // day/period it's scheduled. Filter down to one row per real, named
    // course - same fix applied in ClassCoursesScreen.
    final namedEntries = <dynamic>[];
    final seenCourseIds = <int>{};
    for (var e in _entries) {
      if (e['course_name'] != null && !seenCourseIds.contains(e['course_id'])) {
        namedEntries.add(e);
        seenCourseIds.add(e['course_id']);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text('${widget.className} - Courses')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : namedEntries.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No courses yet. The CC or Admin needs to build the '
                  'timetable for this class first.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: namedEntries.length,
              itemBuilder: (context, index) {
                final entry = namedEntries[index];
                final hasFaculty = entry['faculty_name'] != null;
                return Card(
                  child: ListTile(
                    title: Text(entry['course_name']),
                    subtitle: Text(
                      hasFaculty
                          ? 'Faculty: ${entry['faculty_name']}'
                          : 'No faculty assigned',
                    ),
                    trailing: hasFaculty
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () => _requestCourse(entry['course_id']),
                            child: const Text('Request'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
