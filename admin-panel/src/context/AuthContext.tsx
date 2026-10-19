/* eslint-disable react-refresh/only-export-components */
import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

export interface AuthUser { id: number; username: string; email: string; name: string; role: string | null; is_staff: boolean; }
const apiBase = (import.meta.env.VITE_API_BASE_URL ?? '/api').replace(/\/$/, '');

interface AuthContextType {
  user: AuthUser | null;
  loading: boolean;
  login: (identifier: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  loading: true,
  login: async () => {},
  logout: async () => {},
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    void fetch(`${apiBase}/auth/session/`, { credentials: 'include' })
      .then((response) => response.json())
      .then((data) => { if (!cancelled) setUser(data.authenticated ? data.user : null); })
      .catch(() => { if (!cancelled) setUser(null); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, []);

  const login = async (identifier: string, password: string) => {
    const csrfToken = document.cookie.split('; ').find((item) => item.startsWith('csrftoken='))?.split('=')[1] ?? '';
    const response = await fetch(`${apiBase}/auth/session/login/`, { method: 'POST', credentials: 'include', headers: { 'Content-Type': 'application/json', 'X-CSRFToken': decodeURIComponent(csrfToken) }, body: JSON.stringify({ username: identifier.trim(), password }) });
    const data = await response.json();
    if (!response.ok) throw new Error(data.detail ?? data.non_field_errors?.[0] ?? 'ההתחברות נכשלה.');
    setUser(data.user);
  };

  const logout = async () => {
    const csrfToken = document.cookie.split('; ').find((item) => item.startsWith('csrftoken='))?.split('=')[1] ?? '';
    await fetch(`${apiBase}/auth/session/logout/`, { method: 'POST', credentials: 'include', headers: { 'X-CSRFToken': decodeURIComponent(csrfToken) } });
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
