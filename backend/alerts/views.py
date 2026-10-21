from datetime import timedelta

from django.contrib.auth import login as django_login, logout as django_logout
from django.contrib.auth.models import User
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.contrib.gis.geos import Point
from django.contrib.gis.measure import D
from django.db.models import Prefetch, Q
from django.db import transaction
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django.conf import settings
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import ensure_csrf_cookie
from drf_spectacular.utils import extend_schema, OpenApiResponse
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken
from livekit import api as livekit_api

from .models import (
    Alert,
    AlertAssignment,
    DeviceRegistration,
    UserProfile,
    Group,
    Message,
    Notification,
)
from .notifications import send_alert_assignment_notification
from .permissions import IsDispatcher, IsManager, is_dispatcher
from .realtime import publish_message_created
from .serializers import (
    AlertSerializer, DeviceRegistrationSerializer,
    UserProfileSerializer, GroupSerializer, MessageSerializer, NotificationSerializer,
    RegisterSerializer, SessionLoginSerializer, UserInfoSerializer,
)

class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        refresh = RefreshToken.for_user(user)
        return Response({'access': str(refresh.access_token), 'refresh': str(refresh), 'user': UserInfoSerializer(user).data}, status=status.HTTP_201_CREATED)


class WhoAmIView(APIView):
    @extend_schema(
        tags=['TEST'],
        summary='Verify your token works (start here)',
        responses={
            200: OpenApiResponse(description='Token accepted — returns your identity'),
            401: OpenApiResponse(description='Missing, expired, or invalid token'),
        },
        description=(
            '**Use this before testing anything else.**\n\n'
            'Send a JWT as `Authorization: Bearer <access>` or sign in through the web session. '
            'If you get a 200 back, you are authenticated and ready to test all other endpoints.'
        ),
    )
    def get(self, request):
        return Response({
            'authenticated': True,
            'user': UserInfoSerializer(request.user).data,
        })


@method_decorator(ensure_csrf_cookie, name='dispatch')
class SessionView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        return Response({'authenticated': request.user.is_authenticated, 'user': UserInfoSerializer(request.user).data if request.user.is_authenticated else None})


@method_decorator(ensure_csrf_cookie, name='dispatch')
class SessionLoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = SessionLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.validated_data['user']
        django_login(request, user)
        return Response({'authenticated': True, 'user': UserInfoSerializer(user).data})


class SessionLogoutView(APIView):
    def post(self, request):
        django_logout(request)
        return Response(status=status.HTTP_204_NO_CONTENT)


class JWTLogoutView(APIView):
    def post(self, request):
        refresh_token = request.data.get('refresh')
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except TokenError:
                pass
        return Response(status=status.HTTP_205_RESET_CONTENT)


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '')
        user = User.objects.filter(email__iexact=email).first()
        if user is not None and settings.PASSWORD_RESET_URL:
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            reset_url = settings.PASSWORD_RESET_URL.format(uid=uid, token=token)
            send_mail(
                'Reset your Rescue Alert System password',
                f'Use this link to reset your password: {reset_url}',
                settings.DEFAULT_FROM_EMAIL,
                [user.email],
                fail_silently=False,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]

    def post(self, request, uid, token):
        try:
            user = User.objects.get(pk=force_str(urlsafe_base64_decode(uid)))
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            return Response({'detail': 'Invalid password reset link.'}, status=status.HTTP_400_BAD_REQUEST)
        if not default_token_generator.check_token(user, token):
            return Response({'detail': 'Invalid password reset link.'}, status=status.HTTP_400_BAD_REQUEST)
        password = request.data.get('password', '')
        if len(password) < 8:
            return Response({'password': ['Ensure this field has at least 8 characters.']}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(password)
        user.save(update_fields=['password'])
        return Response(status=status.HTTP_204_NO_CONTENT)


class RegisterDeviceView(APIView):
    permission_classes = [IsAuthenticated]
    @extend_schema(
        request=DeviceRegistrationSerializer,
        responses={
            204: OpenApiResponse(description='Device registered'),
            401: OpenApiResponse(description='Missing or invalid token'),
        },
    )
    def post(self, request):
        serializer = DeviceRegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        DeviceRegistration.objects.update_or_create(
            user_uid=str(request.user.pk),
            device_id=data['device_id'],
            defaults={
                'push_token': data['push_token'],
                'platform': data['platform'],
                'device_model': data.get('device_model', ''),
            },
        )
        return Response(status=204)


class UserProfileViewSet(viewsets.ModelViewSet):
    queryset = UserProfile.objects.all()
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in {'create', 'destroy'}:
            return [IsManager()]
        if self.action in {'update', 'partial_update'}:
            return [IsManager()]
        return [IsAuthenticated()]

    @action(detail=False, methods=['post'])
    def location(self, request):
        profile = request.user.userprofile
        latitude = request.data.get('latitude')
        longitude = request.data.get('longitude')
        if latitude and longitude:
            profile.latitude = float(latitude)
            profile.longitude = float(longitude)
            profile.save()
            return Response(self.get_serializer(profile).data)
        return Response({"error": "latitude and longitude required"}, status=400)

    @action(detail=False, methods=['get'])
    def all(self, request):
        profiles = UserProfile.objects.filter(latitude__isnull=False, longitude__isnull=False)
        return Response(self.get_serializer(profiles, many=True).data)

    @action(detail=False, methods=['get'])
    def profile(self, request):
        return Response(self.get_serializer(request.user.userprofile).data)

    @action(detail=False, methods=['put'])
    def update_profile(self, request):
        mutable_fields = {
            key: value
            for key, value in request.data.items()
            if key in {'display_name', 'phone', 'latitude', 'longitude'}
        }
        serializer = self.get_serializer(
            request.user.userprofile,
            data=mutable_fields,
            partial=True,
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)


class GroupViewSet(viewsets.ModelViewSet):
    queryset = Group.objects.all()
    serializer_class = GroupSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in {'create', 'update', 'partial_update', 'destroy', 'add_user', 'remove_user'}:
            return [IsManager()]
        return [IsAuthenticated()]

    def get_queryset(self):
        if is_dispatcher(self.request.user):
            return Group.objects.all()
        return Group.objects.filter(members=self.request.user)

    @extend_schema(
        request=None,
        responses={
            200: OpenApiResponse(
                description='A short-lived LiveKit token scoped to this group room and the authenticated participant.',
            ),
            404: OpenApiResponse(description='The group is unavailable to the authenticated user.'),
            503: OpenApiResponse(description='Realtime PTT is not configured on this deployment.'),
        },
        description=(
            'Joins the live PTT room for this group. The returned token is restricted to microphone publishing '
            'and subscribing in this one room. It does not grant access to recordings or other group rooms.'
        ),
    )
    @action(detail=True, methods=['post'], url_path='ptt-token', url_name='ptt-token')
    def ptt_token(self, request, pk=None):
        group = self.get_object()
        if not is_dispatcher(request.user) and not group.members.filter(id=request.user.id).exists():
            raise PermissionDenied('You are not a member of this group.')
        if not all((settings.LIVEKIT_URL, settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)):
            return Response(
                {'detail': 'Realtime PTT is not configured.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        room_name = f'group-{group.id}'
        token = (
            livekit_api.AccessToken(settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)
            .with_identity(f'user-{request.user.id}')
            .with_name(request.user.get_full_name() or request.user.username)
            .with_ttl(timedelta(minutes=15))
            .with_grants(livekit_api.VideoGrants(
                room_join=True,
                room=room_name,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=False,
                can_publish_sources=['microphone'],
            ))
            .to_jwt()
        )
        return Response({'url': settings.LIVEKIT_URL, 'room': room_name, 'token': token})

    @action(detail=True, methods=['post'])
    def add_user(self, request, pk=None):
        group = self.get_object()
        try:
            group.members.add(User.objects.get(id=request.data.get('user_id')))
            return Response({"message": "User added to group"})
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=404)

    @action(detail=True, methods=['delete'])
    def remove_user(self, request, pk=None):
        group = self.get_object()
        try:
            group.members.remove(User.objects.get(id=request.data.get('user_id')))
            return Response({"message": "User removed from group"})
        except User.DoesNotExist:
            return Response({"error": "User not found"}, status=404)


class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = Message.objects.select_related('sender', 'alert', 'group')
        if is_dispatcher(self.request.user):
            visible = queryset
        else:
            visible = queryset.filter(
                Q(sender=self.request.user)
                | Q(group__members=self.request.user)
                | Q(alert__assignments__user=self.request.user),
            ).distinct()
        alert_id = self.request.query_params.get('alert')
        group_id = self.request.query_params.get('group')
        if alert_id:
            visible = visible.filter(alert_id=alert_id)
        if group_id:
            visible = visible.filter(group_id=group_id)
        return visible

    def perform_create(self, serializer):
        alert = serializer.validated_data.get('alert')
        group = serializer.validated_data.get('group')
        if not is_dispatcher(self.request.user):
            if alert and not AlertAssignment.objects.filter(
                alert=alert,
                user=self.request.user,
                status__in=[
                    AlertAssignment.Status.PENDING,
                    AlertAssignment.Status.ACCEPTED,
                    AlertAssignment.Status.ARRIVED,
                ],
            ).exists():
                raise PermissionDenied('You are not assigned to this alert.')
            if group and not group.members.filter(id=self.request.user.id).exists():
                raise PermissionDenied('You are not a member of this group.')
        message = serializer.save(sender=self.request.user)
        transaction.on_commit(lambda: publish_message_created(message.id))

    @action(detail=False, methods=['get'])
    def list_messages(self, request):
        messages = self.filter_queryset(self.get_queryset()).order_by('-timestamp')
        return Response(self.get_serializer(messages, many=True).data)


class NotificationViewSet(viewsets.ModelViewSet):
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class AlertViewSet(viewsets.ModelViewSet):
    serializer_class = AlertSerializer
    permission_classes = [IsAuthenticated]

    def _queryset_with_assignments(self):
        return Alert.objects.prefetch_related(
            Prefetch(
                'assignments',
                queryset=AlertAssignment.objects.select_related('user'),
                to_attr='_prefetched_assignments',
            ),
        )

    def get_queryset(self):
        queryset = self._queryset_with_assignments()
        # These actions are already guarded by IsDispatcher. Resolving their
        # target from the full set avoids applying volunteer assignment filters
        # while DRF is still authenticating the request.
        if getattr(self, 'action', None) in {
            'update', 'partial_update', 'destroy', 'dispatch_alert',
        }:
            return queryset
        if is_dispatcher(self.request.user):
            return queryset
        return queryset.filter(
            assignments__user=self.request.user,
        ).exclude(
            assignments__user=self.request.user,
            assignments__status=AlertAssignment.Status.DECLINED,
        ).distinct()

    def get_permissions(self):
        if self.action in {
            'create', 'update', 'partial_update', 'destroy', 'dispatch_alert',
        }:
            return [IsDispatcher()]
        return [IsAuthenticated()]

    @staticmethod
    def _sync_alert_status(alert):
        assignment_statuses = set(alert.assignments.values_list('status', flat=True))
        if AlertAssignment.Status.ARRIVED in assignment_statuses:
            next_status = Alert.Status.IN_PROGRESS
        elif AlertAssignment.Status.ACCEPTED in assignment_statuses:
            next_status = Alert.Status.ACCEPTED
        elif assignment_statuses and assignment_statuses == {AlertAssignment.Status.DECLINED}:
            next_status = Alert.Status.OPEN
        elif assignment_statuses:
            next_status = Alert.Status.DISPATCHED
        else:
            next_status = Alert.Status.OPEN

        if alert.status != next_status:
            alert.status = next_status
            alert.save(update_fields=['status', 'updated_at'])

    @extend_schema(
        request={
            'application/json': {
                'type': 'object',
                'required': ['user_ids'],
                'properties': {
                    'user_ids': {'type': 'array', 'items': {'type': 'integer'}, 'minItems': 1},
                },
            },
        },
        responses=AlertSerializer,
        description='Dispatch an alert to one or more volunteers. Re-dispatching resets a declined assignment to pending.',
    )
    @action(detail=True, methods=['post'], url_path='dispatch', url_name='dispatch')
    def dispatch_alert(self, request, pk=None):
        alert = self.get_object()
        if alert.status in {Alert.Status.RESOLVED, Alert.Status.CANCELLED}:
            raise ValidationError({'status': 'Resolved or cancelled alerts cannot be dispatched.'})

        user_ids = request.data.get('user_ids')
        if not isinstance(user_ids, list) or not user_ids:
            raise ValidationError({'user_ids': 'Provide a non-empty list of volunteer user IDs.'})
        try:
            normalized_ids = {int(user_id) for user_id in user_ids}
        except (TypeError, ValueError):
            raise ValidationError({'user_ids': 'Every user ID must be an integer.'})

        volunteers = list(
            User.objects.filter(
                id__in=normalized_ids,
                userprofile__role=UserProfile.Role.USER,
            ),
        )
        found_ids = {volunteer.id for volunteer in volunteers}
        if found_ids != normalized_ids:
            raise ValidationError({'user_ids': 'Every assignee must be an existing volunteer.'})

        for volunteer in volunteers:
            assignment, created = AlertAssignment.objects.get_or_create(
                alert=alert,
                user=volunteer,
                defaults={'dispatched_by': request.user},
            )
            if not created and assignment.status == AlertAssignment.Status.DECLINED:
                assignment.status = AlertAssignment.Status.PENDING
                assignment.dispatched_by = request.user
                assignment.responded_at = None
                assignment.save(update_fields=['status', 'dispatched_by', 'responded_at', 'updated_at'])

        self._sync_alert_status(alert)
        send_alert_assignment_notification(
            alert=alert,
            user_ids=[volunteer.username for volunteer in volunteers],
        )
        alert.refresh_from_db()
        return Response(self.get_serializer(alert).data, status=status.HTTP_200_OK)

    @extend_schema(
        request={
            'application/json': {
                'type': 'object',
                'required': ['response'],
                'properties': {
                    'response': {'type': 'string', 'enum': ['accept', 'decline', 'arrive']},
                },
            },
        },
        responses=AlertSerializer,
        description='Volunteer response for their own assignment. `arrive` requires a previous acceptance.',
    )
    @action(detail=True, methods=['post'])
    def respond(self, request, pk=None):
        alert = Alert.objects.get(pk=pk)
        response_value = request.data.get('response')
        assignment = AlertAssignment.objects.filter(alert=alert, user=request.user).first()
        if assignment is None:
            raise PermissionDenied('You are not assigned to this alert.')

        target_status = {
            'accept': AlertAssignment.Status.ACCEPTED,
            'decline': AlertAssignment.Status.DECLINED,
            'arrive': AlertAssignment.Status.ARRIVED,
        }.get(response_value)
        if target_status is None:
            raise ValidationError({'response': 'Use accept, decline, or arrive.'})
        if target_status == AlertAssignment.Status.ARRIVED and assignment.status != AlertAssignment.Status.ACCEPTED:
            raise ValidationError({'response': 'Accept the assignment before marking arrival.'})

        assignment.status = target_status
        assignment.responded_at = timezone.now()
        assignment.save(update_fields=['status', 'responded_at', 'updated_at'])
        self._sync_alert_status(alert)
        alert.refresh_from_db()
        return Response(self.get_serializer(alert).data)

    @action(detail=False, methods=['get'])
    def nearby(self, request):
        lat = request.query_params.get('lat')
        lon = request.query_params.get('lon')
        radius = request.query_params.get('radius')

        if not all([lat, lon, radius]):
            return Response(
                {"error": "lat, lon, and radius query parameters are required"},
                status=400
            )

        try:
            lat = float(lat)
            lon = float(lon)
            radius = int(radius)
        except ValueError:
            return Response(
                {"error": "lat and lon must be floats, radius must be an integer"},
                status=400
            )

        user_location = Point(lon, lat, srid=4326)
        alerts = self._queryset_with_assignments().filter(
            status__in=[Alert.Status.OPEN, Alert.Status.DISPATCHED, Alert.Status.ACCEPTED, Alert.Status.IN_PROGRESS],
            location__distance_lte=(user_location, D(m=radius)),
        )
        if not is_dispatcher(request.user):
            alerts = alerts.filter(
                Q(status=Alert.Status.OPEN)
                | Q(assignments__user=request.user),
            ).distinct()

        return Response(self.get_serializer(alerts, many=True).data)
