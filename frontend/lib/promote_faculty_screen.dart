import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PromoteFacultyScreen extends StatefulWidget {
  final int collegeId;

  const PromoteFacultyScreen({super.key, required this.collegeId});

  @override
  State<PromoteFacultyScreen> createState() => _PromoteFacultyScreenState();
}

class _PromoteFacultyScreenState extends State<PromoteFacultyScreen> {
  List<dynamic> _facultyList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
  }

  Future<void> _fetchFaculty() async {
    setState(() => _isLoading = true);
    final url = Uri.parse(
      'http://127.0.0.1:5000/faculty_list/${widget.collegeId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _facultyList = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _confirmPromote(int facultyId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Promote to Admin'),
        content: Text(
          'Give $name Admin (HOD) access? They will be able to log in as Admin using their existing email and password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _promote(facultyId);
            },
            child: const Text('Promote'),
          ),
        ],
      ),
    );
  }

  Future<void> _promote(int facultyId) async {
    final url = Uri.parse('http://127.0.0.1:5000/promote_to_admin');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'faculty_id': facultyId}),
      );
      final data = jsonDecode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? data['error'] ?? 'Done')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to server.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Give Admin Access')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _facultyList.isEmpty
          ? const Center(child: Text('No faculty registered yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _facultyList.length,
              itemBuilder: (context, index) {
                final f = _facultyList[index];
                return Card(
                  child: ListTile(
                    title: Text(f['name']),
                    subtitle: Text(f['email']),
                    trailing: ElevatedButton(
                      onPressed: () =>
                          _confirmPromote(f['faculty_id'], f['name']),
                      child: const Text('Make Admin'),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
