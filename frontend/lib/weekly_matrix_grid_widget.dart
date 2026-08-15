import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'substitute_recommendations_dialog.dart';

class SlotTimeInfo {
  final String label;
  final String time;
  final bool isBreak;
  final int? periodNo;

  const SlotTimeInfo({
    required this.label,
    required this.time,
    this.isBreak = false,
    this.periodNo,
  });
}

class WeeklyMatrixGridWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole; // 'student', 'faculty', 'admin'
  final int? currentFacultyId;
  final VoidCallback? onRefreshNeeded;

  const WeeklyMatrixGridWidget({
    super.key,
    required this.classId,
    required this.className,
    this.userRole = 'student',
    this.currentFacultyId,
    this.onRefreshNeeded,
  });

  @override
  State<WeeklyMatrixGridWidget> createState() => _WeeklyMatrixGridWidgetState();
}

class _WeeklyMatrixGridWidgetState extends State<WeeklyMatrixGridWidget> {
  List<dynamic> _entries = [];
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final Map<String, String> _dayShortMap = {
    'Monday': 'MON',
    'Tuesday': 'TUE',
    'Wednesday': 'WED',
    'Thursday': 'THU',
    'Friday': 'FRI',
    'Saturday': 'SAT',
    'Sunday': 'SUN',
  };

  final List<SlotTimeInfo> _slots = const [
    SlotTimeInfo(label: 'Period 1', time: '9:00–9:55', periodNo: 1),
    SlotTimeInfo(label: 'Period 2', time: '9:55–10:50', periodNo: 2),
    SlotTimeInfo(label: 'TEA BREAK', time: '10:50–11:05', isBreak: true),
    SlotTimeInfo(label: 'Period 3', time: '11:05–12:00', periodNo: 3),
    SlotTimeInfo(label: 'Period 4', time: '12:00–12:55', periodNo: 4),
    SlotTimeInfo(label: 'LUNCH', time: '12:55–1:55', isBreak: true),
    SlotTimeInfo(label: 'Period 5', time: '1:55–2:50', periodNo: 5),
    SlotTimeInfo(label: 'Period 6', time: '2:50–3:45', periodNo: 6),
    SlotTimeInfo(label: 'TEA BREAK', time: '3:45–3:55', isBreak: true),
    SlotTimeInfo(label: 'Period 7', time: '3:55–4:50', periodNo: 7),
    SlotTimeInfo(label: 'Period 8', time: '5:00–6:00', periodNo: 8),
  ];

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
      } else {
        setState(() {
          _errorMessage = 'Could not load timetable matrix.';
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

  dynamic _getEntryForCell(String dayFull, int? periodNo) {
    if (periodNo == null) return null;
    final dayShort = _dayShortMap[dayFull] ?? 'MON';
    for (var e in _entries) {
      if (e['day_of_week'] == dayShort && e['period_no'] == periodNo) {
        return e;
      }
    }
    return null;
  }

  Future<void> _autoAllocateOneTap(int entryId) async {
    // Get leave ID for entry
    final leaveUrl = Uri.parse('http://127.0.0.1:5000/leave_by_entry/$entryId');
    try {
      final leaveRes = await http.get(leaveUrl);
      if (leaveRes.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active leave found for this slot.')),
          );
        }
        return;
      }

      final leaveId = jsonDecode(leaveRes.body)['leave_id'];

      final allocUrl = Uri.parse('http://127.0.0.1:5000/auto_allocate_substitute');
      final allocRes = await http.post(
        allocUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leave_id': leaveId,
          'approved_by_role': widget.userRole,
        }),
      );

      if (allocRes.statusCode == 200) {
        final resData = jsonDecode(allocRes.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '⚡ ${resData["message"]} (${resData["match_score"]}% Match)',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
        _fetchTimetable();
        widget.onRefreshNeeded?.call();
      } else {
        final err = jsonDecode(allocRes.body)['error'] ?? 'Auto-allocation failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
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

  Future<void> _openSuggestionsModal(int entryId) async {
    final leaveUrl = Uri.parse('http://127.0.0.1:5000/leave_by_entry/$entryId');
    try {
      final leaveRes = await http.get(leaveUrl);
      if (leaveRes.statusCode == 200) {
        final leaveId = jsonDecode(leaveRes.body)['leave_id'];
        if (!mounted) return;
        final refreshed = await showDialog<bool>(
          context: context,
          builder: (context) => SubstituteRecommendationsDialog(
            leaveId: leaveId,
            userRole: widget.userRole,
          ),
        );
        if (refreshed == true) {
          _fetchTimetable();
          widget.onRefreshNeeded?.call();
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  void _showCellDetailsDialog(dynamic entry) {
    if (entry == null) return;
    final courseName = entry['course_name'] ?? 'Unassigned';
    final facultyName = entry['faculty_name'] ?? 'No Faculty';
    final statusColor = entry['status_color'] ?? 'normal';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              courseName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text(
              '${entry['day_of_week']} • Period ${entry['period_no']} (${entry['start_time'] ?? ''} - ${entry['end_time'] ?? ''})',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Colors.deepPurple,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                facultyName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(statusColor == 'confirmed_cover' ? 'Substitute Covering' : 'Assigned Faculty'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.room, size: 18, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  Text(
                    'Room / Location: ${entry['room'] ?? "R006"}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (statusColor == 'open_leave' && widget.userRole != 'student') ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _autoAllocateOneTap(entry['entry_id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('1-Tap Smart Allocate'),
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _openSuggestionsModal(entry['entry_id']);
              },
              child: const Text('Ranked List'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchTimetable,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple.shade800, Colors.indigo.shade900],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.grid_view_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Generated Timetable • ${widget.className}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '7 Periods / Day',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Grid Matrix Body
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const FixedColumnWidth(140),
                  columnWidths: const {
                    0: FixedColumnWidth(110), // Days column
                  },
                  border: TableBorder.all(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                  children: [
                    // Row 0: Column Headers (Day + Slot Times)
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                      ),
                      children: [
                        _buildHeaderCell('Day', isFirst: true),
                        ..._slots.map(
                          (slot) => _buildHeaderCell(
                            '${slot.label}\n${slot.time}',
                            isBreak: slot.isBreak,
                          ),
                        ),
                      ],
                    ),

                    // Rows 1-7: Days (MON to SUN)
                    ..._days.map((dayFull) {
                      return TableRow(
                        children: [
                          // Day Sticky Cell
                          Container(
                            padding: const EdgeInsets.all(12),
                            color: Colors.indigo.shade50.withValues(alpha: 0.5),
                            alignment: Alignment.center,
                            child: Text(
                              dayFull,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Colors.indigo,
                              ),
                            ),
                          ),

                          // Slot Cells
                          ..._slots.map((slot) {
                            if (slot.isBreak) {
                              return _buildBreakCell(slot.label);
                            }

                            final entry = _getEntryForCell(dayFull, slot.periodNo);
                            return _buildMatrixCell(entry);
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text, {bool isFirst = false, bool isBreak = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      alignment: Alignment.center,
      color: isBreak ? Colors.orange.shade50 : null,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isFirst ? 13 : 11,
          color: isBreak ? Colors.orange.shade900 : Colors.indigo.shade900,
        ),
      ),
    );
  }

  Widget _buildBreakCell(String label) {
    return Container(
      height: 90,
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixCell(dynamic entry) {
    if (entry == null) {
      return Container(
        height: 90,
        color: Colors.white,
        alignment: Alignment.center,
        child: Text(
          '—',
          style: TextStyle(color: Colors.grey.shade400),
        ),
      );
    }

    final courseName = entry['course_name'];
    final facultyName = entry['faculty_name'];
    final statusColor = entry['status_color'] ?? 'normal';
    final isUnassigned = courseName == null;

    Color bgColor = Colors.white;
    Border border = Border.all(color: Colors.grey.shade200);

    if (statusColor == 'open_leave') {
      bgColor = Colors.amber.shade50;
      border = Border.all(color: Colors.amber.shade400, width: 1.5);
    } else if (statusColor == 'confirmed_cover') {
      bgColor = Colors.green.shade50;
      border = Border.all(color: Colors.green.shade400, width: 1.5);
    } else if (statusColor == 'special_class') {
      bgColor = Colors.red.shade50;
      border = Border.all(color: Colors.red.shade300, width: 1.5);
    } else if (statusColor == 'lab_batch') {
      bgColor = Colors.blue.shade50;
      border = Border.all(color: Colors.blue.shade300, width: 1.5);
    }

    return InkWell(
      onTap: () => _showCellDetailsDialog(entry),
      child: Container(
        height: 95,
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isUnassigned
            ? Center(
                child: Text(
                  'Free Period',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    courseName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    facultyName ?? 'No Faculty',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor == 'confirmed_cover'
                          ? Colors.green.shade900
                          : Colors.grey.shade700,
                      fontWeight: statusColor == 'confirmed_cover'
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.room, size: 10, color: Colors.grey.shade600),
                      const SizedBox(width: 2),
                      Text(
                        'Room: ${entry['room'] ?? "R006"}',
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  if (statusColor == 'open_leave' && widget.userRole != 'student') ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _autoAllocateOneTap(entry['entry_id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Auto-Allocate',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
