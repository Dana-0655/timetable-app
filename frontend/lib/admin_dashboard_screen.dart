import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'class_courses_screen.dart';
import 'semester_management_screen.dart';
import 'session_manager.dart';
import 'role_selection_screen.dart';
import 'main.dart';
import 'admin_timetable_view_screen.dart';
import 'promote_faculty_screen.dart';
import 'admin_add_faculty_screen.dart';
import 'notification_bell.dart';
import 'timetable_grid_screen.dart';
import 'faculty_my_schedule_screen.dart';
import 'faculty_open_slots_screen.dart';
import 'faculty_pending_leaves_screen.dart';
import 'faculty_swap_responses_screen.dart';
import 'browse_timetables_screen.dart';
import 'holiday_management_screen.dart';
import 'admin_timetable_upload_screen.dart';

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

  int? _localSemesterId;
  String? _localSemesterName;
  int? _activeSemesterId;

  int? _linkedFacultyId;
  List<dynamic> _myRoleClasses = [];
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _fetchActiveSemester();
    _fetchClasses();
    _fetchMyFacultyRoles();
  }

  Set<int> get _myCCClassIds {
    if (_linkedFacultyId == null) return {};
    return _myRoleClasses
        .where((c) => c['cc_faculty_id'] == _linkedFacultyId)
        .map<int>((c) => c['class_id'] as int)
        .toSet();
  }

  List<dynamic> get _sortedClasses {
    final ccIds = _myCCClassIds;
    if (ccIds.isEmpty) return _classes;
    final pinned = _classes
        .where((c) => ccIds.contains(c['class_id']))
        .toList();
    final rest = _classes.where((c) => !ccIds.contains(c['class_id'])).toList();
    return [...pinned, ...rest];
  }

  List<dynamic> get _ccClassesElsewhere {
    final ccIds = _myCCClassIds;
    if (ccIds.isEmpty) return [];
    final visibleIds = _classes.map((c) => c['class_id']).toSet();
    return _myRoleClasses
        .where(
          (c) =>
              c['cc_faculty_id'] == _linkedFacultyId &&
              !visibleIds.contains(c['class_id']),
        )
        .toList();
  }

  Future<void> _fetchActiveSemester() async {
    final semUrl = Uri.parse(
      'http://127.0.0.1:5000/semesters/${widget.collegeId}',
    );
    try {
      final semResponse = await http.get(semUrl);
      if (semResponse.statusCode == 200) {
        final List<dynamic> semesters = jsonDecode(semResponse.body);
        final activeSem = semesters.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s != null && s['is_active'] == true,
          orElse: () => null,
        );

        setState(() {
          _hasActiveSemester = activeSem != null;
          _activeSemesterId = activeSem?['semester_id'];
        });
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _showInviteFacultyDialog(int classId) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_list/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> rawFacultyList = jsonDecode(response.body);
      final List<dynamic> facultyList = rawFacultyList
          .where((f) => f['faculty_id'] != _linkedFacultyId)
          .toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invite Faculty as CC'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.person, size: 18),
                  label: const Text('Assign myself as CC'),
                  onPressed: () async {
                    Navigator.pop(context);
                    await _selfAssignCC(classId);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
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
                                  await _inviteCC(classId, f['faculty_id']);
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

  Future<int?> _ensureFacultyIdentity() async {
    if (_linkedFacultyId != null) return _linkedFacultyId;

    final url = Uri.parse(
      'http://127.0.0.1:5000/admin_ensure_faculty_identity',
    );
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'admin_id': widget.adminId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fid = data['faculty_id'] as int;
        setState(() => _linkedFacultyId = fid);
        return fid;
      }
    } catch (e) {
      // Silently fail for now
    }
    return null;
  }

  Future<void> _selfAssignCC(int classId) async {
    final facultyId = await _ensureFacultyIdentity();
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

    final url = Uri.parse('http://127.0.0.1:5000/admin_self_assign_cc');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId, 'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? data['error'] ?? 'Done')),
        );
      }
      _fetchClasses();
      _fetchMyFacultyRoles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
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
        _fetchMyFacultyRoles();
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  Future<void> _logout() async {
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
        _fetchMyFacultyRoles();
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

    if (_localSemesterId != null) {
      _hasActiveSemester = true;
      final url = Uri.parse(
        'http://127.0.0.1:5000/classes_by_semester/$_localSemesterId',
      );
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          setState(() {
            _classes = jsonDecode(response.body);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        setState(() => _isLoading = false);
      }
      return;
    }

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

  Future<void> _fetchMyFacultyRoles() async {
    setState(() => _isLoadingRoles = true);
    final ctxUrl = Uri.parse(
      'http://127.0.0.1:5000/admin_faculty_context/${widget.adminId}',
    );
    try {
      final ctxResponse = await http.get(ctxUrl);
      if (ctxResponse.statusCode == 200) {
        final ctxData = jsonDecode(ctxResponse.body);
        if (ctxData['has_faculty_record'] == true) {
          final fid = ctxData['faculty_id'] as int;
          final classesUrl = Uri.parse(
            'http://127.0.0.1:5000/faculty_related_classes_all/$fid',
          );
          final classesResponse = await http.get(classesUrl);
          if (classesResponse.statusCode == 200) {
            setState(() {
              _linkedFacultyId = fid;
              _myRoleClasses = jsonDecode(classesResponse.body);
            });
          }
        }
      }
    } catch (e) {
      // Silently fail for now
    }
    setState(() => _isLoadingRoles = false);
  }

  Future<void> _openSemesterManagement() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SemesterManagementScreen(collegeId: widget.collegeId),
      ),
    );

    if (result is Map && result.containsKey('local_semester_id')) {
      setState(() {
        _localSemesterId = result['local_semester_id'] as int?;
        _localSemesterName = result['semester_name'] as String?;
      });
    } else {
      setState(() {
        _localSemesterId = null;
        _localSemesterName = null;
      });
    }

    _fetchClasses();
  }

  void _clearLocalSemester() {
    setState(() {
      _localSemesterId = null;
      _localSemesterName = null;
    });
    _fetchClasses();
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
            const SizedBox(height: 12),
            TextField(
              controller: sectionController,
              decoration: const InputDecoration(labelText: 'Section (e.g. A)'),
            ),
            const SizedBox(height: 12),
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

  void _showEditClassDialog(dynamic cls) {
    final yearController = TextEditingController(text: cls['year']);
    final sectionController = TextEditingController(text: cls['section']);
    final departmentController = TextEditingController(text: cls['department']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: yearController,
              decoration: const InputDecoration(
                labelText: 'Year (e.g. 2nd Year)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sectionController,
              decoration: const InputDecoration(labelText: 'Section (e.g. A)'),
            ),
            const SizedBox(height: 12),
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
              await _updateClass(
                cls['class_id'],
                yearController.text,
                sectionController.text,
                departmentController.text,
              );
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateClass(
    int classId,
    String year,
    String section,
    String department,
  ) async {
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

    final url = Uri.parse('http://127.0.0.1:5000/update_class');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'class_id': classId,
          'year': year,
          'section': section,
          'department': department,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _fetchClasses();
        _fetchMyFacultyRoles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Class updated!')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not update class.')),
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
  @override
  Widget build(BuildContext context) {
    final displayClasses = _sortedClasses;
    final ccElsewhere = _ccClassesElsewhere;
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.adminName}'),
        actions: [
          NotificationBell(recipientType: 'admin', recipientId: widget.adminId),
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.amber),
            tooltip: 'Auto Generate Timetable',
            onPressed: () {
              final targetSemesterId = _localSemesterId ?? _activeSemesterId;
              if (targetSemesterId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please create or select an active semester first.',
                    ),
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AdminTimetableUploadScreen(
                    collegeId: widget.collegeId,
                    semesterId: targetSemesterId,
                    baseUrl: 'http://127.0.0.1:5000',
                  ),
                ),
              ).then((_) => _fetchClasses());
            },
          ),
          if (!isMobile) ...[
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
              onPressed: _openSemesterManagement,
            ),
            IconButton(
              icon: const Icon(Icons.beach_access),
              tooltip: 'Manage Holidays',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      HolidayManagementScreen(collegeId: widget.collegeId),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
              onPressed: _logout,
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More Admin Options',
              onSelected: (val) {
                switch (val) {
                  case 'add_faculty':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminAddFacultyScreen(
                          adminId: widget.adminId,
                          collegeId: widget.collegeId,
                        ),
                      ),
                    );
                    break;
                  case 'give_admin':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PromoteFacultyScreen(collegeId: widget.collegeId),
                      ),
                    );
                    break;
                  case 'manage_semesters':
                    _openSemesterManagement();
                    break;
                  case 'manage_holidays':
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => HolidayManagementScreen(
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
                  value: 'add_faculty',
                  child: Row(
                    children: [
                      Icon(Icons.person_add_rounded, size: 20, color: Color(0xFF1565C0)),
                      SizedBox(width: 12),
                      Text('Add Faculty'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'give_admin',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFF2E7D32)),
                      SizedBox(width: 12),
                      Text('Give Admin Access'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'manage_semesters',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFEF6C00)),
                      SizedBox(width: 12),
                      Text('Manage Semesters'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'manage_holidays',
                  child: Row(
                    children: [
                      Icon(Icons.beach_access_rounded, size: 20, color: Colors.indigo),
                      SizedBox(width: 12),
                      Text('Manage Holidays'),
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
      body: Column(
        children: [
          if (_localSemesterId != null)
            Container(
              width: double.infinity,
              color: Colors.blue.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility,
                    size: 18,
                    color: Colors.blueGrey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Viewing "${_localSemesterName ?? 'a semester'}" — just for you. '
                      'Everyone else still sees the active semester.',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _clearLocalSemester,
                    child: const Text('Return to global'),
                  ),
                ],
              ),
            ),
          if (!_isLoadingRoles && _linkedFacultyId != null)
            Container(
              width: double.infinity,
              color: Colors.purple.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Faculty Tools',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.schedule, size: 16),
                          label: const Text('My Schedule'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacultyMyScheduleScreen(
                                facultyId: _linkedFacultyId!,
                                collegeId: widget.collegeId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.search, size: 16),
                          label: const Text('Browse'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BrowseTimetablesScreen(
                                facultyId: _linkedFacultyId!,
                                collegeId: widget.collegeId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.inbox, size: 16),
                          label: const Text('Swap Responses'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacultySwapResponsesScreen(
                                facultyId: _linkedFacultyId!,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.pending_actions, size: 16),
                          label: const Text('My Leave Requests'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacultyPendingLeavesScreen(
                                facultyId: _linkedFacultyId!,
                                collegeId: widget.collegeId,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.event_available, size: 16),
                          label: const Text('Open Slots'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FacultyOpenSlotsScreen(
                                facultyId: _linkedFacultyId!,
                                collegeId: widget.collegeId,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (ccElsewhere.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ccElsewhere.map((c) {
                        final className = '${c['year']} - ${c['section']}';
                        return ActionChip(
                          avatar: const Icon(
                            Icons.badge,
                            size: 16,
                            color: Colors.purple,
                          ),
                          label: Text('Your CC (other sem): $className'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TimetableGridScreen(
                                classId: c['class_id'],
                                className: className,
                                facultyId: _linkedFacultyId!,
                                collegeId: widget.collegeId,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          Expanded(
            child: _isLoading
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
                            onPressed: _openSemesterManagement,
                            child: const Text('Create Semester'),
                          ),
                        ],
                      ),
                    ),
                  )
                : displayClasses.isEmpty
                ? const Center(child: Text('No classes yet. Tap + to add one.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: displayClasses.length,
                    itemBuilder: (context, index) {
                      final cls = displayClasses[index];
                      final hasCC = cls['cc_faculty_id'] != null;
                      final isMyCC =
                          _linkedFacultyId != null &&
                          cls['cc_faculty_id'] == _linkedFacultyId;
                      final className = '${cls['year']} - ${cls['section']}';

                      if (isMobile) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Title & Badges
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
                                      if (isMyCC)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'Your CC',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.purple.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // Bottom Action Bar
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        hasCC
                                            ? ActionChip(
                                                avatar: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                                                label: const Text('CC Assigned', style: TextStyle(fontSize: 12)),
                                                backgroundColor: Colors.green.shade50,
                                                onPressed: () => _showCCDetails(cls['class_id']),
                                              )
                                            : ActionChip(
                                                avatar: const Icon(Icons.person_add_outlined, size: 14, color: Colors.orange),
                                                label: const Text('Unassigned', style: TextStyle(fontSize: 12)),
                                                backgroundColor: Colors.orange.shade50,
                                                onPressed: () => _showInviteFacultyDialog(cls['class_id']),
                                              ),
                                        const SizedBox(width: 6),
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.people_alt_rounded, size: 18),
                                          tooltip: 'CC Requests',
                                          onPressed: () => _showPendingRequests(
                                            cls['class_id'],
                                            className,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                                          tooltip: 'Manage Courses',
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ClassCoursesScreen(
                                                classId: cls['class_id'],
                                                className: className,
                                                collegeId: widget.collegeId,
                                                selfFacultyId: _linkedFacultyId,
                                                selfAdminId: widget.adminId,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (isMyCC) ...[
                                          const SizedBox(width: 4),
                                          IconButton.filledTonal(
                                            icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                                            tooltip: 'Build Timetable',
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => TimetableGridScreen(
                                                  classId: cls['class_id'],
                                                  className: className,
                                                  facultyId: _linkedFacultyId!,
                                                  collegeId: widget.collegeId,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(width: 4),
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.edit_rounded, size: 18),
                                          tooltip: 'Edit Class',
                                          onPressed: () => _showEditClassDialog(cls),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton.filledTonal(
                                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                          tooltip: 'Delete Class',
                                          onPressed: () => _confirmDeleteClass(
                                            cls['class_id'],
                                            className,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return Card(
                        color: isMyCC ? Colors.purple.shade50 : null,
                        child: ListTile(
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${cls['year']} - Section ${cls['section']}',
                                ),
                              ),
                              if (isMyCC) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Your CC',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.purple.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                                      onPressed: () => _showInviteFacultyDialog(
                                        cls['class_id'],
                                      ),
                                    ),
                              IconButton(
                                icon: const Icon(Icons.people),
                                tooltip: 'CC Requests',
                                onPressed: () => _showPendingRequests(
                                  cls['class_id'],
                                  className,
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
                                      className: className,
                                      collegeId: widget.collegeId,
                                      selfFacultyId: _linkedFacultyId,
                                      selfAdminId: widget.adminId,
                                    ),
                                  ),
                                ),
                              ),
                              if (isMyCC)
                                IconButton(
                                  icon: const Icon(Icons.edit_calendar),
                                  tooltip: 'Build Timetable',
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TimetableGridScreen(
                                        classId: cls['class_id'],
                                        className: className,
                                        facultyId: _linkedFacultyId!,
                                        collegeId: widget.collegeId,
                                      ),
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                tooltip: 'Edit Class',
                                onPressed: () => _showEditClassDialog(cls),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                tooltip: 'Delete Class',
                                onPressed: () => _confirmDeleteClass(
                                  cls['class_id'],
                                  className,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AdminTimetableViewScreen(
                                classId: cls['class_id'],
                                className: className,
                                collegeId: widget.collegeId,
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
      floatingActionButton: _hasActiveSemester && _localSemesterId == null
          ? FloatingActionButton(
              onPressed: _showAddClassDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
