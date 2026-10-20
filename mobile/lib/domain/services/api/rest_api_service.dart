import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:rescue_app/constants/app_env.dart';
import 'package:rescue_app/managers/storage_manager.dart';
import 'package:rescue_app/models/alert_message.dart';
import 'package:rescue_app/models/message.dart';
import 'package:rescue_app/models/user_details.dart';
import 'package:rescue_app/models/user_group.dart';
import 'package:rescue_app/models/user_location.dart';

import 'rest_api_models.dart';

class RestApiService {
  static final String baseUrl = AppEnv.apiBaseUrl;

  static final RestApiService _instance = RestApiService._internal();
  factory RestApiService() => _instance;

  RestApiService._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final String? storedAccessToken =
              await StorageManager.instance.getJwtAccessToken();

          if (_accessToken != null && _accessToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          } else if (storedAccessToken != null &&
              storedAccessToken.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $storedAccessToken';
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isTokenRoute = request.path.startsWith('/api/token/');
          if (error.response?.statusCode != 401 ||
              request.extra['jwtRetried'] == true ||
              isTokenRoute) {
            handler.next(error);
            return;
          }

          final refresh = _refreshToken ??
              await StorageManager.instance.getJwtRefreshToken();
          if (refresh == null || refresh.isEmpty) {
            await clearTokens();
            onSessionExpired?.call();
            handler.next(error);
            return;
          }

          try {
            final refreshedAccess =
                await refreshAccessToken(refreshToken: refresh);
            request.headers['Authorization'] = 'Bearer $refreshedAccess';
            request.extra['jwtRetried'] = true;
            final replay = await _dio.fetch(request);
            handler.resolve(replay);
          } catch (_) {
            await clearTokens();
            onSessionExpired?.call();
            handler.next(error);
          }
        },
      ),
    );
  }

  final Dio _dio;
  String? _accessToken;
  String? _refreshToken;
  VoidCallback? onSessionExpired;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  void dispose() => _dio.close();

  Future<void> setAuthToken(
      {required String access, required String refresh}) async {
    _accessToken = access;
    _refreshToken = refresh;
    _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    _dio.options.headers['Content-Type'] = 'application/json';
    await StorageManager.instance
        .saveJwtTokens(access: access, refresh: refresh);
  }

  Future<void> setAccessAuthToken({required String access}) async {
    _accessToken = access;
    _dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  bool hasDioHeaders() {
    return _dio.options.headers.containsKey('Authorization') &&
        _dio.options.headers['Authorization'] != null;
  }

  Future<bool> checkDioHeaders() async {
    if (hasDioHeaders()) {
      return true;
    } else {
      final storedAccessToken =
          await StorageManager.instance.getJwtAccessToken();
      if (storedAccessToken == null || storedAccessToken.isEmpty) return false;
      await setAccessAuthToken(access: storedAccessToken);
      return true;
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _dio.options.headers.remove('Authorization');
    await StorageManager.instance.clearJwtTokens();
  }

  Future<void> postCurrentLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return;
      }

      await _dio.post(
        '/api/user/location/',
        data: {'latitude': latitude, 'longitude': longitude},
      );
    } on DioException catch (e) {
      debugPrint('postCurrentLocation error: ${e.message}');
      return;
    } catch (e) {
      debugPrint('postCurrentLocation error: $e');
      return;
    }
  }

  Future<List<UserLocation>> getAllUsersLocation() async {
    try {
      if (!await checkDioHeaders()) {
        return [];
      }

      final response = await _dio.get('/api/user/all/');
      final list = (response.data as List<dynamic>? ?? const [])
          .map((item) => UserLocation.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      debugPrint('getAllUsersLocation error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('getAllUsersLocation error: $e');
      return [];
    }
  }

  Future<List<Message>> getMessages() async {
    try {
      if (!await checkDioHeaders()) {
        return [];
      }

      final response = await _dio.get('/api/message/');
      final list = (response.data as List<dynamic>? ?? const [])
          .map((item) => Message.fromJson(item as Map<String, dynamic>))
          .toList();
      return list;
    } on DioException catch (e) {
      debugPrint('getMessages error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('getMessages error: $e');
      return [];
    }
  }

  Future<List<UserGroup>> getUserGroups() async {
    try {
      if (!await checkDioHeaders()) {
        return [];
      }

      final response = await _dio.get('/api/group/');
      return (response.data as List<dynamic>? ?? const [])
          .map((item) => UserGroup.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      debugPrint('getUserGroups error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('getUserGroups error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getUsersInGroup(String groupId) async {
    try {
      if (!await checkDioHeaders()) {
        return [];
      }

      final response = await _dio.get('/api/group/$groupId/');
      return (response.data as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      debugPrint('getUsersInGroup error: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('getUsersInGroup error: $e');
      return [];
    }
  }

  Future<void> addUserToGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return;
      }

      await _dio
          .post('/api/group/$groupId/add_user/', data: {'user_id': userId});
    } on DioException catch (e) {
      debugPrint('addUserToGroup error: ${e.message}');
      return;
    } catch (e) {
      debugPrint('addUserToGroup error: $e');
      return;
    }
  }

  Future<void> removeUserFromGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return;
      }

      await _dio.delete('/api/group/$groupId/remove_user/',
          data: {'user_id': userId});
    } on DioException catch (e) {
      debugPrint('removeUserFromGroup error: ${e.message}');
      return;
    } catch (e) {
      debugPrint('removeUserFromGroup error: $e');
      return;
    }
  }

  Future<Message> getMessageById(String id) async {
    try {
      if (!await checkDioHeaders()) {
        return _emptyAppMessage();
      }

      final response = await _dio.get('/api/message/$id/');
      return Message.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      debugPrint('getMessageById error: ${e.message}');
      return _emptyAppMessage();
    } catch (e) {
      debugPrint('getMessageById error: $e');
      return _emptyAppMessage();
    }
  }

  Future<List<Message>> postMessage({
    required String title,
    required String text,
    Uint8List? voicePayload,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return const [];
      }

      final data = FormData.fromMap({
        'title': title,
        'text': text,
        if (voicePayload != null)
          'voice_file': MultipartFile.fromBytes(
            voicePayload,
            filename: 'voice_note.m4a',
          ),
      });

      final response = await _dio.post('/api/message/', data: data);
      if (response.data == null || response.data is! Map<String, dynamic>) {
        debugPrint('postMessage error: Unexpected response format');
        return const [];
      }
      return [Message.fromJson(response.data as Map<String, dynamic>)];
    } on DioException catch (e) {
      debugPrint('postMessage error: ${e.message}');
      return const [];
    } catch (e) {
      debugPrint('postMessage error: $e');
      return const [];
    }
  }

  Future<void> registerDevice({
    required String pushToken,
    required String deviceId,
    required String platform,
    required String deviceModel,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return;
      }

      await _dio.post('/api/notifications/token', data: {
        'push_token': pushToken,
        'device_id': deviceId,
        'platform': platform,
        'device_model': deviceModel,
      });
    } on DioException catch (e) {
      debugPrint('registerDevice error: ${e.message}');
      return;
    } catch (e) {
      debugPrint('registerDevice error: $e');
      return;
    }
  }

  Future<JwtTokens> obtainToken({
    required String username,
    required String password,
  }) async {
    final response = await _safePost(
      '/api/token/',
      data: <String, dynamic>{
        'username': username,
        'password': password,
      },
    );

    final tokens = JwtTokens.fromJson(_asMap(response.data));
    await setAuthToken(access: tokens.access, refresh: tokens.refresh);
    return tokens;
  }

  Future<JwtTokens> register({
    required String email,
    required String password,
    String fullName = '',
  }) async {
    final response = await _safePost(
      '/api/auth/register/',
      data: <String, dynamic>{
        'email': email,
        'password': password,
        'full_name': fullName,
      },
    );
    final tokens = JwtTokens.fromJson(_asMap(response.data));
    await setAuthToken(access: tokens.access, refresh: tokens.refresh);
    return tokens;
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _safePost('/api/auth/password-reset/',
        data: <String, dynamic>{'email': email});
  }

  Future<void> confirmPasswordReset({
    required String uid,
    required String token,
    required String password,
  }) async {
    await _safePost('/api/auth/password-reset/$uid/$token/',
        data: <String, dynamic>{'password': password});
  }

  Future<Map<String, dynamic>> whoAmI() async {
    final response = await _safeGet('/api/auth/whoami/');
    return _asMap(_asMap(response.data)['user']);
  }

  Future<String> refreshAccessToken({String? refreshToken}) async {
    final token = refreshToken ?? _refreshToken;
    if (token == null || token.isEmpty) {
      throw StateError('No refresh token set. Call obtainToken first.');
    }

    final response = await _safePost(
      '/api/token/refresh/',
      data: <String, dynamic>{'refresh': token},
    );

    final data = _asMap(response.data);
    final access = data['access'] as String;
    final refreshedToken = data['refresh'] as String? ?? token;
    _accessToken = access;
    _refreshToken = refreshedToken;
    await StorageManager.instance
        .saveJwtTokens(access: access, refresh: refreshedToken);
    return access;
  }

  Future<void> logout() async {
    final refresh =
        _refreshToken ?? await StorageManager.instance.getJwtRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      await _safePost('/api/auth/logout/',
          data: <String, dynamic>{'refresh': refresh});
    }
    await clearTokens();
  }

  Future<List<dynamic>> listUsers() async {
    final response = await _safeGet('/api/user/');
    return _asList(response.data);
  }

  Future<Map<String, dynamic>> createUserProfile({
    required String role,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _safePost(
      '/api/user/',
      data: <String, dynamic>{
        'role': role,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return _asMap(response.data);
  }

  Future<List<UserDetails>> getAllUsers() async {
    final response = await _safeGet('/api/user/');
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw StateError(_apiErrorMessage(response.data));
    }
    final userList = _asList(response.data);
    return userList.map((json) => UserDetails.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getUserProfile(int id) async {
    final response = await _safeGet('/api/user/$id/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateUserProfile({
    required int id,
    required String role,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _safePut(
      '/api/user/$id/',
      data: <String, dynamic>{
        'role': role,
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchUserProfile({
    required int id,
    String? role,
    double? latitude,
    double? longitude,
  }) async {
    final data = <String, dynamic>{};
    if (role != null) data['role'] = role;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    final response = await _safePatch('/api/user/$id/', data: data);
    return _asMap(response.data);
  }

  Future<void> deleteUserProfile(int id) async {
    await _safeDelete('/api/user/$id/');
  }

  Future<Map<String, dynamic>> updateCurrentUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _safePost(
      '/api/user/location/',
      data: <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw StateError(_apiErrorMessage(response.data));
    }
    return _asMap(response.data);
  }

  // Future<List<dynamic>> listUsersWithCoordinates() async {
  //   final response = await _safeGet('/api/user/all/');
  //   return _asList(response.data);
  // }

  Future<Map<String, dynamic>> getCurrentUserProfile() async {
    final response = await _safeGet('/api/user/profile/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateCurrentUserProfile(
    Map<String, dynamic> fields,
  ) async {
    final response = await _safePut(
      '/api/user/update_profile/',
      data: fields,
    );
    return _asMap(response.data);
  }

  Future<List<dynamic>> listGroups() async {
    final response = await _safeGet('/api/group/');
    return _asList(response.data);
  }

  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<int> members,
  }) async {
    final response = await _safePost(
      '/api/group/',
      data: <String, dynamic>{
        'name': name,
        'members': members,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getGroup(int id) async {
    final response = await _safeGet('/api/group/$id/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateGroup({
    required int id,
    required String name,
    required List<int> members,
  }) async {
    final response = await _safePut(
      '/api/group/$id/',
      data: <String, dynamic>{
        'name': name,
        'members': members,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchGroup({
    required int id,
    String? name,
    List<int>? members,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (members != null) data['members'] = members;

    final response = await _safePatch('/api/group/$id/', data: data);
    return _asMap(response.data);
  }

  Future<void> deleteGroup(int id) async {
    await _safeDelete('/api/group/$id/');
  }

  // Future<Map<String, dynamic>> addUserToGroup({
  //   required int groupId,
  //   required int userId,
  // }) async {
  //   final response = await _safePost(
  //     '/api/group/$groupId/add_user/',
  //     data: <String, dynamic>{'user_id': userId},
  //   );
  //   return _asMap(response.data);
  // }

  // Future<Map<String, dynamic>> removeUserFromGroup({
  //   required int groupId,
  //   required int userId,
  // }) async {
  //   final response = await _safeDelete(
  //     '/api/group/$groupId/remove_user/',
  //     data: <String, dynamic>{'user_id': userId},
  //   );
  //   return _asMap(response.data);
  // }

  Future<List<dynamic>> listMessages({int? alertId, int? groupId}) async {
    final response = await _safeGet(
      '/api/message/',
      queryParameters: <String, dynamic>{
        if (alertId != null) 'alert': alertId,
        if (groupId != null) 'group': groupId,
      },
    );
    return _asList(response.data);
  }

  Future<Map<String, dynamic>> createMessage({
    required String title,
    required String text,
    dynamic voiceFile,
    double? latitude,
    double? longitude,
    int? alertId,
    int? groupId,
  }) async {
    final payload = await _buildMessagePayload(
      title: title,
      text: text,
      voiceFile: voiceFile,
      latitude: latitude,
      longitude: longitude,
    );

    if (payload is Map<String, dynamic>) {
      if (alertId != null) payload['alert'] = alertId;
      if (groupId != null) payload['group'] = groupId;
    } else if (payload is FormData) {
      if (alertId != null) payload.fields.add(MapEntry('alert', '$alertId'));
      if (groupId != null) payload.fields.add(MapEntry('group', '$groupId'));
    }

    final response = await _safePost('/api/message/', data: payload);
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw StateError(_apiErrorMessage(response.data));
    }
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getMessage(int id) async {
    final response = await _safeGet('/api/message/$id/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateMessage({
    required int id,
    required String title,
    required String text,
    dynamic voiceFile,
    double? latitude,
    double? longitude,
  }) async {
    final payload = await _buildMessagePayload(
      title: title,
      text: text,
      voiceFile: voiceFile,
      latitude: latitude,
      longitude: longitude,
    );

    final response = await _safePut('/api/message/$id/', data: payload);
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchMessage({
    required int id,
    String? title,
    String? text,
    dynamic voiceFile,
    double? latitude,
    double? longitude,
  }) async {
    final payload = await _buildMessagePayload(
      title: title,
      text: text,
      voiceFile: voiceFile,
      latitude: latitude,
      longitude: longitude,
      skipNulls: true,
    );

    final response = await _safePatch(
      '/api/message/$id/',
      data: payload,
    );
    return _asMap(response.data);
  }

  Future<void> deleteMessage(int id) async {
    await _safeDelete('/api/message/$id/');
  }

  Future<List<dynamic>> listMessagesNewestFirst() async {
    final response = await _safeGet('/api/message/list_messages/');
    return _asList(response.data);
  }

  Future<List<dynamic>> listNotifications() async {
    final response = await _safeGet('/api/notification/');
    return _asList(response.data);
  }

  Future<Map<String, dynamic>> createNotification(
      {required String token}) async {
    final response = await _safePost(
      '/api/notification/',
      data: <String, dynamic>{'token': token},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getNotification(int id) async {
    final response = await _safeGet('/api/notification/$id/');
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> updateNotification({
    required int id,
    required String token,
  }) async {
    final response = await _safePut(
      '/api/notification/$id/',
      data: <String, dynamic>{'token': token},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchNotification({
    required int id,
    required String token,
  }) async {
    final response = await _safePatch(
      '/api/notification/$id/',
      data: <String, dynamic>{'token': token},
    );
    return _asMap(response.data);
  }

  Future<void> deleteNotification(int id) async {
    await _safeDelete('/api/notification/$id/');
  }

  Future<List<AlertMessage>> getAllAlerts() async {
    final response = await _safeGet('/api/alerts/');
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw StateError(_apiErrorMessage(response.data));
    }
    final alertsResult = _asList(response.data);
    final alerts =
        alertsResult.map((json) => AlertMessage.fromJson(json)).toList();
    return alerts;
  }

  Future<Map<String, dynamic>> createAlert({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String status,
    required String priority,
  }) async {
    final response = await _safePost(
      '/api/alerts/',
      data: <String, dynamic>{
        'title': title,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'priority': priority,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> getAlert(int id) async {
    final response = await _safeGet('/api/alerts/$id/');
    return _asMap(response.data);
  }

  Future<AlertMessage> respondToAlert({
    required int id,
    required String response,
  }) async {
    final result = await _safePost(
      '/api/alerts/$id/respond/',
      data: <String, dynamic>{'response': response},
    );
    if (result.statusCode == null || result.statusCode! >= 400) {
      throw StateError(_apiErrorMessage(result.data));
    }
    return AlertMessage.fromJson(_asMap(result.data));
  }

  Future<AlertMessage> dispatchAlert({
    required int id,
    required List<int> userIds,
  }) async {
    final result = await _safePost(
      '/api/alerts/$id/dispatch/',
      data: <String, dynamic>{'user_ids': userIds},
    );
    if (result.statusCode == null || result.statusCode! >= 400) {
      throw StateError(_apiErrorMessage(result.data));
    }
    return AlertMessage.fromJson(_asMap(result.data));
  }

  Future<Map<String, dynamic>> updateAlert({
    required int id,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String status,
    required String priority,
  }) async {
    final response = await _safePut(
      '/api/alerts/$id/',
      data: <String, dynamic>{
        'title': title,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'priority': priority,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> patchAlert({
    required int id,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? status,
    String? priority,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (status != null) data['status'] = status;
    if (priority != null) data['priority'] = priority;

    final response = await _safePatch('/api/alerts/$id/', data: data);
    return _asMap(response.data);
  }

  Future<void> deleteAlert(int id) async {
    await _safeDelete('/api/alerts/$id/');
  }

  Future<List<dynamic>> listNearbyAlerts({
    required double lat,
    required double lon,
    required int radius,
  }) async {
    final response = await _safeGet(
      '/api/alerts/nearby/',
      queryParameters: <String, dynamic>{
        'lat': lat,
        'lon': lon,
        'radius': radius,
      },
    );
    return _asList(response.data);
  }

  Future<dynamic> _buildMessagePayload({
    String? title,
    String? text,
    dynamic voiceFile,
    double? latitude,
    double? longitude,
    bool skipNulls = false,
  }) async {
    final hasFile = voiceFile != null;

    if (!hasFile) {
      final data = <String, dynamic>{
        'title': title,
        'text': text,
        'latitude': latitude,
        'longitude': longitude,
      };
      if (skipNulls) {
        data.removeWhere((key, value) => value == null);
      }
      return data;
    }

    MultipartFile filePart;
    if (voiceFile is MultipartFile) {
      filePart = voiceFile;
    } else if (voiceFile is String) {
      filePart = await MultipartFile.fromFile(voiceFile);
    } else {
      throw ArgumentError(
        'voiceFile must be either a file path String or MultipartFile.',
      );
    }

    final formMap = <String, dynamic>{
      'title': title,
      'text': text,
      'voice_file': filePart,
      'latitude': latitude,
      'longitude': longitude,
    };

    if (skipNulls) {
      formMap.removeWhere((key, value) => value == null);
    }

    return FormData.fromMap(formMap);
  }

  Future<Response<dynamic>> _safeGet(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return _toErrorResponse(
          path: path,
          error: StateError('Missing authorization headers'),
        );
      }

      return await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      return _toErrorResponse(
        path: path,
        dioException: error,
      );
    } catch (error) {
      return _toErrorResponse(
        path: path,
        error: error,
      );
    }
  }

  Future<Response<dynamic>> _safePost(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final isJwtTokenRoute =
          path == '/api/token/' || path == '/api/token/refresh/';
      if (!isJwtTokenRoute && !await checkDioHeaders()) {
        return _toErrorResponse(
          path: path,
          error: StateError('Missing authorization headers'),
        );
      }

      return await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      return _toErrorResponse(
        path: path,
        dioException: error,
      );
    } catch (error) {
      return _toErrorResponse(
        path: path,
        error: error,
      );
    }
  }

  Future<Response<dynamic>> _safePut(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return _toErrorResponse(
          path: path,
          error: StateError('Missing authorization headers'),
        );
      }

      return await _dio.put<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      return _toErrorResponse(
        path: path,
        dioException: error,
      );
    } catch (error) {
      return _toErrorResponse(
        path: path,
        error: error,
      );
    }
  }

  Future<Response<dynamic>> _safePatch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return _toErrorResponse(
          path: path,
          error: StateError('Missing authorization headers'),
        );
      }

      return await _dio.patch<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      return _toErrorResponse(
        path: path,
        dioException: error,
      );
    } catch (error) {
      return _toErrorResponse(
        path: path,
        error: error,
      );
    }
  }

  Future<Response<dynamic>> _safeDelete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      if (!await checkDioHeaders()) {
        return _toErrorResponse(
          path: path,
          error: StateError('Missing authorization headers'),
        );
      }

      return await _dio.delete<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
    } on DioException catch (error) {
      return _toErrorResponse(
        path: path,
        dioException: error,
      );
    } catch (error) {
      return _toErrorResponse(
        path: path,
        error: error,
      );
    }
  }

  Response<dynamic> _toErrorResponse({
    required String path,
    DioException? dioException,
    Object? error,
  }) {
    if (dioException?.response != null) {
      return dioException!.response!;
    }

    final String message =
        dioException?.message ?? error?.toString() ?? 'Unknown API error';

    return Response<dynamic>(
      requestOptions:
          dioException?.requestOptions ?? RequestOptions(path: path),
      statusCode: -1,
      statusMessage: message,
      data: <String, dynamic>{
        'error': message,
      },
    );
  }

  Message _emptyAppMessage() {
    return Message.empty();
  }

  String _apiErrorMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data.values.join(' ');
    }
    return data?.toString() ?? 'הפעולה נכשלה. נסו שוב.';
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw StateError('Expected JSON object but received: ${data.runtimeType}');
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List) {
      return data;
    }
    if (data is Map<String, dynamic> && data['results'] is List) {
      return data['results'] as List<dynamic>;
    }
    throw StateError('Expected JSON list but received: ${data.runtimeType}');
  }
}
