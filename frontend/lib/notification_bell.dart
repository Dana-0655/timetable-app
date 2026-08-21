import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationBell extends StatefulWidget {
  final String recipientType; // 'admin' or 'faculty'
  final int recipientId;

  const NotificationBell({
    super.key,
    required this.recipientType,
    required this.recipientId,
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnreadCount();
  }

  Future<void> _fetchUnreadCount() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/unread_notification_count/${widget.recipientType}/${widget.recipientId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _unreadCount = data['count'] ?? 0);
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _resolveFromNotification(
    BuildContext sheetContext,
    Map notif,
    String decision,
    VoidCallback refreshState,
  ) async {
    // Special handling: accepting a CC invite needs to check whether this
    // faculty is already CC somewhere before we let the accept go through.
    if (notif['notif_type'] == 'cc_invite' && decision == 'accepted') {
      final proceed = await _checkCcSwitchBeforeAccept(sheetContext, notif);
      if (!proceed) return;
    }

    String endpoint;
    Map<String, dynamic> body;

    switch (notif['notif_type']) {
      case 'cc_invite':
        endpoint = '/resolve_cc_request';
        body = {'cc_request_id': notif['reference_id'], 'decision': decision};
        break;
      case 'course_invite':
        endpoint = '/resolve_course_faculty_request';
        body = {'cf_request_id': notif['reference_id'], 'decision': decision};
        break;
      case 'substitute_invite':
        endpoint = '/resolve_substitute_invite';
        body = {'cover_req_id': notif['reference_id'], 'decision': decision};
        break;
      default:
        return;
    }

    final url = Uri.parse('http://127.0.0.1:5000$endpoint');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      await http.post(
        Uri.parse('http://127.0.0.1:5000/mark_notification_read'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'notification_id': notif['notification_id']}),
      );

      notif['is_read'] = true;
      _fetchUnreadCount();
      refreshState();

      if (response.statusCode != 200 && sheetContext.mounted) {
        String errorMsg = 'Could not update this request.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded['error'] != null) errorMsg = decoded['error'];
        } catch (_) {}
        ScaffoldMessenger.of(sheetContext).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(
          sheetContext,
        ).showSnackBar(const SnackBar(content: Text('Network error')));
      }
    }
  }

  Future<bool> _checkCcSwitchBeforeAccept(
    BuildContext sheetContext,
    Map notif,
  ) async {
    try {
      final detailRes = await http.get(
        Uri.parse(
          'http://127.0.0.1:5000/cc_request_detail/${notif['reference_id']}',
        ),
      );
      if (detailRes.statusCode != 200) return true;
      final detail = jsonDecode(detailRes.body);

      if (detail['status'] != 'pending') return true;

      final targetClassId = detail['class_id'];
      final targetLabel = '${detail['year']} - ${detail['section']}';

      final currentRes = await http.get(
        Uri.parse(
          'http://127.0.0.1:5000/faculty_current_cc/${widget.recipientId}',
        ),
      );
      if (currentRes.statusCode != 200) return true;
      final current = jsonDecode(currentRes.body);

      if (current['has_cc'] != true) return true;

      final currentClassId = current['class_id'];
      final currentLabel = '${current['year']} - ${current['section']}';

      if (currentClassId == targetClassId) {
        if (sheetContext.mounted) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text('You are already CC for $targetLabel.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return false;
      }

      if (!sheetContext.mounted) return false;
      final confirmed = await showDialog<bool>(
        context: sheetContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Switch CC Class?'),
          content: Text(
            'Do you want to leave your current class counsellor position '
            'from Class $currentLabel and take over Class $targetLabel as CC?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Switch'),
            ),
          ],
        ),
      );

      return confirmed ?? false;
    } catch (e) {
      return true;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'cc_invite':
      case 'cc_response':
        return Icons.admin_panel_settings;
      case 'course_invite':
      case 'course_response':
        return Icons.menu_book;
      case 'cover_confirmed':
      case 'substitute_invite':
      case 'cover_declined':
        return Icons.event_available;
      case 'swap_request':
      case 'swap_response':
      case 'swap_update':
        return Icons.swap_horiz;
      case 'leave_reminder':
      case 'leave_notice':
        return Icons.alarm;
      case 'timetable_generated':
        return Icons.auto_awesome;
      default:
        return Icons.notifications;
    }
  }

  Color _colorFor(String type, bool isRead) {
    if (isRead) return Colors.grey.shade600;
    switch (type) {
      case 'cc_invite':
      case 'cc_response':
        return Colors.indigo;
      case 'course_invite':
      case 'course_response':
        return Colors.blue.shade700;
      case 'cover_confirmed':
        return Colors.green.shade700;
      case 'substitute_invite':
      case 'cover_declined':
      case 'leave_reminder':
      case 'leave_notice':
        return Colors.orange.shade800;
      case 'swap_request':
      case 'swap_response':
      case 'swap_update':
        return Colors.teal.shade700;
      case 'timetable_generated':
        return Colors.purple.shade700;
      default:
        return const Color(0xFF1565C0);
    }
  }

  void _openNotifications() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/notifications/${widget.recipientType}/${widget.recipientId}',
    );
    try {
      final response = await http.get(url);
      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> notifs = jsonDecode(response.body);

        // Filter categories:
        // 'all', 'unread', 'cc', 'courses', 'swaps', 'leaves', 'system'
        String selectedFilter = 'all';
        String selectedSort = 'newest'; // 'newest', 'oldest', 'actionable'

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) => StatefulBuilder(
            builder: (ctx, setSheetState) {
              // 1. Filter logic
              List<dynamic> filtered = notifs.where((n) {
                final type = (n['notif_type'] ?? '').toString();
                final isRead = n['is_read'] == true;

                if (selectedFilter == 'unread') return !isRead;
                if (selectedFilter == 'cc') {
                  return type == 'cc_invite' || type == 'cc_response';
                }
                if (selectedFilter == 'courses') {
                  return type == 'course_invite' || type == 'course_response';
                }
                if (selectedFilter == 'swaps') {
                  return type == 'swap_request' || type == 'swap_response' || type == 'swap_update';
                }
                if (selectedFilter == 'leaves') {
                  return type == 'substitute_invite' ||
                      type == 'cover_confirmed' ||
                      type == 'cover_declined' ||
                      type == 'cover_request' ||
                      type == 'leave_reminder' ||
                      type == 'leave_notice';
                }
                if (selectedFilter == 'system') {
                  return type == 'timetable_generated' ||
                      (!['cc_invite', 'cc_response', 'course_invite', 'course_response', 'swap_request', 'swap_response', 'swap_update', 'substitute_invite', 'cover_confirmed', 'cover_declined', 'cover_request', 'leave_reminder', 'leave_notice'].contains(type));
                }
                return true; // 'all'
              }).toList();

              // 2. Sort logic
              if (selectedSort == 'newest') {
                filtered.sort((a, b) => (b['notification_id'] ?? 0).compareTo(a['notification_id'] ?? 0));
              } else if (selectedSort == 'oldest') {
                filtered.sort((a, b) => (a['notification_id'] ?? 0).compareTo(b['notification_id'] ?? 0));
              } else if (selectedSort == 'actionable') {
                filtered.sort((a, b) {
                  final aActionable = ['cc_invite', 'course_invite', 'substitute_invite'].contains(a['notif_type']) && a['is_read'] != true ? 1 : 0;
                  final bActionable = ['cc_invite', 'course_invite', 'substitute_invite'].contains(b['notif_type']) && b['is_read'] != true ? 1 : 0;
                  return bActionable.compareTo(aActionable);
                });
              }

              final unreadTotal = notifs.where((n) => n['is_read'] != true).length;

              return DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.4,
                maxChildSize: 0.95,
                expand: false,
                builder: (context, scrollController) => Column(
                  children: [
                    // Handle Bar
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),

                    // Top Bar: Title & Mark All Read
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: Color(0xFF1565C0),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (unreadTotal > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$unreadTotal new',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (unreadTotal > 0)
                            TextButton.icon(
                              onPressed: () async {
                                await http.post(
                                  Uri.parse('http://127.0.0.1:5000/mark_all_notifications_read'),
                                  headers: {'Content-Type': 'application/json'},
                                  body: jsonEncode({
                                    'recipient_type': widget.recipientType,
                                    'recipient_id': widget.recipientId,
                                  }),
                                );
                                for (var n in notifs) {
                                  n['is_read'] = true;
                                }
                                _fetchUnreadCount();
                                setSheetState(() {});
                              },
                              icon: const Icon(Icons.done_all_rounded, size: 16),
                              label: const Text(
                                'Mark all read',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Side-by-Side Sort & Category Filter Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Sort Selector Dropdown Button
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedSort,
                                icon: const Icon(Icons.sort_rounded, size: 18),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                                onChanged: (val) {
                                  if (val != null) {
                                    setSheetState(() => selectedSort = val);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'newest',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule_rounded, size: 15, color: Colors.blue),
                                        SizedBox(width: 6),
                                        Text('Newest'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'oldest',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.history_rounded, size: 15, color: Colors.grey),
                                        SizedBox(width: 6),
                                        Text('Oldest'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'actionable',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 15, color: Colors.orange),
                                        SizedBox(width: 6),
                                        Text('Actionable'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Near-by-Near Filter Category Chips
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    label: 'All (${notifs.length})',
                                    isSelected: selectedFilter == 'all',
                                    onTap: () => setSheetState(() => selectedFilter = 'all'),
                                  ),
                                  if (unreadTotal > 0)
                                    _buildFilterChip(
                                      label: 'Unread ($unreadTotal)',
                                      isSelected: selectedFilter == 'unread',
                                      highlightColor: Colors.red.shade50,
                                      selectedColor: Colors.red.shade700,
                                      onTap: () => setSheetState(() => selectedFilter = 'unread'),
                                    ),
                                  _buildFilterChip(
                                    label: 'CC Requests',
                                    icon: Icons.admin_panel_settings_rounded,
                                    isSelected: selectedFilter == 'cc',
                                    onTap: () => setSheetState(() => selectedFilter = 'cc'),
                                  ),
                                  _buildFilterChip(
                                    label: 'Courses',
                                    icon: Icons.menu_book_rounded,
                                    isSelected: selectedFilter == 'courses',
                                    onTap: () => setSheetState(() => selectedFilter = 'courses'),
                                  ),
                                  _buildFilterChip(
                                    label: 'Swaps',
                                    icon: Icons.swap_horiz_rounded,
                                    isSelected: selectedFilter == 'swaps',
                                    onTap: () => setSheetState(() => selectedFilter = 'swaps'),
                                  ),
                                  _buildFilterChip(
                                    label: 'Leaves & Covers',
                                    icon: Icons.event_available_rounded,
                                    isSelected: selectedFilter == 'leaves',
                                    onTap: () => setSheetState(() => selectedFilter = 'leaves'),
                                  ),
                                  _buildFilterChip(
                                    label: 'System',
                                    icon: Icons.auto_awesome_rounded,
                                    isSelected: selectedFilter == 'system',
                                    onTap: () => setSheetState(() => selectedFilter = 'system'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1),

                    // Notification List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_off_outlined,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    selectedFilter == 'all'
                                        ? 'No notifications yet.'
                                        : 'No notifications in this category.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 64,
                                endIndent: 16,
                              ),
                              itemBuilder: (context, index) {
                                final notif = filtered[index];
                                final isRead = notif['is_read'] == true;
                                final isActionable = [
                                      'cc_invite',
                                      'course_invite',
                                      'substitute_invite'
                                    ].contains(notif['notif_type']) &&
                                    notif['reference_id'] != null &&
                                    !isRead;

                                final iconColor = _colorFor(notif['notif_type'] ?? '', isRead);

                                return Container(
                                  color: isRead ? Colors.transparent : const Color(0xFF1565C0).withValues(alpha: 0.04),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: isRead ? Colors.grey.shade100 : iconColor.withValues(alpha: 0.12),
                                      child: Icon(
                                        _iconFor(notif['notif_type'] ?? ''),
                                        color: iconColor,
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(
                                      notif['message'] ?? '',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        color: isRead ? Colors.black87 : Colors.black,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Text(
                                            notif['created_at'] ?? '',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                          if (!isRead) ...[
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF1565C0),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    trailing: isActionable
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: Colors.green,
                                                  size: 26,
                                                ),
                                                tooltip: 'Accept',
                                                onPressed: () => _resolveFromNotification(
                                                  sheetContext,
                                                  notif,
                                                  'accepted',
                                                  () => setSheetState(() {}),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.cancel_rounded,
                                                  color: Colors.red,
                                                  size: 26,
                                                ),
                                                tooltip: 'Reject',
                                                onPressed: () => _resolveFromNotification(
                                                  sheetContext,
                                                  notif,
                                                  'rejected',
                                                  () => setSheetState(() {}),
                                                ),
                                              ),
                                            ],
                                          )
                                        : null,
                                    onTap: () async {
                                      if (!isRead) {
                                        await http.post(
                                          Uri.parse('http://127.0.0.1:5000/mark_notification_read'),
                                          headers: {'Content-Type': 'application/json'},
                                          body: jsonEncode({'notification_id': notif['notification_id']}),
                                        );
                                        notif['is_read'] = true;
                                        _fetchUnreadCount();
                                        setSheetState(() {});
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ).then((_) => _fetchUnreadCount());
      }
    } catch (e) {
      // Silently fail
    }
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? highlightColor,
    Color? selectedColor,
  }) {
    final activeColor = selectedColor ?? const Color(0xFF1565C0);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        avatar: icon != null
            ? Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              )
            : null,
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: activeColor,
        backgroundColor: highlightColor ?? Colors.grey.shade100,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : Colors.grey.shade800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? activeColor : Colors.grey.shade300,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded),
          tooltip: 'Notifications',
          onPressed: _openNotifications,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadCount > 9 ? '9+' : '$_unreadCount',
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
    );
  }
}
