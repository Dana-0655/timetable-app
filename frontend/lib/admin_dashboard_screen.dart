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
      appBar: AppBar(
        title: Text('Welcome, ${widget.adminName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
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
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Give Admin Access',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    PromoteFacultyScreen(collegeId: widget.collegeId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Manage Semesters',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      SemesterManagementScreen(collegeId: widget.collegeId),
                ),
              );
              _fetchClasses(); // Refresh class list after returning (in case semester was switched)
            },
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
          : !_hasActiveSemester
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 48,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Create a semester first',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Classes belong to a semester. Set one up before adding classes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SemesterManagementScreen(
                              collegeId: widget.collegeId,
                            ),
                          ),
                        );
                        _fetchClasses();
                      },
                      child: const Text('Create Semester'),
                    ),
                  ],
                ),
              ),
            )
          : _classes.isEmpty
          ? const Center(child: Text('No classes yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                final hasCC = cls['cc_faculty_id'] != null;
                return Card(
                  child: ListTile(
                    title: Text('${cls['year']} - Section ${cls['section']}'),
                    subtitle: Text(cls['department']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        hasCC
                            ? ActionChip(
                                label: const Text('CC Assigned'),
                                backgroundColor: Colors.green.shade100,
                                onPressed: () =>
                                    _showCCDetails(cls['class_id']),
                              )
                            : ActionChip(
                                label: const Text('Unassigned'),
                                backgroundColor: Colors.orange.shade100,
                                onPressed: () =>
                                    _showInviteFacultyDialog(cls['class_id']),
                              ),
                        IconButton(
                          icon: const Icon(Icons.people),
                          tooltip: 'CC Requests',
                          onPressed: () => _showPendingRequests(
                            cls['class_id'],
                            '${cls['year']} - ${cls['section']}',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.menu_book),
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
                          icon: const Icon(Icons.delete, color: Colors.red),
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
                );
              },
            ),
      floatingActionButton: _hasActiveSemester
          ? FloatingActionButton(
              onPressed: _showAddClassDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
