import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:rescue_app/domain/services/api/rest_api_service.dart';
import 'package:rescue_app/domain/services/permission_service.dart';

class PttRoomCredentials {
  const PttRoomCredentials({required this.url, required this.token});

  final String url;
  final String token;
}

abstract interface class PttCredentialsProvider {
  Future<PttRoomCredentials> getCredentials(int groupId);
}

abstract interface class PttMicrophonePermission {
  Future<bool> requestMicrophone();
}

abstract interface class PttRoomClient {
  bool get isConnected;
  List<String> get activeSpeakerNames;
  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<void> connect(PttRoomCredentials credentials);
  Future<void> setMicrophoneEnabled(bool enabled);
  Future<void> disconnect();
  Future<void> dispose();
}

abstract interface class PttRoomClientFactory {
  PttRoomClient create();
}

class PttSession extends ChangeNotifier {
  PttSession({
    required PttCredentialsProvider credentialsProvider,
    required PttMicrophonePermission microphonePermission,
    required PttRoomClientFactory roomFactory,
  })  : _credentialsProvider = credentialsProvider,
        _microphonePermission = microphonePermission,
        _roomFactory = roomFactory;

  factory PttSession.live() => PttSession(
        credentialsProvider: _RestCredentialsProvider(),
        microphonePermission: _PermissionAdapter(),
        roomFactory: _LiveKitRoomFactory(),
      );

  final PttCredentialsProvider _credentialsProvider;
  final PttMicrophonePermission _microphonePermission;
  final PttRoomClientFactory _roomFactory;
  PttRoomClient? _room;
  bool _transmitting = false;

  bool get connected => _room?.isConnected ?? false;
  bool get transmitting => _transmitting;
  List<String> get activeSpeakerNames => _room?.activeSpeakerNames ?? const [];

  Future<void> join(int groupId) async {
    if (connected) return;
    await leave();
    final room = _roomFactory.create();
    room.addListener(_onRoomChanged);
    try {
      await room.connect(await _credentialsProvider.getCredentials(groupId));
      await room.setMicrophoneEnabled(false);
      _room = room;
      notifyListeners();
    } catch (_) {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
      rethrow;
    }
  }

  Future<bool> startTransmission() async {
    final room = _room;
    if (room == null || !room.isConnected) return false;
    if (!await _microphonePermission.requestMicrophone()) return false;
    await room.setMicrophoneEnabled(true);
    _transmitting = true;
    notifyListeners();
    return true;
  }

  Future<void> stopTransmission() async {
    if (!_transmitting) return;
    await _room?.setMicrophoneEnabled(false);
    _transmitting = false;
    notifyListeners();
  }

  Future<void> leave() async {
    final room = _room;
    _room = null;
    _transmitting = false;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      await room.disconnect();
      await room.dispose();
    }
    notifyListeners();
  }

  void _onRoomChanged() => notifyListeners();

  @override
  void dispose() {
    final room = _room;
    _room = null;
    if (room != null) {
      room.removeListener(_onRoomChanged);
      room.disconnect();
      room.dispose();
    }
    super.dispose();
  }
}

class _RestCredentialsProvider implements PttCredentialsProvider {
  final _api = RestApiService();

  @override
  Future<PttRoomCredentials> getCredentials(int groupId) async {
    final credentials = await _api.getPttRoomCredentials(groupId);
    return PttRoomCredentials(
      url: credentials['url'] as String,
      token: credentials['token'] as String,
    );
  }
}

class _PermissionAdapter implements PttMicrophonePermission {
  final _permissions = PermissionService();

  @override
  Future<bool> requestMicrophone() => _permissions.requestMicrophone();
}

class _LiveKitRoomFactory implements PttRoomClientFactory {
  @override
  PttRoomClient create() => _LiveKitRoomClient(Room());
}

class _LiveKitRoomClient implements PttRoomClient {
  _LiveKitRoomClient(this._room);

  final Room _room;

  @override
  bool get isConnected => _room.connectionState == ConnectionState.connected;

  @override
  List<String> get activeSpeakerNames => _room.activeSpeakers
      .where((participant) => participant.identity != _room.localParticipant?.identity)
      .map((participant) => participant.name)
      .toList(growable: false);

  @override
  void addListener(VoidCallback listener) => _room.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _room.removeListener(listener);

  @override
  Future<void> connect(PttRoomCredentials credentials) =>
      _room.connect(credentials.url, credentials.token);

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async =>
      _room.localParticipant?.setMicrophoneEnabled(enabled);

  @override
  Future<void> disconnect() => _room.disconnect();

  @override
  Future<void> dispose() => _room.dispose();
}
