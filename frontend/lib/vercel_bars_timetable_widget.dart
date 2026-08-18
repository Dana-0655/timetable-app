import 'package:flutter/material.dart';

class VercelBarsTimetableWidget extends StatefulWidget {
  final int classId;
  final String className;
  final String userRole; // 'student', 'faculty', 'admin'
  final int? currentFacultyId;
  final List<dynamic> entries;
  final String department;
  final String roomNo;
  final Function(dynamic entry)? onCellTap;
  final VoidCallback? onRefreshNeeded;

  const VercelBarsTimetableWidget({
    super.key,
    required this.classId,
    required this.className,
    required this.entries,
    required this.department,
    required this.roomNo,
    this.userRole = 'student',
    this.currentFacultyId,
    this.onCellTap,
    this.onRefreshNeeded,
  });

  @override
  State<VercelBarsTimetableWidget> createState() => _VercelBarsTimetableWidgetState();
}

class _VercelBarsTimetableWidgetState extends State<VercelBarsTimetableWidget> {
  String _selectedDay = 'MON';

  final List<Map<String, String>> _days = const [
    {'short': 'MON', 'full': 'Monday'},
    {'short': 'TUE', 'full': 'Tuesday'},
    {'short': 'WED', 'full': 'Wednesday'},
    {'short': 'THU', 'full': 'Thursday'},
    {'short': 'FRI', 'full': 'Friday'},
    {'short': 'SAT', 'full': 'Saturday'},
  ];

  List<dynamic> _getEntriesForDay(String dayShort) {
    final list = widget.entries.where((e) => e['day_of_week'] == dayShort).toList();
    list.sort((a, b) => (a['period_no'] as int? ?? 0).compareTo(b['period_no'] as int? ?? 0));
    return list;
  }

  Color _getStatusBgColor(String? colorType) {
    switch (colorType) {
      case 'open_leave':
        return const Color(0xFFFEF2F2); // Red tint
      case 'confirmed_cover':
        return const Color(0xFFECFDF5); // Emerald tint
      case 'swapped':
        return const Color(0xFFF0F9FF); // Sky tint
      default:
        return Colors.white;
    }
  }

  Color _getStatusBorderColor(String? colorType) {
    switch (colorType) {
      case 'open_leave':
        return const Color(0xFFFCA5A5);
      case 'confirmed_cover':
        return const Color(0xFF6EE7B7);
      case 'swapped':
        return const Color(0xFF7DD3FC);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  Widget _buildStatusBadge(String? colorType, String? facultyName) {
    switch (colorType) {
      case 'open_leave':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'ABSENT • OPEN',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case 'confirmed_cover':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                'COVERED: ${facultyName ?? "Substitute"}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      case 'swapped':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.swap_horiz_rounded, size: 12, color: Colors.white),
              SizedBox(width: 4),
              Text(
                'SWAPPED',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      default:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'SCHEDULED',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayEntries = _getEntriesForDay(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day selector tabs bar (Vercel style dark pills)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _days.map((day) {
              final isSelected = _selectedDay == day['short'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(
                    day['short']!,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF8FAFC),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDay = day['short']!);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Timeline Vercel Bars
        if (dayEntries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.calendar_today_outlined, size: 40, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'No schedule entries set for this day.',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dayEntries.length,
            itemBuilder: (context, index) {
              final entry = dayEntries[index];
              final isBreak = entry['entry_type'] == 'break';
              final courseName = entry['course_name'] ?? (isBreak ? (entry['label'] ?? 'BREAK') : 'Unassigned Slot');
              final facultyName = entry['faculty_name'] ?? 'No Faculty Assigned';
              final statusColor = entry['status_color'] ?? 'normal';
              final startTime = entry['start_time'] ?? '00:00';
              final endTime = entry['end_time'] ?? '00:00';
              final periodNo = entry['period_no'] ?? (index + 1);

              if (isBreak) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.coffee_rounded, size: 18, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              courseName.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (startTime != '00:00')
                              Text(
                                '$startTime - $endTime',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return InkWell(
                onTap: () => widget.onCellTap?.call(entry),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusBgColor(statusColor),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusBorderColor(statusColor), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Period badge & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PERIOD $periodNo',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (startTime != '00:00') ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$startTime - $endTime',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          _buildStatusBadge(statusColor, facultyName),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Middle: Course Name
                      Text(
                        courseName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom: Faculty info & Room info
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              facultyName,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (widget.roomNo.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.meeting_room_rounded, size: 12, color: Color(0xFF6D28D9)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Room ${widget.roomNo}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6D28D9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
