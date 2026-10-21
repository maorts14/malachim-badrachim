import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_app/domain/services/ptt_session.dart';

void main() {
  group('PttSession', () {
    late _FakeCredentials credentials;
    late _FakePermission permission;
    late _FakeRoom room;
    late PttSession session;

    setUp(() {
      credentials = _FakeCredentials();
      permission = _FakePermission();
      room = _FakeRoom();
      session = PttSession(
        credentialsProvider: credentials,
        microphonePermission: permission,
        roomFactory: _FakeRoomFactory(room),
      );
    });

    test('joins with backend credentials and starts muted', () async {
      await session.join(7);

      expect(credentials.requestedGroupId, 7);
      expect(room.connectedUrl, 'ws://livekit.test:7880');
      expect(room.connectedToken, 'ptt-token');
      expect(room.microphoneStates, [false]);
      expect(session.connected, isTrue);
    });

    test('only enables the microphone while permission is granted', () async {
      await session.join(7);
      permission.granted = false;

      expect(await session.startTransmission(), isFalse);
      expect(room.microphoneStates, [false]);
      expect(session.transmitting, isFalse);

      permission.granted = true;
      expect(await session.startTransmission(), isTrue);
      expect(room.microphoneStates, [false, true]);
      expect(session.transmitting, isTrue);

      await session.stopTransmission();
      expect(room.microphoneStates, [false, true, false]);
      expect(session.transmitting, isFalse);
    });

    test('cannot transmit before joining and releases the room on leave', () async {
      expect(await session.startTransmission(), isFalse);
      await session.join(7);
      await session.leave();

      expect(room.disconnected, isTrue);
      expect(room.disposed, isTrue);
      expect(session.connected, isFalse);
    });
  });
}

class _FakeCredentials implements PttCredentialsProvider {
  int? requestedGroupId;

  @override
  Future<PttRoomCredentials> getCredentials(int groupId) async {
    requestedGroupId = groupId;
    return const PttRoomCredentials(
      url: 'ws://livekit.test:7880',
      token: 'ptt-token',
    );
  }
}

class _FakePermission implements PttMicrophonePermission {
  bool granted = true;

  @override
  Future<bool> requestMicrophone() async => granted;
}

class _FakeRoomFactory implements PttRoomClientFactory {
  _FakeRoomFactory(this.room);
  final _FakeRoom room;

  @override
  PttRoomClient create() => room;
}

class _FakeRoom implements PttRoomClient {
  bool _connected = false;
  String? connectedUrl;
  String? connectedToken;
  bool disconnected = false;
  bool disposed = false;
  final List<bool> microphoneStates = [];

  @override
  List<String> get activeSpeakerNames => const [];

  @override
  bool get isConnected => _connected;

  @override
  void addListener(void Function() listener) {}

  @override
  Future<void> connect(PttRoomCredentials credentials) async {
    connectedUrl = credentials.url;
    connectedToken = credentials.token;
    _connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
    _connected = false;
  }

  @override
  Future<void> dispose() async => disposed = true;

  @override
  void removeListener(void Function() listener) {}

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    microphoneStates.add(enabled);
  }
}
