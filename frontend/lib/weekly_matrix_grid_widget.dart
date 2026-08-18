import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';

class WeeklyMatrixGridWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole;
  final int currentFacultyId;
  final bool canEdit;
  final VoidCallback? onTimetableChanged;

  const WeeklyMatrixGridWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.userRole,
    required this.currentFacultyId,
    this.canEdit = true,
    this.onTimetableChanged,
  });

  @override
  State<WeeklyMatrixGridWidget> createState() => _WeeklyMatrixGridWidgetState();
}

class _WeeklyMatrixGridWidgetState extends State<WeeklyMatrixGridWidget> {
  bool _isLoading = true;
  List<dynamic> _entries = [];
  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  static const List<Color> _swapPalette = [
    Color(0xFFB3E5FC),
    Color(0xFFC8E6C9),
    Color(0xFFFFF9C4),
    Color(0xFFF8BBD0),
    Color(0xFFD1C4E9),
    Color(0xFFFFCCBC),
    Color(0xFFB2DFDB),
    Color(0xFFDCEDC8),
  ];

  static const List<Color> _swapBorderPalette = [
    Color(0xFF81D4FA),
    Color(0xFFA5D6A7),
    Color(0xFFFFF59D),
    Color(0xFFF48FB1),
    Color(0xFFB39DDB),
    Color(0xFFFFAB91),
    Color(0xFF80CBC4),
    Color(0xFFC5E1A5),
  ];

  final Map<int, int> _swapColorIndex = {};

  int _colorIndexForSwap(int swapId) {
    if (!_swapColorIndex.containsKey(swapId)) {
      _swapColorIndex[swapId] = _swapColorIndex.length % _swapPalette.length;
    }
    return _swapColorIndex[swapId]!;
  }

  Color _swapFillColor(int swapId) {
    return _swapPalette[_colorIndexForSwap(swapId)];
  }

  Color _swapBorderColor(int swapId) {
    return _swapBorderPalette[_colorIndexForSwap(swapId)];
  }

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    setState(() => _isLoading = true);
    _swapColorIndex.clear();
    final url = Uri.parse('http://127.0.0.1:5000/timetable/${widget.classId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _entries = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Color _getCellColor(dynamic entry, bool isMySubject) {
    if (entry == null) return Colors.grey.shade50;
    if (entry['entry_type'] == 'break') return Colors.amber.shade50;
    if (isMySubject) return const Color(0xFFE8F5E9);

    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        return Colors.red.shade100;
      case 'confirmed_cover':
        return Colors.green.shade100;
      case 'swapped':
        return entry['swap_id'] != null
            ? _swapFillColor(entry['swap_id'] as int)
            : Colors.blue.shade50;
      default:
        return Colors.white;
    }
  }

  Color _getBorderColor(dynamic entry, bool isMySubject) {
    if (entry == null) return Colors.grey.shade300;
    if (entry['entry_type'] == 'break') return Colors.amber.shade300;
    if (isMySubject) return Colors.green.shade400;

    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        return Colors.red.shade400;
      case 'confirmed_cover':
        return Colors.green.shade400;
      case 'swapped':
        return entry['swap_id'] != null
            ? _swapBorderColor(entry['swap_id'] as int)
            : Colors.blue.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  void _handleCellTap(dynamic entry, String day, int periodNo) {
    if (!widget.canEdit) return;

    if (entry != null && entry['entry_type'] != 'break') {
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
      ).then((val) {
        _fetchTimetable();
        widget.onTimetableChanged?.call();
      });
    } else if (entry == null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ScheduleBuilderScreen(
            classId: widget.classId,
            className: widget.className,
            dayOfWeek: day,
          ),
        ),
      ).then((val) {
        _fetchTimetable();
        widget.onTimetableChanged?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No timetable entries available for this class.'),
        ),
      );
    }

    int maxPeriod = 1;
    for (var e in _entries) {
      final p = e['period_no'];
      if (p != null && p is int && p > maxPeriod) {
        maxPeriod = p;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(140.0),
            border: TableBorder.all(
              color: Colors.grey.shade300,
              width: 1,
              borderRadius: BorderRadius.circular(8),
            ),
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    child: const Text(
                      'Day',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  for (int p = 1; p <= maxPeriod; p++)
                    Container(
                      padding: const EdgeInsets.all(10),
                      alignment: Alignment.center,
                      child: Text(
                        'Period $p',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              for (String day in _days)
                TableRow(
                  children: [
                    Container(
                      height: 90,
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      color: Colors.indigo.shade50.withOpacity(0.4),
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),

                    for (int p = 1; p <= maxPeriod; p++) ...[
                      Builder(
                        builder: (context) {
                          final entry = _entries.firstWhere(
                            (e) =>
                                e['day_of_week'] == day && e['period_no'] == p,
                            orElse: () => null,
                          );

                          if (entry == null) {
                            return InkWell(
                              onTap: () => _handleCellTap(null, day, p),
                              child: Container(
                                height: 90,
                                color: Colors.grey.shade50,
                                alignment: Alignment.center,
                                child: Text(
                                  widget.canEdit ? 'Free Period\n(Tap to add)' : 'Free Period',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                            );
                          }

                          final isBreak = entry['entry_type'] == 'break';
                          final isOpenLeave = entry['status_color'] == 'open_leave';
                          final isSwapped = entry['status_color'] == 'swapped';
                          final isMySubject = widget.currentFacultyId > 0 &&
                              entry['faculty_id'] == widget.currentFacultyId;

                          final title = isBreak
                              ? (entry['label'] ?? 'BREAK')
                              : (entry['course_name'] ?? 'Free Period');
                          final faculty = entry['faculty_name'] ?? '';
                          final room = entry['room_number'] ?? '';

                          return InkWell(
                            onTap: () => _handleCellTap(entry, day, p),
                            child: Container(
                              height: 90,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _getCellColor(entry, isMySubject),
                                border: Border.all(
                                  color: _getBorderColor(entry, isMySubject),
                                  width: isMySubject || isOpenLeave || isSwapped ? 1.8 : 0.8,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        title.toUpperCase(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: isBreak
                                              ? Colors.amber.shade900
                                              : isOpenLeave
                                                  ? Colors.red.shade900
                                                  : (isMySubject
                                                      ? Colors.green.shade900
                                                      : Colors.black87),
                                        ),
                                      ),
                                      if (isOpenLeave) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          'ABSENT',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ] else if (faculty.isNotEmpty && !isBreak) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          faculty,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                      if (room.isNotEmpty && !isBreak) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.meeting_room, size: 10, color: Colors.grey),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Room: $room',
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isSwapped)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: entry['swap_id'] != null
                                              ? _swapBorderColor(entry['swap_id'] as int)
                                              : Colors.blue.shade700,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.swap_horiz,
                                          size: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
