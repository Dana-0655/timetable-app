import 'package:flutter/material.dart';

class FutureAbsentCalendarDialog extends StatefulWidget {
  final int facultyId;
  final String facultyName;

  const FutureAbsentCalendarDialog({
    super.key,
    required this.facultyId,
    required this.facultyName,
  });

  @override
  State<FutureAbsentCalendarDialog> createState() => _FutureAbsentCalendarDialogState();
}

class _FutureAbsentCalendarDialogState extends State<FutureAbsentCalendarDialog> {
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Mark Future Absent (${widget.facultyName})'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select a date in the future to report absence:'),
          const SizedBox(height: 16),
          ListTile(
            title: Text(
              _selectedDate == null
                  ? 'No date selected'
                  : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (date != null) {
                if (mounted) setState(() {
                  _selectedDate = date;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedDate == null
              ? null
              : () {
                  // Handle submission logic here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Future absence marked for ${_selectedDate.toString().split(' ')[0]}'),
                    ),
                  );
                  Navigator.pop(context, true);
                },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
