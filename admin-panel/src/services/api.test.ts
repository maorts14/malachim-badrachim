import { afterEach, describe, expect, it, vi } from 'vitest';
import { rescueApi } from './api';

describe('session API client', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    document.cookie = 'csrftoken=; Max-Age=0';
  });

  it('uses the shared authenticated request path for session operations', async () => {
    document.cookie = 'csrftoken=csrf%20token';
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({ authenticated: false, user: null })))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        authenticated: true,
        user: { id: 1, username: 'dispatcher', email: 'dispatcher@example.com', name: 'Dispatcher', role: 'emergency_dispatcher', is_staff: true },
      })))
      .mockResolvedValueOnce(new Response(null, { status: 204 }));
    vi.stubGlobal('fetch', fetchMock);

    await rescueApi.getSession();
    await rescueApi.login('dispatcher@example.com', 'secret');
    await rescueApi.logout();

    expect(fetchMock).toHaveBeenNthCalledWith(1, '/api/auth/session/', expect.objectContaining({ credentials: 'include' }));
    expect(fetchMock).toHaveBeenNthCalledWith(2, '/api/auth/session/login/', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ 'Content-Type': 'application/json', 'X-CSRFToken': 'csrf token' }),
      body: JSON.stringify({ username: 'dispatcher@example.com', password: 'secret' }),
    }));
    expect(fetchMock).toHaveBeenNthCalledWith(3, '/api/auth/session/logout/', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ 'X-CSRFToken': 'csrf token' }),
    }));
  });
});
