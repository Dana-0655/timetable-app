import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FillSlotScreen extends StatefulWidget {
  final int entryId;
  final String entryType;
  final bool isEdit;
  final String? existingCourseName;
  final String? existingCourseCode;
  final String? existingLabel;
  final String? existingStartTime;
  final String? existingEndTime;

  const FillSlotScreen({
    super.key,
    required this.entryId,
    required this.entryType,
    this.isEdit = false,
    this.existingCourseName,
    this.existingCourseCode,
    this.existingLabel,
    this.existingStartTime,
    this.existingEndTime,
  });

  @override
  State<FillSlotScreen> createState() => _FillSlotScreenState();
}

class _FillSlotScreenState extends State<FillSlotScreen> {
  late TextEditingController _courseNameController;
  late TextEditingController _courseCodeController;
  late TextEditingController _labelController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _courseNameController = TextEditingController(
      text: widget.existingCourseName ?? '',
    );
    _courseCodeController = TextEditingController(
      text: widget.existingCourseCode ?? '',
    );
    _labelController = TextEditingController(text: widget.existingLabel ?? '');
    _startTimeController = TextEditingController(
      text: widget.existingStartTime ?? '',
    );
    _endTimeController = TextEditingController(
      text: widget.existingEndTime ?? '',
    );
  }

  Future<void> _pickTime(TextEditingController controller) async {
    TimeOfDay initial = TimeOfDay.now();

    // Try to use last-used time as default
    final prefs = await SharedPreferences.getInstance();
    final lastHour = prefs.getInt('last_hour');
    final lastMinute = prefs.getInt('last_minute');
    if (lastHour != null && lastMinute != null) {
      initial = TimeOfDay(hour: lastHour, minute: lastMinute);
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await prefs.setInt('last_hour', picked.hour);
      await prefs.setInt('last_minute', picked.minute);

      final hour12 = picked.hourOfPeriod == 0 ? 12 : picked.hourOfPeriod;
      final minute = picked.minute.toString().padLeft(2, '0');
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      controller.text = '$hour12:$minute $period';
    }
  }

  Future<void> _save() async {
    if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
      if (mounted) setState(() => _errorMessage = 'Please set start and end time.');
      return;
    }
    if (widget.entryType == 'period' &&
        _courseNameController.text.trim().isEmpty) {
      if (mounted) setState(() => _errorMessage = 'Please enter a course name.');
      return;
    }
    if (widget.entryType == 'break' && _labelController.text.trim().isEmpty) {
      if (mounted) setState(() => _errorMessage = 'Please enter a break name.');
      return;
    }

    if (mounted) setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final isPeriod = widget.entryType == 'period';
    String endpoint;
    if (isPeriod) {
      endpoint = widget.isEdit ? 'update_period_slot' : 'fill_period_slot';
    } else {
      endpoint = widget.isEdit ? 'update_break_slot' : 'fill_break_slot';
    }
    final url = Uri.parse('http://127.0.0.1:5000/$endpoint');

    final body = isPeriod
        ? {
            'entry_id': widget.entryId,
            'course_name': _courseNameController.text.trim(),
            'course_code': _courseCodeController.text.trim(),
            'start_time': _startTimeController.text,
            'end_time': _endTimeController.text,
          }
        : {
            'entry_id': widget.entryId,
            'label': _labelController.text.trim(),
            'start_time': _startTimeController.text,
            'end_time': _endTimeController.text,
          };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) setState(() => _errorMessage = 'Could not save. Try again.');
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not connect to server.');
    }

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isPeriod = widget.entryType == 'period';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.isEdit ? "Edit" : "Fill"} ${isPeriod ? "Period" : "Break"}',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPeriod) ...[
              TextField(
                controller: _courseNameController,
                decoration: const InputDecoration(
                  labelText: 'Course Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _courseCodeController,
                decoration: const InputDecoration(
                  labelText: 'Course Code (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              TextField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Break Name (e.g. Lunch)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _startTimeController,
              decoration: InputDecoration(
                labelText: 'Start Time (e.g. 9:30 AM)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(_startTimeController),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endTimeController,
              decoration: InputDecoration(
                labelText: 'End Time (e.g. 9:30 AM)',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: () => _pickTime(_endTimeController),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
