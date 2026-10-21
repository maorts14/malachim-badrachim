import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/domain/services/auth_service.dart';
import 'package:rescue_app/managers/storage_manager.dart';

void main() {
  late HttpServer server;
  late List<_Request> requests;
  late _Response Function(_Request request) respond;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    dotenv.testLoad(
      fileInput: 'API_BASE_URL=http://${server.address.host}:${server.port}',
    );
    unawaited(_serve(server, () => requests, () => respond));
  });

  setUp(() {
    requests = <_Request>[];
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    AuthService().session.value = false;
  });

  tearDown(() async {
    await RestApiService().clearTokens();
    AuthService().session.value = false;
  });

  tearDownAll(() => server.close(force: true));

  test('restores a persisted session before an Events request is made',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      StorageManager.jwtRefreshToken: 'valid-refresh',
    });

    respond = (request) {
      if (request.path == '/api/token/refresh/') {
        return _Response.ok(<String, String>{
          'access': 'restored-access',
          'refresh': 'valid-refresh',
        });
      }
      if (request.path == '/api/alerts/') return _Response.ok(<Object>[]);
      return _Response.notFound();
    };

    expect(
      await StorageManager.instance.getJwtRefreshToken(),
      'valid-refresh',
    );
    await AuthService().restoreSession();
    expect(
        RestApiService.baseUrl, 'http://${server.address.host}:${server.port}');
    expect(
      requests.map((request) => request.path),
      <String>['/api/token/refresh/'],
    );
    expect(AuthService().isAuthenticated, isTrue);

    await RestApiService().getAllAlerts();

    expect(
      requests.map((request) => request.path),
      <String>['/api/token/refresh/', '/api/alerts/'],
    );
    expect(requests.last.authorization, 'Bearer restored-access');
  });

  test('refreshes an expired access token once and retries Events', () async {
    respond = (request) {
      if (request.path == '/api/alerts/' &&
          request.authorization == 'Bearer expired-access') {
        return _Response.unauthorized();
      }
      if (request.path == '/api/token/refresh/') {
        return _Response.ok(<String, String>{
          'access': 'renewed-access',
          'refresh': 'valid-refresh',
        });
      }
      if (request.path == '/api/alerts/' &&
          request.authorization == 'Bearer renewed-access') {
        return _Response.ok(<Object>[]);
      }
      return _Response.notFound();
    };

    await RestApiService().setAuthToken(
      access: 'expired-access',
      refresh: 'valid-refresh',
    );
    await RestApiService().getAllAlerts();

    expect(
      requests.map((request) => '${request.method} ${request.path}'),
      <String>[
        'GET /api/alerts/',
        'POST /api/token/refresh/',
        'GET /api/alerts/',
      ],
    );
  });

  test(
      'invalid saved credentials leave the user signed out and never load Events',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      StorageManager.jwtRefreshToken: 'invalid-refresh',
    });

    respond = (request) {
      if (request.path == '/api/token/refresh/') {
        return _Response.unauthorized();
      }
      return _Response.notFound();
    };

    await AuthService().restoreSession();

    expect(AuthService().isAuthenticated, isFalse);
    expect(requests.map((request) => request.path),
        <String>['/api/token/refresh/']);
  });
}

Future<void> _serve(
  HttpServer server,
  List<_Request> Function() requests,
  _Response Function(_Request request) Function() respond,
) async {
  await for (final request in server) {
    await request.drain<void>();
    final captured = _Request(
      method: request.method,
      path: request.uri.path,
      authorization: request.headers.value(HttpHeaders.authorizationHeader),
    );
    requests().add(captured);
    final response = respond()(captured);
    request.response.statusCode = response.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(response.body));
    await request.response.close();
  }
}

class _Request {
  const _Request({
    required this.method,
    required this.path,
    required this.authorization,
  });

  final String method;
  final String path;
  final String? authorization;
}

class _Response {
  const _Response(this.statusCode, this.body);

  factory _Response.ok(Object body) => _Response(200, body);
  factory _Response.unauthorized() =>
      const _Response(401, <String, String>{'detail': 'Unauthorized'});
  factory _Response.notFound() =>
      const _Response(404, <String, String>{'detail': 'Not found'});

  final int statusCode;
  final Object body;
}
