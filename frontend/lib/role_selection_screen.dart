import 'package:flutter/material.dart';
import 'package:frontend/faculty_login_screen.dart';
import 'admin_login_screen.dart';
import 'faculty_login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  final String collegeCode;
  const RoleSelectionScreen({super.key, required this.collegeCode});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  int? _pressedIndex;

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
                                color: Colors.black.withOpacity(0.06),
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
                                  color: role.color.withOpacity(0.12),
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
                                child: Text(
                                  role.label,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
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
