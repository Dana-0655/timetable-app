import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SubstituteRecommendationsDialog extends StatefulWidget {
  final int leaveId;
  final String userRole; // 'faculty' or 'admin'

  const SubstituteRecommendationsDialog({
    super.key,
    required this.leaveId,
    this.userRole = 'faculty',
  });

  @override
  State<SubstituteRecommendationsDialog> createState() =>
      _SubstituteRecommendationsDialogState();
}

class _SubstituteRecommendationsDialogState
    extends State<SubstituteRecommendationsDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _slotInfo;
  List<dynamic> _candidates = [];

  @override
  void initState() {
    super.initState();
    _fetchSuggestions();
  }

  Future<void> _fetchSuggestions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse(
      'http://127.0.0.1:5000/suggest_substitutes/${widget.leaveId}',
    );
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _slotInfo = data['slot_info'];
          _candidates = data['candidates'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load substitute suggestions.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server.';
        _isLoading = false;
      });
    }
  }

  Future<void> _approveSubstitute(int facultyId, String facultyName) async {
    final url = Uri.parse('http://127.0.0.1:5000/approve_substitute');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'leave_id': widget.leaveId,
          'substitute_faculty_id': facultyId,
          'approved_by_role': widget.userRole,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$facultyName approved as substitute!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final err = jsonDecode(response.body)['error'] ?? 'Approval failed';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to server.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.deepPurple),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Auto-Substitute Suggestions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          if (_slotInfo != null) ...[
            const SizedBox(height: 4),
            Text(
              '${_slotInfo!['class_name']} • ${_slotInfo!['day_of_week']} Period ${_slotInfo!['period_no']} (${_slotInfo!['course_name']})',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Text(
              'Absent: ${_slotInfo!['absent_faculty_name']}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.6,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _fetchSuggestions,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _candidates.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No eligible free substitutes found for this hour under load cap.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            : ListView.builder(
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final cand = _candidates[index];
                  final isTopRank = cand['rank'] == 1;
                  final matchScore = cand['match_score'] ?? 50;
                  final reasons = (cand['reasons'] as List<dynamic>?) ?? [];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isTopRank ? Colors.deepPurple.shade50 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTopRank
                            ? Colors.deepPurple.shade300
                            : Colors.grey.shade300,
                        width: isTopRank ? 1.5 : 1,
                      ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isTopRank
                                    ? Colors.deepPurple
                                    : Colors.blueGrey,
                                child: Text(
                                  '#${cand['rank']}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            cand['name'],
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: matchScore >= 80
                                                ? Colors.green.shade100
                                                : Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '$matchScore% Match',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: matchScore >= 80
                                                  ? Colors.green.shade900
                                                  : Colors.orange.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dept: ${cand['department']} • ${cand['subject_expertise'] ?? ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: reasons.map((reason) {
                              final String reasonStr = reason.toString();
                              bool isFamiliar = reasonStr.contains('Teaches');
                              bool isDept = reasonStr.contains('Department');
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isFamiliar
                                      ? Colors.blue.shade50
                                      : isDept
                                          ? Colors.purple.shade50
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isFamiliar
                                        ? Colors.blue.shade200
                                        : isDept
                                            ? Colors.purple.shade200
                                            : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  reasonStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isFamiliar
                                        ? Colors.blue.shade900
                                        : isDept
                                            ? Colors.purple.shade900
                                            : Colors.grey.shade800,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _approveSubstitute(
                                cand['faculty_id'],
                                cand['name'],
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isTopRank
                                    ? Colors.deepPurple
                                    : Colors.indigo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text(
                                'Approve Substitute',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
