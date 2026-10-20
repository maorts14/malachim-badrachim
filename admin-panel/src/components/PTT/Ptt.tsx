import { useCallback, useEffect, useRef, useState } from "react";
import { Room, RoomEvent, Track } from "livekit-client";
import { Mic, Radio, RefreshCw, Users } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { rescueApi, type ApiGroup, type ApiUser } from "@/services/api";
import "./Ptt.css";

const errorMessage = (error: unknown) => error instanceof Error ? error.message : "הפעולה נכשלה. נסו שוב.";

export default function Ptt() {
  const { user } = useAuth();
  const room = useRef<Room | null>(null);
  const audioElements = useRef<HTMLAudioElement[]>([]);
  const [groups, setGroups] = useState<ApiGroup[]>([]);
  const [users, setUsers] = useState<ApiUser[]>([]);
  const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null);
  const [members, setMembers] = useState<number[]>([]);
  const [groupName, setGroupName] = useState("");
  const [newGroupName, setNewGroupName] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [connected, setConnected] = useState(false);
  const [transmitting, setTransmitting] = useState(false);
  const [activeSpeakers, setActiveSpeakers] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const selectedGroup = groups.find((group) => group.id === selectedGroupId) ?? null;
  const canManageGroups = user?.role === "manager";

  const disconnect = useCallback(async () => {
    const currentRoom = room.current;
    room.current = null;
    audioElements.current.forEach((element) => element.remove());
    audioElements.current = [];
    if (currentRoom) await currentRoom.disconnect();
    setConnected(false);
    setTransmitting(false);
    setActiveSpeakers([]);
  }, []);

  const selectGroup = useCallback(async (group: ApiGroup) => {
    await disconnect();
    setSelectedGroupId(group.id);
    setGroupName(group.name);
    setMembers(group.members);
  }, [disconnect]);

  const loadWorkspace = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const [nextGroups, nextUsers] = await Promise.all([rescueApi.listGroups(), rescueApi.listUsers()]);
      setGroups(nextGroups);
      setUsers(nextUsers);
      const nextSelected = nextGroups.find((group) => group.id === selectedGroupId) ?? nextGroups[0];
      if (nextSelected) await selectGroup(nextSelected);
      else setSelectedGroupId(null);
    } catch (loadError) {
      setError(errorMessage(loadError));
    } finally {
      setLoading(false);
    }
  }, [selectGroup, selectedGroupId]);

  useEffect(() => {
    void loadWorkspace();
    return () => { void disconnect(); };
  }, [disconnect, loadWorkspace]);

  const joinSelectedGroup = async () => {
    if (!selectedGroup || room.current || connecting) return;
    setConnecting(true);
    setError(null);
    try {
      const credentials = await rescueApi.getPttRoomCredentials(selectedGroup.id);
      const nextRoom = new Room();
      nextRoom.on(RoomEvent.TrackSubscribed, (track) => {
        if (track.kind !== Track.Kind.Audio) return;
        const element = track.attach() as HTMLAudioElement;
        element.autoplay = true;
        document.body.append(element);
        audioElements.current.push(element);
      });
      nextRoom.on(RoomEvent.TrackUnsubscribed, (track) => {
        if (track.kind !== Track.Kind.Audio) return;
        track.detach().forEach((element) => element.remove());
        audioElements.current = audioElements.current.filter((element) => element.isConnected);
      });
      nextRoom.on(RoomEvent.ActiveSpeakersChanged, (speakers) => {
        setActiveSpeakers(speakers.map((speaker) => speaker.name || speaker.identity));
      });
      nextRoom.on(RoomEvent.Disconnected, () => {
        room.current = null;
        setConnected(false);
        setTransmitting(false);
        setActiveSpeakers([]);
      });
      await nextRoom.connect(credentials.url, credentials.token);
      await nextRoom.localParticipant.setMicrophoneEnabled(false);
      room.current = nextRoom;
      setConnected(true);
    } catch (joinError) {
      setError(errorMessage(joinError));
    } finally {
      setConnecting(false);
    }
  };

  const startTransmission = async () => {
    if (!room.current) {
      await joinSelectedGroup();
      return;
    }
    try {
      await room.current.startAudio();
      await room.current.localParticipant.setMicrophoneEnabled(true);
      setTransmitting(true);
    } catch (transmitError) {
      setError(errorMessage(transmitError));
    }
  };

  const stopTransmission = () => {
    if (!room.current || !transmitting) return;
    void room.current.localParticipant.setMicrophoneEnabled(false);
    setTransmitting(false);
  };

  const saveGroup = async () => {
    if (!selectedGroup || !groupName.trim()) return;
    setSaving(true);
    setError(null);
    try {
      await rescueApi.updateGroup(selectedGroup.id, { name: groupName.trim(), members });
      await loadWorkspace();
    } catch (saveError) {
      setError(errorMessage(saveError));
    } finally {
      setSaving(false);
    }
  };

  const createGroup = async () => {
    if (!newGroupName.trim()) return;
    setSaving(true);
    setError(null);
    try {
      const created = await rescueApi.createGroup({ name: newGroupName.trim(), members: [] });
      setNewGroupName("");
      await loadWorkspace();
      await selectGroup(created);
    } catch (createError) {
      setError(errorMessage(createError));
    } finally {
      setSaving(false);
    }
  };

  const toggleMember = (userId: number) => setMembers((current) =>
    current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);

  return <main className="ptt" dir="rtl">
    <header className="ptt__header">
      <div><h1>קשר קולי קבוצתי</h1><p>שידור חי בלבד. אודיו אינו נשמר או נשלח כהודעה.</p></div>
      <button type="button" className="ptt__icon-button" onClick={() => void loadWorkspace()} disabled={loading} aria-label="רענון"><RefreshCw size={18} /></button>
    </header>
    {error && <p className="ptt__error" role="alert">{error}</p>}
    {loading ? <p className="ptt__state">טוען קבוצות קשר…</p> : groups.length === 0 ? <section className="ptt__empty"><p className="ptt__state">אין קבוצות קשר זמינות.</p>{canManageGroups && <><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></>}</section> : <div className="ptt__layout">
      <aside className="ptt__groups"><h2>קבוצות</h2>{groups.map((group) => <button type="button" key={group.id} className={group.id === selectedGroupId ? "ptt__group ptt__group--active" : "ptt__group"} onClick={() => void selectGroup(group)}>{group.name}<small>{group.members.length} חברים</small></button>)}</aside>
      <section className="ptt__conversation">
        <h2>{selectedGroup?.name}</h2>
        <p className="ptt__state"><Users size={16} /> {connected ? `מחובר/ת · ${activeSpeakers.length ? `מדברים: ${activeSpeakers.join(", ")}` : "ממתין/ה לשידור"}` : "לא מחובר/ת לחדר"}</p>
        {!connected && <button type="button" className="ptt__join" onClick={() => void joinSelectedGroup()} disabled={connecting}>{connecting ? "מתחבר/ת…" : "התחבר/י לקשר"}</button>}
        <button type="button" className={transmitting ? "ptt__transmit ptt__transmit--recording" : "ptt__transmit"} onPointerDown={() => void startTransmission()} onPointerUp={stopTransmission} onPointerLeave={stopTransmission} onPointerCancel={stopTransmission} disabled={connecting} aria-pressed={transmitting}><Mic size={28} />{transmitting ? "משדר/ת — שחררו לסיום" : connected ? "לחצו והחזיקו כדי לדבר" : "התחברו כדי לדבר"}</button>
        {connected && <button type="button" className="ptt__leave" onClick={() => void disconnect()}><Radio size={16} /> נתק/י קשר</button>}
      </section>
      {canManageGroups && <aside className="ptt__manage"><h2>ניהול קבוצה</h2><input value={groupName} onChange={(event) => setGroupName(event.target.value)} aria-label="שם הקבוצה" />{users.map((member) => <label key={member.user_id}><input type="checkbox" checked={members.includes(member.user_id)} onChange={() => toggleMember(member.user_id)} />{member.display_name || member.username}</label>)}<button type="button" onClick={() => void saveGroup()} disabled={saving || !groupName.trim()}>שמור חברים ושם</button><hr /><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></aside>}
    </div>}
  </main>;
}
