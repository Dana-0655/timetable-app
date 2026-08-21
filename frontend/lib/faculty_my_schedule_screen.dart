import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'weekly_matrix_grid_widget.dart';
import 'vercel_bars_timetable_widget.dart';
import 'swap_color_utils.dart';

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
  int _selectedViewIndex = 0; // 0 = Grid Matrix, 1 = Vercel Bars
  List<dynamic> _myEntries = [];
  Map<int, int> _swapColorIndex = {};
  bool _isLoading = true;

  String get _todayDateStr {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _fetchMySchedule();
  }

  Future<void> _fetchMySchedule() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'http://127.0.0.1:5000/faculty_timetable/${widget.facultyId}',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() {
          _myEntries = data;
          _swapColorIndex = buildSwapColorIndex(_myEntries);
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markLeave(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/mark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'faculty_id': widget.facultyId,
          'entry_id': entryId,
          'leave_date': _todayDateStr,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Leave marked! Slot highlighted for others.'),
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

  Future<void> _unmarkLeave(int entryId) async {
    final url = Uri.parse('http://127.0.0.1:5000/unmark_leave');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'faculty_id': widget.facultyId, 'entry_id': entryId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Leave unmarked.')
                  : (data['error'] ?? 'Could not unmark leave.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
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

  void _showEntryDetailsDialog(dynamic entry) {
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class scheduled for this period.')),
      );
      return;
    }

    final isOpen = entry['status_color'] == 'open_leave';
    final courseName = entry['course_name'] ?? 'Class Period';
    final className = entry['class_name'] ?? 'Assigned Class';
    final room = entry['room_number'] ?? 'Not Set';
    final day = entry['day_of_week'] ?? '';
    final period = entry['period_no'] ?? '';
    final startTime = entry['start_time'] ?? '';
    final endTime = entry['end_time'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.school_rounded, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                courseName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.class_rounded, 'Class', className),
            const SizedBox(height: 8),
            _buildDetailRow(Icons.meeting_room, 'Room', room),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.access_time_rounded,
              'Time',
              '$day Period $period (${startTime.isNotEmpty ? "$startTime - $endTime" : "Scheduled"})',
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.info_outline,
              'Status',
              isOpen ? 'Leave Marked (Open for Substitute)' : 'Regular Class',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOpen ? Colors.green : Colors.orange,
              foregroundColor: Colors.white,
            ),
            icon: Icon(isOpen ? Icons.check_circle : Icons.event_busy),
            label: Text(isOpen ? 'Unmark Leave' : 'Mark Leave'),
            onPressed: () {
              Navigator.pop(ctx);
              if (isOpen) {
                _unmarkLeave(entry['entry_id']);
              } else {
                _markLeave(entry['entry_id']);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Dark Header Card matching Joz 2x Grid Matrix design
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'My Weekly Teaching Schedule',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total: ${_myEntries.length} Assigned Periods/Week',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // View Toggle Selector
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildToggleButton(
                              index: 0,
                              label: 'Grid Matrix',
                              icon: Icons.grid_on,
                            ),
                            const SizedBox(width: 4),
                            _buildToggleButton(
                              index: 1,
                              label: 'Vercel Bars',
                              icon: Icons.segment,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main View Content
                Expanded(
                  child: _selectedViewIndex == 0
                      ? WeeklyMatrixGridWidget(
                          classId: 0,
                          className: 'My Schedule',
                          entries: _myEntries,
                          userRole: 'faculty_my_schedule',
                          currentFacultyId: widget.facultyId,
                          canEdit: false,
                          swapColorIndex: _swapColorIndex,
                          onCellTap: (entry) => _showEntryDetailsDialog(entry),
                          onTimetableChanged: _fetchMySchedule,
                        )
                      : VercelBarsTimetableWidget(
                          classId: 0,
                          className: 'My Schedule',
                          entries: _myEntries,
                          department: 'Faculty',
                          roomNo: '',
                          userRole: 'faculty_my_schedule',
                          currentFacultyId: widget.facultyId,
                          swapColorIndex: _swapColorIndex,
                          onCellTap: (entry) => _showEntryDetailsDialog(entry),
                          onRefreshNeeded: _fetchMySchedule,
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildToggleButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedViewIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedViewIndex = index),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
