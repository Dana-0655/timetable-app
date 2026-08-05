import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'schedule_builder_screen.dart';

class AdminTimetableViewScreen extends StatefulWidget {
  final int classId;
  final String className;

  const AdminTimetableViewScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AdminTimetableViewScreen> createState() =>
      _AdminTimetableViewScreenState();
}

class _AdminTimetableViewScreenState extends State<AdminTimetableViewScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;

  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/timetable/${widget.classId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _entries = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'open_leave':
        return Colors.orange.shade100;
      case 'confirmed_cover':
        return Colors.green.shade100;
      case 'swapped':
        return Colors.blue.shade100;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.className} - Timetable'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((d) => Tab(text: d)).toList(),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: _days.map((day) {
                  final dayEntries =
                      _entries.where((e) => e['day_of_week'] == day).toList()
                        ..sort(
                          (a, b) => a['period_no'].compareTo(b['period_no']),
                        );

                  if (dayEntries.isEmpty) {
                    return Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Make Schedule'),
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ScheduleBuilderScreen(
                                classId: widget.classId,
                                className: widget.className,
                                dayOfWeek: day,
                              ),
                            ),
                          );
                          if (result == true) {
                            _fetchTimetable(); // Refresh after building schedule
                          }
                        },
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayEntries.length,
                    itemBuilder: (context, index) {
                      final entry = dayEntries[index];
                      return Card(
                        color: _colorForStatus(entry['status_color']),
                        child: ListTile(
                          title: Text('Period ${entry['period_no']}'),
                          subtitle: Text(
                            '${entry['course_name'] ?? 'Unassigned'} • '
                            '${entry['faculty_name'] ?? 'No faculty'}',
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }
}
