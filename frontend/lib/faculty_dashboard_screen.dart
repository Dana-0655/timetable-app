import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'faculty_my_schedule_screen.dart';
import 'faculty_open_slots_screen.dart';
import 'faculty_pending_leaves_screen.dart';
import 'faculty_swap_responses_screen.dart';
import 'browse_timetables_screen.dart';
import 'admin_timetable_view_screen.dart';
import 'class_courses_screen.dart';
import 'timetable_grid_screen.dart';
import 'session_manager.dart';
import 'role_selection_screen.dart';
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await SessionManager.clearSession();
    await SessionManager.clearLastPage();
    final savedCollege = await SessionManager.getSavedCollegeCode();
    if (mounted) {
      if (savedCollege != null) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionScreen(
              collegeCode: savedCollege['code'],
              collegeId: savedCollege['collegeId'],
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _fetchRelatedClasses() async {
    if (mounted) setState(() => _isLoading = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_related_classes/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() {
          _relatedClasses = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.facultyName}'),
        actions: [
          NotificationBell(
            recipientType: 'faculty',
            recipientId: widget.facultyId,
          ),
          IconButton(
            icon: const Icon(Icons.schedule_rounded),
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
          if (!isMobile) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded),
              tooltip: 'Browse Timetables',
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
              icon: const Icon(Icons.pending_actions_rounded),
              tooltip: 'My Leaves',
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
              icon: const Icon(Icons.event_available_rounded),
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
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More Faculty Tools',
              onSelected: (val) {
                switch (val) {
                  case 'browse':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BrowseTimetablesScreen(
                          facultyId: widget.facultyId,
                          collegeId: widget.collegeId,
                        ),
                      ),
                    );
                    break;
                  case 'swaps':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacultySwapResponsesScreen(
                          facultyId: widget.facultyId,
                        ),
                      ),
                    );
                    break;
                  case 'leaves':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacultyPendingLeavesScreen(
                          facultyId: widget.facultyId,
                          collegeId: widget.collegeId,
                        ),
                      ),
                    );
                    break;
                  case 'open_slots':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacultyOpenSlotsScreen(
                          facultyId: widget.facultyId,
                          collegeId: widget.collegeId,
                        ),
                      ),
                    );
                    break;
                  case 'logout':
                    _logout();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'browse',
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 20, color: Color(0xFF1565C0)),
                      SizedBox(width: 12),
                      Text('Browse Timetables'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'swaps',
                  child: Row(
                    children: [
                      Icon(Icons.inbox_rounded, size: 20, color: Color(0xFF2E7D32)),
                      SizedBox(width: 12),
                      Text('Swap Responses'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'leaves',
                  child: Row(
                    children: [
                      Icon(Icons.pending_actions_rounded, size: 20, color: Color(0xFFEF6C00)),
                      SizedBox(width: 12),
                      Text('My Leaves'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open_slots',
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, size: 20, color: Colors.indigo),
                      SizedBox(width: 12),
                      Text('Open Slots'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
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

                        if (isMobile) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isMyCC ? Colors.purple.shade200 : Colors.grey.shade200,
                              ),
                            ),
                            color: isMyCC ? Colors.purple.shade50.withValues(alpha: 0.3) : Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AdminTimetableViewScreen(
                                    classId: cls['class_id'],
                                    className: className,
                                    collegeId: widget.collegeId,
                                    isReadOnly: !isMyCC,
                                    userRole: isMyCC ? 'cc' : 'faculty',
                                    currentFacultyId: widget.facultyId,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${cls['year']} - Section ${cls['section']}',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                cls['department'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.blueGrey.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isMyCC ? Colors.purple.shade100 : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isMyCC ? 'Class Coordinator' : 'Teaching',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isMyCC ? Colors.purple.shade900 : Colors.blue.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (isMyCC) ...[
                                      const SizedBox(height: 10),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            OutlinedButton.icon(
                                              icon: const Icon(Icons.menu_book_rounded, size: 16),
                                              label: const Text('Courses', style: TextStyle(fontSize: 12)),
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => ClassCoursesScreen(
                                                    classId: cls['class_id'],
                                                    className: className,
                                                    collegeId: widget.collegeId,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.icon(
                                              icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                                              label: const Text('Build Timetable', style: TextStyle(fontSize: 12)),
                                              onPressed: () => Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => TimetableGridScreen(
                                                    classId: cls['class_id'],
                                                    className: className,
                                                    facultyId: widget.facultyId,
                                                    collegeId: widget.collegeId,
                                                    isCC: true,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          color: isMyCC ? Colors.purple.shade50 : Colors.white,
                          child: ListTile(
                            title: Text(
                              '${cls['year']} - Section ${cls['section']}',
                            ),
                            subtitle: Text(cls['department']),
                            trailing: isMyCC
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
                                                  collegeId: widget.collegeId,
                                                  isCC: true,
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
                                  collegeId: widget.collegeId,
                                  isReadOnly: !isMyCC,
                                  userRole: isMyCC ? 'cc' : 'faculty',
                                  currentFacultyId: widget.facultyId,
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
