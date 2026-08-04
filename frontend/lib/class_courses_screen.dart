import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClassCoursesScreen extends StatefulWidget {
  final int classId;
  final String className;

  const ClassCoursesScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ClassCoursesScreen> createState() => _ClassCoursesScreenState();
}

class _ClassCoursesScreenState extends State<ClassCoursesScreen> {
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

  void _showAddCourseDialog() {
    final courseController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Course'),
        content: TextField(
          controller: courseController,
          decoration: const InputDecoration(labelText: 'Course Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addCourse(courseController.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCourse(String courseName) async {
    final url = Uri.parse('http://127.0.0.1:5000/add_course');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'class_id': widget.classId,
          'course_name': courseName,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _addTimetableEntry(data['course_id']);
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _addTimetableEntry(int courseId) async {
    final url = Uri.parse('http://127.0.0.1:5000/add_timetable_entry');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'class_id': widget.classId,
          'day_of_week': 'MON',
          'period_no': _entries.length + 1,
          'course_id': courseId,
        }),
      );
      _fetchTimetable();
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _showPendingCourseRequests(
    int courseId,
    String courseName,
  ) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/course_faculty_requests/$courseId',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> requests = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Requests - $courseName'),
          content: SizedBox(
            width: double.maxFinite,
            child: requests.isEmpty
                ? const Text('No pending requests.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return ListTile(
                        title: Text(req['faculty_name']),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () async {
                                await _resolveCourseRequest(
                                  req['cf_request_id'],
                                  'accepted',
                                );
                                if (mounted) Navigator.pop(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await _resolveCourseRequest(
                                  req['cf_request_id'],
                                  'rejected',
                                );
                                if (mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _resolveCourseRequest(int cfRequestId, String decision) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/resolve_course_faculty_request',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cf_request_id': cfRequestId, 'decision': decision}),
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
      appBar: AppBar(title: Text('${widget.className} - Courses')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
          ? const Center(child: Text('No courses yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final hasFaculty = entry['faculty_name'] != null;
                return Card(
                  child: ListTile(
                    title: Text(entry['course_name'] ?? 'Unnamed'),
                    subtitle: Text(
                      hasFaculty
                          ? 'Faculty: ${entry['faculty_name']}'
                          : 'No faculty assigned',
                    ),
                    trailing: hasFaculty
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.list_alt),
                            onPressed: () => _showPendingCourseRequests(
                              entry['course_id'],
                              entry['course_name'],
                            ),
                          ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCourseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
