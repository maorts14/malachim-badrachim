# Live PTT implementation

## Decision

The previous group “PTT” implementation was asynchronous voice notes: a client
recorded a file, uploaded it as `Message.voice_file`, and later clients played
the stored file. That model was removed.

The product now uses true, live push-to-talk for operational groups. There is
no MinIO/S3 bucket, audio retention window, scanning pipeline, or replay
feature because PTT audio is not stored by this system.

This work fulfils the real-time communication part of #88 and the durable
dashboard PTT portion of #32. Issue #37 was consolidated into #88 and is not a
separate delivery target.

## Architecture

```text
Mobile app / Admin panel
        │ authenticated POST /api/group/{id}/ptt-token/
        ▼
Django API ── verifies dispatcher or group membership ──► LiveKit JWT
        │                                              (15 minutes, one room)
        ▼
LiveKit room: group-{id} ◄──── live microphone audio ────► room participants
```

Each group maps to a LiveKit room named `group-{group_id}`. The Django API
issues a 15-minute JWT only after confirming that the caller is a dispatcher or
a member of that group. Tokens permit microphone publishing and subscribing in
that one room. The LiveKit API secret remains server-side.

## Backend contract

`POST /api/group/{group_id}/ptt-token/`

Successful response:

```json
{
  "url": "wss://ptt.example.com",
  "room": "group-42",
  "token": "<short-lived-livekit-jwt>"
}
```

- A non-member cannot retrieve a room through the group queryset and receives
  `404`.
- A deployment without LiveKit configuration receives `503` with a clear
  configuration error.
- Group creation and membership management remain manager-only; dispatchers can
  operate across existing groups and volunteers can access only their own.

The Postman collection is the runnable API reference for this endpoint.

## Client behavior

### Admin panel

The PTT route loads durable group and membership data. Managers can create and
edit groups. A dispatcher joins a selected group, then the hold-to-talk button
enables the microphone only while held and disables it on release. The screen
shows connection and active-speaker state. It does not show a message history,
an upload control, or stored-audio playback.

### Mobile app

The Flutter PTT tab loads permitted groups, joins the selected LiveKit room,
and enables the microphone only for the duration of a long press. It displays
room connection and remote active-speaker state. Android declares `INTERNET`
and `RECORD_AUDIO`; iOS declares a microphone usage description.

## Removed voice-note architecture

- `Message.voice_file` and `voice_url` were removed from the Django model,
  serializer, API clients, and the initial schema baseline.
- Browser `MediaRecorder`, Flutter recorder/player services, multipart audio
  uploads, and message-audio playback widgets were removed.
- `audioplayers` and `record` were removed from Flutter dependencies.
- The Message API and its WebSocket/polling transport remain for text messages.

## Configuration and deployment

Local development uses `livekit/livekit-server:v1.9.10 --dev` through
`docker-compose.local.yml`, with local-only `devkey`/`secret` defaults. The
backend can be overridden with `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and
`LIVEKIT_API_SECRET` in `.env.local`.

Production requires a separately deployed, publicly reachable LiveKit service:

1. Provide a TLS-enabled public `wss://` endpoint.
2. Configure real `LIVEKIT_URL`, `LIVEKIT_API_KEY`, and
   `LIVEKIT_API_SECRET` in the backend environment.
3. Configure the LiveKit deployment’s required TCP/UDP connectivity, including
   TURN where the target networks require it.
4. Validate live audio on a real mobile device and a dispatcher browser over
   the production network.

The local `ws://localhost:7880` URL works for the browser. Android emulator
testing instead needs `ws://10.0.2.2:7880`; physical devices need a reachable
LAN URL. This is a development-host addressing difference, not a production
design.

## Verification completed

- Django `alerts` suite: 18 tests pass, including group access, token claims,
  and unavailable-configuration cases.
- Flutter analysis passes with no issues.
- Admin production build succeeds.
- The Postman collection parses as valid JSON.
- Local Docker Compose starts the LiveKit development server and backend with
  the documented defaults.

## Remaining operational verification

Real device/browser audio and production network traversal have not yet been
performed. They depend on the production LiveKit hostname, TLS, firewall/TURN
configuration, and test devices. There is intentionally no recording,
retention, deletion, or forensic-history workflow in this release.
