import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'faculty_my_schedule_screen.dart';
import 'faculty_open_slots_screen.dart';
import 'faculty_pending_leaves_screen.dart';
import 'faculty_swap_responses_screen.dart';
import 'browse_timetables_screen.dart';
import 'browse_classes_screen.dart';
import 'admin_timetable_view_screen.dart';
import 'session_manager.dart';
import 'main.dart';
import 'notification_bell.dart';

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
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.facultyName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'Faculty Portal • Class Instructor',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          NotificationBell(
            recipientType: 'faculty',
            recipientId: widget.facultyId,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
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
            icon: const Icon(Icons.calendar_month_rounded),
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
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Swap Responses',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FacultySwapResponsesScreen(facultyId: widget.facultyId),
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Portal Action Grid
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      _buildQuickActionTile(
                        'My Schedule',
                        Icons.schedule_rounded,
                        Colors.indigo,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FacultyMyScheduleScreen(
                              facultyId: widget.facultyId,
                              collegeId: widget.collegeId,
                            ),
                          ),
                        ),
                      ),
                      _buildQuickActionTile(
                        'Browse Timetables',
                        Icons.calendar_view_week_rounded,
                        Colors.deepPurple,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BrowseTimetablesScreen(
                              facultyId: widget.facultyId,
                              collegeId: widget.collegeId,
                            ),
                          ),
                        ),
                      ),
                      _buildQuickActionTile(
                        'Leave Requests',
                        Icons.pending_actions_rounded,
                        Colors.amber.shade900,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FacultyPendingLeavesScreen(
                              facultyId: widget.facultyId,
                              collegeId: widget.collegeId,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Section Title
                const Padding(
                  padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 10),
                  child: Text(
                    'Assigned & Coordinated Classes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B1C30),
                    ),
                  ),
                ),

                // Related Classes List
                Expanded(
                  child: _relatedClasses.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'You are not linked to any class yet.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Tap the search icon in the top header to browse and request course assignment.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _relatedClasses.length,
                          itemBuilder: (context, index) {
                            final cls = _relatedClasses[index];
                            final isMyCC = cls['cc_faculty_id'] == widget.facultyId;

                            return TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: Duration(milliseconds: 300 + (index * 100)),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey.shade200),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(16),
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isMyCC
                                          ? Colors.amber.shade100
                                          : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isMyCC ? Icons.stars_rounded : Icons.menu_book_rounded,
                                      color: isMyCC ? Colors.amber.shade900 : const Color(0xFF0EA5E9),
                                    ),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        'Class ${cls['year']} - Section ${cls['section']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0B1C30),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          cls['department'],
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      isMyCC
                                          ? 'Class Coordinator • Full Matrix Permissions'
                                          : 'Subject Teacher',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isMyCC ? Colors.amber.shade900 : Colors.grey.shade700,
                                        fontWeight: isMyCC ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  trailing: isMyCC
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'CC Manager',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade900,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdminTimetableViewScreen(
                                        classId: cls['class_id'],
                                        className: '${cls['year']} - ${cls['section']}',
                                      ),
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
    );
  }

  Widget _buildQuickActionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
