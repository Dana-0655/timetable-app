import 'package:flutter/material.dart';
import 'schedule_builder_screen.dart';
import 'weekly_matrix_grid_widget.dart';

class AdminTimetableViewScreen extends StatefulWidget {
  final int classId;
  final String className;

  const AdminTimetableViewScreen({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<AdminTimetableViewScreen> createState() =>
      _AdminTimetableViewScreenState();
}

class _AdminTimetableViewScreenState extends State<AdminTimetableViewScreen> {
  final GlobalKey _matrixKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - Matrix Grid Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            tooltip: 'Build / Edit Schedule',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ScheduleBuilderScreen(
                    classId: widget.classId,
                    className: widget.className,
                    dayOfWeek: 'MON',
                  ),
                ),
              );
              if (result == true) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: WeeklyMatrixGridWidget(
          key: _matrixKey,
          classId: widget.classId,
          className: widget.className,
          userRole: 'admin',
        ),
      ),
    );
  }
}
