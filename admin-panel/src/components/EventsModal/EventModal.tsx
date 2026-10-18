import { useState, type FormEvent } from 'react';
import './EventModal.css';
import MapComponent from '../Map/Map';
import { rescueApi } from '../../services/api';

type Props = { open: boolean; onClose: () => void };

export default function EventsModal({ open, onClose }: Props) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [latitude, setLatitude] = useState(32.0853);
  const [longitude, setLongitude] = useState(34.7818);
  const [priority, setPriority] = useState<'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'>('MEDIUM');
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  if (!open) return null;

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    try {
      setSaving(true); setError(null);
      await rescueApi.createAlert({ title, description, latitude, longitude, priority });
      onClose();
      window.location.assign('/events-table');
    } catch (submitError) {
      setError(submitError instanceof Error ? submitError.message : 'יצירת האירוע נכשלה.');
    } finally { setSaving(false); }
  };

  return <div className="modal-overlay" dir="rtl">
    <form className="modal" onSubmit={submit}>
      <div className="modal-header"><button type="button" className="close-btn" onClick={onClose}>✕</button></div>
      <div className="modal-body">
        <div className="map-container"><MapComponent height="68vh" initialCenter={[latitude, longitude]} onSelect={(lat, lng) => { setLatitude(lat); setLongitude(lng); }} /></div>
        <div className="form-container">
          <h2 className="title">יצירת אירוע</h2>
          {error && <p role="alert">{error}</p>}
          <label htmlFor="event-title">כותרת האירוע</label>
          <input id="event-title" required value={title} onChange={(event) => setTitle(event.target.value)} placeholder="למשל: תאונת דרכים" />
          <label htmlFor="event-priority">עדיפות</label>
          <select id="event-priority" value={priority} onChange={(event) => setPriority(event.target.value as typeof priority)}><option value="LOW">נמוכה</option><option value="MEDIUM">בינונית</option><option value="HIGH">גבוהה</option><option value="CRITICAL">דחופה</option></select>
          <label>מיקום</label>
          <div className="coords-row"><input type="number" step="any" value={latitude} onChange={(event) => setLatitude(Number(event.target.value))} aria-label="קו רוחב" /><input type="number" step="any" value={longitude} onChange={(event) => setLongitude(Number(event.target.value))} aria-label="קו אורך" /></div>
          <label htmlFor="event-description">פרטי אירוע</label>
          <textarea id="event-description" value={description} onChange={(event) => setDescription(event.target.value)} placeholder="הזן מידע" />
        </div>
      </div>
      <div className="modal-footer"><button type="button" className="btn-cancel" onClick={onClose}>בטל</button><button className="btn primary" disabled={saving}>{saving ? 'שולח…' : 'צור ושלח'}</button></div>
    </form>
  </div>;
}
