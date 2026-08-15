import 'package:flutter/material.dart';
import 'admin_login_screen.dart';
import 'faculty_login_screen.dart';
import 'student_department_screen.dart';

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

  final List<_RoleData> _roles = const [
    _RoleData(
      'Admin Portal',
      'System HOD & Administrator',
      Icons.admin_panel_settings_rounded,
      Color(0xFF3525CD),
      Color(0xFF4F46E5),
    ),
    _RoleData(
      'Faculty Portal',
      'Teachers & Class Coordinators',
      Icons.school_rounded,
      Color(0xFF0EA5E9),
      Color(0xFF0284C7),
    ),
    _RoleData(
      'Student Portal',
      'Schedules, Alerts & Updates',
      Icons.backpack_rounded,
      Color(0xFF7E3000),
      Color(0xFFA44100),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E1B4B),
              Colors.indigo.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.apartment_rounded, size: 14, color: Colors.purpleAccent),
                          const SizedBox(width: 6),
                          Text(
                            widget.collegeCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select Portal Role',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Access your personalized scheduling space',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: ListView.separated(
                    itemCount: _roles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 18),
                    itemBuilder: (context, index) {
                      final role = _roles[index];

                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 400 + (index * 150)),
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
                            if (role.label == 'Admin Portal') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const AdminLoginScreen(),
                                ),
                              );
                            } else if (role.label == 'Faculty Portal') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const FacultyLoginScreen(),
                                ),
                              );
                            } else if (role.label == 'Student Portal') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StudentDepartmentScreen(
                                    collegeId: widget.collegeId,
                                  ),
                                ),
                              );
                            }
                          },
                          child: AnimatedScale(
                            scale: _pressedIndex == index ? 0.97 : 1.0,
                            duration: const Duration(milliseconds: 120),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: role.primaryColor.withValues(alpha: 0.25),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [role.primaryColor, role.secondaryColor],
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: role.primaryColor.withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      role.icon,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          role.label,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          role.subtitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white.withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
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
        ),
      ),
    );
  }
}

class _RoleData {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  const _RoleData(this.label, this.subtitle, this.icon, this.primaryColor, this.secondaryColor);
}
