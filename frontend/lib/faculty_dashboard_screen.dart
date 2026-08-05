import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'faculty_class_courses_screen.dart';
import 'faculty_my_schedule_screen.dart';
import 'faculty_open_slots_screen.dart';
import 'faculty_pending_leaves_screen.dart';
import 'faculty_swap_responses_screen.dart';
import 'browse_timetables_screen.dart';
import 'session_manager.dart';
import 'main.dart';

class FacultyDashboardScreen extends StatefulWidget {
  final int facultyId;
  final String facultyName;
  final int collegeId;

  const FacultyDashboardScreen({
    super.key,
    required this.facultyId,
    required this.facultyName,
    required this.collegeId,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/classes/${widget.collegeId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _classes = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCCRequest(int classId) async {
    final url = Uri.parse('http://127.0.0.1:5000/request_cc');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId, 'faculty_id': widget.facultyId}),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CC request sent!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send request.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to server.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.facultyName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule),
            tooltip: 'My Schedule',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FacultyMyScheduleScreen(
                  facultyId: widget.facultyId,
                  collegeId: widget.collegeId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            tooltip: 'Browse Timetables / Swap',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrowseTimetablesScreen(
                  facultyId: widget.facultyId,
                  collegeId: widget.collegeId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.inbox),
            tooltip: 'Swap Responses',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FacultySwapResponsesScreen(facultyId: widget.facultyId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.pending_actions),
            tooltip: 'My Leave Requests',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FacultyPendingLeavesScreen(
                  facultyId: widget.facultyId,
                  collegeId: widget.collegeId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.event_available),
            tooltip: 'Open Slots',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FacultyOpenSlotsScreen(
                  facultyId: widget.facultyId,
                  collegeId: widget.collegeId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? const Center(child: Text('No classes available yet.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Classes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _classes.length,
                      itemBuilder: (context, index) {
                        final cls = _classes[index];
                        final hasCC = cls['cc_faculty_id'] != null;
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${cls['year']} - Section ${cls['section']}',
                            ),
                            subtitle: Text(cls['department']),
                            trailing: hasCC
                                ? const Chip(label: Text('CC Assigned'))
                                : ElevatedButton(
                                    onPressed: () =>
                                        _sendCCRequest(cls['class_id']),
                                    child: const Text('Request CC'),
                                  ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FacultyClassCoursesScreen(
                                  classId: cls['class_id'],
                                  className:
                                      '${cls['year']} - ${cls['section']}',
                                  facultyId: widget.facultyId,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
