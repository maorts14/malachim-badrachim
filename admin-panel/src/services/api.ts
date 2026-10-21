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
  latitude: number | null;
  longitude: number | null;
  timestamp: string;
}

export interface ApiGroup {
  id: number;
  name: string;
  members: number[];
}

export interface PttRoomCredentials {
  url: string;
  room: string;
  token: string;
}

export interface RealtimeMessageEvent {
  type: 'message.created';
  message: ApiMessage;
}

export interface SessionUser {
  id: number;
  username: string;
  email: string;
  name: string;
  role: string | null;
  is_staff: boolean;
}

export interface SessionResponse {
  authenticated: boolean;
  user: SessionUser | null;
}

export class ApiError extends Error {
  readonly status: number;
  readonly fieldErrors: Record<string, string[]>;

  constructor(message: string, status: number, fieldErrors: Record<string, string[]> = {}) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.fieldErrors = fieldErrors;
  }
}

export function isApiError(error: unknown): error is ApiError {
  return error instanceof ApiError;
}

async function errorDetails(response: Response): Promise<{ message: string; fieldErrors: Record<string, string[]> }> {
  const body = await response.json().catch(() => null) as Record<string, unknown> | null;
  if (body?.detail && typeof body.detail === 'string') return { message: body.detail, fieldErrors: {} };
  if (body?.error && typeof body.error === 'string') return { message: body.error, fieldErrors: {} };
  const fieldErrors = Object.fromEntries(Object.entries(body ?? {}).filter(([, value]) =>
    Array.isArray(value) && value.every((message) => typeof message === 'string'),
  )) as Record<string, string[]>;
  if (Object.keys(fieldErrors).length > 0) return { message: 'יש לתקן את השדות המסומנים.', fieldErrors };
  return { message: `Request failed (${response.status})`, fieldErrors: {} };
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const method = (init.method ?? 'GET').toUpperCase();
  const csrfToken = document.cookie.split('; ').find((item) => item.startsWith('csrftoken='))?.split('=')[1];

  const response = await fetch(`${baseUrl}${path}`, {
    ...init,
    credentials: 'include',
    headers: {
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...(method === 'GET' || method === 'HEAD' || !csrfToken ? {} : { 'X-CSRFToken': decodeURIComponent(csrfToken) }),
      ...init.headers,
    },
  });
  if (!response.ok) {
    const details = await errorDetails(response);
    throw new ApiError(details.message, response.status, details.fieldErrors);
  }
  return response.status === 204 ? (undefined as T) : (response.json() as Promise<T>);
}

export const rescueApi = {
  getSession: () => request<SessionResponse>('/auth/session/'),
  login: (username: string, password: string) =>
    request<SessionResponse>('/auth/session/login/', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),
  logout: () => request<void>('/auth/session/logout/', { method: 'POST' }),
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
  getPttRoomCredentials: (groupId: number) =>
    request<PttRoomCredentials>(`/group/${groupId}/ptt-token/`, { method: 'POST' }),
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
