import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'weekly_matrix_grid_widget.dart';
import 'vercel_bars_timetable_widget.dart';
import 'class_info_dialog.dart';
import 'swap_color_utils.dart';
import 'session_manager.dart';
import 'student_department_screen.dart';
import 'main.dart';

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
  int _selectedViewIndex = 0; // 0 = Grid Matrix, 1 = Vercel Bars
  Map<String, dynamic> _classInfo = {};
  List<dynamic> _entries = [];
  List<dynamic> _updates = [];
  Map<int, int> _swapColorIndex = {};
  bool _isLoading = true;
  bool _bannerDismissed = false;
  bool _isPinned = false;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _checkPinnedStatus();
    _fetchClassData();
  }

  Future<void> _checkPinnedStatus() async {
    final pinned = await SessionManager.getDefaultClass();
    if (mounted) {
      if (mounted) setState(() {
        _isPinned = pinned != null && pinned['classId'] == widget.classId;
      });
    }
  }

  Future<void> _togglePin() async {
    if (_isPinned) {
      await SessionManager.clearDefaultClass();
      if (mounted) {
        if (mounted) setState(() => _isPinned = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Timetable unpinned. You can browse and pin any class.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await SessionManager.saveDefaultClass(
        widget.classId,
        widget.className,
        collegeId: _classInfo['college_id'] is int
            ? _classInfo['college_id']
            : null,
      );
      if (mounted) {
        if (mounted) setState(() => _isPinned = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Pinned! Opening the app as a student will now open ${widget.className} directly.',
            ),
            backgroundColor: const Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchClassData() async {
    //OFFLINE VIEW
    // 1. Instantly load from local device cache if available (Offline Support)
    final cachedData = await SessionManager.getCachedTimetable(widget.classId);
    if (cachedData != null && mounted) {
      final cachedEntries = cachedData['entries'] as List<dynamic>;
      final cachedInfo = cachedData['classInfo'] as Map<String, dynamic>;
      if (mounted) setState(() {
        _entries = cachedEntries;
        _classInfo = cachedInfo;
        _swapColorIndex = buildSwapColorIndex(_entries);
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = true);
    }

    final infoUrl = Uri.parse(
      'http://127.0.0.1:5000/class_info/${widget.classId}',
    );
    final ttUrl = Uri.parse(
      'http://127.0.0.1:5000/timetable/${widget.classId}',
    );
    final updatesUrl = Uri.parse(
      'http://127.0.0.1:5000/class_updates/${widget.classId}',
    );

    bool networkSuccess = false;

    try {
      final infoRes = await http
          .get(infoUrl)
          .timeout(const Duration(seconds: 4));
      if (infoRes.statusCode == 200) {
        _classInfo = jsonDecode(infoRes.body);
      }
    } catch (_) {}

    try {
      final ttRes = await http.get(ttUrl).timeout(const Duration(seconds: 4));
      if (ttRes.statusCode == 200) {
        _entries = jsonDecode(ttRes.body);
        _swapColorIndex = buildSwapColorIndex(_entries);
        networkSuccess = true;
      }
    } catch (_) {}

    try {
      final updatesRes = await http
          .get(updatesUrl)
          .timeout(const Duration(seconds: 4));
      if (updatesRes.statusCode == 200) {
        _updates = jsonDecode(updatesRes.body);
      }
    } catch (_) {}

    if (networkSuccess) {
      // 2. Persist fresh backend data to cache for future offline access
      await SessionManager.saveCachedTimetable(
        widget.classId,
        _entries,
        _classInfo,
      );
    }

    if (mounted) {
      final wasOffline = !networkSuccess && cachedData != null;
      if (mounted) setState(() {
        _isLoading = false;
        _isOfflineMode = wasOffline;
      });

      if (wasOffline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Offline Mode: Displaying saved timetable.'),
              ],
            ),
            backgroundColor: Color(0xFFE65100),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showBulletinModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Color(0xFF1565C0),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Class Bulletin & Updates',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_updates.length} live update${_updates.length == 1 ? '' : 's'} for ${widget.className}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),

                  // List of updates
                  Expanded(
                    child: _updates.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'All classes running on regular schedule.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No substitutions or holiday notices right now.',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _updates.length,
                            itemBuilder: (context, index) {
                              final u = _updates[index];
                              return _buildBulletinCard(u);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBulletinCard(Map<String, dynamic> u) {
    final type = u['type'] ?? '';
    final title = u['title'] ?? 'Notice';
    final message = u['message'] ?? '';
    final createdAt = u['created_at'] ?? '';

    Color iconBg;
    Color iconColor;
    IconData iconData;
    String badgeText;

    switch (type) {
      case 'substitute_confirmed':
        iconBg = Colors.green.shade50;
        iconColor = Colors.green.shade700;
        iconData = Icons.swap_calls_rounded;
        badgeText = 'Substitute';
        break;
      case 'free_period':
        iconBg = Colors.orange.shade50;
        iconColor = Colors.orange.shade800;
        iconData = Icons.hourglass_top_rounded;
        badgeText = 'Leave / Free';
        break;
      case 'swap':
        iconBg = Colors.blue.shade50;
        iconColor = Colors.blue.shade700;
        iconData = Icons.swap_horiz_rounded;
        badgeText = 'Swapped';
        break;
      case 'holiday':
        iconBg = Colors.purple.shade50;
        iconColor = Colors.purple.shade700;
        iconData = Icons.celebration_rounded;
        badgeText = 'Holiday';
        break;
      default:
        iconBg = Colors.grey.shade100;
        iconColor = Colors.grey.shade700;
        iconData = Icons.info_outline;
        badgeText = 'Notice';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (createdAt.isNotEmpty)
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAlertBanner() {
    if (_updates.isEmpty || _bannerDismissed) return const SizedBox.shrink();

    final topUpdate = _updates.first;
    final type = topUpdate['type'] ?? '';
    final message = topUpdate['message'] ?? '';

    Color bannerBg;
    Color borderColor;
    Color textColor;
    IconData iconData;

    switch (type) {
      case 'substitute_confirmed':
        bannerBg = const Color(0xFFE8F5E9);
        borderColor = Colors.green.shade300;
        textColor = Colors.green.shade900;
        iconData = Icons.swap_calls_rounded;
        break;
      case 'free_period':
        bannerBg = const Color(0xFFFFF3E0);
        borderColor = Colors.orange.shade300;
        textColor = Colors.orange.shade900;
        iconData = Icons.hourglass_top_rounded;
        break;
      case 'holiday':
        bannerBg = const Color(0xFFF3E5F5);
        borderColor = Colors.purple.shade300;
        textColor = Colors.purple.shade900;
        iconData = Icons.celebration_rounded;
        break;
      default:
        bannerBg = const Color(0xFFE3F2FD);
        borderColor = Colors.blue.shade300;
        textColor = const Color(0xFF0D47A1);
        iconData = Icons.campaign_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBulletinModal(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(iconData, color: textColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'LIVE BULLETIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: textColor,
                            ),
                          ),
                          if (_updates.length > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '+${_updates.length - 1} more',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'View',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: textColor.withValues(alpha: 0.7),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss Banner',
                  onPressed: () {
                    if (mounted) setState(() => _bannerDismissed = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFE65100),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Offline Mode — Displaying cached timetable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

    final isMobile = MediaQuery.of(context).size.width < 700;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        centerTitle: true,
        actions: [
          // Pin / Unpin Timetable Button
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? Colors.amberAccent : null,
            ),
            tooltip: _isPinned
                ? 'Pinned as Default (Tap to Unpin)'
                : 'Pin this Timetable (Opens automatically on launch)',
            onPressed: _togglePin,
          ),
          // Class Bulletin Notification Bell with active badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.campaign_rounded),
                tooltip: 'Class Bulletin & Live Updates',
                onPressed: () => _showBulletinModal(context),
              ),
              if (_updates.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _updates.length > 9 ? '9+' : '${_updates.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // Browse / Change Class Button
          IconButton(
            icon: const Icon(Icons.apps_rounded),
            tooltip: 'Browse All Classes',
            onPressed: () async {
              final defaultClass = await SessionManager.getDefaultClass();
              final collegeInfo = await SessionManager.getSavedCollegeCode();
              final targetCollegeId =
                  defaultClass?['collegeId'] ?? collegeInfo?['collegeId'];

              if (context.mounted) {
                if (targetCollegeId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          StudentDepartmentScreen(collegeId: targetCollegeId),
                    ),
                  );
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Class Details',
            onPressed: () => showClassInfoDialog(
              context,
              classId: widget.classId,
              className: widget.className,
              canEdit: false,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchClassData,
              child: Column(
                children: [
                  if (_isOfflineMode) _buildOfflineBanner(),

                  // Live Alert Banner (if updates exist)
                  _buildLiveAlertBanner(),

                  // Dark Header Card matching Joz 2x Grid Matrix design
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(12, 4, 12, isMobile ? 6 : 10),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 16,
                      vertical: isMobile ? 8 : 16,
                    ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 15 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 12),

                        // Chips Row: Branch | Room | CC | Pinned Badge
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (_isPinned)
                              Chip(
                                avatar: const Icon(
                                  Icons.push_pin_rounded,
                                  size: 13,
                                  color: Colors.amberAccent,
                                ),
                                label: const Text('Pinned Default'),
                                backgroundColor: Colors.amber.shade900.withValues(
                                  alpha: 0.3,
                                ),
                                labelStyle: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                padding: EdgeInsets.zero,
                              ),
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

                        SizedBox(height: isMobile ? 8 : 14),

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
                            userRole: 'student',
                            currentFacultyId: 0,
                            canEdit: false,
                            swapColorIndex: _swapColorIndex,
                          )
                        : VercelBarsTimetableWidget(
                            classId: widget.classId,
                            className: widget.className,
                            entries: _entries,
                            department: dept,
                            roomNo: room,
                            userRole: 'student',
                            currentFacultyId: 0,
                            swapColorIndex: _swapColorIndex,
                          ),
                  ),
                ],
              ),
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
