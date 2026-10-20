import 'dart:async';
import 'dart:convert';
import 'package:rescue_app/constants/app_env.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/models/message.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MessageRepository {
  MessageRepository({required RestApiService apiClient})
      : _apiClient = apiClient;

  final RestApiService _apiClient;
  final BehaviorSubject<List<Message>> _messageStream =
      BehaviorSubject.seeded(const []);
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  StreamSubscription<dynamic>? _socketSubscription;
  WebSocketChannel? _socket;
  bool _refreshInFlight = false;
  bool _realtimeWanted = false;

  Stream<List<Message>> get messages$ => _messageStream.stream;

  Future<void> refreshMessages() async {
    final messages = await _apiClient.getMessages();
    _messageStream.add(messages);
  }

  /// Keeps the queue current while the signed-in app is foregrounded.  The
  /// server still applies its per-user visibility rules on every request.
  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _pollTimer ??= Timer.periodic(interval, (_) => _refreshSilently());
    _refreshSilently();
    _realtimeWanted = true;
    unawaited(_startRealtime());
  }

  void stopPolling() {
    _realtimeWanted = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    unawaited(_socketSubscription?.cancel());
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    unawaited(socket?.sink.close());
    _messageStream.add(const []);
  }

  Future<void> _startRealtime() async {
    if (!_realtimeWanted || _socket != null) return;
    try {
      final token = _apiClient.accessToken;
      if (token == null || token.isEmpty) return;
      final apiUri = Uri.parse(AppEnv.apiBaseUrl);
      final socketUri = apiUri.replace(
        scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/messages/',
        queryParameters: {'token': token},
      );
      final channel = WebSocketChannel.connect(
        socketUri,
        protocols: const ['rescue-v1'],
      );
      await channel.ready;
      if (!_realtimeWanted) {
        await channel.sink.close();
        return;
      }
      _socket = channel;
      _socketSubscription = channel.stream.listen(
        _handleRealtimeEvent,
        onError: (_, __) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _socketSubscription = null;
    _socket = null;
    if (!_realtimeWanted || _reconnectTimer != null) return;
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _reconnectTimer = null;
      unawaited(_startRealtime());
    });
  }

  void _handleRealtimeEvent(dynamic rawEvent) {
    try {
      final event = jsonDecode(rawEvent as String) as Map<String, dynamic>;
      if (event['type'] != 'message.created' || event['message'] is! Map) {
        return;
      }
      final message = Message.fromJson(
        Map<String, dynamic>.from(event['message'] as Map),
      );
      final current =
          List<Message>.from(_messageStream.valueOrNull ?? const []);
      if (current.any((existing) => existing.id == message.id)) return;
      _messageStream.add([message, ...current]);
    } catch (_) {
      // Ignore malformed transport events; polling will reconcile the queue.
    }
  }

  Future<void> _refreshSilently() async {
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    try {
      await refreshMessages();
    } catch (_) {
      // A transient refresh must not clear the last known operational queue.
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<Message> getMessageDetails(String id) => _apiClient.getMessageById(id);

  Future<void> postMessage({
    required String title,
    required String text,
  }) async {
    await _apiClient.postMessage(
      title: title,
      text: text,
    );
    await refreshMessages();
  }

  Future<void> dispose() async {
    stopPolling();
    await _messageStream.close();
  }
}
