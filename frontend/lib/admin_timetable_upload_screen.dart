import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show File, Directory, Platform;
import 'package:url_launcher/url_launcher.dart';

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
    final downloadUrl = Uri.parse('${widget.baseUrl}/download_timetable_template');
    try {
      if (kIsWeb) {
        if (await canLaunchUrl(downloadUrl)) {
          await launchUrl(downloadUrl, mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Downloading Timetable_Template.xlsx...')),
            );
          }
        }
      } else {
        final response = await http.get(downloadUrl);
        if (response.statusCode == 200) {
          String? downloadsPath;
          if (Platform.isWindows) {
            final userProfile = Platform.environment['USERPROFILE'];
            if (userProfile != null && userProfile.isNotEmpty) {
              downloadsPath = '$userProfile\\Downloads';
            }
          }
          if (downloadsPath == null || !Directory(downloadsPath).existsSync()) {
            final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
            downloadsPath = dir.path;
          }
          final file = File('$downloadsPath\\Timetable_Template.xlsx');
          await file.writeAsBytes(response.bodyBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Template saved to Downloads: ${file.path}'),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Download failed: ${response.statusCode}')),
            );
          }
        }
      }
    } catch (e) {
      try {
        await launchUrl(downloadUrl, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading template... $e')),
        );
      }
    }
  }

  Uint8List? _fileBytes;
  String? _fileName;

  // 2. Pick File (Cross-platform compatible using bytes)
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final picked = result.files.single;
      Uint8List? bytes = picked.bytes;
      if (bytes == null && picked.path != null && picked.path!.isNotEmpty) {
        try {
          bytes = await File(picked.path!).readAsBytes();
        } catch (_) {}
      }
      if (bytes != null) {
        if (mounted) setState(() {
          _fileBytes = bytes;
          _fileName = picked.name;
          _selectedPlatformFile = picked;
        });
      }
    }
  }

  // 3. Upload & Start Async Solver
  Future<void> _startGeneration() async {
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Excel file first.')),
      );
      return;
    }

    if (mounted) setState(() {
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
        http.MultipartFile.fromBytes(
          'file',
          _fileBytes!,
          filename: _fileName ?? 'Timetable.xlsx',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 202) {
        var data = jsonDecode(response.body);
        String jobId = data['job_id'];
        _pollJobStatus(jobId);
      } else {
        if (mounted) setState(() {
          _isProcessing = false;
          _statusMessage = 'Upload failed: ${response.body}';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
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
      // Timeout after 150 polls (~5 minutes)
      if (pollCount > 150) {
        timer.cancel();
        if (mounted) setState(() {
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

          if (mounted) setState(() {
            _statusMessage = data['progress_message'] ?? 'Processing...';
          });

          if (status == 'success') {
            timer.cancel();
            if (mounted) setState(() => _isProcessing = false);
            _showResultDialog(data['result']);
          } else if (status == 'failed') {
            timer.cancel();
            if (mounted) setState(() => _isProcessing = false);
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 26),
            SizedBox(width: 8),
            Text('Generation Successful!'),
          ],
        ),
        content: Text(
          'Timetable generated and saved successfully!\n\n'
          '📌 Classes/Schedules Created: ${result?['created']['classes'] ?? 0}\n'
          '📚 Courses Mapped: ${result?['created']['courses'] ?? 0}\n'
          '🏫 Rooms Allocated: ${result?['created']['rooms'] ?? 0}',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
            child: const Text('View Timetables'),
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
