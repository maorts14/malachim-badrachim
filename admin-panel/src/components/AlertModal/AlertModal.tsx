import { type FC, useEffect, useState } from "react";
import { X, AlertCircle, AlertTriangle, Info, CheckCircle } from "lucide-react";
import "./AlertModal.css";
import { rescueApi, type ApiAlert } from "../../services/api";

type Props = {
    open: boolean;
    onClose: () => void;
};

const AlertModal: FC<Props> = ({ open, onClose }) => {
    const [alerts, setAlerts] = useState<ApiAlert[]>([]);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const [selectedAlert, setSelectedAlert] = useState<ApiAlert | null>(null);

    useEffect(() => {
        if (!open) return;

        const loadAlerts = async () => {
            setLoading(true);
            setError(null);
            try {
                setAlerts(await rescueApi.listAlerts());
            } catch (fetchError) {
                setError(fetchError instanceof Error ? fetchError.message : 'טעינת ההתראות נכשלה.');
            } finally {
                setLoading(false);
            }
        };

        loadAlerts();
    }, [open]);

    const getIconForPriority = (priority: ApiAlert['priority']) => {
        switch (priority) {
            case "CRITICAL":
                return <AlertCircle size={20} className="alert-icon error" />;
            case "HIGH":
                return <AlertTriangle size={20} className="alert-icon warning" />;
            case "LOW":
                return <CheckCircle size={20} className="alert-icon success" />;
            default:
                return <Info size={20} className="alert-icon info" />;
        }
    };

    if (!open) return null;

    return (
        <div className="modal-overlay">
            <div className="alert-modal">
                {/* HEADER */}
                <div className="modal-header">
                    <h2 className="modal-title">התראות</h2>
                    <button
                        type="button"
                        className="close-btn"
                        onClick={onClose}
                        aria-label="סגור"
                    >
                        <X size={24} />
                    </button>
                </div>

                {/* BODY */}
                <div className="alert-modal-body">
                    {loading && <div className="loading">טוען...</div>}

                    {error && <div className="error-message">שגיאה: {error}</div>}

                    {!loading && !error && alerts.length === 0 && (
                        <div className="no-alerts">אין התראות</div>
                    )}

                    {!loading && !error && alerts.length > 0 && !selectedAlert && (
                        <div className="alerts-list">
                            {alerts.map((alert) => (
                                <div
                                    key={alert.id}
                                    className={`alert-item ${alert.priority.toLowerCase()}`}
                                    onClick={() => setSelectedAlert(alert)}
                                >
                                    <div className="alert-item-icon">
                                        {getIconForPriority(alert.priority)}
                                    </div>
                                    <div className="alert-item-content">
                                        <h3>{alert.title}</h3>
                                        <p>{alert.description}</p>
                                        <span className="alert-time">
                                            {new Date(alert.created_at).toLocaleString(
                                                "he-IL"
                                            )}
                                        </span>
                                    </div>
                                    <span className={`severity-badge ${alert.priority.toLowerCase()}`}>{alert.priority}</span>
                                </div>
                            ))}
                        </div>
                    )}

                    {selectedAlert && (
                        <div className="alert-detail">
                            <button
                                type="button"
                                className="back-btn"
                                onClick={() => setSelectedAlert(null)}
                            >
                                ← חזור
                            </button>
                            <div className="detail-header">
                                <div className="detail-icon">
                                    {getIconForPriority(selectedAlert.priority)}
                                </div>
                                <div className="detail-title-section">
                                    <h2>{selectedAlert.title}</h2>
                                    <span className={`severity-badge ${selectedAlert.priority.toLowerCase()}`}>{selectedAlert.priority}</span>
                                </div>
                            </div>

                            <div className="detail-content">
                                <div className="detail-field">
                                    <label>תיאור:</label>
                                    <p>{selectedAlert.description}</p>
                                </div>

                                <div className="detail-field">
                                    <label>זמן:</label>
                                    <p>
                                        {new Date(selectedAlert.created_at).toLocaleString(
                                            "he-IL"
                                        )}
                                    </p>
                                </div>

                                <div className="detail-field">
                                    <label>עדיפות:</label>
                                    <p>{selectedAlert.priority}</p>
                                </div>

                                <div className="detail-field"><label>סטטוס:</label><p>{selectedAlert.status}</p></div>
                            </div>
                        </div>
                    )}
                </div>

                {/* FOOTER */}
                <div className="modal-footer">
                    <button className="btn btn-secondary" onClick={onClose}>
                        סגור
                    </button>
                </div>
            </div>
        </div>
    );
};

export default AlertModal;
