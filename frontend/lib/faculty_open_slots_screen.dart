import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyOpenSlotsScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const FacultyOpenSlotsScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<FacultyOpenSlotsScreen> createState() => _FacultyOpenSlotsScreenState();
}

class _FacultyOpenSlotsScreenState extends State<FacultyOpenSlotsScreen> {
  List<dynamic> _openEntries = [];
  bool _isLoading = true;

  static const TextStyle classHighlightStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A237E),
  );

  @override
  void initState() {
    super.initState();
    _fetchOpenSlots();
  }

  Future<void> _fetchOpenSlots() async {
    if (mounted) setState(() => _isLoading = true);
    List<dynamic> allOpen = [];

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
          // Don't show your own leave as something you can volunteer for.
          if (entry['status_color'] == 'open_leave' &&
              entry['faculty_id'] != widget.facultyId) {
            entry['class_id'] = cls['class_id'];
            entry['class_name'] =
                '${cls['year']} - ${cls['department']} - ${cls['section']}';
            allOpen.add(entry);
          }
        }
      }

      if (mounted) setState(() {
        _openEntries = allOpen;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Since we don't have a direct "get leave_id by entry_id" API,
  // we need one. For now, this is a placeholder for the next step.
  Future<void> _sendCoverRequest(int entryId) async {
    try {
      // Step 1: Get the leave_id for this entry
      final leaveUrl = Uri.parse(
        'http://127.0.0.1:5000/leave_by_entry/$entryId',
      );
      final leaveResponse = await http.get(leaveUrl);

      if (leaveResponse.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This slot is no longer open.')),
          );
        }
        return;
      }

      final leaveData = jsonDecode(leaveResponse.body);
      final leaveId = leaveData['leave_id'];

      // Step 2: Send the cover request using that leave_id
      final url = Uri.parse('http://127.0.0.1:5000/send_cover_request');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leave_id': leaveId,
          'requesting_faculty_id': widget.facultyId,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cover request sent!')));
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
      appBar: AppBar(title: const Text('Open Slots (Cover Requests)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _openEntries.isEmpty
          ? const Center(child: Text('No open slots right now.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _openEntries.length,
              itemBuilder: (context, index) {
                final entry = _openEntries[index];
                return Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    title: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: entry['class_name'],
                            style: classHighlightStyle,
                          ),
                          TextSpan(text: ' - ${entry['course_name']}'),
                        ],
                      ),
                    ),
                    subtitle: Text(
                      '${entry['day_of_week']} Period ${entry['period_no']}',
                    ),
                    trailing: ElevatedButton(
                      onPressed: () => _sendCoverRequest(entry['entry_id']),
                      child: const Text('Volunteer'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
