import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FacultySwapResponsesScreen extends StatefulWidget {
  final int facultyId;

  const FacultySwapResponsesScreen({super.key, required this.facultyId});

  @override
  State<FacultySwapResponsesScreen> createState() =>
      _FacultySwapResponsesScreenState();
}

class _FacultySwapResponsesScreenState
    extends State<FacultySwapResponsesScreen> {
  List<dynamic> _incoming = [];
  List<dynamic> _sent = [];
  bool _isLoadingIncoming = true;
  bool _isLoadingSent = true;

  @override
  void initState() {
    super.initState();
    _fetchIncoming();
    _fetchSent();
  }

  Future<void> _fetchIncoming() async {
    setState(() => _isLoadingIncoming = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/swap_requests/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _incoming = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
    // Always clear the spinner, even on a non-200 response or exception —
    // otherwise a backend error leaves this stuck loading forever.
    setState(() => _isLoadingIncoming = false);
  }

  Future<void> _fetchSent() async {
    setState(() => _isLoadingSent = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/my_sent_swap_requests/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _sent = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
    setState(() => _isLoadingSent = false);
  }

  Future<void> _resolveRequest(int swapId, String decision) async {
    final url = Uri.parse('http://127.0.0.1:5000/resolve_swap_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'swap_id': swapId, 'decision': decision}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Swap $decision!')
                  : (data['error'] ?? 'Could not resolve request.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) {
        _fetchIncoming();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;
    switch (status) {
      case 'accepted':
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Swap Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests to You'),
              Tab(text: 'Sent by You'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // --- Requests to You (act on them) ---
            _isLoadingIncoming
                ? const Center(child: CircularProgressIndicator())
                : _incoming.isEmpty
                ? const Center(child: Text('No pending swap requests.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _incoming.length,
                    itemBuilder: (context, index) {
                      final req = _incoming[index];
                      return Card(
                        child: ListTile(
                          title: Text('From: ${req['requester_name']}'),
                          subtitle: Text(
                            'Wants: ${req['target_class']} \u2022 ${req['target_slot']}'
                            '${req['target_course'] != null ? ' \u2022 ${req['target_course']}' : ''}\n'
                            'Offers: ${req['requester_class']} \u2022 ${req['requester_slot']}'
                            '${req['requester_course'] != null ? ' \u2022 ${req['requester_course']}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.check,
                                  color: Colors.green,
                                ),
                                onPressed: () =>
                                    _resolveRequest(req['swap_id'], 'accepted'),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () =>
                                    _resolveRequest(req['swap_id'], 'rejected'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            // --- Sent by You (read-only status) ---
            _isLoadingSent
                ? const Center(child: CircularProgressIndicator())
                : _sent.isEmpty
                ? const Center(
                    child: Text('You haven\'t sent any swap requests.'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _sent.length,
                    itemBuilder: (context, index) {
                      final req = _sent[index];
                      return Card(
                        child: ListTile(
                          title: Text('To: ${req['target_name']}'),
                          subtitle: Text(
                            'You offer: ${req['requester_class']} \u2022 ${req['requester_slot']}'
                            '${req['requester_course'] != null ? ' \u2022 ${req['requester_course']}' : ''}\n'
                            'You want: ${req['target_class']} \u2022 ${req['target_slot']}'
                            '${req['target_course'] != null ? ' \u2022 ${req['target_course']}' : ''}'
                            '${req['status'] == 'rejected' && (req['rejection_reason'] ?? '').isNotEmpty ? '\nReason: ${req['rejection_reason']}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: _statusChip(req['status']),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
