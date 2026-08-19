import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'fill_slot_screen.dart';
import 'schedule_builder_screen.dart';
import 'swap_color_utils.dart';

// TODO: replace with your existing base URL constant if you have one
const String _kApiBase = "http://127.0.0.1:5000";

class WeeklyMatrixGridWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole;
  final int currentFacultyId;
  final bool canEdit;
  final VoidCallback? onTimetableChanged;
  final Map<int, int> swapColorIndex;

  const WeeklyMatrixGridWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.userRole,
    required this.currentFacultyId,
    required this.swapColorIndex,
    this.canEdit = true,
    this.onTimetableChanged,
  });

  @override
  State<WeeklyMatrixGridWidget> createState() => _WeeklyMatrixGridWidgetState();
}

class _WeeklyMatrixGridWidgetState extends State<WeeklyMatrixGridWidget> {
  bool _isLoading = true;
  List<dynamic> _entries = [];
  final List<String> _days = kWeekDays;

  // ---- Swap mode state (new — doesn't touch existing state) ----
  bool _swapModeOn = false;
  Map<String, dynamic>? _swapSourceEntry;
  bool _swapSubmitting = false;

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
            ? swapFillColor(widget.swapColorIndex, entry['swap_id'] as int)
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
            ? swapBorderColor(widget.swapColorIndex, entry['swap_id'] as int)
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

  // =====================================================================
  // NEW: Swap mode logic (added — no existing methods above were changed)
  // =====================================================================

  bool get _isAdmin => widget.userRole == 'admin';
  bool get _isFacultyOrCC =>
      widget.userRole == 'faculty' || widget.userRole == 'cc';

  bool get _teachesInThisTimetable {
    if (widget.currentFacultyId <= 0) return false;
    return _entries.any((e) => e['faculty_id'] == widget.currentFacultyId);
  }

  bool get _canUseSwapMode {
    if (!widget.canEdit) return false;
    if (_isAdmin) return true;
    if (_isFacultyOrCC) return _teachesInThisTimetable;
    return false;
  }

  bool _isSwappableEntry(dynamic entry) {
    if (entry == null) return false;
    if (entry['entry_type'] == 'break') return false;
    if (entry['course_name'] == null) return false;
    if (entry['faculty_id'] == null) return false;
    return true;
  }

  void _toggleSwapMode() {
    setState(() {
      _swapModeOn = !_swapModeOn;
      _swapSourceEntry = null;
    });
  }

  void _handleSwapTap(dynamic entry) {
    if (!_isSwappableEntry(entry)) {
      _showSwapSnack(
        'This slot can\'t be swapped — it has no assigned course.',
      );
      return;
    }
    final entryMap = Map<String, dynamic>.from(entry as Map);

    if (_isFacultyOrCC && _swapSourceEntry == null) {
      if (entryMap['faculty_id'] != widget.currentFacultyId) {
        _showSwapSnack('You can only start a swap from your own period.');
        return;
      }
    }

    if (_swapSourceEntry == null) {
      setState(() => _swapSourceEntry = entryMap);
      return;
    }

    if (_swapSourceEntry!['entry_id'] == entryMap['entry_id']) {
      setState(() => _swapSourceEntry = null);
      return;
    }

    if (_isFacultyOrCC && entryMap['faculty_id'] == widget.currentFacultyId) {
      _showSwapSnack(
        'Pick a period taught by a different faculty to swap with.',
      );
      return;
    }

    _showSwapConfirmDialog(_swapSourceEntry!, entryMap);
  }

  void _showSwapSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showSwapConfirmDialog(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFF0EA5E9)),
            SizedBox(width: 8),
            Text('Confirm Swap Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSwapPreviewRow(
              'From',
              source['course_name'] ?? '',
              source['faculty_name'] ?? '',
              '${source['day_of_week']} • Period ${source['period_no']}',
            ),
            const SizedBox(height: 12),
            const Icon(Icons.swap_vert_rounded, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            _buildSwapPreviewRow(
              'With',
              target['course_name'] ?? '',
              target['faculty_name'] ?? '',
              '${target['day_of_week']} • Period ${target['period_no']}',
            ),
            const SizedBox(height: 16),
            Text(
              _isAdmin
                  ? 'This will send a swap request that ${target['faculty_name']} still needs to approve.'
                  : 'A swap request will be sent to ${target['faculty_name']} for approval.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitSwapRequest(source, target);
    } else {
      setState(() => _swapSourceEntry = null);
    }
  }

  Widget _buildSwapPreviewRow(
    String label,
    String course,
    String faculty,
    String slot,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            course,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          Text(
            faculty,
            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
          ),
          Text(
            slot,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitSwapRequest(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) async {
    setState(() => _swapSubmitting = true);
    try {
      final response = await http.post(
        Uri.parse('$_kApiBase/send_swap_request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requester_faculty_id': source['faculty_id'],
          'requester_entry_id': source['entry_id'],
          'target_faculty_id': target['faculty_id'],
          'target_entry_id': target['entry_id'],
        }),
      );

      if (response.statusCode == 200) {
        _showSwapSnack('Swap request sent!');
        widget.onTimetableChanged?.call();
      } else {
        final body = jsonDecode(response.body);
        _showSwapSnack(body['error'] ?? 'Failed to send swap request.');
      }
    } catch (e) {
      _showSwapSnack('Network error — could not send swap request.');
    } finally {
      if (mounted) {
        setState(() {
          _swapSubmitting = false;
          _swapSourceEntry = null;
        });
      }
    }
  }

  Widget _buildSwapModeToggle() {
    return InkWell(
      onTap: _swapSubmitting ? null : _toggleSwapMode,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _swapModeOn
              ? const Color(0xFF0EA5E9)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _swapModeOn
                ? const Color(0xFF0EA5E9)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_swapSubmitting)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: _swapModeOn ? Colors.white : const Color(0xFF475569),
              ),
            const SizedBox(width: 6),
            Text(
              'Swap',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _swapModeOn ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwapModeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7DD3FC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: Color(0xFF0EA5E9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _swapSourceEntry == null
                  ? (_isAdmin
                        ? 'Swap Mode: tap a period, then tap another to swap them.'
                        : 'Swap Mode: tap one of your own periods to start.')
                  : 'Selected ${_swapSourceEntry!['course_name']} (P${_swapSourceEntry!['period_no']}) — now tap the period to swap with.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1)),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // END new swap mode logic
  // =====================================================================

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- NEW: Swap Mode toggle row, top-right ----
        if (_canUseSwapMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [_buildSwapModeToggle()],
            ),
          ),
        if (_canUseSwapMode && _swapModeOn) _buildSwapModeBanner(),

        Expanded(
          child: SingleChildScrollView(
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
                                      e['day_of_week'] == day &&
                                      e['period_no'] == p,
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
                                        widget.canEdit
                                            ? 'Free Period\n(Tap to add)'
                                            : 'Free Period',
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
                                final isOpenLeave =
                                    entry['status_color'] == 'open_leave';
                                final isSwapped =
                                    entry['status_color'] == 'swapped';
                                final isMySubject =
                                    widget.currentFacultyId > 0 &&
                                    entry['faculty_id'] ==
                                        widget.currentFacultyId;

                                // NEW: highlight if this cell is the selected swap source
                                final isSelectedAsSource =
                                    _swapModeOn &&
                                    _swapSourceEntry != null &&
                                    _swapSourceEntry!['entry_id'] ==
                                        entry['entry_id'];

                                final title = isBreak
                                    ? (entry['label'] ?? 'BREAK')
                                    : (entry['course_name'] ?? 'Free Period');
                                final faculty = entry['faculty_name'] ?? '';
                                final room = entry['room_number'] ?? '';

                                return InkWell(
                                  // NEW: route tap through swap handler when swap mode is on,
                                  // otherwise call the original _handleCellTap unchanged.
                                  onTap: () {
                                    if (_swapModeOn && !isBreak) {
                                      _handleSwapTap(entry);
                                    } else {
                                      _handleCellTap(entry, day, p);
                                    }
                                  },
                                  child: Container(
                                    height: 90,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: _getCellColor(entry, isMySubject),
                                      border: Border.all(
                                        // NEW: blue highlight border when selected as swap source
                                        color: isSelectedAsSource
                                            ? const Color(0xFF0EA5E9)
                                            : _getBorderColor(
                                                entry,
                                                isMySubject,
                                              ),
                                        width: isSelectedAsSource
                                            ? 2.5
                                            : (isMySubject ||
                                                      isOpenLeave ||
                                                      isSwapped
                                                  ? 1.8
                                                  : 0.8),
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
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
                                                          ? Colors
                                                                .green
                                                                .shade900
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
                                            if (room.isNotEmpty &&
                                                !isBreak) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  const Icon(
                                                    Icons.meeting_room,
                                                    size: 10,
                                                    color: Colors.grey,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Room: $room',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color:
                                                          Colors.grey.shade700,
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
                                                    ? swapBorderColor(
                                                        widget.swapColorIndex,
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
                                        // NEW: "SELECTED" badge on the chosen source cell
                                        if (isSelectedAsSource)
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0EA5E9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'SEL',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
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
          ),
        ),
      ],
    );
  }
}
