import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  // ---- Admin / Faculty session ----

  static Future<void> saveAdminSession(
    int adminId,
    String adminName,
    int collegeId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'admin');
    await prefs.setInt('adminId', adminId);
    await prefs.setString('name', adminName);
    await prefs.setInt('collegeId', collegeId);
  }

  static Future<void> saveFacultySession(
    int facultyId,
    String facultyName,
    int collegeId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', 'faculty');
    await prefs.setInt('facultyId', facultyId);
    await prefs.setString('name', facultyName);
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
    await prefs.remove('role');
    await prefs.remove('adminId');
    await prefs.remove('facultyId');
    await prefs.remove('name');
    await prefs.remove('collegeId');
    await prefs.remove('college_code');
    await prefs.remove('last_college_id');
  }

  // ---- College code (for unauthenticated page restore) ----

  static Future<void> saveCollegeCode(String code, int collegeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('college_code', code);
    await prefs.setInt('last_college_id', collegeId);
  }

  static Future<Map<String, dynamic>?> getSavedCollegeCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('college_code');
    final id = prefs.getInt('last_college_id');
    if (code == null || id == null) return null;
    return {'code': code, 'collegeId': id};
  }

  // ---- Default pinned class (student, no login) ----

  static Future<void> saveDefaultClass(
    int classId,
    String className, {
    int? collegeId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('default_class_id', classId);
    await prefs.setString('default_class_name', className);
    if (collegeId != null) {
      await prefs.setInt('default_college_id', collegeId);
    } else {
      await prefs.remove('default_college_id');
    }
  }

  static Future<Map<String, dynamic>?> getDefaultClass() async {
    final prefs = await SharedPreferences.getInstance();
    final classId = prefs.getInt('default_class_id');
    if (classId == null) return null;
    return {
      'classId': classId,
      'className': prefs.getString('default_class_name'),
      'collegeId': prefs.getInt('default_college_id'),
    };
  }

  static Future<void> clearDefaultClass() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('default_class_id');
    await prefs.remove('default_class_name');
    await prefs.remove('default_college_id');
  }

  // ---- Preferred View Mode (Grid vs List) ----

  static Future<void> savePreferredViewMode(String role, bool is2D) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('preferred_2d_view_$role', is2D);
  }

  static Future<bool> getPreferredViewMode(String role) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('preferred_2d_view_$role') ?? false;
  }

  // ---- Last visited deep page (for full-app reload restore) ----
  // Stored as a JSON string: {'page': String, ...params}

  static Future<void> saveLastPage(Map<String, dynamic> pageData) async {
    final prefs = await SharedPreferences.getInstance();
    // Manual JSON encode without dart:convert import overhead
    final parts = pageData.entries
        .map((e) => '"${e.key}":"${e.value}"')
        .join(',');
    await prefs.setString('last_page', '{$parts}');
  }

  static Future<Map<String, dynamic>?> getLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('last_page');
    if (raw == null) return null;
    // Simple key-value parse (all values are strings)
    final result = <String, dynamic>{};
    final content = raw.replaceAll('{', '').replaceAll('}', '');
    for (final pair in content.split('","')) {
      final kv = pair.replaceAll('"', '').split(':');
      if (kv.length >= 2) {
        result[kv[0]] = kv.sublist(1).join(':');
      }
    }
    return result.isEmpty ? null : result;
  }

  static Future<void> clearLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_page');
  }
}

