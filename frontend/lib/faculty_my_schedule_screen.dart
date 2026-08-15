import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultyMyScheduleScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const FacultyMyScheduleScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<FacultyMyScheduleScreen> createState() =>
      _FacultyMyScheduleScreenState();
}

class _FacultyMyScheduleScreenState extends State<FacultyMyScheduleScreen> {
  List<dynamic> _schedule = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMySchedule();
  }

  Future<void> _fetchMySchedule() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/faculty_schedule/${widget.facultyId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _schedule = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markLeave(int entryId) async {
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final url = Uri.parse('http://127.0.0.1:5000/mark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'entry_id': entryId,
          'leave_date': dateStr,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave marked! Slot highlighted for substitutes.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        _fetchMySchedule();
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
      appBar: AppBar(
        title: const Text('My Teaching Schedule'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedule.isEmpty
          ? const Center(child: Text('No classes assigned to you yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final item = _schedule[index];
                final isCovering = item['type'] == 'covering';
                final isOnLeave = item['is_on_leave'] == true;
                final subName = item['substitute_name'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isCovering
                        ? Colors.green.shade50
                        : (isOnLeave ? Colors.amber.shade50 : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCovering
                          ? Colors.green.shade400
                          : (isOnLeave
                              ? Colors.amber.shade400
                              : Colors.grey.shade300),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isCovering
                          ? Colors.green
                          : (isOnLeave ? Colors.amber.shade800 : Colors.deepPurple),
                      child: Icon(
                        isCovering
                            ? Icons.assignment_ind
                            : (isOnLeave ? Icons.event_busy : Icons.class_),
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      '${item['class_name']} • ${item['course_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${item['day_of_week']} Period ${item['period_no']} (${item['start_time'] ?? ''} - ${item['end_time'] ?? ''})'
                      '${isCovering ? '\nCovering for: ${item['absent_faculty_name']}' : ''}'
                      '${subName != null ? '\nSubstituted by: $subName' : ''}',
                    ),
                    trailing: isCovering
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Covering',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : (isOnLeave
                            ? Chip(
                                backgroundColor: Colors.amber.shade100,
                                label: Text(
                                  subName != null ? 'Covered' : 'On Leave',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                onPressed: () => _markLeave(item['entry_id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade800,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Mark Leave'),
                              )),
                  ),
                );
              },
            ),
    );
  }
}
