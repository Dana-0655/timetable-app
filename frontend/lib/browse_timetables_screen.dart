import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'timetable_grid_screen.dart';
import 'class_info_dialog.dart';

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

  static const TextStyle classHighlightStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A237E),
  );

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    // Only classes where this faculty is CC or teaches a course - not
    // every class in the college.
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_related_classes/${widget.facultyId}',
    );
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
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You are not linked to any class yet — become a CC or get '
                  'assigned to teach a course to see it here.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                final isCC = cls['cc_faculty_id'] == widget.facultyId;
                final className = '${cls['year']} - ${cls['section']}';
                return Card(
                  child: ListTile(
                    title: Text(
                      '${cls['year']} - ${cls['department']} - ${cls['section']}',
                      style: classHighlightStyle,
                    ),
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
                            canEdit: isCC,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TimetableGridScreen(
                            classId: cls['class_id'],
                            className: className,
                            facultyId: widget.facultyId,
                            isCC: isCC,
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
