import { useCallback, useState } from 'react';
import { MessageSquare, RefreshCw } from 'lucide-react';
import { rescueApi } from '../../services/api';
import GroupChat from './GroupChat/GroupChat';
import './Messages.css';
import ResourceState from '../ResourceState/ResourceState';
import { useDashboardResource } from '../../hooks/useDashboardResource';

export default function Messages() {
  const loadAlerts = useCallback(() => rescueApi.listAlerts(), []);
  const alertsResource = useDashboardResource(loadAlerts);
  const alerts = alertsResource.data ?? [];
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const selected = alerts.find((alert) => alert.id === selectedId) ?? alerts[0] ?? null;
  return <div className="panelBoardApp operational-chat">
    <aside className="operational-chat__contexts" aria-label="אירועי שיח">
      <div className="operational-chat__contexts-header"><div><h2>שיח מבצעי</h2><span>בחר אירוע לשיחה עם הצוות שהוקצה</span></div><button type="button" onClick={() => void alertsResource.refresh()} disabled={alertsResource.loading || alertsResource.refreshing} aria-label="רענון אירועים"><RefreshCw size={17} className={alertsResource.loading || alertsResource.refreshing ? 'operational-chat__spin' : ''} /></button></div>
      <ResourceState error={alertsResource.error} loading={alertsResource.loading} refreshing={alertsResource.refreshing} empty={alerts.length === 0} onRetry={() => void alertsResource.refresh()} loadingLabel="טוען אירועים…" emptyLabel="אין אירועים פעילים." />
      <div className="operational-chat__event-list">{alerts.map((alert) => <button type="button" key={alert.id} className={selectedId === alert.id ? 'active' : ''} onClick={() => setSelectedId(alert.id)}><MessageSquare size={18} /><span><strong>{alert.title}</strong><small>{alert.assignments.length} מוקצים · {alert.status}</small></span></button>)}</div>
    </aside>
    {selected ? <GroupChat alert={selected} /> : <div className="operational-chat__placeholder">בחרו אירוע כדי לפתוח שיח מבצעי.</div>}
  </div>;
}
