"""Authenticated realtime delivery for messages created through the REST API."""

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth.models import User

from .models import AlertAssignment, Message
from .permissions import is_dispatcher
from .serializers import MessageSerializer


@database_sync_to_async
def _visible_message_payload(user_id, message_id):
    """Apply the same visibility policy as ``MessageViewSet.get_queryset``."""
    try:
        user = User.objects.select_related('userprofile').get(pk=user_id)
        message = Message.objects.select_related('sender', 'alert', 'group').get(pk=message_id)
    except (User.DoesNotExist, Message.DoesNotExist):
        return None

    if not is_dispatcher(user):
        allowed = message.sender_id == user.id
        if message.group_id:
            allowed = allowed or message.group.members.filter(pk=user.id).exists()
        if message.alert_id:
            allowed = allowed or AlertAssignment.objects.filter(
                alert_id=message.alert_id,
                user_id=user.id,
            ).exists()
        if not allowed:
            return None
    return MessageSerializer(message).data


class MessageConsumer(AsyncJsonWebsocketConsumer):
    """One authenticated connection receives only messages it can already read."""

    async def connect(self):
        user = self.scope['user']
        if not user.is_authenticated:
            await self.close(code=4401)
            return
        self.user_id = user.id
        await self.channel_layer.group_add('messages', self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'user_id'):
            await self.channel_layer.group_discard('messages', self.channel_name)

    async def message_created(self, event):
        payload = await _visible_message_payload(self.user_id, event['message_id'])
        if payload is not None:
            await self.send_json({'type': 'message.created', 'message': payload})
