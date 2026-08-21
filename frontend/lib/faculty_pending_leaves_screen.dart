import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyPendingLeavesScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const FacultyPendingLeavesScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<FacultyPendingLeavesScreen> createState() =>
      _FacultyPendingLeavesScreenState();
}

class _FacultyPendingLeavesScreenState
    extends State<FacultyPendingLeavesScreen> {
  List<dynamic> _myOpenEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMyOpenLeaves();
  }

  Future<void> _fetchMyOpenLeaves() async {
    if (mounted) setState(() => _isLoading = true);
    List<dynamic> myOpen = [];

    try {
      final classesUrl = Uri.parse(
        'http://127.0.0.1:5000/classes/${widget.collegeId}',
      );
      final classesResponse = await http.get(classesUrl);
      final classes = jsonDecode(classesResponse.body);

      for (var cls in classes) {
        final ttUrl = Uri.parse(
          'http://127.0.0.1:5000/timetable/${cls['class_id']}',
        );
        final ttResponse = await http.get(ttUrl);
        final entries = jsonDecode(ttResponse.body);

        for (var entry in entries) {
          if (entry['status_color'] == 'open_leave') {
            // Get the leave_id for this entry
            final leaveUrl = Uri.parse(
              'http://127.0.0.1:5000/leave_by_entry/${entry['entry_id']}',
            );
            final leaveResponse = await http.get(leaveUrl);
            if (leaveResponse.statusCode == 200) {
              final leaveData = jsonDecode(leaveResponse.body);
              // Only show leaves belonging to THIS faculty
              entry['leave_id'] = leaveData['leave_id'];
              entry['class_name'] =
                  '${cls['year']} - ${cls['department']} - ${cls['section']}';
              myOpen.add(entry);
            }
          }
        }
      }

      if (mounted) setState(() {
        _myOpenEntries = myOpen;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewAndConfirmRequests(int leaveId, String slotInfo) async {
    final url = Uri.parse('http://127.0.0.1:5000/cover_requests/$leaveId');
    try {
      final response = await http.get(url);
      final List<dynamic> requests = jsonDecode(response.body);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Volunteers - $slotInfo'),
          content: SizedBox(
            width: double.maxFinite,
            child: requests.isEmpty
                ? const Text('No volunteers yet.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final req = requests[index];
                      return ListTile(
                        title: Text(req['faculty_name']),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _confirmCover(leaveId, req['cover_req_id']);
                          },
                          child: const Text('Confirm'),
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

  Future<void> _confirmCover(int leaveId, int coverReqId) async {
    final url = Uri.parse('http://127.0.0.1:5000/confirm_cover_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leave_id': leaveId,
          'cover_req_id': coverReqId,
          'confirmed_by_role': 'faculty',
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Substitute confirmed!')),
          );
        }
        _fetchMyOpenLeaves();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  /// Lets the absent faculty directly pick and assign a specific colleague
  /// to cover this period, instead of waiting for volunteers.
  Future<void> _showInviteSubstituteDialog(int leaveId, String slotInfo) async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_list/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      final List<dynamic> rawFacultyList = jsonDecode(response.body);
      // Don't let the absent faculty "invite" themselves.
      final facultyList = rawFacultyList
          .where((f) => f['faculty_id'] != widget.facultyId)
          .toList();

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) {
          String searchQuery = '';
          final searchController = TextEditingController();

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final query = searchQuery.trim().toLowerCase();
              final filteredList = facultyList.where((f) {
                final name = (f['name'] ?? '').toString().toLowerCase();
                final email = (f['email'] ?? '').toString().toLowerCase();
                return name.contains(query) || email.contains(query);
              }).toList();

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Text(
                  'Invite Someone - $slotInfo',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by name or user ID...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    setDialogState(() {
                                      searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onChanged: (val) {
                          setDialogState(() {
                            searchQuery = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Flexible(
                        child: facultyList.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No other faculty available.'),
                              )
                            : filteredList.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'No faculty found matching "$searchQuery"',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final f = filteredList[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    title: Text(
                                      f['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      f['email'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    trailing: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(context);
                                        await _inviteSubstitute(
                                          leaveId,
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
              );
            },
          );
        },
      );
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _inviteSubstitute(int leaveId, int facultyId) async {
    final url = Uri.parse('http://127.0.0.1:5000/invite_substitute');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'leave_id': leaveId, 'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Substitute assigned!')
                  : (data['error'] ?? 'Could not assign substitute.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
        _fetchMyOpenLeaves();
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
      appBar: AppBar(title: const Text('My Open Leave Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _myOpenEntries.isEmpty
          ? const Center(child: Text('No open leave requests.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _myOpenEntries.length,
              itemBuilder: (context, index) {
                final entry = _myOpenEntries[index];
                final slotInfo =
                    '${entry['class_name']} - ${entry['day_of_week']} Period ${entry['period_no']}';
                return Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    title: Text(entry['course_name'] ?? ''),
                    subtitle: Text(slotInfo),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _showInviteSubstituteDialog(
                            entry['leave_id'],
                            slotInfo,
                          ),
                          child: const Text('Invite'),
                        ),
                        ElevatedButton(
                          onPressed: () => _viewAndConfirmRequests(
                            entry['leave_id'],
                            slotInfo,
                          ),
                          child: const Text('View Volunteers'),
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
