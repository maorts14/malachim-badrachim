import { useCallback, useMemo, useState } from 'react';
import './EventTable.css';
import { type ApiAlert, type ApiUser, rescueApi } from '../../services/api';
import ResourceState from '../ResourceState/ResourceState';
import { useDashboardResource } from '../../hooks/useDashboardResource';

const statusLabel: Record<ApiAlert['status'], string> = {
  OPEN: 'פתוח', DISPATCHED: 'שובץ', ACCEPTED: 'התקבל',
  IN_PROGRESS: 'בטיפול', RESOLVED: 'טופל', CANCELLED: 'בוטל',
};
const priorityLabel: Record<ApiAlert['priority'], string> = {
  LOW: 'נמוך', MEDIUM: 'בינוני', HIGH: 'גבוה', CRITICAL: 'דחוף',
};
const emptyAlerts: ApiAlert[] = [];

export default function EventTable() {
  const loadAlerts = useCallback(() => rescueApi.listAlerts(), []);
  const alertsResource = useDashboardResource(loadAlerts);
  const alerts = alertsResource.data ?? emptyAlerts;
  const [title, setTitle] = useState('');
  const [status, setStatus] = useState<'ALL' | ApiAlert['status']>('ALL');
  const [priority, setPriority] = useState<'ALL' | ApiAlert['priority']>('ALL');
  const [actionError, setActionError] = useState<string | null>(null);
  const [dispatchTarget, setDispatchTarget] = useState<ApiAlert | null>(null);
  const [responders, setResponders] = useState<ApiUser[]>([]);
  const [responderSearch, setResponderSearch] = useState('');
  const [selectedResponderIds, setSelectedResponderIds] = useState<number[]>([]);
  const [loadingResponders, setLoadingResponders] = useState(false);
  const [submittingDispatch, setSubmittingDispatch] = useState(false);

  const filteredAlerts = useMemo(() => alerts.filter((alert) => (
    (!title || alert.title.toLowerCase().includes(title.toLowerCase()))
    && (status === 'ALL' || alert.status === status)
    && (priority === 'ALL' || alert.priority === priority)
  )), [alerts, priority, status, title]);

  const resolveAlert = async (alert: ApiAlert) => {
    if (!window.confirm(`לסגור את האירוע "${alert.title}"?`)) return;
    try { await rescueApi.updateAlert(alert.id, { status: 'RESOLVED' }); await alertsResource.refresh(); }
    catch (updateError) { setActionError(updateError instanceof Error ? updateError.message : 'סגירת האירוע נכשלה.'); }
  };

  const openDispatcher = async (alert: ApiAlert) => {
    setDispatchTarget(alert);
    setResponderSearch('');
    setSelectedResponderIds(alert.assignments.map((assignment) => assignment.user_id));
    setLoadingResponders(true);
    try {
      const users = await rescueApi.listUsers();
      setResponders(users.filter((user) => user.role === 'user'));
    } catch (loadError) {
      setDispatchTarget(null);
      setActionError(loadError instanceof Error ? loadError.message : 'טעינת המתנדבים נכשלה.');
    } finally {
      setLoadingResponders(false);
    }
  };

  const toggleResponder = (userId: number) => {
    setSelectedResponderIds((current) => current.includes(userId)
      ? current.filter((id) => id !== userId)
      : [...current, userId]);
  };

  const dispatchAlert = async () => {
    if (!dispatchTarget || !selectedResponderIds.length) return;
    setSubmittingDispatch(true);
    try {
      await rescueApi.dispatchAlert(dispatchTarget.id, selectedResponderIds);
      setDispatchTarget(null);
      await alertsResource.refresh();
    } catch (dispatchError) {
      setActionError(dispatchError instanceof Error ? dispatchError.message : 'שיבוץ המתנדבים נכשל.');
    } finally {
      setSubmittingDispatch(false);
    }
  };

  const filteredResponders = responders.filter((user) => {
    const search = responderSearch.trim().toLowerCase();
    return !search || user.username.toLowerCase().includes(search) || user.email.toLowerCase().includes(search);
  });

  return (
    <div className="table-wrapper" dir="rtl">
      <ResourceState error={alertsResource.error} loading={alertsResource.loading} refreshing={alertsResource.refreshing} empty={alerts.length === 0} onRetry={() => void alertsResource.refresh()} loadingLabel="טוען אירועים…" emptyLabel="אין אירועים להצגה." />
      {actionError && <p role="alert">{actionError}</p>}
      <table className="event-table">
        <thead>
            <tr><th>אירוע</th><th>מיקום</th><th>סטטוס</th><th>עדיפות</th><th>נפתח</th><th>מתנדבים</th><th>פעולות</th></tr>
          <tr className="filters">
            <th><input aria-label="חיפוש אירוע" value={title} placeholder="חפש..." onChange={(event) => setTitle(event.target.value)} /></th>
            <th />
            <th><select value={status} onChange={(event) => setStatus(event.target.value as typeof status)}><option value="ALL">הכל</option>{Object.entries(statusLabel).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></th>
            <th><select value={priority} onChange={(event) => setPriority(event.target.value as typeof priority)}><option value="ALL">הכל</option>{Object.entries(priorityLabel).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></th>
            <th /><th /><th><button type="button" className="clear-btn" onClick={() => void alertsResource.refresh()} disabled={alertsResource.loading || alertsResource.refreshing}>רענן</button></th>
          </tr>
        </thead>
        <tbody>
          {filteredAlerts.map((alert) => (
            <tr key={alert.id}>
              <td>{alert.title}</td>
              <td>{alert.latitude.toFixed(5)}, {alert.longitude.toFixed(5)}</td>
              <td><span className="badge status">{statusLabel[alert.status]}</span></td>
              <td><span className="badge priority">{priorityLabel[alert.priority]}</span></td>
              <td>{new Date(alert.created_at).toLocaleString('he-IL')}</td>
              <td>{alert.assignments.length ? alert.assignments.map((assignment) => assignment.username).join(', ') : 'טרם שובץ'}</td>
              <td className="actions">
                <button type="button" className="action-btn view" disabled={alert.status === 'RESOLVED' || alert.status === 'CANCELLED'} onClick={() => void openDispatcher(alert)}>שבץ</button>
                <button type="button" className="action-btn close" disabled={alert.status === 'RESOLVED' || alert.status === 'CANCELLED'} onClick={() => void resolveAlert(alert)}>סגור</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
      {dispatchTarget && (
        <div className="dispatch-modal-backdrop" role="presentation" onMouseDown={() => !submittingDispatch && setDispatchTarget(null)}>
          <section className="dispatch-modal" role="dialog" aria-modal="true" aria-labelledby="dispatch-title" onMouseDown={(event) => event.stopPropagation()}>
            <div className="dispatch-modal__header">
              <div><h2 id="dispatch-title">שיבוץ מתנדבים</h2><p>{dispatchTarget.title}</p></div>
              <button type="button" aria-label="סגירה" onClick={() => setDispatchTarget(null)} disabled={submittingDispatch}>×</button>
            </div>
            <label className="dispatch-modal__search">חיפוש מתנדב
              <input autoFocus value={responderSearch} onChange={(event) => setResponderSearch(event.target.value)} placeholder="שם או דוא״ל" />
            </label>
            <div className="dispatch-modal__summary">נבחרו {selectedResponderIds.length} מתנדבים</div>
            <div className="dispatch-modal__responders" aria-busy={loadingResponders}>
              {loadingResponders && <p>טוען מתנדבים…</p>}
              {!loadingResponders && filteredResponders.length === 0 && <p>לא נמצאו מתנדבים זמינים.</p>}
              {!loadingResponders && filteredResponders.map((user) => (
                <label className="responder-option" key={user.user_id}>
                  <input type="checkbox" checked={selectedResponderIds.includes(user.user_id)} onChange={() => toggleResponder(user.user_id)} />
                  <span><strong>{user.username}</strong><small>{user.email || 'ללא כתובת דוא״ל'}</small></span>
                </label>
              ))}
            </div>
            <div className="dispatch-modal__actions">
              <button type="button" className="clear-btn" onClick={() => setDispatchTarget(null)} disabled={submittingDispatch}>ביטול</button>
              <button type="button" className="action-btn view" onClick={() => void dispatchAlert()} disabled={submittingDispatch || selectedResponderIds.length === 0}>{submittingDispatch ? 'משבץ…' : 'שיבוץ נבחרים'}</button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
