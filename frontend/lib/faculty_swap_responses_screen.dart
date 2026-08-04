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
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/swap_requests/${widget.facultyId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _requests = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveRequest(int swapId, String decision) async {
    final url = Uri.parse('http://127.0.0.1:5000/resolve_swap_request');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'swap_id': swapId, 'decision': decision}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Swap $decision!')));
        }
        _fetchRequests();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Swap Requests')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? const Center(child: Text('No pending swap requests.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return Card(
                  child: ListTile(
                    title: Text('From: ${req['requester_name']}'),
                    subtitle: Text(
                      'Wants: ${req['target_slot']}\nOffers: ${req['requester_slot']}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () =>
                              _resolveRequest(req['swap_id'], 'accepted'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              _resolveRequest(req['swap_id'], 'rejected'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
