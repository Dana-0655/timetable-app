import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static Future<void> saveAdminSession(
    int adminId,
    String name,
    int collegeId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'admin');
    await prefs.setInt('adminId', adminId);
    await prefs.setString('name', name);
    await prefs.setInt('collegeId', collegeId);
  }

  static Future<void> saveFacultySession(
    int facultyId,
    String name,
    int collegeId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'faculty');
    await prefs.setInt('facultyId', facultyId);
    await prefs.setString('name', name);
    await prefs.setInt('collegeId', collegeId);
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role == null) return null;

    return {
      'role': role,
      'adminId': prefs.getInt('adminId'),
      'facultyId': prefs.getInt('facultyId'),
      'name': prefs.getString('name'),
      'collegeId': prefs.getInt('collegeId'),
    };
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
