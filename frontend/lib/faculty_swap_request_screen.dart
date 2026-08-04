import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultySwapRequestScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const FacultySwapRequestScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<FacultySwapRequestScreen> createState() =>
      _FacultySwapRequestScreenState();
}

class _FacultySwapRequestScreenState extends State<FacultySwapRequestScreen> {
  List<dynamic> _allEntries = [];
  bool _isLoading = true;
  dynamic _selectedMyEntry;

  @override
  void initState() {
    super.initState();
    _fetchAllEntries();
  }

  Future<void> _fetchAllEntries() async {
    setState(() => _isLoading = true);
    List<dynamic> allEntries = [];

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
          if (entry['course_id'] != null) {
            entry['class_name'] = '${cls['year']} - ${cls['section']}';
            allEntries.add(entry);
          }
        }
      }

      setState(() {
        _allEntries = allEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
          Navigator.pop(context);
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
    // Filter: my own slots (for step 1)
    final myEntries = _allEntries
        .where((e) => e['faculty_id'] == widget.facultyId)
        .toList();

    // Filter: other faculty's slots (for step 2, only after selecting mine)
    final otherEntries = _allEntries
        .where(
          (e) => e['faculty_id'] != widget.facultyId && e['faculty_id'] != null,
        )
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Request a Swap')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedMyEntry == null
          // STEP 1: Pick your own slot
          ? Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Step 1: Tap YOUR period to give up',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: myEntries.isEmpty
                      ? const Center(
                          child: Text('You have no assigned periods.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: myEntries.length,
                          itemBuilder: (context, index) {
                            final entry = myEntries[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${entry['class_name']} - ${entry['course_name']}',
                                ),
                                subtitle: Text(
                                  '${entry['day_of_week']} Period ${entry['period_no']}',
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedMyEntry = entry;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                ),
              ],
            )
          // STEP 2: Pick the target slot to swap into
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.shade50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Step 2: Tap the period you want instead',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You are giving up: ${_selectedMyEntry['class_name']} - '
                        '${_selectedMyEntry['course_name']} '
                        '(${_selectedMyEntry['day_of_week']} P${_selectedMyEntry['period_no']})',
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedMyEntry = null;
                          });
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: otherEntries.isEmpty
                      ? const Center(
                          child: Text('No other faculty slots found.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: otherEntries.length,
                          itemBuilder: (context, index) {
                            final entry = otherEntries[index];
                            return Card(
                              child: ListTile(
                                title: Text(
                                  '${entry['class_name']} - ${entry['course_name']}',
                                ),
                                subtitle: Text(
                                  '${entry['faculty_name']} • ${entry['day_of_week']} Period ${entry['period_no']}',
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _sendSwapRequest(entry),
                                  child: const Text('Request'),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
