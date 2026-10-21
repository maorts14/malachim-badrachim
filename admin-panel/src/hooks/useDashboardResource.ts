import { useCallback, useEffect, useRef, useState } from 'react';
import { type ApiError, isApiError } from '@/services/api';

export interface DashboardResource<T> {
  data: T | undefined;
  error: ApiError | Error | null;
  loading: boolean;
  refreshing: boolean;
  refresh: () => Promise<void>;
  update: (updater: (current: T | undefined) => T) => void;
}

function toError(error: unknown): ApiError | Error {
  return isApiError(error) || error instanceof Error
    ? error
    : new Error('טעינת הנתונים נכשלה.');
}

export function useDashboardResource<T>(load: () => Promise<T>): DashboardResource<T> {
  const [data, setData] = useState<T>();
  const [error, setError] = useState<ApiError | Error | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const dataRef = useRef<T | undefined>(undefined);
  const mountedRef = useRef(true);
  const requestIdRef = useRef(0);

  useEffect(() => () => { mountedRef.current = false; }, []);

  const refresh = useCallback(async () => {
    const requestId = requestIdRef.current + 1;
    requestIdRef.current = requestId;
    const hasData = dataRef.current !== undefined;
    setError(null);
    if (hasData) setRefreshing(true);
    else setLoading(true);
    try {
      const nextData = await load();
      if (!mountedRef.current || requestId !== requestIdRef.current) return;
      dataRef.current = nextData;
      setData(nextData);
    } catch (loadError) {
      if (!mountedRef.current || requestId !== requestIdRef.current) return;
      setError(toError(loadError));
    } finally {
      if (mountedRef.current && requestId === requestIdRef.current) {
        setLoading(false);
        setRefreshing(false);
      }
    }
  }, [load]);

  useEffect(() => {
    queueMicrotask(() => { void refresh(); });
  }, [refresh]);

  const update = useCallback((updater: (current: T | undefined) => T) => {
    const nextData = updater(dataRef.current);
    dataRef.current = nextData;
    setData(nextData);
  }, []);

  return { data, error, loading, refreshing, refresh, update };
}
