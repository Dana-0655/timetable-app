import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TimetableGridScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int facultyId;

  const TimetableGridScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.facultyId,
  });

  @override
  State<TimetableGridScreen> createState() => _TimetableGridScreenState();
}

class _TimetableGridScreenState extends State<TimetableGridScreen> {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  bool _swapMode = false;
  dynamic _selectedMyEntry;

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

  Color _colorForEntry(dynamic entry) {
    if (_selectedMyEntry != null &&
        entry['entry_id'] == _selectedMyEntry['entry_id']) {
      return Colors.orange.shade200; // My selected period to give up
    }
    switch (entry['status_color']) {
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

  bool _isTappable(dynamic entry) {
    if (!_swapMode) return false;
    if (entry['course_id'] == null) return false; // unassigned slot, can't swap

    if (_selectedMyEntry == null) {
      // Step 1: only my own periods are tappable
      return entry['faculty_id'] == widget.facultyId;
    } else {
      // Step 2: only OTHER faculty's periods are tappable (mine is disabled now)
      return entry['faculty_id'] != widget.facultyId;
    }
  }

  void _onEntryTap(dynamic entry) {
    if (!_isTappable(entry)) return;

    if (_selectedMyEntry == null) {
      // Picking my own period
      setState(() {
        _selectedMyEntry = entry;
      });
    } else {
      // Picking target period -> confirm
      _confirmSwap(entry);
    }
  }

  void _confirmSwap(dynamic targetEntry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Swap Request'),
        content: Text(
          'Do you want to request a swap with ${targetEntry['faculty_name']}?\n\n'
          'You give: ${_selectedMyEntry['course_name']} '
          '(${_selectedMyEntry['day_of_week']} P${_selectedMyEntry['period_no']})\n'
          'You get: ${targetEntry['course_name']} '
          '(${targetEntry['day_of_week']} P${targetEntry['period_no']})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendSwapRequest(targetEntry);
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSwapRequest(dynamic targetEntry) async {
    final url = Uri.parse('http://127.0.0.1:5000/send_swap_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requester_faculty_id': widget.facultyId,
          'requester_entry_id': _selectedMyEntry['entry_id'],
          'target_faculty_id': targetEntry['faculty_id'],
          'target_entry_id': targetEntry['entry_id'],
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Swap request sent!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
    setState(() {
      _swapMode = false;
      _selectedMyEntry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.className),
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((d) => Tab(text: d)).toList(),
          ),
          actions: [
            IconButton(
              icon: Icon(_swapMode ? Icons.close : Icons.swap_horiz),
              tooltip: _swapMode ? 'Cancel Swap' : 'Start Swap Request',
              onPressed: () {
                setState(() {
                  _swapMode = !_swapMode;
                  _selectedMyEntry = null;
                });
              },
            ),
          ],
        ),
        body: Column(
          children: [
            if (_swapMode)
              Container(
                width: double.infinity,
                color: Colors.blue.shade50,
                padding: const EdgeInsets.all(12),
                child: Text(
                  _selectedMyEntry == null
                      ? 'Tap YOUR period to give up'
                      : 'Now tap the period you want instead',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: _days.map((day) {
                        final dayEntries =
                            _entries
                                .where((e) => e['day_of_week'] == day)
                                .toList()
                              ..sort(
                                (a, b) =>
                                    a['period_no'].compareTo(b['period_no']),
                              );

                        if (dayEntries.isEmpty) {
                          return const Center(
                            child: Text('No periods this day.'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: dayEntries.length,
                          itemBuilder: (context, index) {
                            final entry = dayEntries[index];
                            final tappable = _isTappable(entry);
                            return Opacity(
                              opacity:
                                  _swapMode &&
                                      !tappable &&
                                      _selectedMyEntry != entry
                                  ? 0.4
                                  : 1.0,
                              child: Card(
                                color: _colorForEntry(entry),
                                child: ListTile(
                                  title: Text('Period ${entry['period_no']}'),
                                  subtitle: Text(
                                    '${entry['course_name'] ?? 'Unassigned'} • '
                                    '${entry['faculty_name'] ?? 'No faculty'}',
                                  ),
                                  onTap: tappable
                                      ? () => _onEntryTap(entry)
                                      : null,
                                ),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
