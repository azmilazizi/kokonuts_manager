import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _keyToken = 'mgr_token';
  static const _keyStaffId = 'mgr_staff_id';
  static const _keyStaffName = 'mgr_staff_name';
  static const _keyStaffEmail = 'mgr_staff_email';
  static const _keyRole = 'mgr_role';

  Future<void> save({
    required String token,
    required int staffId,
    required String staffName,
    required String staffEmail,
    required String role,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setInt(_keyStaffId, staffId);
    await prefs.setString(_keyStaffName, staffName);
    await prefs.setString(_keyStaffEmail, staffEmail);
    await prefs.setString(_keyRole, role);
  }

  Future<Map<String, dynamic>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_keyToken);
    if (token == null) return null;
    return {
      'token': token,
      'staff_id': prefs.getInt(_keyStaffId) ?? 0,
      'staff_name': prefs.getString(_keyStaffName) ?? '',
      'staff_email': prefs.getString(_keyStaffEmail) ?? '',
      'role': prefs.getString(_keyRole) ?? 'manager',
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyStaffId);
    await prefs.remove(_keyStaffName);
    await prefs.remove(_keyStaffEmail);
    await prefs.remove(_keyRole);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }
}
