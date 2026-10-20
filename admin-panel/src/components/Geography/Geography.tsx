import "./Geography.css";
import Map from "../Map/Map"
import { useEffect, useState } from 'react';
import { rescueApi, type ApiAlert, type ApiUser } from '../../services/api';


export default function Geography() {
    const [alerts, setAlerts] = useState<ApiAlert[]>([]);
    const [users, setUsers] = useState<ApiUser[]>([]);
    const [error, setError] = useState<string | null>(null);

    useEffect(() => {
        let active = true;
        void Promise.all([rescueApi.listAlerts(), rescueApi.listUsers()])
            .then(([nextAlerts, nextUsers]) => {
                if (active) { setAlerts(nextAlerts); setUsers(nextUsers); }
            })
            .catch((loadError: unknown) => {
                if (active) setError(loadError instanceof Error ? loadError.message : 'טעינת המפה נכשלה.');
            });
        return () => { active = false; };
    }, []);

    const markers = [
        ...alerts.map((alert) => ({ id: `alert-${alert.id}`, latitude: alert.latitude, longitude: alert.longitude, label: alert.title, kind: 'alert' as const })),
        ...users.filter((user) => user.latitude !== null && user.longitude !== null).map((user) => ({ id: `user-${user.id}`, latitude: user.latitude!, longitude: user.longitude!, label: user.username, kind: 'volunteer' as const })),
    ];

    return (
        <div className="panelBoardApp">
            <section>
              {error && <p role="alert">{error}</p>}
              <Map markers={markers}/>
            </section>

        </div>
    );
}
