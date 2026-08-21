import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Shows a class's details — CC (auto-derived, never manually entered),
/// branch/department, and room number — in a dialog.
///
/// Pass [canEdit] = true for Admin or that class's own CC; they'll get an
/// edit icon to update the room number. Everyone else sees a read-only view.
Future<void> showClassInfoDialog(
  BuildContext context, {
  required int classId,
  required String className,
  bool canEdit = false,
}) async {
  final url = Uri.parse('http://127.0.0.1:5000/class_info/$classId');
  try {
    final response = await http.get(url);
    if (response.statusCode != 200) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load class details.')),
        );
      }
      return;
    }
    final data = jsonDecode(response.body);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => _ClassInfoDialogContent(
        classId: classId,
        className: className,
        initialData: data,
        canEdit: canEdit,
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not connect to server.')),
      );
    }
  }
}

class _ClassInfoDialogContent extends StatefulWidget {
  final int classId;
  final String className;
  final Map<String, dynamic> initialData;
  final bool canEdit;

  const _ClassInfoDialogContent({
    required this.classId,
    required this.className,
    required this.initialData,
    required this.canEdit,
  });

  @override
  State<_ClassInfoDialogContent> createState() =>
      _ClassInfoDialogContentState();
}

class _ClassInfoDialogContentState extends State<_ClassInfoDialogContent> {
  late Map<String, dynamic> _data;
  bool _isEditingRoom = false;
  late TextEditingController _roomController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData;
    _roomController = TextEditingController(text: _data['room_number'] ?? '');
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _saveRoomNumber() async {
    if (mounted) setState(() => _isSaving = true);
    final url = Uri.parse('http://127.0.0.1:5000/update_class_room');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'class_id': widget.classId,
          'room_number': _roomController.text.trim(),
        }),
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() {
          _data['room_number'] = _roomController.text.trim();
          _isEditingRoom = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update room number.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final ccName = _data['cc_name'];
    final department = _data['department'] ?? '';
    final roomNumber = _data['room_number'] as String?;

    return AlertDialog(
      title: Text('${widget.className} - Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
            title: Text(ccName ?? 'No CC assigned yet'),
            subtitle: const Text('Class Counselor'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_tree, color: Colors.blue),
            title: Text(department),
            subtitle: const Text('Branch / Department'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.meeting_room, color: Colors.blue),
            title: _isEditingRoom
                ? TextField(
                    controller: _roomController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Block A - 204',
                    ),
                  )
                : Text(
                    (roomNumber == null || roomNumber.isEmpty)
                        ? 'Not set'
                        : roomNumber,
                  ),
            subtitle: const Text('Room Number'),
            trailing: !widget.canEdit
                ? null
                : _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(
                      _isEditingRoom ? Icons.check : Icons.edit,
                      size: 20,
                    ),
                    onPressed: () {
                      if (_isEditingRoom) {
                        _saveRoomNumber();
                      } else {
                        if (mounted) setState(() => _isEditingRoom = true);
                      }
                    },
                  ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
