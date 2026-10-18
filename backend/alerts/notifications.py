import logging

from firebase_admin import messaging

from .models import DeviceRegistration

logger = logging.getLogger(__name__)


def send_alert_assignment_notification(*, alert, user_ids):
    """Best-effort FCM delivery; assignment persistence never depends on FCM."""
    tokens = list(
        DeviceRegistration.objects.filter(firebase_uid__in=user_ids)
        .values_list('fcm_token', flat=True)
    )
    if not tokens:
        return 0

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(
            title=alert.title,
            body=alert.description or 'אירוע חדש ממתין לתגובה',
        ),
        data={
            'type': 'alert_assignment',
            'alert_id': str(alert.id),
            'deepLink': 'rescue://events/${}'.format(alert.id),
        },
    )
    try:
        response = messaging.send_each_for_multicast(message)
    except Exception:
        logger.exception('Unable to deliver alert assignment notification', extra={'alert_id': alert.id})
        return 0
    return response.success_count
