import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'notification_bell.dart';

class AdminAddFacultyScreen extends StatefulWidget {
  final int adminId;
  final int collegeId;

  const AdminAddFacultyScreen({
    super.key,
    required this.adminId,
    required this.collegeId,
  });

  @override
  State<AdminAddFacultyScreen> createState() => _AdminAddFacultyScreenState();
}

class _AdminAddFacultyScreenState extends State<AdminAddFacultyScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _expertiseController = TextEditingController();

  bool _isSaving = false;
  List<String> _addedNames = [];
  

  Future<void> _addFaculty() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Name, Email, and Password.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final url = Uri.parse('http://127.0.0.1:5000/admin_create_faculty');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'admin_id': widget.adminId,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'subject_expertise': _expertiseController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _addedNames.insert(0, _nameController.text.trim());
        });
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _expertiseController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${data['message']} Add another below.')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['error'] ?? 'Could not add faculty.')),
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

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Faculty Accounts')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add faculty one at a time — form clears after each save so you can keep adding.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Temporary Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expertiseController,
              decoration: const InputDecoration(
                labelText: 'Subject Expertise (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _addFaculty,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Add Faculty'),
              ),
            ),
            const SizedBox(height: 24),
            if (_addedNames.isNotEmpty) ...[
              const Text(
                'Added this session:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _addedNames.length,
                  itemBuilder: (context, index) => Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(_addedNames[index]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
