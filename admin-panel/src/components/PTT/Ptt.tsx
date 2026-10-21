import { useCallback, useEffect, useRef, useState } from "react";
import { Room, RoomEvent, Track } from "livekit-client";
import { Mic, Radio, RefreshCw, Users } from "lucide-react";
import { useAuth } from "@/context/AuthContext";
import { rescueApi, type ApiGroup, type ApiUser } from "@/services/api";
import ResourceState from "../ResourceState/ResourceState";
import { useDashboardResource } from "../../hooks/useDashboardResource";
import "./Ptt.css";

const errorMessage = (error: unknown) => error instanceof Error ? error.message : "הפעולה נכשלה. נסו שוב.";
const emptyGroups: ApiGroup[] = [];
const emptyUsers: ApiUser[] = [];

export default function Ptt() {
  const { user } = useAuth();
  const room = useRef<Room | null>(null);
  const audioElements = useRef<HTMLAudioElement[]>([]);
  const loadWorkspace = useCallback(async (): Promise<{ groups: ApiGroup[]; users: ApiUser[] }> => {
    const [groups, users] = await Promise.all([rescueApi.listGroups(), rescueApi.listUsers()]);
    return { groups, users };
  }, []);
  const workspaceResource = useDashboardResource(loadWorkspace);
  const groups = workspaceResource.data?.groups ?? emptyGroups;
  const users = workspaceResource.data?.users ?? emptyUsers;
  const [selectedGroupId, setSelectedGroupId] = useState<number | null>(null);
  const [members, setMembers] = useState<number[]>([]);
  const [groupName, setGroupName] = useState("");
  const [newGroupName, setNewGroupName] = useState("");
  const [saving, setSaving] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [connected, setConnected] = useState(false);
  const [transmitting, setTransmitting] = useState(false);
  const [activeSpeakers, setActiveSpeakers] = useState<string[]>([]);
  const [actionError, setActionError] = useState<string | null>(null);
  const selectedGroup = groups.find((group) => group.id === selectedGroupId) ?? groups[0] ?? null;
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

  useEffect(() => {
    if (selectedGroupId === null && groups[0]) queueMicrotask(() => { void selectGroup(groups[0]); });
  }, [groups, selectGroup, selectedGroupId]);

  useEffect(() => {
    return () => { void disconnect(); };
  }, [disconnect]);

  const joinSelectedGroup = async () => {
    if (!selectedGroup || room.current || connecting) return;
    setConnecting(true);
    setActionError(null);
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
      setActionError(errorMessage(joinError));
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
      setActionError(errorMessage(transmitError));
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
    setActionError(null);
    try {
      await rescueApi.updateGroup(selectedGroup.id, { name: groupName.trim(), members });
      await workspaceResource.refresh();
    } catch (saveError) {
      setActionError(errorMessage(saveError));
    } finally {
      setSaving(false);
    }
  };

  const createGroup = async () => {
    if (!newGroupName.trim()) return;
    setSaving(true);
    setActionError(null);
    try {
      const created = await rescueApi.createGroup({ name: newGroupName.trim(), members: [] });
      setNewGroupName("");
      await workspaceResource.refresh();
      await selectGroup(created);
    } catch (createError) {
      setActionError(errorMessage(createError));
    } finally {
      setSaving(false);
    }
  };

  const toggleMember = (userId: number) => setMembers((current) =>
    current.includes(userId) ? current.filter((id) => id !== userId) : [...current, userId]);

  return <main className="ptt" dir="rtl">
    <header className="ptt__header">
      <div><h1>קשר קולי קבוצתי</h1><p>שידור חי בלבד. אודיו אינו נשמר או נשלח כהודעה.</p></div>
      <button type="button" className="ptt__icon-button" onClick={() => void workspaceResource.refresh()} disabled={workspaceResource.loading || workspaceResource.refreshing} aria-label="רענון"><RefreshCw size={18} /></button>
    </header>
    <ResourceState error={workspaceResource.error} loading={workspaceResource.loading} refreshing={workspaceResource.refreshing} empty={groups.length === 0} onRetry={() => void workspaceResource.refresh()} loadingLabel="טוען קבוצות קשר…" emptyLabel="אין קבוצות קשר זמינות." />
    {actionError && <p className="ptt__error" role="alert">{actionError}</p>}
    {!workspaceResource.loading && groups.length === 0 ? <section className="ptt__empty">{canManageGroups && <><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></>}</section> : groups.length > 0 ? <div className="ptt__layout">
      <aside className="ptt__groups"><h2>קבוצות</h2>{groups.map((group) => <button type="button" key={group.id} className={group.id === selectedGroupId ? "ptt__group ptt__group--active" : "ptt__group"} onClick={() => void selectGroup(group)}>{group.name}<small>{group.members.length} חברים</small></button>)}</aside>
      <section className="ptt__conversation">
        <h2>{selectedGroup?.name}</h2>
        <p className="ptt__state"><Users size={16} /> {connected ? `מחובר/ת · ${activeSpeakers.length ? `מדברים: ${activeSpeakers.join(", ")}` : "ממתין/ה לשידור"}` : "לא מחובר/ת לחדר"}</p>
        {!connected && <button type="button" className="ptt__join" onClick={() => void joinSelectedGroup()} disabled={connecting}>{connecting ? "מתחבר/ת…" : "התחבר/י לקשר"}</button>}
        <button type="button" className={transmitting ? "ptt__transmit ptt__transmit--recording" : "ptt__transmit"} onPointerDown={() => void startTransmission()} onPointerUp={stopTransmission} onPointerLeave={stopTransmission} onPointerCancel={stopTransmission} disabled={connecting} aria-pressed={transmitting}><Mic size={28} />{transmitting ? "משדר/ת — שחררו לסיום" : connected ? "לחצו והחזיקו כדי לדבר" : "התחברו כדי לדבר"}</button>
        {connected && <button type="button" className="ptt__leave" onClick={() => void disconnect()}><Radio size={16} /> נתק/י קשר</button>}
      </section>
      {canManageGroups && <aside className="ptt__manage"><h2>ניהול קבוצה</h2><input value={groupName} onChange={(event) => setGroupName(event.target.value)} aria-label="שם הקבוצה" />{users.map((member) => <label key={member.user_id}><input type="checkbox" checked={members.includes(member.user_id)} onChange={() => toggleMember(member.user_id)} />{member.display_name || member.username}</label>)}<button type="button" onClick={() => void saveGroup()} disabled={saving || !groupName.trim()}>שמור חברים ושם</button><hr /><input value={newGroupName} onChange={(event) => setNewGroupName(event.target.value)} placeholder="שם קבוצה חדשה" /><button type="button" onClick={() => void createGroup()} disabled={saving || !newGroupName.trim()}>צור קבוצה</button></aside>}
    </div> : null}
  </main>;
}
