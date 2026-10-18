import { useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { Send, Users } from 'lucide-react';
import { type ApiAlert, type ApiMessage, openMessageSocket, rescueApi } from '../../../services/api';
import './GroupChat.css';

interface GroupChatProps { alert: ApiAlert; }

function displayTime(timestamp: string): string {
  return new Intl.DateTimeFormat('he-IL', { hour: '2-digit', minute: '2-digit' }).format(new Date(timestamp));
}

export default function GroupChat({ alert }: GroupChatProps) {
  const [messages, setMessages] = useState<ApiMessage[]>([]);
  const [input, setInput] = useState('');
  const [error, setError] = useState('');
  const [sending, setSending] = useState(false);
  const bottomRef = useRef<HTMLDivElement>(null);
  const appendMessage = (message: ApiMessage) => {
    setMessages((current) => current.some((item) => item.id === message.id) ? current : [...current, message]);
  };
  useEffect(() => {
    let active = true;
    let socket: WebSocket | undefined;
    const load = async () => {
      try {
        const items = await rescueApi.listMessages(alert.id);
        if (active) { setMessages([...items].reverse()); setError(''); }
      } catch (reason) { if (active) setError(reason instanceof Error ? reason.message : 'טעינת השיחה נכשלה.'); }
    };
    void load();
    // Keep the operational thread current without requiring a manual refresh.
    // The API remains the authorization source for every poll; when a WebSocket
    // transport is introduced this interval can be replaced without changing
    // the message contract.
    const timer = window.setInterval(() => { void load(); }, 5000);
    void openMessageSocket((event) => {
      if (active && event.message.alert === alert.id) appendMessage(event.message);
    }).then((connection) => {
      if (active) socket = connection;
      else connection.close();
    }).catch(() => {
      // Polling above remains a deliberately safe compatibility fallback.
    });
    return () => { active = false; window.clearInterval(timer); socket?.close(); };
  }, [alert.id]);
  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);
  const sendMessage = async () => {
    const text = input.trim();
    if (!text || sending) return;
    setSending(true);
    try {
      const message = await rescueApi.createAlertMessage(alert.id, text);
      appendMessage(message);
      setInput(''); setError('');
    } catch (reason) { setError(reason instanceof Error ? reason.message : 'שליחת ההודעה נכשלה.'); }
    finally { setSending(false); }
  };
  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === 'Enter') { event.preventDefault(); void sendMessage(); }
  };
  return <section className="gc-root" aria-label={`שיח אירוע ${alert.title}`}>
    <header className="gc-header"><div className="gc-header__left"><div className="gc-header__group-avatar"><Users size={22} /></div><div><div className="gc-header__name">{alert.title}</div><div className="gc-header__sub">{alert.assignments.length ? `צוות מוקצה: ${alert.assignments.map((item) => item.username).join(', ')}` : 'טרם הוקצה צוות'}</div></div></div></header>
    <main className="gc-body"><div className="gc-date-divider"><span className="gc-date-pill">עדכוני אירוע</span></div>{error && <p className="gc-error">{error}</p>}{messages.length === 0 && !error && <p className="gc-empty">עדיין אין הודעות לאירוע זה.</p>}{messages.map((message) => <div className="gc-msg-row gc-msg-row--right" key={message.id}><div className="gc-bubble gc-bubble--right"><div className="gc-sender-name">{message.sender.username}</div><div className="gc-msg-text">{message.text || message.title}</div><div className="gc-time-line"><span className="gc-time-text">{displayTime(message.timestamp)}</span></div></div></div>)}<div ref={bottomRef} /></main>
    <footer className="gc-input-bar"><input className="gc-input" placeholder="כתבו עדכון לצוות…" value={input} onChange={(event) => setInput(event.target.value)} onKeyDown={handleKeyDown} aria-label="תוכן ההודעה" /><button className="gc-send-btn" onClick={() => void sendMessage()} disabled={!input.trim() || sending} aria-label="שליחת הודעה"><Send size={18} color="white" /></button></footer>
  </section>;
}
