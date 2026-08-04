import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  @override
  void initState() {
    super.initState();
    _fetchClasses();
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
        _fetchClasses(); // Refresh the class list to show updated CC status
      }
    } catch (e) {
      // Silently fail for now
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
      if (response.statusCode == 200) {
        _fetchClasses(); // Refresh the list
      }
    } catch (e) {
      // Silently fail for now; could add error handling later
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${widget.adminName}')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                    trailing: Chip(
                      label: Text(hasCC ? 'CC Assigned' : 'Unassigned'),
                      backgroundColor: hasCC
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                    ),
                    onTap: () => _showPendingRequests(
                      cls['class_id'],
                      '${cls['year']} - ${cls['section']}',
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddClassDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
