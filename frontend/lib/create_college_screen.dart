import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session_manager.dart';
import 'admin_dashboard_screen.dart';

class CreateCollegeScreen extends StatefulWidget {
  const CreateCollegeScreen({super.key});

  @override
  State<CreateCollegeScreen> createState() => _CreateCollegeScreenState();
}

class _CreateCollegeScreenState extends State<CreateCollegeScreen> {
  final _collegeNameController = TextEditingController();
  final _collegeCodeController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _departmentController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _createCollege() async {
    if (_collegeNameController.text.trim().isEmpty ||
        _collegeCodeController.text.trim().isEmpty ||
        _adminNameController.text.trim().isEmpty ||
        _adminEmailController.text.trim().isEmpty ||
        _adminPasswordController.text.isEmpty) {
      if (mounted) setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    if (mounted) setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse('http://127.0.0.1:5000/create_college_and_admin');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'college_name': _collegeNameController.text.trim(),
          'college_code': _collegeCodeController.text.trim(),
          'admin_name': _adminNameController.text.trim(),
          'admin_email': _adminEmailController.text.trim(),
          'admin_password': _adminPasswordController.text,
          'department_name': _departmentController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await SessionManager.saveCollegeCode(
          _collegeCodeController.text.trim(),
          data['college_id'],
        );
        await SessionManager.saveAdminSession(
          data['admin_id'],
          data['admin_name'],
          data['college_id'],
        );
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => AdminDashboardScreen(
                adminId: data['admin_id'],
                adminName: data['admin_name'],
                collegeId: data['college_id'],
              ),
            ),
            (route) => false,
          );
        }
      } else {
        if (mounted) setState(() {
          _errorMessage = data['error'] ?? 'Could not create college.';
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _errorMessage = 'Could not connect to server.';
      });
    }

    if (mounted) setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Your College')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'College Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _collegeNameController,
              decoration: const InputDecoration(
                labelText: 'College Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _collegeCodeController,
              decoration: const InputDecoration(
                labelText: 'Choose a College Code (e.g. ABC123)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Admin Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Department',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminEmailController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _adminPasswordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    if (mounted) setState(() => _obscurePassword = !_obscurePassword);
                  },
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
                onPressed: _isLoading ? null : _createCollege,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create College & Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
