import 'package:flutter/foundation.dart';

class StaffInfo {
  final int id;
  final String fullName;
  final String email;

  const StaffInfo({required this.id, required this.fullName, required this.email});

  factory StaffInfo.fromJson(Map<String, dynamic> json) => StaffInfo(
        id: json['id'] as int,
        fullName: json['full_name'] as String,
        email: json['email'] as String,
      );
}

class Warehouse {
  final int id;
  final String name;
  final String code;
  final String address;

  const Warehouse({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
  });

  factory Warehouse.fromJson(Map<String, dynamic> json) => Warehouse(
        id: int.parse(json['id'].toString()),
        name: json['name'] as String,
        code: json['code'] as String,
        address: (json['address'] ?? '') as String,
      );
}

class AppState extends ChangeNotifier {
  String? _token;
  StaffInfo? _staff;
  String? _role;
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  bool _isInitialized = false;

  String? get token => _token;
  StaffInfo? get staff => _staff;
  String? get role => _role;
  List<Warehouse> get warehouses => _warehouses;
  Warehouse? get selectedWarehouse => _selectedWarehouse;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _token != null;
  bool get isAdministrator => _role == 'administrator';

  void setAuth({
    required String token,
    required StaffInfo staff,
    required String role,
    required List<Warehouse> warehouses,
  }) {
    _token = token;
    _staff = staff;
    _role = role;
    _warehouses = warehouses;
    // Auto-select single warehouse for managers
    if (warehouses.length == 1 && role != 'administrator') {
      _selectedWarehouse = warehouses.first;
    } else {
      _selectedWarehouse = null;
    }
    notifyListeners();
  }

  void setSelectedWarehouse(Warehouse? warehouse) {
    _selectedWarehouse = warehouse;
    notifyListeners();
  }

  void clearAuth() {
    _token = null;
    _staff = null;
    _role = null;
    _warehouses = [];
    _selectedWarehouse = null;
    notifyListeners();
  }

  void setInitialized() {
    _isInitialized = true;
    notifyListeners();
  }
}
