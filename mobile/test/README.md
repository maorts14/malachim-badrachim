# Mobile tests

Run `flutter test` from `mobile`.

`ptt_session_test.dart` covers the PTT client contract: joining with backend
credentials, default mute, permission-gated transmission, release-to-mute, and
room cleanup. It uses fakes, so it does not need a device or LiveKit server.
