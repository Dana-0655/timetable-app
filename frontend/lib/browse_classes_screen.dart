import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'faculty_class_courses_screen.dart';
import 'class_info_dialog.dart';

class BrowseClassesScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const BrowseClassesScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<BrowseClassesScreen> createState() => _BrowseClassesScreenState();
}

class _BrowseClassesScreenState extends State<BrowseClassesScreen> {
  List<dynamic> _classes = [];
  bool _isLoading = true;
  bool _isAlreadyCCSomewhere = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    final classesUrl = Uri.parse(
      'http://127.0.0.1:5000/classes/${widget.collegeId}',
    );
    final relatedUrl = Uri.parse(
      'http://127.0.0.1:5000/faculty_related_classes/${widget.facultyId}',
    );

    try {
      final classesResponse = await http.get(classesUrl);
      final relatedResponse = await http.get(relatedUrl);

      if (classesResponse.statusCode == 200 &&
          relatedResponse.statusCode == 200) {
        final related = jsonDecode(relatedResponse.body);
        final alreadyCC = related.any(
          (c) => c['cc_faculty_id'] == widget.facultyId,
        );

        setState(() {
          _classes = jsonDecode(classesResponse.body);
          _isAlreadyCCSomewhere = alreadyCC;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendCCRequest(int classId) async {
    final url = Uri.parse('http://127.0.0.1:5000/request_cc');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': classId, 'faculty_id': widget.facultyId}),
      );
      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CC request sent!')));
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Browse Classes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _classes.length,
              itemBuilder: (context, index) {
                final cls = _classes[index];
                final hasCC = cls['cc_faculty_id'] != null;
                final isMyCC = cls['cc_faculty_id'] == widget.facultyId;
                final className = '${cls['year']} - ${cls['section']}';
                return Card(
                  child: ListTile(
                    title: Text('${cls['year']} - Section ${cls['section']}'),
                    subtitle: Text(cls['department']),
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
                            // Only editable if THIS faculty is that
                            // specific class's CC — everyone else,
                            // including other CCs, sees it read-only.
                            canEdit: isMyCC,
                          ),
                        ),
                        if (hasCC)
                          const Chip(label: Text('CC Assigned'))
                        else if (!_isAlreadyCCSomewhere)
                          ElevatedButton(
                            onPressed: () => _sendCCRequest(cls['class_id']),
                            child: const Text('Request CC'),
                          ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FacultyClassCoursesScreen(
                          classId: cls['class_id'],
                          className: className,
                          facultyId: widget.facultyId,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
