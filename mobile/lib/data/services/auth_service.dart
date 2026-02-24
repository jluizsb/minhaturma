import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

import '../../config/app_config.dart';

/// Serviço central de autenticação.
/// Suporta: e-mail/senha, Google, Facebook, Apple, Microsoft.
class AuthService {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AuthService()
      : _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)),
        _storage = const FlutterSecureStorage();

  // ── Tokens ────────────────────────────────────────────

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token',  value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<String?> getAccessToken() => _storage.read(key: 'access_token');

  Future<void> clearTokens() async {
    await _storage.deleteAll();
  }

  // ── Login com e-mail e senha ──────────────────────────

  Future<void> loginWithEmail(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'username': email,
      'password': password,
    });
    await saveTokens(response.data['access_token'], response.data['refresh_token']);
  }

  // ── Google ────────────────────────────────────────────

  Future<void> loginWithGoogle() async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return;
    final auth = await googleUser.authentication;
    await _socialLogin('google', auth.idToken!);
  }

  // ── Facebook ──────────────────────────────────────────

  Future<void> loginWithFacebook() async {
    final result = await FacebookAuth.instance.login();
    if (result.status != LoginStatus.success) return;
    await _socialLogin('facebook', result.accessToken!.tokenString);
  }

  // ── Apple ─────────────────────────────────────────────

  Future<void> loginWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    await _socialLogin('apple', credential.identityToken!);
  }

  // ── Microsoft ─────────────────────────────────────────
  // Requer configuração do MSAL no azure portal
  Future<void> loginWithMicrosoft(String msalToken) async {
    await _socialLogin('microsoft', msalToken);
  }

  // ── Helper interno ────────────────────────────────────

  Future<void> _socialLogin(String provider, String token) async {
    final response = await _dio.post('/auth/social-login', data: {
      'provider': provider,
      'token': token,
    });
    await saveTokens(response.data['access_token'], response.data['refresh_token']);
  }

  Future<void> logout() async {
    await _dio.post('/auth/logout');
    await clearTokens();
    await GoogleSignIn().signOut();
    await FacebookAuth.instance.logOut();
  }
}
