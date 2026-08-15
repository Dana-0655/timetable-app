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
        if (mounted) setState(() => _unreadCount = data['count']);
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  Future<void> _resolveFromNotification(
    BuildContext sheetContext,
    Map notif,
    String decision,
  ) async {
    // Special handling: accepting a CC invite needs to check whether this
    // faculty is already CC somewhere before we let the accept go through.
    if (notif['notif_type'] == 'cc_invite' && decision == 'accepted') {
      final proceed = await _checkCcSwitchBeforeAccept(sheetContext, notif);
      if (!proceed) return; // blocked, or user cancelled the switch dialog
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

      if (response.statusCode == 200) {
        await http.post(
          Uri.parse('http://127.0.0.1:5000/mark_notification_read'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'notification_id': notif['notification_id']}),
        );
        _fetchUnreadCount();
        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      } else {
        // Whatever the reason (already resolved, etc.) this notification's
        // action is no longer valid - mark it read so it stops looking active.
        await http.post(
          Uri.parse('http://127.0.0.1:5000/mark_notification_read'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'notification_id': notif['notification_id']}),
        );
        _fetchUnreadCount();

        if (sheetContext.mounted) {
          String errorMsg = 'Could not update this request.';
          try {
            final decoded = jsonDecode(response.body);
            if (decoded['error'] != null) errorMsg = decoded['error'];
          } catch (_) {
            // keep the default message if body isn't valid JSON
          }
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (sheetContext.mounted) {
        ScaffoldMessenger.of(
          sheetContext,
        ).showSnackBar(const SnackBar(content: Text('Network error')));
      }
    }
  }

  /// Returns true if the accept should proceed, false if it should be
  /// blocked or the user cancelled.
  Future<bool> _checkCcSwitchBeforeAccept(
    BuildContext sheetContext,
    Map notif,
  ) async {
    try {
      // 1. Find out which class this invite is actually for
      final detailRes = await http.get(
        Uri.parse(
          'http://127.0.0.1:5000/cc_request_detail/${notif['reference_id']}',
        ),
      );
      if (detailRes.statusCode != 200)
        return true; // let backend reject it normally
      final detail = jsonDecode(detailRes.body);

      if (detail['status'] != 'pending') {
        // Already resolved (e.g. a duplicate invite) - let the normal
        // "already resolved" error path handle the message.
        return true;
      }

      final targetClassId = detail['class_id'];
      final targetLabel = '${detail['year']} - ${detail['section']}';

      // 2. Find out if this faculty is already CC somewhere
      final currentRes = await http.get(
        Uri.parse(
          'http://127.0.0.1:5000/faculty_current_cc/${widget.recipientId}',
        ),
      );
      if (currentRes.statusCode != 200) return true;
      final current = jsonDecode(currentRes.body);

      if (current['has_cc'] != true) {
        return true; // not CC anywhere yet, safe to accept directly
      }

      final currentClassId = current['class_id'];
      final currentLabel = '${current['year']} - ${current['section']}';

      // 3. Same class -> block, nothing to do
      if (currentClassId == targetClassId) {
        if (sheetContext.mounted) {
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(
              content: Text('You are already CC for $targetLabel.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        return false;
      }

      // 4. Different class -> confirm the switch
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
      // If any of these checks fail, don't block the user - fall back to
      // letting the backend's own validation handle it.
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
        return Icons.event_available;

      default:
        return Icons.notifications;
    }
  }

  Widget _buildNotificationTile(BuildContext sheetContext, Map notif) {
    final isRead = notif['is_read'] == true;
    final isActionable =
        ['cc_invite', 'course_invite'].contains(notif['notif_type']) &&
        notif['reference_id'] != null &&
        !isRead;

    return ListTile(
      leading: Icon(
        _iconFor(notif['notif_type']),
        color: isRead ? Colors.grey : Colors.blue,
      ),
      title: Text(
        notif['message'],
        style: TextStyle(
          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(notif['created_at']),
      trailing: isActionable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  tooltip: 'Accept',
                  onPressed: () =>
                      _resolveFromNotification(sheetContext, notif, 'accepted'),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  tooltip: 'Reject',
                  onPressed: () =>
                      _resolveFromNotification(sheetContext, notif, 'rejected'),
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
          _fetchUnreadCount();
        }
      },
    );
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

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Notifications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: notifs.isEmpty
                      ? const Center(child: Text('No notifications yet.'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: notifs.length,
                          itemBuilder: (context, index) {
                            return _buildNotificationTile(
                              sheetContext,
                              notifs[index],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ).then((_) => _fetchUnreadCount());
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          tooltip: 'Notifications',
          onPressed: _openNotifications,
        ),
        if (_unreadCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
