import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SemesterManagementScreen extends StatefulWidget {
  final int collegeId;

  const SemesterManagementScreen({super.key, required this.collegeId});

  @override
  State<SemesterManagementScreen> createState() =>
      _SemesterManagementScreenState();
}

class _SemesterManagementScreenState extends State<SemesterManagementScreen> {
  List<dynamic> _semesters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSemesters();
  }

  Future<void> _fetchSemesters() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/semesters/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _semesters = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showCreateSemesterDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Semester'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Semester Name (e.g. 2026 Odd Semester)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _createSemester(nameController.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _createSemester(String name) async {
    final url = Uri.parse('http://127.0.0.1:5000/create_semester');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'college_id': widget.collegeId,
          'semester_name': name,
        }),
      );
      if (response.statusCode == 200) {
        _fetchSemesters();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _switchSemesterForEveryone(int semesterId) async {
    final url = Uri.parse('http://127.0.0.1:5000/switch_semester');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'college_id': widget.collegeId,
          'semester_id': semesterId,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Semester switched for everyone!')),
          );
        }
        _fetchSemesters();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  /// Ask the admin whether this semester switch should apply to everyone
  /// (students, faculty, CC, other admins) or just their own view.
  void _confirmSwitchSemester(Map sem) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch Semester'),
        content: Text(
          'Do you want to change the semester to "${sem['semester_name']}" '
          'for all users - students, faculty, CC, and other admins?\n\n'
          'Choosing "Just for me" will only change what you see. '
          'Everyone else stays on the current active semester.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(dialogContext); // close the dialog
              Navigator.pop(context, {
                'local_semester_id': sem['semester_id'],
                'semester_name': sem['semester_name'],
              }); // return to Admin Dashboard with a local-only selection
            },
            child: const Text('Just for me'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _switchSemesterForEveryone(sem['semester_id']);
            },
            child: const Text('For everyone'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int semesterId, String semesterName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Semester'),
        content: Text(
          'This will permanently remove "$semesterName" from view. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _deleteSemester(semesterId);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSemester(int semesterId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_semester');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'semester_id': semesterId}),
      );
      if (response.statusCode == 200) {
        _fetchSemesters();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Semesters')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _semesters.isEmpty
          ? const Center(child: Text('No semesters yet. Tap + to create one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _semesters.length,
              itemBuilder: (context, index) {
                final sem = _semesters[index];
                final isActive = sem['is_active'] == true;
                return Card(
                  color: isActive ? Colors.green.shade50 : null,
                  child: ListTile(
                    title: Text(sem['semester_name']),
                    subtitle: Text(isActive ? 'Active' : 'Inactive'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          TextButton(
                            onPressed: () => _confirmSwitchSemester(sem),
                            child: const Text('Switch'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(
                            sem['semester_id'],
                            sem['semester_name'],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSemesterDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
