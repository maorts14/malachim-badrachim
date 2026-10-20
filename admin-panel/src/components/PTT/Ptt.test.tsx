import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

const testState = vi.hoisted(() => ({
  rooms: [] as Array<{
    connect: ReturnType<typeof vi.fn>;
    disconnect: ReturnType<typeof vi.fn>;
    startAudio: ReturnType<typeof vi.fn>;
    localParticipant: { setMicrophoneEnabled: ReturnType<typeof vi.fn> };
  }>,
  api: {
    listGroups: vi.fn(),
    listUsers: vi.fn(),
    getPttRoomCredentials: vi.fn(),
    createGroup: vi.fn(),
    updateGroup: vi.fn(),
  },
}));

vi.mock('livekit-client', () => ({
  Room: class {
    connect = vi.fn().mockResolvedValue(undefined);
    disconnect = vi.fn().mockResolvedValue(undefined);
    startAudio = vi.fn().mockResolvedValue(undefined);
    localParticipant = { setMicrophoneEnabled: vi.fn().mockResolvedValue(undefined) };
    on = vi.fn();

    constructor() {
      testState.rooms.push(this);
    }
  },
  RoomEvent: {
    TrackSubscribed: 'TrackSubscribed',
    TrackUnsubscribed: 'TrackUnsubscribed',
    ActiveSpeakersChanged: 'ActiveSpeakersChanged',
    Disconnected: 'Disconnected',
  },
  Track: { Kind: { Audio: 'audio' } },
}));

vi.mock('@/context/AuthContext', () => ({
  useAuth: () => ({ user: { role: 'emergency_dispatcher' } }),
}));

vi.mock('@/services/api', () => ({
  rescueApi: testState.api,
}));

import Ptt from './Ptt';

describe('Ptt', () => {
  afterEach(() => {
    vi.clearAllMocks();
    testState.rooms.length = 0;
  });

  it('joins the selected live room and enables the microphone only while held', async () => {
    testState.api.listGroups.mockResolvedValue([{ id: 7, name: 'North team', members: [12] }]);
    testState.api.listUsers.mockResolvedValue([]);
    testState.api.getPttRoomCredentials.mockResolvedValue({
      url: 'ws://livekit.test:7880',
      room: 'group-7',
      token: 'group-token',
    });

    render(<Ptt />);

    await screen.findByRole('button', { name: /North team/ });
    fireEvent.click(screen.getByRole('button', { name: 'התחבר/י לקשר' }));

    await waitFor(() => expect(testState.rooms).toHaveLength(1));
    const room = testState.rooms[0]!;
    expect(testState.api.getPttRoomCredentials).toHaveBeenCalledWith(7);
    expect(room.connect).toHaveBeenCalledWith('ws://livekit.test:7880', 'group-token');
    expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenCalledWith(false);

    const transmit = screen.getByRole('button', { name: /לחצו והחזיקו כדי לדבר/ });
    fireEvent.pointerDown(transmit);
    await waitFor(() => expect(room.startAudio).toHaveBeenCalledOnce());
    expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenLastCalledWith(true);

    fireEvent.pointerUp(transmit);
    await waitFor(() => expect(room.localParticipant.setMicrophoneEnabled).toHaveBeenLastCalledWith(false));
  });
});
