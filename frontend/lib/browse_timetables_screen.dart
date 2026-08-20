import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'timetable_grid_screen.dart';
import 'class_info_dialog.dart';

class BrowseTimetablesScreen extends StatefulWidget {
  final int facultyId;
  final int collegeId;

  const BrowseTimetablesScreen({
    super.key,
    required this.facultyId,
    required this.collegeId,
  });

  @override
  State<BrowseTimetablesScreen> createState() => _BrowseTimetablesScreenState();
}

class _BrowseTimetablesScreenState extends State<BrowseTimetablesScreen> {
  List<dynamic> _classes = [];
  List<dynamic> _filteredClasses = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  static const TextStyle classHighlightStyle = TextStyle(
    fontWeight: FontWeight.bold,
    color: Color(0xFF1A237E),
  );

  @override
  void initState() {
    super.initState();
    _fetchClasses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredClasses = List.from(_classes);
      } else {
        _filteredClasses = _classes.where((cls) {
          final year = (cls['year'] ?? '').toString().toLowerCase();
          final dept = (cls['department'] ?? '').toString().toLowerCase();
          final sec = (cls['section'] ?? '').toString().toLowerCase();
          final fullStr = '$year $dept $sec'.toLowerCase();
          return year.contains(query) ||
              dept.contains(query) ||
              sec.contains(query) ||
              fullStr.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    // Fetch ALL classes in the college so search works across all classes
    final collegeClassesUrl = Uri.parse(
      'http://127.0.0.1:5000/classes_with_cc/${widget.collegeId}',
    );
    final facultyClassesUrl = Uri.parse(
      'http://127.0.0.1:5000/faculty_related_classes/${widget.facultyId}',
    );

    try {
      final response = await http.get(collegeClassesUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          setState(() {
            _classes = data;
            _filteredClasses = List.from(data);
            _isLoading = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback if college endpoint returns empty or fails
    try {
      final response = await http.get(facultyClassesUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _classes = data;
          _filteredClasses = List.from(data);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse Timetables'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar with autocomplete / dynamic filtering
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by class, year, section, or department...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1565C0)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      filled: true,
                      fillColor: Colors.blue.shade50.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade100),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF1565C0),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Suggestion / Count indicator
                if (_classes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _searchQuery.isEmpty
                              ? 'All Classes (${_classes.length})'
                              : 'Found ${_filteredClasses.length} matching class${_filteredClasses.length == 1 ? '' : 'es'}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),

                const Divider(height: 1),

                // Classes List View
                Expanded(
                  child: _classes.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'No classes found for this college yet.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _filteredClasses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No classes found matching "$_searchQuery"',
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
                              itemCount: _filteredClasses.length,
                              itemBuilder: (context, index) {
                                final cls = _filteredClasses[index];
                                final isCC = cls['cc_faculty_id'] == widget.facultyId;
                                final className = '${cls['year']} - ${cls['section']}';
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: ListTile(
                                    title: Text(
                                      '${cls['year']} - ${cls['department']} - ${cls['section']}',
                                      style: classHighlightStyle,
                                    ),
                                    subtitle: isCC
                                        ? const Text(
                                            'Class Coordinator (CC)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          )
                                        : (cls['cc_name'] != null
                                            ? Text(
                                                'CC: ${cls['cc_name']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              )
                                            : null),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.info_outline),
                                          tooltip: 'Class Details',
                                          onPressed: () => showClassInfoDialog(
                                            context,
                                            classId: cls['class_id'],
                                            className: className,
                                            canEdit: isCC,
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 16),
                                      ],
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TimetableGridScreen(
                                            classId: cls['class_id'],
                                            className: className,
                                            facultyId: widget.facultyId,
                                            collegeId: widget.collegeId,
                                            isCC: isCC,
                                          ),
                                        ),
                                      );
                                    },
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
