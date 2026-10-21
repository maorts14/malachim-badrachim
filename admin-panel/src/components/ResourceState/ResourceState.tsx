import { isApiError } from '@/services/api';
import './ResourceState.css';

interface ResourceStateProps {
  error: Error | null;
  loading: boolean;
  refreshing: boolean;
  empty: boolean;
  onRetry: () => void;
  loadingLabel: string;
  emptyLabel: string;
}

export default function ResourceState({
  error,
  loading,
  refreshing,
  empty,
  onRetry,
  loadingLabel,
  emptyLabel,
}: ResourceStateProps) {
  if (loading) return <p className="resource-state" role="status">{loadingLabel}</p>;
  if (error && isApiError(error) && error.status === 403) {
    return <section className="resource-state resource-state--forbidden" role="alert"><p>אין לך הרשאה לצפות בנתונים אלה.</p><button type="button" onClick={onRetry}>נסה שוב</button></section>;
  }
  if (error) {
    return <section className="resource-state resource-state--error" role="alert"><p>{error.message}</p><button type="button" onClick={onRetry}>נסה שוב</button></section>;
  }
  if (empty) return <p className="resource-state">{emptyLabel}</p>;
  if (refreshing) return <p className="resource-state resource-state--refreshing" role="status">מעדכן נתונים…</p>;
  return null;
}
