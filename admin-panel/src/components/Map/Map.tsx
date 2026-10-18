import { useState, type FC } from "react";
import { MapContainer, TileLayer, Marker, useMapEvents } from "react-leaflet";
import { divIcon } from "leaflet";
import "leaflet/dist/leaflet.css";

type MapProps = {
  onSelect?: (lat: number, lng: number) => void;
  initialCenter?: [number, number]; // [lat, lng]
  zoom?: number;
  height?: string | number;
  markers?: MapMarker[];
};

export type MapMarker = {
  id: string;
  latitude: number;
  longitude: number;
  label: string;
  kind: 'alert' | 'volunteer';
};

const DEFAULT_CENTER: [number, number] = [32.0853, 34.7818]; // Tel Aviv [lat, lng]

const ClickableMarker: FC<{
  position: [number, number];
  onClick?: (lat: number, lng: number) => void;
  setPosition: (pos: [number, number]) => void;
}> = ({ position, onClick, setPosition }) => {
  const emojiIcon = divIcon({
    className: "", // no extra CSS class
    html: `<span style="font-size:32px; line-height:1; background:transparent;">🚩</span>`,
    iconSize: [32, 32],
    iconAnchor: [16, 32], // bottom center aligns with coordinates
  });

  useMapEvents({
    click(e) {
      const coords: [number, number] = [e.latlng.lat, e.latlng.lng];
      setPosition(coords);
      onClick?.(coords[0], coords[1]);
    },
  });

  return <Marker position={position} icon={emojiIcon} />;
};

const MapComponent: FC<MapProps> = ({
  onSelect,
  initialCenter = DEFAULT_CENTER,
  zoom = 13,
  height = "650px",
  markers = [],
}) => {
  const [position, setPosition] = useState<[number, number]>(initialCenter);

  return (
    <div style={{ width: "100%", height }}>
      <MapContainer
        center={position}
        zoom={zoom}
        style={{ width: "100%", height: "100%" }}
      >
        <TileLayer url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png" />
        <ClickableMarker
          position={position}
          setPosition={setPosition}
          onClick={onSelect}
        />
        {markers.map((marker) => (
          <Marker
            key={marker.id}
            position={[marker.latitude, marker.longitude]}
            icon={divIcon({
              className: '',
              html: `<span title="${marker.label}" style="font-size:24px">${marker.kind === 'alert' ? '🚨' : '👤'}</span>`,
              iconSize: [24, 24],
              iconAnchor: [12, 24],
            })}
          />
        ))}
      </MapContainer>
    </div>
  );
};

export default MapComponent;
