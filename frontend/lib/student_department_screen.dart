import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'student_class_screen.dart';

class StudentDepartmentScreen extends StatefulWidget {
  final int collegeId;
  const StudentDepartmentScreen({super.key, required this.collegeId});

  @override
  State<StudentDepartmentScreen> createState() =>
      _StudentDepartmentScreenState();
}

class _StudentDepartmentScreenState extends State<StudentDepartmentScreen> {
  List<String> _departments = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/departments/${widget.collegeId}',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _departments = data.cast<String>();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Could not load departments.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Department')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _departments.isEmpty
          ? const Center(child: Text('No departments found.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _departments.length,
              itemBuilder: (context, index) {
                final dept = _departments[index];
                return Card(
                  child: ListTile(
                    title: Text(dept),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentClassScreen(
                            collegeId: widget.collegeId,
                            department: dept,
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
