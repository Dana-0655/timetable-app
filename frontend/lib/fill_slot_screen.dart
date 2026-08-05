import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final hour = picked.hour.toString().padLeft(2, '0');
      final minute = picked.minute.toString().padLeft(2, '0');
      controller.text = '$hour:$minute';
    }
  }

  Future<void> _save() async {
    if (_startTimeController.text.isEmpty || _endTimeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please set start and end time.');
      return;
    }
    if (widget.entryType == 'period' &&
        _courseNameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a course name.');
      return;
    }
    if (widget.entryType == 'break' && _labelController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter a break name.');
      return;
    }

    setState(() {
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
        setState(() => _errorMessage = 'Could not save. Try again.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not connect to server.');
    }

    setState(() => _isSaving = false);
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
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Start Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              onTap: () => _pickTime(_startTimeController),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _endTimeController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'End Time',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.access_time),
              ),
              onTap: () => _pickTime(_endTimeController),
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
