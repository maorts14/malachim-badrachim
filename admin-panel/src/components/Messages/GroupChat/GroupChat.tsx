import { useCallback, useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { RefreshCw, Send, Users } from 'lucide-react';
import { type ApiAlert, type ApiMessage, openMessageSocket, rescueApi } from '../../../services/api';
import './GroupChat.css';
import ResourceState from '../../ResourceState/ResourceState';
import { useDashboardResource } from '../../../hooks/useDashboardResource';

interface GroupChatProps { alert: ApiAlert; }
const emptyMessages: ApiMessage[] = [];

function displayTime(timestamp: string): string {
  return new Intl.DateTimeFormat('he-IL', { hour: '2-digit', minute: '2-digit' }).format(new Date(timestamp));
}

export default function GroupChat({ alert }: GroupChatProps) {
  const loadMessages = useCallback(async () => (await rescueApi.listMessages(alert.id)).reverse(), [alert.id]);
  const { data, error, loading, refreshing, refresh, update } = useDashboardResource(loadMessages);
  const messages = data ?? emptyMessages;
  const [input, setInput] = useState('');
  const [sendError, setSendError] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const appendMessage = useCallback((message: ApiMessage) => {
    update((current) => current?.some((item) => item.id === message.id) ? current : [...(current ?? []), message]);
  }, [update]);
  useEffect(() => {
    let active = true;
    let socket: WebSocket | undefined;
    // Keep the operational thread current without requiring a manual refresh.
    // The API remains the authorization source for every poll; when a WebSocket
    // transport is introduced this interval can be replaced without changing
    // the message contract.
    const timer = window.setInterval(() => { if (active) void refresh(); }, 5000);
    void openMessageSocket((event) => {
      if (active && event.message.alert === alert.id) appendMessage(event.message);
    }).then((connection) => {
      if (active) socket = connection;
      else connection.close();
    }).catch(() => {
      // Polling above remains a deliberately safe compatibility fallback.
    });
    return () => { active = false; window.clearInterval(timer); socket?.close(); };
  }, [alert.id, appendMessage, refresh]);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);
  const sendMessage = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setSending(true);
    setSendError('');
    try {
      const message = await rescueApi.createAlertMessage(alert.id, text);
      appendMessage(message);
      setInput('');
    } catch (reason) {
      setSendError(reason instanceof Error ? reason.message : 'שליחת ההודעה נכשלה.');
    }
    finally { setSending(false); }
  };
  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') { event.preventDefault(); void sendMessage(); }
  };
  return <section className="gc-root" aria-label={`שיח אירוע ${alert.title}`}>
    <header className="gc-header"><div className="gc-header__left"><div className="gc-header__group-avatar"><Users size={22} /></div><div><div className="gc-header__name">{alert.title}</div><div className="gc-header__sub">{alert.assignments.length ? `צוות מוקצה: ${alert.assignments.map((item) => item.username).join(', ')}` : 'טרם הוקצה צוות'}</div></div></div><button type="button" onClick={() => void refresh()} disabled={loading || refreshing} aria-label="רענון הודעות"><RefreshCw size={17} /></button></header>
    <main className="gc-body"><div className="gc-date-divider"><span className="gc-date-pill">עדכוני אירוע</span></div><ResourceState error={error} loading={loading} refreshing={refreshing} empty={messages.length === 0} onRetry={() => void refresh()} loadingLabel="טוען הודעות…" emptyLabel="עדיין אין הודעות לאירוע זה." />{sendError && <p className="gc-error" role="alert">{sendError}</p>}{messages.map((message) => <div className="gc-msg-row gc-msg-row--right" key={message.id}><div className="gc-bubble gc-bubble--right"><div className="gc-sender-name">{message.sender.username}</div><div className="gc-msg-text">{message.text || message.title}</div><div className="gc-time-line"><span className="gc-time-text">{displayTime(message.timestamp)}</span></div></div></div>)}<div ref={bottomRef} /></main>
    <footer className="gc-input-bar"><input className="gc-input" placeholder="כתבו עדכון לצוות…" value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={handleKeyDown} aria-label="תוכן ההודעה" /><button className="gc-send-btn" onClick={() => void sendMessage()} disabled={!input.trim() || sending} aria-label="שליחת הודעה"><Send size={18} color="white" /></button></footer>
  </section>;
}
