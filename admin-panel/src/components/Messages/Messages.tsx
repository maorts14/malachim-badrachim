import { useEffect, useState } from 'react';
import { MessageSquare, RefreshCw } from 'lucide-react';
import { type ApiAlert, rescueApi } from '../../services/api';
import GroupChat from './GroupChat/GroupChat';
import './Messages.css';

export default function Messages() {
  const [alerts, setAlerts] = useState<ApiAlert[]>([]);
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const loadAlerts = async () => {
    setLoading(true);
    try {
      const response = await rescueApi.listAlerts();
      setAlerts(response);
      setSelectedId((current) => current ?? response[0]?.id ?? null);
      setError('');
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'טעינת האירועים נכשלה.'); }
    finally { setLoading(false); }
  };
  // Initial fetch synchronizes the operational context list with the protected API.
  // eslint-disable-next-line react-hooks/set-state-in-effect
  useEffect(() => { void loadAlerts(); }, []);
  const selected = alerts.find((alert) => alert.id === selectedId) ?? null;
  return <div className="panelBoardApp operational-chat">
    <aside className="operational-chat__contexts" aria-label="אירועי שיח">
      <div className="operational-chat__contexts-header"><div><h2>שיח מבצעי</h2><span>בחר אירוע לשיחה עם הצוות שהוקצה</span></div><button type="button" onClick={() => void loadAlerts()} aria-label="רענון אירועים"><RefreshCw size={17} className={loading ? 'operational-chat__spin' : ''} /></button></div>
      {error && <p className="operational-chat__error">{error}</p>}
      {!loading && alerts.length === 0 && <p className="operational-chat__empty">אין אירועים פעילים.</p>}
      <div className="operational-chat__event-list">{alerts.map((alert) => <button type="button" key={alert.id} className={selectedId === alert.id ? 'active' : ''} onClick={() => setSelectedId(alert.id)}><MessageSquare size={18} /><span><strong>{alert.title}</strong><small>{alert.assignments.length} מוקצים · {alert.status}</small></span></button>)}</div>
    </aside>
    {selected ? <GroupChat alert={selected} /> : <div className="operational-chat__placeholder">בחרו אירוע כדי לפתוח שיח מבצעי.</div>}
  </div>;
}
