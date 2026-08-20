import 'package:flutter/material.dart';
import 'admin_login_screen.dart';
import 'faculty_login_screen.dart';
import 'student_department_screen.dart';
import 'student_timetable_screen.dart';
import 'session_manager.dart';
import 'main.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String collegeCode;
  final int collegeId;
  const RoleSelectionScreen({
    super.key,
    required this.collegeCode,
    required this.collegeId,
  });

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int? _pressedIndex;
  Map<String, dynamic>? _pinnedClass;

  @override
  void initState() {
    super.initState();
    _loadPinnedClass();
  }

  Future<void> _loadPinnedClass() async {
    final pinned = await SessionManager.getDefaultClass();
    if (mounted) setState(() => _pinnedClass = pinned);
  }

  final List<_RoleData> _roles = const [
    _RoleData('Admin', Icons.admin_panel_settings_rounded, Color(0xFF1565C0)),
    _RoleData('Faculty', Icons.school_rounded, Color(0xFF2E7D32)),
    _RoleData('Student', Icons.backpack_rounded, Color(0xFFEF6C00)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text('Code: ${widget.collegeCode}'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await SessionManager.clearCollegeCode();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WelcomeScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Change Code'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Who are you signing in as?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your role to continue',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView.separated(
                itemCount: _roles.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final role = _roles[index];

                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 500 + (index * 150)),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 30 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _pressedIndex = index),
                      onTapUp: (_) => setState(() => _pressedIndex = null),
                      onTapCancel: () => setState(() => _pressedIndex = null),
                      onTap: () {
                        if (role.label == 'Admin') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminLoginScreen(),
                            ),
                          );
                        } else if (role.label == 'Faculty') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FacultyLoginScreen(),
                            ),
                          );
                        } else if (role.label == 'Student') {
                          if (_pinnedClass != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentTimetableScreen(
                                  classId: _pinnedClass!['classId'],
                                  className: _pinnedClass!['className'],
                                ),
                              ),
                            ).then((_) => _loadPinnedClass());
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StudentDepartmentScreen(
                                  collegeId: widget.collegeId,
                                ),
                              ),
                            ).then((_) => _loadPinnedClass());
                          }
                        }
                      },
                      child: AnimatedScale(
                        scale: _pressedIndex == index ? 0.97 : 1.0,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: role.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  role.icon,
                                  color: role.color,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      role.label,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (role.label == 'Student' && _pinnedClass != null) ...[
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.push_pin_rounded,
                                            size: 13,
                                            color: Color(0xFFEF6C00),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${_pinnedClass!['className']}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFFEF6C00),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      ),
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

class _RoleData {
  final String label;
  final IconData icon;
  final Color color;
  const _RoleData(this.label, this.icon, this.color);
}
