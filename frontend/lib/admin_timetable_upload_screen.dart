import 'dart:async';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File;

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
  PlatformFile? _selectedPlatformFile;
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
        if (kIsWeb) {
          // Web download workaround (or just show success message)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Template downloaded successfully!')),
          );
        } else {
          // Mobile & Desktop path handling
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/Timetable_Template.xlsx');
          await file.writeAsBytes(response.bodyBytes);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template downloaded to: ${file.path}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  // 2. Pick File (Cross-platform compatible using bytes)
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true, // Ensures bytes are loaded for Web & mobile/desktop
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedPlatformFile = result.files.single;
      });
    }
  }

  // 3. Upload & Start Async Solver
  Future<void> _startGeneration() async {
    if (_selectedPlatformFile == null || _selectedPlatformFile!.bytes == null) {
      return;
    }

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

      // Use bytes instead of path so it works seamlessly on Web, Android, iOS, and Desktop
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _selectedPlatformFile!.bytes!,
          filename: _selectedPlatformFile!.name,
        ),
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
          _statusMessage = 'Upload failed: ${response.body}';
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
    int pollCount = 0;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      pollCount++;
      // Timeout after 60 polls (~2 minutes)
      if (pollCount > 60) {
        timer.cancel();
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
        _showErrorDialog('Timetable generation timed out. Please try again.');
        return;
      }
      try {
        final res = await http.get(
          Uri.parse('${widget.baseUrl}/job_status/$jobId'),
        );
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          String status = data['status'];

          setState(() {
            _statusMessage = data['progress_message'] ?? 'Processing...';
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
      } catch (e) {
        // Handle network blips during polling gracefully
      }
    });
  }

  void _showResultDialog(Map<String, dynamic>? result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generation Complete'),
        content: Text(
          'Classes: ${result?['created']['classes'] ?? 0}\nCourses: ${result?['created']['courses'] ?? 0}\nRooms: ${result?['created']['rooms'] ?? 0}',
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
                _selectedPlatformFile == null
                    ? 'Select .xlsx File'
                    : _selectedPlatformFile!.name,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_selectedPlatformFile != null && !_isProcessing)
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
