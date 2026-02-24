import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../models/auth_model.dart';

/// Serviço central de autenticação (e-mail/senha).
/// Login social fica reservado para implementação futura.
class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';
  static const _keyUser = 'auth_user';

  AuthService()
      : _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
        _storage = const FlutterSecureStorage();

  // ── Tokens ────────────────────────────────────────────

  Future<void> saveTokens(String access, String refresh) async {
    await Future.wait([
      _storage.write(key: _keyAccess, value: access),
      _storage.write(key: _keyRefresh, value: refresh),
    ]);
  }

  Future<String?> getAccessToken() => _storage.read(key: _keyAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  Future<void> clearTokens() => _storage.deleteAll();

  // ── User persistido ───────────────────────────────────

  Future<void> saveUser(AuthUser user) =>
      _storage.write(key: _keyUser, value: jsonEncode(user.toJson()));

  Future<AuthUser?> getUser() async {
    final raw = await _storage.read(key: _keyUser);
    if (raw == null) return null;
    try {
      return AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Estado de sessão ──────────────────────────────────

  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Cadastro ──────────────────────────────────────────

  Future<AuthUser> register(String name, String email, String password) async {
    final response = await _dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    final user = AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    await saveTokens(
      response.data['access_token'] as String,
      response.data['refresh_token'] as String,
    );
    await saveUser(user);
    return user;
  }

  // ── Login com e-mail e senha ──────────────────────────

  Future<AuthUser> loginWithEmail(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: 'username=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}',
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    final user = AuthUser.fromJson(response.data['user'] as Map<String, dynamic>);
    await saveTokens(
      response.data['access_token'] as String,
      response.data['refresh_token'] as String,
    );
    await saveUser(user);
    return user;
  }

  // ── Logout ────────────────────────────────────────────

  Future<void> logout() async {
    final token = await getAccessToken();
    if (token != null) {
      try {
        await _dio.post(
          '/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (_) {
        // Ignora erros de rede — tokens serão limpos localmente de qualquer forma
      }
    }
    await clearTokens();
  }
}
