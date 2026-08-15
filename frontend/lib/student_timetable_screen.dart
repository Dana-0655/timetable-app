import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'date_helpers.dart';

class StudentTimetableScreen extends StatefulWidget {
  final int classId;
  final String className;
  const StudentTimetableScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<StudentTimetableScreen> createState() => _StudentTimetableScreenState();
}

class _StudentTimetableScreenState extends State<StudentTimetableScreen> {
  List<dynamic> _entries = [];
  List<dynamic> _updates = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToToday = false;

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
    _fetchUpdates();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchTimetable();
      _fetchUpdates();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToToday() {
    if (_hasScrolledToToday || _entries.isEmpty) return;
    final index = _entries.indexWhere(
      (e) => DateHelpers.isToday(e['day_of_week']),
    );
    if (index != -1 && _scrollController.hasClients) {
      _scrollController.animateTo(
        index * 88.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      _hasScrolledToToday = true;
    }
  }

  Future<void> _fetchUpdates() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/class_updates/${widget.classId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _updates = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  IconData _iconForUpdate(String type) {
    switch (type) {
      case 'substitute_confirmed':
        return Icons.event_available;
      case 'free_period':
        return Icons.free_breakfast;
      case 'swap':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
    }
  }

  Color _colorForUpdate(String type) {
    switch (type) {
      case 'substitute_confirmed':
        return Colors.green;
      case 'free_period':
        return Colors.orange;
      case 'swap':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _showUpdatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Recent Updates',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _updates.isEmpty
                  ? const Center(child: Text('No recent updates.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _updates.length,
                      itemBuilder: (context, index) {
                        final u = _updates[index];
                        return ListTile(
                          leading: Icon(
                            _iconForUpdate(u['type']),
                            color: _colorForUpdate(u['type']),
                          ),
                          title: Text(u['message']),
                          subtitle: Text(u['created_at']),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchTimetable() async {
    final url = Uri.parse('http://127.0.0.1:5000/timetable/${widget.classId}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _entries = jsonDecode(response.body);
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToToday());
      } else {
        setState(() {
          _errorMessage = 'Could not load timetable.';
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

  Future<void> _showCourseInfo(int courseId) async {
    final url = Uri.parse('http://127.0.0.1:5000/course_detail/$courseId');
    try {
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final faculty = data['faculty'];

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(data['course_name']),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Course Code: ${data['course_code']}'),
                const SizedBox(height: 12),
                if (faculty != null) ...[
                  const Text(
                    'Faculty',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Name: ${faculty['name']}'),
                  Text('Email: ${faculty['email']}'),
                  Text('Expertise: ${faculty['subject_expertise']}'),
                ] else
                  const Text('No faculty assigned yet.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Color _getColorForStatus(String status) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Recent Updates',
                onPressed: _showUpdatesSheet,
              ),
              if (_updates.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_updates.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _entries.isEmpty
          ? const Center(
              child: Text(
                'Timetable not available yet, please check back later.',
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                final dayCode = entry['day_of_week'];
                final dateLabel = DateHelpers.labelForDayCode(dayCode);
                final isToday = DateHelpers.isToday(dayCode);

                return Card(
                  color: _getColorForStatus(entry['status_color']),
                  child: ListTile(
                    title: Row(
                      children: [
                        Text(
                          '$dayCode ($dateLabel) - Period ${entry['period_no']}',
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${entry['course_name'] ?? 'Unassigned'} • ${entry['faculty_name'] ?? 'No faculty'}',
                    ),
                    trailing: entry['course_id'] != null
                        ? IconButton(
                            icon: const Icon(Icons.info_outline),
                            onPressed: () =>
                                _showCourseInfo(entry['course_id']),
                          )
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
