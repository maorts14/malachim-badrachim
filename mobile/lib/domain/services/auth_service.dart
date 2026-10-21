import 'package:flutter/foundation.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/managers/storage_manager.dart';

class AuthService {
  AuthService._() {
    _apiClient.onSessionExpired = () => session.value = false;
  }

  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;

  final RestApiService _apiClient = RestApiService();
  final ValueNotifier<bool> session = ValueNotifier<bool>(false);

  bool get isAuthenticated => session.value;

  Future<void> restoreSession() async {
    final refresh = await StorageManager.instance.getJwtRefreshToken();
    if (refresh == null || refresh.isEmpty) return;
    try {
      await _apiClient.refreshAccessToken(refreshToken: refresh);
      session.value = true;
    } catch (_) {
      await _apiClient.clearTokens();
      session.value = false;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    await _apiClient.obtainToken(username: email, password: password);
    session.value = true;
  }

  Future<void> signUp({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    await _apiClient.register(
        email: email, password: password, fullName: fullName);
    session.value = true;
  }

  Future<void> signOut() async {
    try {
      await _apiClient.logout();
    } finally {
      session.value = false;
    }
  }
}
