import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'weekly_matrix_grid_widget.dart';
import 'vercel_bars_timetable_widget.dart';
import 'class_info_dialog.dart';
import 'swap_color_utils.dart';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';

class AdminTimetableViewScreen extends StatefulWidget {
  final int classId;
  final String className;
  final int collegeId;
  final bool isReadOnly;

  const AdminTimetableViewScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.collegeId,
    this.isReadOnly = false,
  });

  @override
  State<AdminTimetableViewScreen> createState() =>
      _AdminTimetableViewScreenState();
}

class _AdminTimetableViewScreenState extends State<AdminTimetableViewScreen> {
  int _selectedViewIndex = 0; // 0 = Grid Matrix, 1 = Vercel Bars
  Map<String, dynamic> _classInfo = {};
  List<dynamic> _entries = [];
  Map<int, int> _swapColorIndex = {};

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  Future<void> _fetchClassData() async {
    final infoUrl = Uri.parse(
      'http://127.0.0.1:5000/class_info/${widget.classId}',
    );
    final ttUrl = Uri.parse(
      'http://127.0.0.1:5000/timetable/${widget.classId}',
    );

    try {
      final infoRes = await http.get(infoUrl);
      if (infoRes.statusCode == 200) {
        _classInfo = jsonDecode(infoRes.body);
      }
    } catch (_) {}

    try {
      final ttRes = await http.get(ttUrl);
      if (ttRes.statusCode == 200) {
        _entries = jsonDecode(ttRes.body);
        _swapColorIndex = buildSwapColorIndex(_entries);
      }
    } catch (_) {}

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final dept = _classInfo['department'] ?? '';
    final sec = _classInfo['section'] ?? '';
    final year = _classInfo['year'] ?? '';
    final room = _classInfo['room_number'] ?? 'Not Set';
    final ccName = _classInfo['cc_name'] ?? 'Unassigned';

    final displayTitle = year.isNotEmpty
        ? '$year - $dept - Sec $sec'
        : widget.className;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Class Details',
            onPressed: () => showClassInfoDialog(
              context,
              classId: widget.classId,
              className: widget.className,
              canEdit: !widget.isReadOnly,
            ),
          ),
        ],
      ),
      body: Column(
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
                Text(
                  displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Chips Row: Branch | Room | CC
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (dept.isNotEmpty)
                      Chip(
                        avatar: const Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.indigoAccent,
                        ),
                        label: Text('Branch: $dept'),
                        backgroundColor: const Color(0xFF1E293B),
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    Chip(
                      avatar: const Icon(
                        Icons.meeting_room,
                        size: 14,
                        color: Colors.amberAccent,
                      ),
                      label: Text('Room: $room'),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    Chip(
                      avatar: const Icon(
                        Icons.person,
                        size: 14,
                        color: Colors.greenAccent,
                      ),
                      label: Text('CC: $ccName'),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
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
                    classId: widget.classId,
                    className: widget.className,
                    userRole: 'admin',
                    currentFacultyId: 0,
                    canEdit: !widget.isReadOnly,
                    swapColorIndex: _swapColorIndex,
                    onTimetableChanged: _fetchClassData,
                  )
                : VercelBarsTimetableWidget(
                    classId: widget.classId,
                    className: widget.className,
                    entries: _entries,
                    department: dept,
                    roomNo: room,
                    userRole: 'admin',
                    currentFacultyId: 0,
                    swapColorIndex: _swapColorIndex,
                    onRefreshNeeded: _fetchClassData,
                    onCellTap: !widget.isReadOnly
                        ? (entry) {
                            if (entry != null) {
                              if (entry['entry_type'] != 'break') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FillSlotScreen(
                                      entryId: entry['entry_id'],
                                      entryType: entry['entry_type'] ?? 'class',
                                      isEdit: true,
                                      existingCourseName: entry['course_name'],
                                      existingLabel: entry['label'],
                                      existingStartTime: entry['start_time'],
                                      existingEndTime: entry['end_time'],
                                    ),
                                  ),
                                ).then((_) => _fetchClassData());
                              }
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ScheduleBuilderScreen(
                                    classId: widget.classId,
                                    className: widget.className,
                                    dayOfWeek: 'SUN',
                                  ),
                                ),
                              ).then((_) => _fetchClassData());
                            }
                          }
                        : null,
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
