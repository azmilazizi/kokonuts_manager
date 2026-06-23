import 'dart:convert';
import 'package:http/http.dart' as http;

const String kManagerApiBase = 'https://crm.kokonuts.my/manager/api';

class AuthException implements Exception {
  final String message;
  final int statusCode;
  const AuthException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class AuthService {
  final String baseUrl;

  const AuthService({this.baseUrl = kManagerApiBase});

  Future<Map<String, dynamic>> login(String email, String password) async {
    final resp = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return body;
    throw AuthException(
      body['error'] as String? ?? 'Login failed',
      resp.statusCode,
    );
  }

  Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort logout; session will expire server-side anyway
    }
  }

  Future<Map<String, dynamic>> me(String token) async {
    final resp = await http
        .get(
          Uri.parse('$baseUrl/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 15));

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode == 200) return body;
    throw AuthException(
      body['error'] as String? ?? 'Session expired',
      resp.statusCode,
    );
  }
}
