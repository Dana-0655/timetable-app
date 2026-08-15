import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SwapInboxScreen extends StatefulWidget {
  final int facultyId;

  const SwapInboxScreen({super.key, required this.facultyId});

  @override
  State<SwapInboxScreen> createState() => _SwapInboxScreenState();
}

class _SwapInboxScreenState extends State<SwapInboxScreen> {
  List<dynamic> _requests = [];
  List<dynamic> _responses = [];
  bool _isLoadingRequests = true;
  bool _isLoadingResponses = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
    _fetchResponses();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoadingRequests = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/swap_requests/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
    // Always clear the spinner — a non-200 response or exception must not
    // leave this stuck loading forever.
    setState(() => _isLoadingRequests = false);
  }

  Future<void> _fetchResponses() async {
    setState(() => _isLoadingResponses = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/swap_responses/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _responses = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // Silently fail for now
    }
    setState(() => _isLoadingResponses = false);
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
        _fetchRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Swap Inbox'),
          bottom: TabBar(
            tabs: [
              Tab(
                text: _requests.isEmpty
                    ? 'Requests'
                    : 'Requests (${_requests.length})',
              ),
              const Tab(text: 'Responses'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Requests tab: incoming swap requests needing action
            _isLoadingRequests
                ? const Center(child: CircularProgressIndicator())
                : _requests.isEmpty
                ? const Center(child: Text('No pending swap requests.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _requests.length,
                    itemBuilder: (context, index) {
                      final req = _requests[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'From: ${req['requester_name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Wants: ${req['target_course'] ?? 'Unassigned'} '
                                      '(${req['target_class']}) - ${req['target_slot']}',
                                    ),
                                    Text(
                                      'Offers: ${req['requester_course'] ?? 'Unassigned'} '
                                      '(${req['requester_class']}) - ${req['requester_slot']}',
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Requested: ${req['requested_at'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.check,
                                      color: Colors.green,
                                    ),
                                    onPressed: () => _resolveRequest(
                                      req['swap_id'],
                                      'accepted',
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => _resolveRequest(
                                      req['swap_id'],
                                      'rejected',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            // Responses tab: outcomes of swaps you sent
            _isLoadingResponses
                ? const Center(child: CircularProgressIndicator())
                : _responses.isEmpty
                ? const Center(child: Text('No responses yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _responses.length,
                    itemBuilder: (context, index) {
                      final res = _responses[index];
                      final accepted = res['status'] == 'accepted';
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            accepted ? Icons.check_circle : Icons.cancel,
                            color: accepted ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            'With ${res['target_name']} - ${accepted ? 'Accepted' : 'Rejected'}',
                          ),
                          subtitle: Text(
                            'You offered: ${res['your_course']} '
                            '(${res['your_class']}) - ${res['your_slot']}\n'
                            'For: ${res['their_course']} '
                            '(${res['their_class']}) - ${res['their_slot']}'
                            '${res['rejection_reason'].toString().isNotEmpty ? '\nReason: ${res['rejection_reason']}' : ''}',
                          ),
                          trailing: Text(
                            res['resolved_at'] ?? '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
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
