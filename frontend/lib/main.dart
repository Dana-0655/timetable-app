import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'role_selection_screen.dart';
import 'session_manager.dart';
import 'admin_dashboard_screen.dart';
import 'faculty_dashboard_screen.dart';
import 'create_college_screen.dart';
import 'student_timetable_screen.dart';
import 'admin_timetable_view_screen.dart';
import 'timetable_grid_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Timetable App',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 6),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      home: const SessionChecker(),
    );
  }
}

class SessionChecker extends StatefulWidget {
  const SessionChecker({super.key});

  @override
  State<SessionChecker> createState() => _SessionCheckerState();
}

class _SessionCheckerState extends State<SessionChecker> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // 1. Student pinned to a class (no login)
    final defaultClass = await SessionManager.getDefaultClass();
    if (defaultClass != null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentTimetableScreen(
            classId: defaultClass['classId'],
            className: defaultClass['className'],
          ),
        ),
      );
      return;
    }

    // 2. Admin or faculty logged-in session
    final session = await SessionManager.getSession();
    final lastPage = await SessionManager.getLastPage();

    if (!mounted) return;

    if (session != null && session['role'] == 'admin') {
      final adminDashboard = AdminDashboardScreen(
        adminId: session['adminId'],
        adminName: session['name'],
        collegeId: session['collegeId'],
      );

      // Restore deep page if there is one
      if (lastPage != null) {
        final page = lastPage['page'];
        if (page == 'admin_timetable_view') {
          final classId = int.tryParse(lastPage['classId'] ?? '');
          final className = lastPage['className'] ?? '';
          final isReadOnly = lastPage['isReadOnly'] == 'true';
          if (classId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => adminDashboard),
            );
            // Push the deep page on top of the dashboard
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminTimetableViewScreen(
                  classId: classId,
                  className: className,
                  collegeId: session['collegeId'],
                  isReadOnly: isReadOnly,
                ),
              ),
            );
            return;
          }
        } else if (page == 'faculty_timetable') {
          final classId = int.tryParse(lastPage['classId'] ?? '');
          final className = lastPage['className'] ?? '';
          final facultyId = int.tryParse(lastPage['facultyId'] ?? '');
          final isCC = lastPage['isCC'] == 'true';
          if (classId != null && facultyId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => adminDashboard),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TimetableGridScreen(
                  classId: classId,
                  className: className,
                  facultyId: facultyId,
                  collegeId: session['collegeId'],
                  isCC: isCC,
                ),
              ),
            );
            return;
          }
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => adminDashboard),
      );
      return;
    } else if (session != null && session['role'] == 'faculty') {
      final facultyDashboard = FacultyDashboardScreen(
        facultyId: session['facultyId'],
        facultyName: session['name'],
        collegeId: session['collegeId'],
      );

      // Restore deep page if there is one
      if (lastPage != null) {
        final page = lastPage['page'];
        if (page == 'faculty_timetable') {
          final classId = int.tryParse(lastPage['classId'] ?? '');
          final className = lastPage['className'] ?? '';
          final facultyId = int.tryParse(lastPage['facultyId'] ?? '');
          final isCC = lastPage['isCC'] == 'true';
          if (classId != null && facultyId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => facultyDashboard),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TimetableGridScreen(
                  classId: classId,
                  className: className,
                  facultyId: facultyId,
                  collegeId: session['collegeId'],
                  isCC: isCC,
                ),
              ),
            );
            return;
          }
        } else if (page == 'admin_timetable_view') {
          final classId = int.tryParse(lastPage['classId'] ?? '');
          final className = lastPage['className'] ?? '';
          if (classId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => facultyDashboard),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminTimetableViewScreen(
                  classId: classId,
                  className: className,
                  collegeId: session['collegeId'],
                  isReadOnly: true,
                ),
              ),
            );
            return;
          }
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => facultyDashboard),
      );
      return;
    }

    // 3. No login but a college code was entered before — go back to role picker
    final savedCode = await SessionManager.getSavedCollegeCode();
    if (!mounted) return;
    if (savedCode != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RoleSelectionScreen(
            collegeCode: savedCode['code'],
            collegeId: savedCode['collegeId'],
          ),
        ),
      );
      return;
    }

    // 4. Completely fresh — show welcome/college code screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a college code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final url = Uri.parse('http://127.0.0.1:5000/verify_college_code/$code');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Persist the college code so reload brings user back here
        await SessionManager.saveCollegeCode(code, data['college_id']);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoleSelectionScreen(
              collegeCode: code,
              collegeId: data['college_id'],
            ),
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid college code. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not connect to server.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Timetable App',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Enter College Code',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _verifyCode,
                      child: const Text('Continue'),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CreateCollegeScreen(),
                    ),
                  );
                },
                child: const Text(
                  "Don't have a college code? Register your college",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
