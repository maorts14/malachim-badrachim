import "./Geography.css";
import Map from "../Map/Map"
import { useCallback } from 'react';
import { rescueApi, type ApiAlert, type ApiUser } from '../../services/api';
import ResourceState from '../ResourceState/ResourceState';
import { useDashboardResource } from '../../hooks/useDashboardResource';


export default function Geography() {
    const loadMap = useCallback(async (): Promise<{ alerts: ApiAlert[]; users: ApiUser[] }> => {
        const [alerts, users] = await Promise.all([rescueApi.listAlerts(), rescueApi.listUsers()]);
        return { alerts, users };
    }, []);
    const mapResource = useDashboardResource(loadMap);
    const alerts = mapResource.data?.alerts ?? [];
    const users = mapResource.data?.users ?? [];

    const markers = [
        ...alerts.map((alert) => ({ id: `alert-${alert.id}`, latitude: alert.latitude, longitude: alert.longitude, label: alert.title, kind: 'alert' as const })),
        ...users.filter((user) => user.latitude !== null && user.longitude !== null).map((user) => ({ id: `user-${user.id}`, latitude: user.latitude!, longitude: user.longitude!, label: user.username, kind: 'volunteer' as const })),
    ];

    return (
        <div className="panelBoardApp">
            <section>
              <button type="button" onClick={() => void mapResource.refresh()} disabled={mapResource.loading || mapResource.refreshing}>רענן מפה</button>
              <ResourceState error={mapResource.error} loading={mapResource.loading} refreshing={mapResource.refreshing} empty={markers.length === 0} onRetry={() => void mapResource.refresh()} loadingLabel="טוען מפה…" emptyLabel="אין סמנים להצגה במפה." />
              <Map markers={markers}/>
            </section>

        </div>
    );
}
