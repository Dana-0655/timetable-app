import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'swap_inbox_screen.dart';

class SwapInboxIcon extends StatefulWidget {
  final int facultyId;

  const SwapInboxIcon({super.key, required this.facultyId});

  @override
  State<SwapInboxIcon> createState() => _SwapInboxIconState();
}

class _SwapInboxIconState extends State<SwapInboxIcon> {
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPendingCount();
  }

  Future<void> _fetchPendingCount() async {
    final url = Uri.parse(
      'http://127.0.0.1:5000/swap_requests/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) setState(() => _pendingCount = data.length);
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
          icon: const Icon(Icons.swap_horiz),
          tooltip: 'Swap Inbox',
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SwapInboxScreen(facultyId: widget.facultyId),
              ),
            );
            _fetchPendingCount();
          },
        ),
        if (_pendingCount > 0)
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
                '$_pendingCount',
                style: const TextStyle(color: Colors.white, fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
