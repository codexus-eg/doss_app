import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'api_client.dart';

class AuthService {
  static AuthService? _instance;
  static AuthService get instance {
    _instance ??= AuthService._internal();
    return _instance!;
  }

  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Register a new rider
  Future<AuthUser> registerRider({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    final result = await ApiClient.instance.mutate(
      'dossAuth.registerRider',
      input: {
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null) 'email': email,
      },
    );
    final user = AuthUser.fromJson(result);
    await _saveUser(user);
    return user;
  }

  /// Register a new driver
  Future<AuthUser> registerDriver({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? vehicleModel,
    String? vehiclePlate,
    int? vehicleYear,
    String? nationalId,
    String? licenseNumber,
    String? vehicleColor,
  }) async {
    final result = await ApiClient.instance.mutate(
      'dossAuth.registerDriver',
      input: {
        'name': name,
        'phone': phone,
        'password': password,
        if (email != null) 'email': email,
        if (vehicleModel != null) 'vehicleModel': vehicleModel,
        if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
        if (vehicleYear != null) 'vehicleYear': vehicleYear,
        if (nationalId != null) 'nationalId': nationalId,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (vehicleColor != null) 'vehicleColor': vehicleColor,
      },
    );
    final user = AuthUser.fromJson(result);
    await _saveUser(user);
    return user;
  }

  /// Generic register (kept for backwards compat — routes to rider or driver)
  Future<AuthUser> register({
    required String name,
    required String phone,
    required String password,
    required String role, // 'rider' | 'driver'
    String? email,
    String? vehicleMake,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleYear,
    String? nationalId,
  }) async {
    if (role == 'driver') {
      return registerDriver(
        name: name,
        phone: phone,
        password: password,
        email: email,
        vehicleModel: vehicleModel,
        vehiclePlate: vehiclePlate,
        vehicleYear: vehicleYear != null ? int.tryParse(vehicleYear) : null,
        nationalId: nationalId,
      );
    } else {
      return registerRider(
        name: name,
        phone: phone,
        password: password,
        email: email,
      );
    }
  }

  /// Login — entity is 'rider' or 'driver'
  Future<AuthUser> login({
    required String phone,
    required String password,
    required String entity, // 'rider' or 'driver'
  }) async {
    final result = await ApiClient.instance.mutate(
      'dossAuth.login',
      input: {
        'phone': phone,
        'password': password,
        'entity': entity,
      },
    );
    final user = AuthUser.fromJson(result);
    await _saveUser(user);
    return user;
  }

  /// Logout
  Future<void> logout() async {
    try {
      await ApiClient.instance.mutate('auth.logout');
    } catch (_) {}
    await _clearUser();
  }

  /// Restore session from secure storage on app start
  Future<AuthUser?> restoreSession() async {
    String? userJson;
    try {
      userJson = await _storage.read(key: 'auth_user')
          .timeout(const Duration(seconds: 3));
    } catch (_) { return null; }
    if (userJson == null) return null;
    try {
      final user = AuthUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      _currentUser = user;
      await ApiClient.instance.saveToken(user.token);
      return user;
    } catch (_) {
      await _clearUser();
      return null;
    }
  }

  Future<void> _saveUser(AuthUser user) async {
    _currentUser = user;
    await ApiClient.instance.saveToken(user.token);
    try {
      await _storage.write(key: 'auth_user', value: jsonEncode(user.toJson()))
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  Future<void> _clearUser() async {
    _currentUser = null;
    try {
      await _storage.delete(key: 'auth_user').timeout(const Duration(seconds: 3));
    } catch (_) {}
    await ApiClient.instance.clearToken();
  }
}
