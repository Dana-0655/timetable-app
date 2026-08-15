import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'date_helpers.dart';

class ScheduleBuilderScreen extends StatefulWidget {
  final int classId;
  final String className;
  final String dayOfWeek;

  const ScheduleBuilderScreen({
    super.key,
    required this.classId,
    required this.className,
    required this.dayOfWeek,
  });

  @override
  State<ScheduleBuilderScreen> createState() => _ScheduleBuilderScreenState();
}

class _ScheduleBuilderScreenState extends State<ScheduleBuilderScreen> {
  int _numPeriods = 5;
  int _numBreaks = 1;
  List<String> _slotOrder = [];
  bool _showOrderStep = false;
  bool _isSaving = false;

  void _buildInitialOrder() {
    _slotOrder = [];
    for (int i = 0; i < _numPeriods; i++) {
      _slotOrder.add('period');
    }
    for (int i = 0; i < _numBreaks; i++) {
      _slotOrder.add('break');
    }
    setState(() {
      _showOrderStep = true;
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _slotOrder.removeAt(oldIndex);
      _slotOrder.insert(newIndex, item);
    });
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    final url = Uri.parse('http://127.0.0.1:5000/generate_schedule');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'class_id': widget.classId,
          'day_of_week': widget.dayOfWeek,
          'slot_order': _slotOrder,
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true); // true = schedule was created
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Make Schedule - ${widget.dayOfWeek}'),
            Text(
              DateHelpers.labelForDayCode(widget.dayOfWeek),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: _showOrderStep ? _buildOrderStep() : _buildCountStep(),
    );
  }

  Widget _buildCountStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Class: ${widget.className}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          const Text(
            'Number of Periods',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _numPeriods.toDouble(),
            min: 1,
            max: 12,
            divisions: 11,
            label: '$_numPeriods',
            onChanged: (value) {
              setState(() => _numPeriods = value.round());
            },
          ),
          Text(
            '$_numPeriods periods',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          const Text(
            'Number of Breaks',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Slider(
            value: _numBreaks.toDouble(),
            min: 0,
            max: 4,
            divisions: 4,
            label: '$_numBreaks',
            onChanged: (value) {
              setState(() => _numBreaks = value.round());
            },
          ),
          Text(
            '$_numBreaks breaks',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _buildInitialOrder,
            child: const Text('Next: Arrange Order'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStep() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: const Text(
            'Drag to arrange the order of periods and breaks',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _slotOrder.length,
            onReorder: _reorder,
            itemBuilder: (context, index) {
              final type = _slotOrder[index];
              final isBreak = type == 'break';
              return Card(
                key: ValueKey('slot_$index\_$type'),
                color: isBreak ? Colors.grey.shade200 : Colors.white,
                child: ListTile(
                  leading: Icon(isBreak ? Icons.free_breakfast : Icons.book),
                  title: Text(isBreak ? 'Break' : 'Period ${index + 1}'),
                  trailing: const Icon(Icons.drag_handle),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSchedule,
              child: _isSaving
                  ? const CircularProgressIndicator()
                  : const Text('Save Schedule Structure'),
            ),
          ),
        ),
      ],
    );
  }
}
