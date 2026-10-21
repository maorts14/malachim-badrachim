import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rescue_app/models/identity_user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class StorageManager {
  StorageManager._privateConstructor() {
    _storage = const FlutterSecureStorage();
  }
  static final StorageManager _instance = StorageManager._privateConstructor();
  static StorageManager get instance => _instance;

  // change to flutter pub add get_storage
  late FlutterSecureStorage _storage;

  static const String bearer = 'bearer';
  static const String jwtAccessToken = 'jwtAccessToken';
  static const String jwtRefreshToken = 'jwtRefreshToken';
  static const String pnToken = 'pnTokenKey';
  static const resentSmsKey = 'resentSmsKey';
  static const String uUID = 'UUID';
  static const String isInitialLoadKey = 'isInitialLoadKey';
  static const String organizationKey = 'organizationKey';
  static const String userListKey = 'userListKey';
  static const String projectsListKey = 'projectsListKey';
  static const String assetsListKey = 'assetsListKey';
  static const String standartsKey = 'standartsKey';

  bool isInitialLoad = true;

  IdentityUserData? identityUser;

  Future<bool> getIsInitialLoad() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isInitialLoad = prefs.getBool(isInitialLoadKey) ?? false;
    return isInitialLoad;
  }

  Future setNotInitialLoading() async {
    isInitialLoad = false;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(isInitialLoadKey, false);
  }

  // GET
  Future<String?> get({required String key}) async {
    return await _storage.read(key: key);
  }

  // WRITE
  Future set({required String key, required String jsonData}) async {
    await _storage.write(key: key, value: jsonData);
  }

  // DELETE
  Future deleteAll() async {
    await _storage.deleteAll();
  }

  Future deleteAllOnFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool('first_run');
    if (isFirstRun ?? true) {
      await _storage.deleteAll();
      prefs.setBool('first_run', false);
    }
  }

  Future<String?> authorization() async {
    final identity = await getBearer();
    return identity?.bearer;
  }

  Future<IdentityUserData?> getBearer() async {
    if (identityUser != null) {
      return identityUser;
    } else {
      final String? bearerValue = await get(key: StorageManager.bearer);
      if (bearerValue?.isNotEmpty ?? false) {
        Map<String, dynamic> identityUser = json.decode(bearerValue ?? '');
        return IdentityUserData.fromJson(identityUser);
      } else {
        return null;
      }
    }
  }

  Future setBearer(IdentityUserData identityUserData) async {
    identityUser = identityUserData;
    Map<String, dynamic> identityUserMap = identityUserData.toJson();
    final String bearerData = json.encode(identityUserMap);
    await set(key: StorageManager.bearer, jsonData: bearerData);
  }

  Future<void> saveJwtTokens(
      {required String access, required String refresh}) async {
    await _storage.write(key: jwtAccessToken, value: access);
    await _storage.write(key: jwtRefreshToken, value: refresh);
  }

  Future<String?> getJwtAccessToken() => _storage.read(key: jwtAccessToken);

  Future<String?> getJwtRefreshToken() => _storage.read(key: jwtRefreshToken);

  Future<void> clearJwtTokens() async {
    await _storage.delete(key: jwtAccessToken);
    await _storage.delete(key: jwtRefreshToken);
  }

  Future<bool> hasPushNotificationToken() async {
    final String? token = await getPushNotificationToken();
    return (token != null);
  }

  Future<String?> getPushNotificationToken() {
    return get(key: pnToken);
  }

  Future setPushNotificationToken(String token) async {
    if (token.isEmpty) {
      return;
    }

    await set(key: pnToken, jsonData: token);
  }

  Future logout() async {
    identityUser = null;
    await _storage.delete(key: StorageManager.bearer);
    await clearJwtTokens();
  }

  Future<String?> getUUID() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? uuid = prefs.getString(uUID);
    if (uuid?.isEmpty ?? true) {
      uuid = const Uuid().v1();
      await prefs.setString(uUID, uuid);
    }

    return uuid;
  }
}
