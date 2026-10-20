const baseUrl = (import.meta.env.VITE_API_BASE_URL ?? '/api').replace(/\/$/, '');

export type AlertStatus =
  | 'OPEN'
  | 'DISPATCHED'
  | 'ACCEPTED'
  | 'IN_PROGRESS'
  | 'RESOLVED'
  | 'CANCELLED';

export interface AlertAssignment {
  user_id: number;
  username: string;
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'ARRIVED';
  dispatched_at: string;
  responded_at: string | null;
}

export interface ApiAlert {
  id: number;
  title: string;
  description: string;
  latitude: number;
  longitude: number;
  status: AlertStatus;
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
  created_at: string;
  updated_at: string;
  assignments: AlertAssignment[];
}

export interface ApiUser {
  /** Profile primary key, used for profile/map presentation. */
  id: number;
  /** Django account primary key, required by POST /alerts/{id}/dispatch/. */
  user_id: number;
  username: string;
  email: string;
  display_name: string;
  phone: string;
  role: 'manager' | 'emergency_dispatcher' | 'user';
  latitude: number | null;
  longitude: number | null;
}

export interface ApiMessage {
  id: number;
  sender: { id: number; username: string; email: string; role: string | null };
  alert: number | null;
  group: number | null;
  title: string;
  text: string;
  voice_url: string | null;
  latitude: number | null;
  longitude: number | null;
  timestamp: string;
}

export interface ApiGroup {
  id: number;
  name: string;
  members: number[];
}

export interface RealtimeMessageEvent {
  type: 'message.created';
  message: ApiMessage;
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method ?? 'GET').toUpperCase();
  const csrfToken = document.cookie.split('; ').find((item) => item.startsWith('csrftoken='))?.split('=')[1];

  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    credentials: 'include',
    headers: {
      ...(init.body && !(init.body instanceof FormData) ? { 'Content-Type': 'application/json' } : {}),
      ...(method === 'GET' || method === 'HEAD' || !csrfToken ? {} : { 'X-CSRFToken': decodeURIComponent(csrfToken) }),
      ...init.headers,
    },
  });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(body || `Request failed (${response.status})`);
  }
  return response.status === 204 ? (undefined as T) : (response.json() as Promise<T>);
}

export const rescueApi = {
  listAlerts: () => request<ApiAlert[]>('/alerts/'),
  listUsers: () => request<ApiUser[]>('/user/'),
  createAlert: (payload: Pick<ApiAlert, 'title' | 'description' | 'latitude' | 'longitude' | 'priority'>) =>
    request<ApiAlert>('/alerts/', { method: 'POST', body: JSON.stringify(payload) }),
  updateAlert: (id: number, payload: Partial<ApiAlert>) =>
    request<ApiAlert>(`/alerts/${id}/`, { method: 'PATCH', body: JSON.stringify(payload) }),
  dispatchAlert: (id: number, userIds: number[]) =>
    request<ApiAlert>(`/alerts/${id}/dispatch/`, { method: 'POST', body: JSON.stringify({ user_ids: userIds }) }),
  listMessages: (alertId: number) => request<ApiMessage[]>(`/message/?alert=${alertId}`),
  createAlertMessage: (alertId: number, text: string) =>
    request<ApiMessage>('/message/', {
      method: 'POST',
      body: JSON.stringify({ alert: alertId, title: 'Dispatcher update', text }),
    }),
  listGroups: () => request<ApiGroup[]>('/group/'),
  createGroup: (payload: Pick<ApiGroup, 'name' | 'members'>) =>
    request<ApiGroup>('/group/', { method: 'POST', body: JSON.stringify(payload) }),
  updateGroup: (id: number, payload: Partial<Pick<ApiGroup, 'name' | 'members'>>) =>
    request<ApiGroup>(`/group/${id}/`, { method: 'PATCH', body: JSON.stringify(payload) }),
  listGroupMessages: (groupId: number) => request<ApiMessage[]>(`/message/?group=${groupId}`),
  createGroupMessage: (groupId: number, text: string) =>
    request<ApiMessage>('/message/', {
      method: 'POST',
      body: JSON.stringify({ group: groupId, title: 'Dispatcher update', text }),
    }),
  createGroupVoiceMessage: (groupId: number, voice: Blob) => {
    const form = new FormData();
    form.append('group', String(groupId));
    form.append('title', 'Voice transmission');
    form.append('text', '');
    form.append('voice_file', voice, 'transmission.webm');
    return request<ApiMessage>('/message/', { method: 'POST', body: form });
  },
};

/**
 * The browser attaches the Django session cookie to the same-origin socket.
 */
export async function openMessageSocket(
  onEvent: (event: RealtimeMessageEvent) => void,
): Promise<WebSocket> {
  const apiUrl = new URL(baseUrl, window.location.origin);
  const protocol = apiUrl.protocol === 'https:' ? 'wss:' : 'ws:';
  const socket = new WebSocket(`${protocol}//${apiUrl.host}/ws/messages/`);
  socket.addEventListener('message', (messageEvent) => {
    try {
      const event = JSON.parse(messageEvent.data) as RealtimeMessageEvent;
      if (event.type === 'message.created' && event.message) onEvent(event);
    } catch {
      // A malformed server event must not take down the dispatcher screen.
    }
  });
  return socket;
}
