"""JWT authentication for responder WebSocket connections.

Browser dispatcher connections continue to use Django's session cookie through
``AuthMiddlewareStack``. Native clients pass their Django access token as the
``token`` query parameter because the WebSocket API does not allow arbitrary
Authorization headers on every platform.
"""

from urllib.parse import parse_qs

from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser, User
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import AccessToken


@database_sync_to_async
def _user_for_access_token(raw_token):
    try:
        token = AccessToken(raw_token)
        return User.objects.get(pk=token['user_id'], is_active=True)
    except (TokenError, User.DoesNotExist, KeyError):
        return AnonymousUser()


class JwtQueryStringAuthMiddleware:
    """Use a Django JWT only when the connection has no session user."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        user = scope.get('user')
        if user is not None and user.is_authenticated:
            return await self.app(scope, receive, send)

        query = parse_qs(scope['query_string'].decode())
        raw_token = query.get('token', [''])[0]
        scope['user'] = await _user_for_access_token(raw_token) if raw_token else AnonymousUser()
        return await self.app(scope, receive, send)
