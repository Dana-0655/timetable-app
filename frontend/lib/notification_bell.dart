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
      case 'swap_request':
      case 'swap_response':
        return Icons.swap_horiz;
      default:
        return Icons.notifications;
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

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (context) => DraggableScrollableSheet(
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
                            final n = notifs[index];
                            final isRead = n['is_read'] == true;
                            return ListTile(
                              leading: Icon(
                                _iconFor(n['notif_type']),
                                color: isRead ? Colors.grey : Colors.blue,
                              ),
                              title: Text(
                                n['message'],
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(n['created_at']),
                              onTap: () async {
                                if (!isRead) {
                                  await http.post(
                                    Uri.parse(
                                      'http://127.0.0.1:5000/mark_notification_read',
                                    ),
                                    headers: {
                                      'Content-Type': 'application/json',
                                    },
                                    body: jsonEncode({
                                      'notification_id': n['notification_id'],
                                    }),
                                  );
                                  _fetchUnreadCount();
                                }
                              },
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
