import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import test from 'node:test';
import { setTimeout as delay } from 'node:timers/promises';
import { AccessToken } from 'livekit-server-sdk';
import {
  AudioFrame,
  AudioSource,
  AudioStream,
  LocalAudioTrack,
  Room,
  RoomEvent,
  TrackPublishOptions,
  TrackSource,
  dispose,
} from '@livekit/rtc-node';

const livekitUrl = process.env.LIVEKIT_URL ?? 'ws://127.0.0.1:7880';
const apiKey = process.env.LIVEKIT_API_KEY ?? 'devkey';
const apiSecret = process.env.LIVEKIT_API_SECRET ?? 'secret';

async function createToken(room, identity) {
  const token = new AccessToken(apiKey, apiSecret, { identity, ttl: '5m' });
  token.addGrant({
    room,
    roomJoin: true,
    canPublish: true,
    canSubscribe: true,
    canPublishSources: [TrackSource.SOURCE_MICROPHONE],
  });
  return token.toJwt();
}

function within(promise, milliseconds, message) {
  return Promise.race([
    promise,
    delay(milliseconds).then(() => {
      throw new Error(message);
    }),
  ]);
}

test('PTT publishes synthetic microphone audio to another room participant', { timeout: 20000 }, async () => {
  const roomName = `ptt-test-${randomUUID()}`;
  const publisher = new Room();
  const subscriber = new Room();
  let track;
  let reader;

  try {
    const subscribedTrack = new Promise((resolve) => {
      subscriber.on(RoomEvent.TrackSubscribed, (remoteTrack) => resolve(remoteTrack));
    });

    await Promise.all([
      publisher.connect(livekitUrl, await createToken(roomName, 'ptt-publisher')),
      subscriber.connect(livekitUrl, await createToken(roomName, 'ptt-listener')),
    ]);

    const source = new AudioSource(16000, 1);
    track = LocalAudioTrack.createAudioTrack('microphone', source);
    const options = new TrackPublishOptions();
    options.source = TrackSource.SOURCE_MICROPHONE;
    await publisher.localParticipant.publishTrack(track, options);

    const remoteTrack = await within(subscribedTrack, 5000, 'subscriber did not receive the microphone track');
    const stream = new AudioStream(remoteTrack, { sampleRate: 16000, numChannels: 1 });
    reader = stream.getReader();

    const samples = new Int16Array(320);
    for (let index = 0; index < samples.length; index += 1) {
      samples[index] = Math.round(12000 * Math.sin((2 * Math.PI * 440 * index) / 16000));
    }
    const receivesNonSilentAudio = (async () => {
      for (let frame = 0; frame < 40; frame += 1) {
        const received = await reader.read();
        if (received.done) return false;
        if (received.value.data.some((sample) => sample !== 0)) return true;
      }
      return false;
    })();

    for (let frame = 0; frame < 40; frame += 1) {
      await source.captureFrame(new AudioFrame(samples, 16000, 1, samples.byteLength / 2));
      await delay(10);
    }

    assert.equal(
      await within(receivesNonSilentAudio, 5000, 'subscriber did not receive a non-silent audio frame'),
      true,
      'received audio frames were silent',
    );
  } finally {
    await reader?.cancel();
    await track?.close();
    await Promise.allSettled([publisher.disconnect(), subscriber.disconnect()]);
    await dispose();
  }
});
