"""Authenticated realtime delivery for messages created through the REST API."""

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.contrib.auth.models import User
import firebase_admin.auth

from .models import AlertAssignment, Message, UserProfile
from .permissions import is_dispatcher
from .serializers import MessageSerializer


_SOCKET_PROTOCOL = 'rescue-v1'


@database_sync_to_async
def _authenticate_subprotocols(subprotocols):
    """Return a Django user for an offered Firebase bearer-token subprotocol.

    The token is offered as the second protocol token after ``rescue-v1``. This
    prevents it appearing in request URLs, reverse-proxy logs, or browser
    history. Firebase JWT characters are valid WebSocket protocol-token chars.
    """
    if len(subprotocols) != 2 or subprotocols[0] != _SOCKET_PROTOCOL:
        return None
    try:
        decoded = firebase_admin.auth.verify_id_token(subprotocols[1])
    except Exception:
        return None

    uid = decoded.get('uid')
    if not uid:
        return None
    email = decoded.get('email', f'{uid}@firebase.local')
    name = decoded.get('name', '')
    user, created = User.objects.get_or_create(
        username=uid,
        defaults={
            'email': email,
            'first_name': name.split(' ')[0] if name else '',
            'last_name': ' '.join(name.split(' ')[1:]) if name else '',
        },
    )
    if not created and user.email != email:
        user.email = email
        user.save(update_fields=['email'])
    UserProfile.objects.get_or_create(user=user)
    return user


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
        user = await _authenticate_subprotocols(self.scope.get('subprotocols', []))
        if user is None:
            await self.close(code=4401)
            return
        self.user_id = user.id
        await self.channel_layer.group_add('messages', self.channel_name)
        await self.accept(subprotocol=_SOCKET_PROTOCOL)

    async def disconnect(self, close_code):
        if hasattr(self, 'user_id'):
            await self.channel_layer.group_discard('messages', self.channel_name)

    async def message_created(self, event):
        payload = await _visible_message_payload(self.user_id, event['message_id'])
        if payload is not None:
            await self.send_json({'type': 'message.created', 'message': payload})
