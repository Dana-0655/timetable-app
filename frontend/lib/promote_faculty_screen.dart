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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _fetchFaculty();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
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
      } else {
        setState(() => _isLoading = false);
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
          'Give $name Admin access? They will be able to log in as Admin using their existing email and password.',
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
      // Refresh the list so the promoted faculty now shows "Promoted Admin"
      _fetchFaculty();
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
    final filteredFaculty = _facultyList.where((f) {
      if (_searchQuery.isEmpty) return true;
      final name = (f['name'] ?? '').toString().toLowerCase();
      final email = (f['email'] ?? '').toString().toLowerCase();
      final expertise = (f['subject_expertise'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          expertise.contains(_searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Give Admin Access')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _facultyList.isEmpty
              ? const Center(child: Text('No faculty registered yet.'))
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by faculty name or email...',
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF1565C0)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    // Results Counter
                    if (_searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Showing ${filteredFaculty.length} of ${_facultyList.length} faculty',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),

                    // Faculty List
                    Expanded(
                      child: filteredFaculty.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No faculty found matching "$_searchQuery"',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredFaculty.length,
                              itemBuilder: (context, index) {
                                final f = filteredFaculty[index];
                                final bool isAdmin = f['is_admin'] == true;

                                return Card(
                                  elevation: 1,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isAdmin
                                          ? Colors.green.shade100
                                          : Colors.blue.shade50,
                                      child: Icon(
                                        isAdmin ? Icons.shield : Icons.person,
                                        color: isAdmin
                                            ? Colors.green.shade800
                                            : const Color(0xFF1565C0),
                                      ),
                                    ),
                                    title: Text(
                                      f['name'] ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(f['email'] ?? ''),
                                    trailing: isAdmin
                                        ? Chip(
                                            label: const Text('Promoted Admin'),
                                            avatar: const Icon(
                                              Icons.verified,
                                              size: 18,
                                              color: Colors.green,
                                            ),
                                            backgroundColor: Colors.green.shade50,
                                            labelStyle: TextStyle(
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : ElevatedButton(
                                            onPressed: () => _confirmPromote(
                                              f['faculty_id'],
                                              f['name'],
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1565C0),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: const Text('Make Admin'),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
