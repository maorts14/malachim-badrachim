import type { ApiUser } from '../services/api';
import type { User } from '../types/types';

const roleLabel: Record<ApiUser['role'], string> = {
  manager: 'מנהל',
  emergency_dispatcher: 'מוקדן חירום',
  user: 'מתנדב',
};

export function toDashboardUser(user: ApiUser): User {
  return {
    id: user.id,
    name: user.display_name || user.username,
    lastUpdate: '—',
    status: roleLabel[user.role],
    event: null,
    info: user.phone || user.email,
    dotColor: user.latitude === null || user.longitude === null ? 'grey' : '#22c55e',
    dotType: 'single',
    unread: 0,
  };
}
