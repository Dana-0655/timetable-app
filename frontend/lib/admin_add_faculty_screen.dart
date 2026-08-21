import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


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
  bool _isLoadingList = false;
  List<dynamic> _existingFaculty = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadExistingFaculty();
  }

  Future<void> _loadExistingFaculty() async {
    if (mounted) setState(() => _isLoadingList = true);
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:5000/faculty_list/${widget.collegeId}'),
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() {
          _existingFaculty = jsonDecode(response.body);
        });
      }
    } catch (e) {
      // ignore connection blips
    }
    if (mounted) setState(() => _isLoadingList = false);
  }

  Future<void> _addFaculty() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill Name, User ID, and Password.')),
      );
      return;
    }

    if (mounted) setState(() => _isSaving = true);

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
        _nameController.clear();
        _emailController.clear();
        _passwordController.clear();
        _expertiseController.clear();
        _loadExistingFaculty(); // Automatically refresh list

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

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaculty = _existingFaculty.where((f) {
      final name = f['name']?.toString().toLowerCase() ?? '';
      final email = f['email']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

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
                labelText: 'User ID',
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
            Row(
              children: [
                const Text(
                  'Available Faculty Members',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Spacer(),
                SizedBox(
                  width: 250,
                  height: 40,
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search faculty...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoadingList
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFaculty.isEmpty
                      ? const Center(child: Text('No faculty found matching search.'))
                      : ListView.builder(
                          itemCount: filteredFaculty.length,
                          itemBuilder: (context, index) {
                            final f = filteredFaculty[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: const Icon(
                                  Icons.person,
                                  color: Colors.blue,
                                ),
                                title: Text(f['name'] ?? ''),
                                subtitle: Text(f['email'] ?? ''),
                                trailing: f['is_admin'] == true
                                    ? const Chip(
                                        label: Text(
                                          'Admin',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
