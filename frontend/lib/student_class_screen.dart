import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student_timetable_screen.dart';
import 'class_info_dialog.dart';

class StudentClassScreen extends StatefulWidget {
  final int collegeId;
  final String department;
  const StudentClassScreen({
    super.key,
    required this.collegeId,
    required this.department,
  });

  @override
  State<StudentClassScreen> createState() => _StudentClassScreenState();
}

class _StudentClassScreenState extends State<StudentClassScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/classes_by_department/${widget.collegeId}/${widget.department}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) setState(() {
          _classes = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() {
          _errorMessage = 'Could not load classes.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.department)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _classes.isEmpty
          ? const Center(child: Text('No classes found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                final className =
                    '${cls['year']} - ${widget.department} - ${cls['section']}';
                return Card(
                  child: ListTile(
                    title: Text('${cls['year']} - Section ${cls['section']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          tooltip: 'Class Details',
                          onPressed: () => showClassInfoDialog(
                            context,
                            classId: cls['class_id'],
                            className: className,
                            canEdit: false, // students are always read-only
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentTimetableScreen(
                            classId: cls['class_id'],
                            className: className,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
