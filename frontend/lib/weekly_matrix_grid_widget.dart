import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WeeklyMatrixGridWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole;
  final int currentFacultyId;

  const WeeklyMatrixGridWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.userRole,
    required this.currentFacultyId,
  });

  @override
  State<WeeklyMatrixGridWidget> createState() => _WeeklyMatrixGridWidgetState();
}

class _WeeklyMatrixGridWidgetState extends State<WeeklyMatrixGridWidget> {
  bool _isLoading = true;
  List<dynamic> _entries = [];
  final List<String> _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  // Same fixed palette as the list-view timetable grid, so a swapped pair
  // gets the exact same distinct color whether viewed as a list or a matrix.
  static const List<Color> _swapPalette = [
    Color(0xFFB3E5FC), // light blue
    Color(0xFFC8E6C9), // light green
    Color(0xFFFFF9C4), // light yellow
    Color(0xFFF8BBD0), // light pink
    Color(0xFFD1C4E9), // light purple
    Color(0xFFFFCCBC), // light orange
    Color(0xFFB2DFDB), // teal
    Color(0xFFDCEDC8), // lime
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

  // Assigns palette colors in the order distinct swap_ids are first seen,
  // instead of hashing the raw id — avoids two unrelated swaps colliding
  // on the same color just because (idA % 8 == idB % 8).
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

  Color _getCellColor(dynamic entry) {
    if (entry == null) return Colors.grey.shade50;
    if (entry['entry_type'] == 'break') return Colors.amber.shade50;
    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        // Absent/unfilled slot — needs to read as clearly red, not a
        // barely-there tint.
        return Colors.red.shade100;
      case 'confirmed_cover':
        return Colors.green.shade50;
      case 'swapped':
        return entry['swap_id'] != null
            ? _swapFillColor(entry['swap_id'] as int)
            : Colors.blue.shade50;
      default:
        return Colors.indigo.shade50;
    }
  }

  Color _getBorderColor(dynamic entry) {
    if (entry == null) return Colors.grey.shade300;
    if (entry['entry_type'] == 'break') return Colors.amber.shade200;
    final statusColor = entry['status_color'];
    switch (statusColor) {
      case 'open_leave':
        return Colors.red.shade400;
      case 'confirmed_cover':
        return Colors.green.shade300;
      case 'swapped':
        return entry['swap_id'] != null
            ? _swapBorderColor(entry['swap_id'] as int)
            : Colors.blue.shade300;
      default:
        return Colors.indigo.shade200;
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

    // Determine max period number present
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
              // Header Row: Day / Period 1 / Period 2 ...
              TableRow(
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade800,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    alignment: Alignment.center,
                    child: const Text(
                      'DAY / PERIOD',
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
                        'P$p',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),

              // Data Rows for each day
              for (String day in _days)
                TableRow(
                  children: [
                    // Day label cell
                    Container(
                      height: 80,
                      padding: const EdgeInsets.all(8),
                      alignment: Alignment.center,
                      color: Colors.blueGrey.shade50,
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),

                    // Period cells
                    for (int p = 1; p <= maxPeriod; p++) ...[
                      Builder(
                        builder: (context) {
                          final entry = _entries.firstWhere(
                            (e) =>
                                e['day_of_week'] == day && e['period_no'] == p,
                            orElse: () => null,
                          );

                          if (entry == null) {
                            return Container(
                              height: 80,
                              color: Colors.grey.shade50,
                              alignment: Alignment.center,
                              child: const Text(
                                '-',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          final isBreak = entry['entry_type'] == 'break';
                          final isOpenLeave =
                              entry['status_color'] == 'open_leave';
                          final isSwapped = entry['status_color'] == 'swapped';
                          final title = isBreak
                              ? (entry['label'] ?? 'BREAK')
                              : (entry['course_name'] ?? 'Unassigned');
                          final faculty = entry['faculty_name'] ?? '';
                          final startTime = entry['start_time'] ?? '';
                          final endTime = entry['end_time'] ?? '';

                          return Container(
                            height: 80,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _getCellColor(entry),
                              border: Border.all(
                                color: _getBorderColor(entry),
                                width: isOpenLeave || isSwapped ? 1.5 : 0.5,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      title,
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
                                            : Colors.black87,
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
                                    ] else if (faculty.isNotEmpty &&
                                        !isBreak) ...[
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
                                    if (startTime.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '$startTime - $endTime',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (isSwapped)
                                  Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Tooltip(
                                      message: entry['swap_id'] != null
                                          ? 'Swapped period (pair #${entry['swap_id']})'
                                          : 'Swapped period',
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: entry['swap_id'] != null
                                              ? _swapBorderColor(
                                                  entry['swap_id'] as int,
                                                )
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
                                  ),
                              ],
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
