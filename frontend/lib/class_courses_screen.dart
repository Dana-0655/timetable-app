import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ClassCoursesScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int collegeId;
  // If the viewer already has a known faculty_id (e.g. a Faculty-login CC
  // viewing their own class), pass it here and self-assign uses it directly.
  final int? selfFacultyId;
  // If the viewer is an Admin who may or may not have a linked faculty
  // record yet, pass their admin_id here — self-assign will create a
  // faculty record for them automatically if needed.
  final int? selfAdminId;

  const ClassCoursesScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.collegeId,
    this.selfFacultyId,
    this.selfAdminId,
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

  bool get _canSelfAssign =>
      widget.selfFacultyId != null || widget.selfAdminId != null;

  Future<void> _showInviteCourseFacultyDialog(int courseId, int classId) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_list/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> rawFacultyList = jsonDecode(response.body);
      // Don't show the viewer's own linked faculty identity in the invite
      // list — the "Assign myself" button above already covers that.
      final List<dynamic> facultyList = rawFacultyList
          .where((f) => f['faculty_id'] != widget.selfFacultyId)
          .toList();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite Faculty to Teach'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_canSelfAssign) ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('Assign myself to teach this course'),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _selfAssignCourseFaculty(courseId);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                ],
                Flexible(
                  child: facultyList.isEmpty
                      ? const Text('No faculty available.')
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: facultyList.length,
                          itemBuilder: (context, index) {
                            final f = facultyList[index];
                            return ListTile(
                              title: Text(f['name']),
                              subtitle: Text(f['email']),
                              trailing: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  await _inviteCourseFaculty(
                                    courseId,
                                    f['faculty_id'],
                                  );
                                },
                                child: const Text('Invite'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _selfAssignCourseFaculty(int courseId) async {
    int? facultyId = widget.selfFacultyId;

    // No known faculty_id yet — ensure one exists (creating it if this
    // admin has never had a faculty record) before assigning.
    if (facultyId == null && widget.selfAdminId != null) {
      final ensureUrl = Uri.parse(
        'http://127.0.0.1:5000/admin_ensure_faculty_identity',
      );
      try {
        final ensureResponse = await http.post(
          ensureUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'admin_id': widget.selfAdminId}),
        );
        if (ensureResponse.statusCode == 200) {
          facultyId = jsonDecode(ensureResponse.body)['faculty_id'] as int;
        }
      } catch (e) {
        // Silently fail for now
      }
    }

    if (facultyId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not set up your faculty profile.'),
          ),
        );
      }
      return;
    }

    final url = Uri.parse(
      'http://127.0.0.1:5000/admin_self_assign_course_faculty',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'course_id': courseId, 'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? data['error'] ?? 'Done')),
        );
      }
      _fetchTimetable();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  Future<void> _inviteCourseFaculty(int courseId, int facultyId) async {
    final url = Uri.parse('http://127.0.0.1:5000/admin_invite_course_faculty');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'course_id': courseId, 'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Invitation sent!')
                  : (data['error'] ?? 'Could not send invitation.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
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
                  'No courses yet. Go to the class Timetable and use "Make Schedule" to add periods and course details.',
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Course Info',
                          onPressed: () => _showCourseInfo(entry['course_id']),
                        ),
                        hasFaculty
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.list_alt),
                                    tooltip: 'Pending Requests',
                                    onPressed: () => _showPendingCourseRequests(
                                      entry['course_id'],
                                      entry['course_name'],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.person_add_alt),
                                    tooltip: 'Invite Faculty',
                                    onPressed: () =>
                                        _showInviteCourseFacultyDialog(
                                          entry['course_id'],
                                          widget.classId,
                                        ),
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
