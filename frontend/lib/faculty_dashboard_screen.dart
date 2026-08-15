import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'faculty_my_schedule_screen.dart';
import 'faculty_open_slots_screen.dart';
import 'faculty_pending_leaves_screen.dart';
import 'browse_timetables_screen.dart';
import 'browse_classes_screen.dart';
import 'admin_timetable_view_screen.dart';
import 'class_courses_screen.dart';
import 'timetable_grid_screen.dart';
import 'session_manager.dart';
import 'main.dart';
import 'notification_bell.dart';
import 'swap_inbox_icon.dart';

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
  List<dynamic> _relatedClasses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRelatedClasses();
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

  Future<void> _fetchRelatedClasses() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_related_classes/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _relatedClasses = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.facultyName}'),
        actions: [
          NotificationBell(
            recipientType: 'faculty',
            recipientId: widget.facultyId,
          ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Browse Classes',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BrowseClassesScreen(
                    facultyId: widget.facultyId,
                    collegeId: widget.collegeId,
                  ),
                ),
              );
              _fetchRelatedClasses();
            },
          ),
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
          SwapInboxIcon(facultyId: widget.facultyId),
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
          : _relatedClasses.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You are not linked to any class yet.\nTap the search icon to browse and request a class.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'My Classes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _relatedClasses.length,
                      itemBuilder: (context, index) {
                        final cls = _relatedClasses[index];
                        final isMyCC = cls['cc_faculty_id'] == widget.facultyId;
                        final className = '${cls['year']} - ${cls['section']}';
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${cls['year']} - Section ${cls['section']}',
                            ),
                            subtitle: Text(cls['department']),
                            trailing: isMyCC
                                // CC gets real management actions, not just a label
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Chip(label: Text('CC')),
                                      IconButton(
                                        icon: const Icon(Icons.menu_book),
                                        tooltip: 'Manage Courses',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ClassCoursesScreen(
                                                  classId: cls['class_id'],
                                                  className: className,
                                                  collegeId: widget.collegeId,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_calendar),
                                        tooltip: 'Build Timetable',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TimetableGridScreen(
                                                  classId: cls['class_id'],
                                                  className: className,
                                                  facultyId: widget.facultyId,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : const Chip(label: Text('Teaching')),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminTimetableViewScreen(
                                  classId: cls['class_id'],
                                  className: className,
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
