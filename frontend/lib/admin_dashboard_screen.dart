import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'class_courses_screen.dart';
import 'semester_management_screen.dart';
import 'session_manager.dart';
import 'main.dart';
import 'admin_timetable_view_screen.dart';
import 'promote_faculty_screen.dart';
import 'admin_add_faculty_screen.dart';
import 'notification_bell.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int adminId;
  final String adminName;
  final int collegeId;

  const AdminDashboardScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.collegeId,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;
  bool _hasActiveSemester = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _showInviteFacultyDialog(int classId) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_list/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> facultyList = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite Faculty as CC'),
          content: SizedBox(
            width: double.maxFinite,
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
                            await _inviteCC(classId, f['faculty_id']);
                          },
                          child: const Text('Invite'),
                        ),
                      );
                    },
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

  Future<void> _removeCC(int classId) async {
    final url = Uri.parse('http://127.0.0.1:5000/remove_cc');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId}),
      );
      if (response.statusCode == 200) {
        _fetchClasses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CC removed successfully.')),
          );
        }
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _showCCDetails(int classId) async {
    final url = Uri.parse('http://127.0.0.1:5000/cc_details/$classId');
    try {
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Class Counselor Details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(data['name']),
                  subtitle: const Text('Name'),
                ),
                ListTile(
                  leading: const Icon(Icons.email, color: Colors.blue),
                  title: Text(data['email']),
                  subtitle: const Text('Email'),
                ),
                ListTile(
                  leading: const Icon(Icons.book, color: Colors.blue),
                  title: Text(data['subject_expertise']),
                  subtitle: const Text('Subject Expertise'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(context);
                  await _removeCC(classId);
                },
                child: const Text('Remove CC'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _inviteCC(int classId, int facultyId) async {
    final url = Uri.parse('http://127.0.0.1:5000/admin_invite_cc');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId, 'faculty_id': facultyId}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
        }
      }
    } catch (e) {
      // Silently fail for now
    }
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

  void _confirmDeleteClass(int classId, String className) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Class'),
        content: Text(
          'Are you sure you want to delete "$className"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteClass(classId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClass(int classId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_class');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId}),
      );
      if (response.statusCode == 200) {
        _fetchClasses();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _showPendingRequests(int classId, String className) async {
    final url = Uri.parse('http://127.0.0.1:5000/cc_requests/$classId');

    try {
      final response = await http.get(url);
      final List<dynamic> requests = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Pending CC Requests - $className'),
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
                                await _resolveCCRequest(
                                  req['cc_request_id'],
                                  'accepted',
                                );
                                Navigator.pop(context);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () async {
                                await _resolveCCRequest(
                                  req['cc_request_id'],
                                  'rejected',
                                );
                                Navigator.pop(context);
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

  Future<void> _resolveCCRequest(int ccRequestId, String decision) async {
    final url = Uri.parse('http://127.0.0.1:5000/resolve_cc_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'cc_request_id': ccRequestId, 'decision': decision}),
      );
      if (response.statusCode == 200) {
        _fetchClasses();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);

    // Check for active semester first
    final semUrl = Uri.parse(
      'http://127.0.0.1:5000/semesters/${widget.collegeId}',
    );
    try {
      final semResponse = await http.get(semUrl);
      if (semResponse.statusCode == 200) {
        final List<dynamic> semesters = jsonDecode(semResponse.body);
        final hasActive = semesters.any((s) => s['is_active'] == true);
        setState(() => _hasActiveSemester = hasActive);
      }
    } catch (e) {
      // Silently fail for now
    }

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

  void _showAddClassDialog() {
    final yearController = TextEditingController();
    final sectionController = TextEditingController();
    final departmentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: yearController,
              decoration: const InputDecoration(
                labelText: 'Year (e.g. 2nd Year)',
              ),
            ),
            TextField(
              controller: sectionController,
              decoration: const InputDecoration(labelText: 'Section (e.g. A)'),
            ),
            TextField(
              controller: departmentController,
              decoration: const InputDecoration(
                labelText: 'Department (e.g. AIML)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _addClass(
                yearController.text,
                sectionController.text,
                departmentController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addClass(String year, String section, String department) async {
    if (year.trim().isEmpty ||
        section.trim().isEmpty ||
        department.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields.')),
        );
      }
      return;
    }

    final url = Uri.parse('http://127.0.0.1:5000/add_class');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'year': year,
          'section': section,
          'department': department,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _fetchClasses();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not add class.')),
          );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3525CD),
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: const Color(0xFF3525CD).withValues(alpha: 0.3),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${widget.adminName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'Admin Portal • Scheduling Manager',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          NotificationBell(recipientType: 'admin', recipientId: widget.adminId),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add Faculty',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminAddFacultyScreen(
                  adminId: widget.adminId,
                  collegeId: widget.collegeId,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.verified_user_rounded),
            tooltip: 'Promote Faculty',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PromoteFacultyScreen(collegeId: widget.collegeId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Manage Semesters',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SemesterManagementScreen(collegeId: widget.collegeId),
                ),
              );
              _fetchClasses();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3525CD)))
          : !_hasActiveSemester
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.calendar_month_rounded, size: 40, color: Colors.orange.shade800),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Active Semester Required',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create and activate an academic semester before configuring classes and timetables.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3525CD),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Setup Semester Now'),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SemesterManagementScreen(collegeId: widget.collegeId),
                            ),
                          );
                          _fetchClasses();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Column(
              children: [
                // Top Metrics Overview Bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      _buildMetricTile('Total Classes', '${_classes.length}', Icons.groups_rounded, Colors.indigo),
                      _buildMetricTile('Active System', 'Online', Icons.cell_tower_rounded, Colors.green),
                      _buildMetricTile('Auto-Engine', 'Active', Icons.auto_awesome_rounded, Colors.purple),
                    ],
                  ),
                ),

                // Main Classes List
                Expanded(
                  child: _classes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.class_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text('No classes added yet. Tap + to create one.', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final cls = _classes[index];
                            final hasCC = cls['cc_faculty_id'] != null;

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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3525CD).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.school_rounded, color: Color(0xFF3525CD)),
                                  ),
                                  title: Row(
                                    children: [
                                      Text(
                                        'Class ${cls['year']} - ${cls['section']}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0B1C30)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          cls['department'],
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade800),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      hasCC ? 'Class Coordinator Assigned' : 'CC Unassigned (Tap chip to invite)',
                                      style: TextStyle(fontSize: 12, color: hasCC ? Colors.green.shade800 : Colors.orange.shade800),
                                    ),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      hasCC
                                          ? ActionChip(
                                              avatar: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                                              label: const Text('CC Active'),
                                              backgroundColor: Colors.green.shade50,
                                              onPressed: () => _showCCDetails(cls['class_id']),
                                            )
                                          : ActionChip(
                                              avatar: const Icon(Icons.add_circle_outline_rounded, size: 16, color: Colors.orange),
                                              label: const Text('Assign CC'),
                                              backgroundColor: Colors.orange.shade50,
                                              onPressed: () => _showInviteFacultyDialog(cls['class_id']),
                                            ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.groups_rounded, color: Colors.indigo),
                                        tooltip: 'CC Requests',
                                        onPressed: () => _showPendingRequests(
                                          cls['class_id'],
                                          '${cls['year']} - ${cls['section']}',
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.book_rounded, color: Colors.deepPurple),
                                        tooltip: 'Manage Courses',
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ClassCoursesScreen(
                                              classId: cls['class_id'],
                                              className: '${cls['year']} - ${cls['section']}',
                                              collegeId: widget.collegeId,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        tooltip: 'Delete Class',
                                        onPressed: () => _confirmDeleteClass(
                                          cls['class_id'],
                                          '${cls['year']} - ${cls['section']}',
                                        ),
                                      ),
                                    ],
                                  ),
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
      floatingActionButton: _hasActiveSemester
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF3525CD),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Class', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _showAddClassDialog,
            )
          : null,
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
