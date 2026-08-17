import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HolidayManagementScreen extends StatefulWidget {
  final int collegeId;

  const HolidayManagementScreen({super.key, required this.collegeId});

  @override
  State<HolidayManagementScreen> createState() =>
      _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  List<dynamic> _holidays = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
  }

  Future<void> _fetchHolidays() async {
    setState(() => _isLoading = true);
    final url = Uri.parse('http://127.0.0.1:5000/holidays/${widget.collegeId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _holidays = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _isoDate(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '${date.year}-$m-$d';
  }

  void _showMarkHolidayDialog() {
    DateTime selectedDate = DateTime.now();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Mark a Holiday'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(_isoDate(selectedDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDate = picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (e.g. Festival, College Day)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _markHoliday(
                  _isoDate(selectedDate),
                  reasonController.text,
                );
              },
              child: const Text('Mark Holiday'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markHoliday(String date, String reason) async {
    final url = Uri.parse('http://127.0.0.1:5000/mark_holiday');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'college_id': widget.collegeId,
          'holiday_date': date,
          'reason': reason,
        }),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response.statusCode == 200
                  ? (data['message'] ?? 'Holiday marked!')
                  : (data['error'] ?? 'Could not mark holiday.'),
            ),
          ),
        );
      }
      if (response.statusCode == 200) _fetchHolidays();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  void _confirmDelete(int holidayId, String date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Holiday'),
        content: Text('Unmark $date as a holiday?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteHoliday(holidayId);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteHoliday(int holidayId) async {
    final url = Uri.parse('http://127.0.0.1:5000/delete_holiday');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'holiday_id': holidayId}),
      );
      if (response.statusCode == 200) {
        _fetchHolidays();
      }
    } catch (e) {
      // Silently fail for now
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Holidays')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _holidays.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No holidays marked yet. Tap + to mark one.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _holidays.length,
              itemBuilder: (context, index) {
                final h = _holidays[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.beach_access,
                      color: Colors.orange,
                    ),
                    title: Text(h['holiday_date']),
                    subtitle: Text(
                      (h['reason'] as String).isEmpty
                          ? 'No reason given'
                          : h['reason'],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _confirmDelete(h['holiday_id'], h['holiday_date']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showMarkHolidayDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
