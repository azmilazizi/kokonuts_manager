import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WarehouseNotifPreference {
  final int warehouseId;
  final String warehouseName;
  bool salesNotify;

  WarehouseNotifPreference({
    required this.warehouseId,
    required this.warehouseName,
    required this.salesNotify,
  });

  factory WarehouseNotifPreference.fromJson(Map<String, dynamic> json) =>
      WarehouseNotifPreference(
        warehouseId: json['warehouse_id'] as int,
        warehouseName: json['warehouse_name'] as String,
        salesNotify: (json['sales_notify'] as bool?) ?? true,
      );
}

class NotificationPreferencesService {
  const NotificationPreferencesService();

  Future<List<WarehouseNotifPreference>> getPreferences(String token) async {
    final resp = await http.get(
      Uri.parse('$kManagerApiBase/notification-preferences'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Failed to load notification preferences');
    }

    return (body['data'] as List)
        .map((e) => WarehouseNotifPreference.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updatePreferences(
    String token,
    List<WarehouseNotifPreference> preferences,
  ) async {
    final resp = await http.put(
      Uri.parse('$kManagerApiBase/notification-preferences'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'preferences': preferences
            .map((p) => {
                  'warehouse_id': p.warehouseId,
                  'sales_notify': p.salesNotify,
                })
            .toList(),
      }),
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Failed to save notification preferences');
    }
  }
}
