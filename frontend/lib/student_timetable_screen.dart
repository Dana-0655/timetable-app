import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'weekly_matrix_grid_widget.dart';

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
  List<dynamic> _updates = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchUpdates();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchUpdates();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
      // Silently fail
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'Real-Time Class Alerts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
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
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: WeeklyMatrixGridWidget(
          classId: widget.classId,
          className: widget.className,
          userRole: 'student',
        ),
      ),
    );
  }
}
