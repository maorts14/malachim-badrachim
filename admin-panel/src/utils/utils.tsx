

/* eslint-disable react-refresh/only-export-components */
export function Timestamp({ value }: { value: string }) {
  const parts = value.split(" ");
  if (parts.length === 2) {
    return (
      <span className="situation__timestamp">
        <strong>{parts[0]}</strong> {parts[1]}
      </span>
    );
  }
  return <span className="situation__timestamp">{value}</span>;
}

/* ── Status ── */
export function StatusCell({ status }: { status: string }) {
  if (status === "לא פעיל") {
    return <span className="situation__status--inactive">{status}</span>;
  }
  return <span className="situation__status">{status}</span>;
}

export function getInitials(name: string): string {
  return name.split(" ").map((n) => n[0]).join("").toUpperCase();
}
