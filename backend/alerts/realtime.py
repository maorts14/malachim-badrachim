"""Small synchronous bridge from DRF writes to the Channels layer."""

import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


logger = logging.getLogger(__name__)


def publish_message_created(message_id):
    """Fan out a committed message ID without making the REST write fail."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    try:
        async_to_sync(channel_layer.group_send)(
            'messages',
            {'type': 'message.created', 'message_id': message_id},
        )
    except Exception:
        logger.exception('Failed to publish realtime message notification')
