import { useCallback, useEffect, useRef, useState } from "react";
import { Mic, RefreshCw, Send } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { rescueApi, type ApiGroup, type ApiMessage, type ApiUser } from "@/services/api";
import "./Ptt.css";

const errorMessage = (error: unknown) => error instanceof Error ? error.message : "הפעולה נכשלה. נסו שוב.";

export default function Ptt() {
  const { user } = useAuth();
  const [groups, setGroups] = useState<ApiGroup[]>([]);
  const [users, setUsers] = useState<ApiUser[]>([]);
  const [messages, setMessages] = useState<ApiMessage[]>([]);
  const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null);
  const [members, setMembers] = useState<number[]>([]);
  const [groupName, setGroupName] = useState("");
  const [newGroupName, setNewGroupName] = useState("");
  const [text, setText] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [recording, setRecording] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const recorder = useRef<MediaRecorder | null>(null);
  const chunks = useRef<BlobPart[]>([]);
  const selectedGroup = groups.find((group) => group.id === selectedGroupId) ?? null;
  const canManageGroups = user?.role === "manager";

  const loadMessages = useCallback(async (groupId: number) => {
    try {
      setMessages(await rescueApi.listGroupMessages(groupId));
    } catch (loadError) {
      setError(errorMessage(loadError));
    }
  }, []);

  const selectGroup = useCallback((group: ApiGroup) => {
    setSelectedGroupId(group.id);
    setGroupName(group.name);
    setMembers(group.members);
    setMessages([]);
    void loadMessages(group.id);
  }, [loadMessages]);

  const loadWorkspace = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [nextGroups, nextUsers] = await Promise.all([rescueApi.listGroups(), rescueApi.listUsers()]);
      setGroups(nextGroups);
      setUsers(nextUsers);
      const nextSelected = nextGroups.find((group) => group.id === selectedGroupId) ?? nextGroups[0];
      if (nextSelected) selectGroup(nextSelected);
      else { setSelectedGroupId(null); setMessages([]); }
    } catch (loadError) {
      setError(errorMessage(loadError));
    } finally {
      setLoading(false);
    }
  }, [selectGroup, selectedGroupId]);

  useEffect(() => {
    let active = true;
    void Promise.all([rescueApi.listGroups(), rescueApi.listUsers()])
      .then(([nextGroups, nextUsers]) => {
        if (!active) return;
        setGroups(nextGroups);
        setUsers(nextUsers);
        const nextSelected = nextGroups[0];
        if (nextSelected) selectGroup(nextSelected);
        setLoading(false);
      })
      .catch((loadError: unknown) => { if (active) { setError(errorMessage(loadError)); setLoading(false); } });
    return () => { active = false; };
  }, [selectGroup]);

  const refresh = async () => {
    await loadWorkspace();
    if (selectedGroupId !== null) await loadMessages(selectedGroupId);
  };

  const saveGroup = async () => {
    if (!selectedGroup || !groupName.trim()) return;
    setSaving(true); setError(null);
    try {
      await rescueApi.updateGroup(selectedGroup.id, { name: groupName.trim(), members });
      await loadWorkspace();
    } catch (saveError) { setError(errorMessage(saveError)); }
    finally { setSaving(false); }
  };

  const createGroup = async () => {
    if (!newGroupName.trim()) return;
    setSaving(true); setError(null);
    try {
      const created = await rescueApi.createGroup({ name: newGroupName.trim(), members: [] });
      setNewGroupName("");
      await loadWorkspace();
      selectGroup(created);
    } catch (createError) { setError(errorMessage(createError)); }
    finally { setSaving(false); }
  };

  const sendText = async () => {
    if (!selectedGroup || !text.trim()) return;
    setSaving(true); setError(null);
    try {
      await rescueApi.createGroupMessage(selectedGroup.id, text.trim());
      setText("");
      await loadMessages(selectedGroup.id);
    } catch (sendError) { setError(errorMessage(sendError)); }
    finally { setSaving(false); }
  };

  const sendVoice = async (groupId: number, voice: Blob) => {
    setSaving(true); setError(null);
    try {
      await rescueApi.createGroupVoiceMessage(groupId, voice);
      await loadMessages(groupId);
    } catch (sendError) { setError(errorMessage(sendError)); }
    finally { setSaving(false); }
  };

  const startRecording = async () => {
    if (!selectedGroup || recording || saving) return;
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const nextRecorder = new MediaRecorder(stream);
      const groupId = selectedGroup.id;
      chunks.current = [];
      nextRecorder.ondataavailable = (event) => { if (event.data.size > 0) chunks.current.push(event.data); };
      nextRecorder.onstop = () => {
        stream.getTracks().forEach((track) => track.stop());
        setRecording(false);
        void sendVoice(groupId, new Blob(chunks.current, { type: nextRecorder.mimeType || "audio/webm" }));
      };
      recorder.current = nextRecorder;
      nextRecorder.start();
      setRecording(true);
    } catch (recordingError) { setError(errorMessage(recordingError)); }
  };

  const stopRecording = () => {
    if (recorder.current?.state === "recording") recorder.current.stop();
    recorder.current = null;
  };

  const toggleMember = (userId: number) => setMembers((current) =>
    current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);

  return <main className="ptt" dir="rtl">
    <header className="ptt__header">
      <div><h1>קשר קולי קבוצתי</h1><p>הודעות קוליות נשמרות ונשלחות לחברי הקבוצה.</p></div>
      <button type="button" className="ptt__icon-button" onClick={() => void refresh()} disabled={loading} aria-label="רענון"><RefreshCw size={18} /></button>
    </header>
    {error && <p className="ptt__error" role="alert">{error}</p>}
    {loading ? <p className="ptt__state">טוען קבוצות קשר…</p> : groups.length === 0 ? <section className="ptt__empty"><p className="ptt__state">אין קבוצות קשר זמינות.</p>{canManageGroups && <><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></>}</section> : <div className="ptt__layout">
      <aside className="ptt__groups"><h2>קבוצות</h2>{groups.map((group) => <button type="button" key={group.id} className={group.id === selectedGroupId ? "ptt__group ptt__group--active" : "ptt__group"} onClick={() => selectGroup(group)}>{group.name}<small>{group.members.length} חברים</small></button>)}</aside>
      <section className="ptt__conversation">
        <h2>{selectedGroup?.name}</h2>
        <div className="ptt__messages">{messages.length === 0 ? <p className="ptt__state">אין הודעות בקבוצה זו.</p> : messages.map((message) => <article className="ptt__message" key={message.id}><strong>{message.sender.username}</strong><time>{new Date(message.timestamp).toLocaleString()}</time>{message.text && <p>{message.text}</p>}{message.voice_url && <audio controls src={message.voice_url}>הדפדפן אינו תומך בהשמעת שמע.</audio>}</article>)}</div>
        <div className="ptt__composer"><input value={text} onChange={(event) => setText(event.target.value)} onKeyDown={(event) => { if (event.key === "Enter") void sendText(); }} placeholder="כתבו עדכון לקבוצה" /><button type="button" onClick={() => void sendText()} disabled={saving || !text.trim()}><Send size={16} /> שלח</button></div>
        <button type="button" className={recording ? "ptt__transmit ptt__transmit--recording" : "ptt__transmit"} onPointerDown={() => void startRecording()} onPointerUp={stopRecording} onPointerCancel={stopRecording} disabled={saving} aria-pressed={recording}><Mic size={28} />{recording ? "הקלטה פעילה — שחררו לשליחה" : "לחצו והחזיקו להודעה קולית"}</button>
      </section>
      {canManageGroups && <aside className="ptt__manage"><h2>ניהול קבוצה</h2><input value={groupName} onChange={(event) => setGroupName(event.target.value)} aria-label="שם הקבוצה" />{users.map((member) => <label key={member.user_id}><input type="checkbox" checked={members.includes(member.user_id)} onChange={() => toggleMember(member.user_id)} />{member.display_name || member.username}</label>)}<button type="button" onClick={() => void saveGroup()} disabled={saving || !groupName.trim()}>שמור חברים ושם</button><hr /><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></aside>}
    </div>}
  </main>;
}
