import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class AdminTimetableUploadScreen extends StatefulWidget {
  final int collegeId;
  final int semesterId;
  final String baseUrl;

  const AdminTimetableUploadScreen({
    Key? key,
    required this.collegeId,
    required this.semesterId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  _AdminTimetableUploadScreenState createState() =>
      _AdminTimetableUploadScreenState();
}

class _AdminTimetableUploadScreenState
    extends State<AdminTimetableUploadScreen> {
  File? _selectedFile;
  bool _isProcessing = false;
  String _statusMessage = '';
  Timer? _pollingTimer;

  // 1. Download Excel Template
  Future<void> _downloadTemplate() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/download_timetable_template'),
      );
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/Timetable_Template.xlsx');
        await file.writeAsBytes(response.bodyBytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template downloaded to: ${file.path}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  // 2. Pick File
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  // 3. Upload & Start Async Solver
  Future<void> _startGeneration() async {
    if (_selectedFile == null) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Uploading file...';
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${widget.baseUrl}/upload_and_generate_timetable_async'),
      );
      request.fields['college_id'] = widget.collegeId.toString();
      request.fields['semester_id'] = widget.semesterId.toString();
      request.files.add(
        await http.MultipartFile.fromPath('file', _selectedFile!.path),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202) {
        var data = jsonDecode(response.body);
        String jobId = data['job_id'];
        _pollJobStatus(jobId);
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Upload failed.';
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  // 4. Poll Job Endpoint
  void _pollJobStatus(String jobId) {
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final res = await http.get(
        Uri.parse('${widget.baseUrl}/job_status/$jobId'),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        String status = data['status'];

        setState(() {
          _statusMessage = data['progress_message'] ?? '';
        });

        if (status == 'success') {
          timer.cancel();
          setState(() => _isProcessing = false);
          _showResultDialog(data['result']);
        } else if (status == 'failed') {
          timer.cancel();
          setState(() => _isProcessing = false);
          _showErrorDialog(data['error']);
        }
      }
    });
  }

  void _showResultDialog(Map<String, dynamic>? result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generation Complete'),
        content: Text(
          'Classes: ${result?['created']['classes']}\nCourses: ${result?['created']['courses']}\nRooms: ${result?['created']['rooms']}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String? error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generation Failed'),
        content: Text(error ?? 'Unknown error occurred.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload & Generate Timetable')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.download),
              label: const Text('Download Excel Template'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.file_upload),
              label: Text(
                _selectedFile == null
                    ? 'Select .xlsx File'
                    : _selectedFile!.path.split('/').last,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_selectedFile != null && !_isProcessing)
                  ? _startGeneration
                  : null,
              child: const Text('Generate Timetable'),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 30),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
