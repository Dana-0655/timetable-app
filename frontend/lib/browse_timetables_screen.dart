import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'timetable_grid_screen.dart';

class BrowseTimetablesScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const BrowseTimetablesScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<BrowseTimetablesScreen> createState() => _BrowseTimetablesScreenState();
}

class _BrowseTimetablesScreenState extends State<BrowseTimetablesScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Timetables')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _classes.isEmpty
          ? const Center(child: Text('No classes yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                return Card(
                  child: ListTile(
                    title: Text('${cls['year']} - Section ${cls['section']}'),
                    subtitle: Text(cls['department']),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TimetableGridScreen(
                            classId: cls['class_id'],
                            className: '${cls['year']} - ${cls['section']}',
                            facultyId: widget.facultyId,
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
