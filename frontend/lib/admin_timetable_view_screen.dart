import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
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

  void _confirmDeleteSlot(int entryId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Slot'),
        content: const Text('Are you sure you want to delete this slot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteSlot(entryId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSlot(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_timetable_entry');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'entry_id': entryId}),
      );
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  void _confirmDeleteDay(String day) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $day Schedule'),
        content: Text(
          'This will delete ALL periods and breaks for $day. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteDay(day);
            },
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDay(String day) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_day_schedule');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'class_id': widget.classId, 'day_of_week': day}),
      );
      if (response.statusCode == 200) {
        _fetchTimetable();
      }
    } catch (e) {
      // Silently fail for now
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
                            _fetchTimetable();
                          }
                        },
                      ),
                    );
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(
                              Icons.delete_sweep,
                              color: Colors.red,
                            ),
                            label: const Text(
                              'Delete Day Schedule',
                              style: TextStyle(color: Colors.red),
                            ),
                            onPressed: () => _confirmDeleteDay(day),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: dayEntries.length,
                          itemBuilder: (context, index) {
                            final entry = dayEntries[index];
                            final isBreakEntry = entry['entry_type'] == 'break';
                            final isFilled = isBreakEntry
                                ? entry['label'] != null
                                : entry['course_name'] != null;

                            return Card(
                              color: isBreakEntry
                                  ? Colors.grey.shade200
                                  : _colorForStatus(entry['status_color']),
                              child: ListTile(
                                leading: Icon(
                                  isBreakEntry
                                      ? Icons.free_breakfast
                                      : Icons.book,
                                ),
                                title: Text(
                                  isBreakEntry
                                      ? (entry['label'] ??
                                            'Break (tap to set up)')
                                      : (entry['course_name'] ??
                                            'Period ${entry['period_no']} (tap to set up)'),
                                ),
                                subtitle: Text(
                                  isFilled
                                      ? '${entry['start_time'] ?? ''} - ${entry['end_time'] ?? ''}'
                                            '${!isBreakEntry ? ' • ${entry['faculty_name'] ?? 'No faculty assigned'}' : ''}'
                                      : 'Tap to fill in details',
                                ),
                                trailing: isFilled
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 20,
                                            ),
                                            onPressed: () async {
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FillSlotScreen(
                                                        entryId:
                                                            entry['entry_id'],
                                                        entryType:
                                                            entry['entry_type'],
                                                        isEdit: true,
                                                        existingCourseName:
                                                            entry['course_name'],
                                                        existingLabel:
                                                            entry['label'],
                                                        existingStartTime:
                                                            entry['start_time'],
                                                        existingEndTime:
                                                            entry['end_time'],
                                                      ),
                                                ),
                                              );
                                              if (result == true)
                                                _fetchTimetable();
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 20,
                                              color: Colors.red,
                                            ),
                                            onPressed: () => _confirmDeleteSlot(
                                              entry['entry_id'],
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Icon(Icons.edit),
                                onTap: isFilled
                                    ? null
                                    : () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FillSlotScreen(
                                                  entryId: entry['entry_id'],
                                                  entryType:
                                                      entry['entry_type'],
                                                ),
                                          ),
                                        );
                                        if (result == true) _fetchTimetable();
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }
}
