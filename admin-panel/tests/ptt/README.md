# Push-to-talk tests

- `npm test -- Ptt.test.tsx` checks joining, mute-by-default, and press/release
  microphone control with a mocked browser LiveKit client.
- `npm run test:ptt:integration` connects two real LiveKit clients and verifies
  that synthetic microphone audio is received. It defaults to the local Docker
  development server at `ws://127.0.0.1:7880`; set `LIVEKIT_URL`,
  `LIVEKIT_API_KEY`, and `LIVEKIT_API_SECRET` to target another test server.
