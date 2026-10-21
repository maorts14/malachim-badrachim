import re

import jwt

from django.contrib.auth.models import User
from django.contrib.gis.geos import Point
from django.contrib.sessions.backends.db import SessionStore
from django.core import mail
from django.test import TransactionTestCase
from django.test import override_settings
from rest_framework import status
from rest_framework.test import APITestCase, APIClient
from rest_framework_simplejwt.tokens import RefreshToken
from asgiref.sync import async_to_sync, sync_to_async
from channels.testing import WebsocketCommunicator

from .models import Alert, AlertAssignment, Group, Message, UserProfile
from .realtime import publish_message_created


class AuthApiTests(APITestCase):
    def register(self, email='new@example.com', password='strongpass123'):
        return self.client.post(
            '/api/auth/register/',
            {'email': email, 'password': password, 'full_name': 'New Responder'},
            format='json',
        )

    def test_register_jwt_and_whoami(self):
        registered = self.register()
        self.assertEqual(registered.status_code, status.HTTP_201_CREATED)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {registered.data['access']}")
        whoami = self.client.get('/api/auth/whoami/')
        self.assertEqual(whoami.status_code, status.HTTP_200_OK)
        self.assertEqual(whoami.data['user']['email'], 'new@example.com')

    def test_session_login_establishes_dispatcher_session(self):
        User.objects.create_user(
            username='dispatcher', email='dispatcher@example.com', password='strongpass123', is_staff=True,
        )
        dispatcher = User.objects.get(username='dispatcher')
        dispatcher.userprofile.role = UserProfile.Role.EMERGENCY_DISPATCHER
        dispatcher.userprofile.save(update_fields=['role'])
        anonymous = self.client.get('/api/auth/session/')
        self.assertFalse(anonymous.data['authenticated'])
        logged_in = self.client.post(
            '/api/auth/session/login/',
            {'username': 'dispatcher@example.com', 'password': 'strongpass123'}, format='json',
        )
        self.assertEqual(logged_in.status_code, status.HTTP_200_OK)
        self.assertTrue(logged_in.data['authenticated'])
        self.assertEqual(self.client.get('/api/auth/session/').data['user']['username'], 'dispatcher')
        self.assertEqual(self.client.post('/api/auth/session/logout/').status_code, status.HTTP_204_NO_CONTENT)

    def test_session_login_rejects_non_dispatcher(self):
        User.objects.create_user(username='volunteer', password='strongpass123')
        response = self.client.post('/api/auth/session/login/', {'username': 'volunteer', 'password': 'strongpass123'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_session_login_rejects_staff_without_dispatcher_role(self):
        User.objects.create_user(username='staff-volunteer', password='strongpass123', is_staff=True)
        response = self.client.post('/api/auth/session/login/', {'username': 'staff-volunteer', 'password': 'strongpass123'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    @override_settings(
        PASSWORD_RESET_URL='https://rescue.example/reset/{uid}/{token}',
        EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    )
    def test_password_reset_request_does_not_expose_account_existence(self):
        User.objects.create_user(username='reset@example.com', email='reset@example.com', password='strongpass123')
        existing = self.client.post('/api/auth/password-reset/', {'email': 'reset@example.com'}, format='json')
        unknown = self.client.post('/api/auth/password-reset/', {'email': 'unknown@example.com'}, format='json')
        self.assertEqual(existing.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(unknown.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn('https://rescue.example/reset/', mail.outbox[0].body)
        match = re.search(r'/reset/([^/]+)/([^\s]+)', mail.outbox[0].body)
        self.assertIsNotNone(match)
        confirmed = self.client.post(
            f'/api/auth/password-reset/{match.group(1)}/{match.group(2)}/',
            {'password': 'newstrongpass123'},
            format='json',
        )
        self.assertEqual(confirmed.status_code, status.HTTP_204_NO_CONTENT)
        self.assertTrue(User.objects.get(username='reset@example.com').check_password('newstrongpass123'))


class AlertDispatchContractTests(APITestCase):
    def setUp(self):
        self.manager = User.objects.create_user(username='manager')
        self.manager.userprofile.role = UserProfile.Role.MANAGER
        self.manager.userprofile.save(update_fields=['role'])
        self.volunteer = User.objects.create_user(username='volunteer')
        self.alert = Alert.objects.create(
            title='Roadside collision',
            description='One lightly injured person',
            location=Point(34.8, 32.1, srid=4326),
            priority=Alert.Priority.HIGH,
        )

    def test_manager_can_dispatch_and_volunteer_can_accept(self):
        self.client.force_authenticate(user=self.manager)
        dispatch_response = self.client.post(
            f'/api/alerts/{self.alert.id}/dispatch/',
            {'user_ids': [self.volunteer.id]},
            format='json',
        )

        self.assertEqual(dispatch_response.status_code, status.HTTP_200_OK)
        self.alert.refresh_from_db()
        self.assertEqual(self.alert.status, Alert.Status.DISPATCHED)
        self.assertEqual(
            AlertAssignment.objects.get(alert=self.alert, user=self.volunteer).status,
            AlertAssignment.Status.PENDING,
        )

        self.client.force_authenticate(user=self.volunteer)
        response = self.client.post(
            f'/api/alerts/{self.alert.id}/respond/',
            {'response': 'accept'},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.alert.refresh_from_db()
        self.assertEqual(self.alert.status, Alert.Status.ACCEPTED)
        self.assertEqual(response.data['assignments'][0]['status'], 'ACCEPTED')

    def test_volunteer_cannot_create_or_dispatch_alerts(self):
        self.client.force_authenticate(user=self.volunteer)
        create_response = self.client.post(
            '/api/alerts/',
            {
                'title': 'Unauthorised incident',
                'description': '',
                'latitude': 32.1,
                'longitude': 34.8,
                'priority': 'HIGH',
            },
            format='json',
        )
        dispatch_response = self.client.post(
            f'/api/alerts/{self.alert.id}/dispatch/',
            {'user_ids': [self.volunteer.id]},
            format='json',
        )

        self.assertEqual(create_response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(dispatch_response.status_code, status.HTTP_403_FORBIDDEN)

    def test_volunteer_can_update_contact_fields_but_not_role(self):
        self.client.force_authenticate(user=self.volunteer)
        response = self.client.put(
            '/api/user/update_profile/',
            {
                'display_name': 'Dana Volunteer',
                'phone': '+972501234567',
                'role': UserProfile.Role.MANAGER,
            },
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        profile = UserProfile.objects.get(user=self.volunteer)
        self.assertEqual(profile.display_name, 'Dana Volunteer')
        self.assertEqual(profile.phone, '+972501234567')
        self.assertEqual(profile.role, UserProfile.Role.USER)

    def test_volunteer_only_reads_and_posts_to_assigned_alert_context(self):
        other_alert = Alert.objects.create(
            title='Private incident',
            location=Point(34.81, 32.11, srid=4326),
        )
        AlertAssignment.objects.create(alert=self.alert, user=self.volunteer, dispatched_by=self.manager)
        Message.objects.create(sender=self.manager, alert=self.alert, title='Assigned', text='Proceed')
        Message.objects.create(sender=self.manager, alert=other_alert, title='Private', text='Do not expose')
        self.client.force_authenticate(user=self.volunteer)

        visible = self.client.get('/api/message/', {'alert': self.alert.id})
        forbidden = self.client.post(
            '/api/message/',
            {'alert': other_alert.id, 'title': 'Unauthorised', 'text': 'Nope'},
            format='json',
        )
        allowed = self.client.post(
            '/api/message/',
            {'alert': self.alert.id, 'title': 'On route', 'text': 'ETA five minutes'},
            format='json',
        )

        self.assertEqual(visible.status_code, status.HTTP_200_OK)
        self.assertEqual(len(visible.data), 1)
        self.assertEqual(forbidden.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(allowed.status_code, status.HTTP_201_CREATED)

    def test_volunteer_only_sees_groups_they_belong_to(self):
        visible_group = Group.objects.create(name='Visible group')
        visible_group.members.add(self.volunteer)
        Group.objects.create(name='Private group')
        self.client.force_authenticate(self.volunteer)

        response = self.client.get('/api/group/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([group['name'] for group in response.data], ['Visible group'])
        self.assertEqual(
            response.data[0],
            {
                'id': visible_group.id,
                'name': 'Visible group',
                'members': [self.volunteer.id],
            },
        )

    def test_volunteer_can_post_only_to_a_group_they_belong_to(self):
        member_group = Group.objects.create(name='PTT responders')
        member_group.members.add(self.volunteer)
        private_group = Group.objects.create(name='Private radio')
        self.client.force_authenticate(self.volunteer)

        allowed = self.client.post(
            '/api/message/',
            {'group': member_group.id, 'title': 'Voice transmission', 'text': ''},
            format='json',
        )
        forbidden = self.client.post(
            '/api/message/',
            {'group': private_group.id, 'title': 'Unauthorised transmission', 'text': ''},
            format='json',
        )

        self.assertEqual(allowed.status_code, status.HTTP_201_CREATED)
        self.assertEqual(allowed.data['group'], member_group.id)
        self.assertEqual(forbidden.status_code, status.HTTP_403_FORBIDDEN)

    def test_profile_list_exposes_the_account_id_used_by_dispatch(self):
        self.client.force_authenticate(self.manager)

        response = self.client.get('/api/user/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        volunteer_profile = next(
            profile for profile in response.data
            if profile['username'] == self.volunteer.username
        )
        self.assertEqual(volunteer_profile['id'], self.volunteer.userprofile.id)
        self.assertEqual(volunteer_profile['user_id'], self.volunteer.id)


class CrossClientPersistenceTests(APITestCase):
    """Two independent clients prove operational data survives a client reload."""

    def setUp(self):
        self.dispatcher = User.objects.create_user(
            username='e2e-dispatcher', email='e2e-dispatcher@example.com', is_staff=True,
        )
        self.dispatcher.userprofile.role = UserProfile.Role.EMERGENCY_DISPATCHER
        self.dispatcher.userprofile.save(update_fields=['role'])
        self.manager = User.objects.create_user(
            username='e2e-manager', email='e2e-manager@example.com', is_staff=True,
        )
        self.manager.userprofile.role = UserProfile.Role.MANAGER
        self.manager.userprofile.save(update_fields=['role'])
        self.volunteer = User.objects.create_user(
            username='e2e-volunteer', email='e2e-volunteer@example.com',
        )
        self.dispatcher_client = APIClient()
        self.dispatcher_client.force_authenticate(self.dispatcher)
        self.manager_client = APIClient()
        self.manager_client.force_authenticate(self.manager)
        self.volunteer_client = APIClient()
        self.volunteer_client.force_authenticate(self.volunteer)

    def test_incident_dispatch_and_message_are_visible_to_a_reloaded_volunteer_client(self):
        created = self.dispatcher_client.post(
            '/api/alerts/',
            {
                'title': 'E2E roadside incident',
                'description': 'Created by the dispatcher client',
                'latitude': 32.0853,
                'longitude': 34.7818,
                'priority': 'HIGH',
            },
            format='json',
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        alert_id = created.data['id']

        dispatched = self.dispatcher_client.post(
            f'/api/alerts/{alert_id}/dispatch/',
            {'user_ids': [self.volunteer.id]},
            format='json',
        )
        self.assertEqual(dispatched.status_code, status.HTTP_200_OK)

        # A new client models a page/app reload rather than reusing local state.
        reloaded_volunteer = APIClient()
        reloaded_volunteer.force_authenticate(self.volunteer)
        visible_alerts = reloaded_volunteer.get('/api/alerts/')
        self.assertEqual(visible_alerts.status_code, status.HTTP_200_OK)
        visible_alert = next(item for item in visible_alerts.data if item['id'] == alert_id)
        self.assertEqual(visible_alert['assignments'][0]['user_id'], self.volunteer.id)

        sent = self.dispatcher_client.post(
            '/api/message/',
            {'alert': alert_id, 'title': 'Dispatch update', 'text': 'Proceed to the incident.'},
            format='json',
        )
        self.assertEqual(sent.status_code, status.HTTP_201_CREATED)

        reloaded_messages = reloaded_volunteer.get('/api/message/', {'alert': alert_id})
        self.assertEqual(reloaded_messages.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [(message['title'], message['text']) for message in reloaded_messages.data],
            [('Dispatch update', 'Proceed to the incident.')],
        )

    def test_group_membership_change_is_visible_after_client_reload(self):
        created = self.manager_client.post(
            '/api/group/',
            {'name': 'E2E operational group', 'members': []},
            format='json',
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        group_id = created.data['id']

        before_membership = self.volunteer_client.get('/api/group/')
        self.assertEqual(before_membership.status_code, status.HTTP_200_OK)
        self.assertNotIn(group_id, [group['id'] for group in before_membership.data])

        changed = self.manager_client.patch(
            f'/api/group/{group_id}/',
            {'members': [self.volunteer.id]},
            format='json',
        )
        self.assertEqual(changed.status_code, status.HTTP_200_OK)

        reloaded_volunteer = APIClient()
        reloaded_volunteer.force_authenticate(self.volunteer)
        after_add = reloaded_volunteer.get('/api/group/')
        self.assertEqual(after_add.status_code, status.HTTP_200_OK)
        self.assertEqual(
            next(group for group in after_add.data if group['id'] == group_id)['members'],
            [self.volunteer.id],
        )

        removed = self.manager_client.patch(
            f'/api/group/{group_id}/',
            {'members': []},
            format='json',
        )
        self.assertEqual(removed.status_code, status.HTTP_200_OK)

        reloaded_after_removal = APIClient()
        reloaded_after_removal.force_authenticate(self.volunteer)
        after_removal = reloaded_after_removal.get('/api/group/')
        self.assertEqual(after_removal.status_code, status.HTTP_200_OK)
        self.assertNotIn(group_id, [group['id'] for group in after_removal.data])


@override_settings(
    LIVEKIT_URL='ws://livekit.test:7880',
    LIVEKIT_API_KEY='test-key',
    LIVEKIT_API_SECRET='test-secret',
)
class PttRoomTokenTests(APITestCase):
    def setUp(self):
        self.manager = User.objects.create_user(username='ptt-manager')
        self.manager.userprofile.role = UserProfile.Role.MANAGER
        self.manager.userprofile.save(update_fields=['role'])
        self.member = User.objects.create_user(username='ptt-member')
        self.outsider = User.objects.create_user(username='ptt-outsider')
        self.group = Group.objects.create(name='PTT responders')
        self.group.members.add(self.member)

    def test_member_receives_a_room_scoped_livekit_token(self):
        self.client.force_authenticate(self.member)

        response = self.client.post(f'/api/group/{self.group.id}/ptt-token/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['url'], 'ws://livekit.test:7880')
        self.assertEqual(response.data['room'], f'group-{self.group.id}')
        self.assertIsInstance(response.data['token'], str)
        self.assertTrue(response.data['token'])
        claims = jwt.decode(response.data['token'], options={'verify_signature': False})
        self.assertEqual(claims['sub'], f'user-{self.member.id}')
        self.assertEqual(claims['video']['room'], f'group-{self.group.id}')
        self.assertTrue(claims['video']['roomJoin'])
        self.assertEqual(claims['video']['canPublishSources'], ['microphone'])

    def test_non_member_cannot_get_a_room_token(self):
        self.client.force_authenticate(self.outsider)

        response = self.client.post(f'/api/group/{self.group.id}/ptt-token/')

        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    @override_settings(LIVEKIT_URL='', LIVEKIT_API_KEY='', LIVEKIT_API_SECRET='')
    def test_returns_service_unavailable_when_realtime_is_not_configured(self):
        self.client.force_authenticate(self.manager)

        response = self.client.post(f'/api/group/{self.group.id}/ptt-token/')

        self.assertEqual(response.status_code, status.HTTP_503_SERVICE_UNAVAILABLE)


class SharedApiContractTests(APITestCase):
    """Protect the payload examples consumed by the two supported clients."""

    def setUp(self):
        self.dispatcher = User.objects.create_user(username='contract-dispatcher')
        self.dispatcher.userprofile.role = UserProfile.Role.MANAGER
        self.dispatcher.userprofile.save(update_fields=['role'])
        self.member = User.objects.create_user(username='contract-member')
        self.client.force_authenticate(self.dispatcher)

    def test_alert_group_and_message_responses_match_the_shared_contract_shape(self):
        alert_response = self.client.post(
            '/api/alerts/',
            {
                'title': 'Contract incident',
                'description': 'Example',
                'latitude': 32.0853,
                'longitude': 34.7818,
                'priority': 'HIGH',
            },
            format='json',
        )
        self.assertEqual(alert_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(set(alert_response.data), {
            'id', 'title', 'description', 'latitude', 'longitude', 'status', 'priority',
            'created_at', 'updated_at', 'assignments',
        })
        self.assertIn(alert_response.data['status'], {'OPEN', 'DISPATCHED', 'ACCEPTED', 'IN_PROGRESS', 'RESOLVED', 'CANCELLED'})

        group_response = self.client.post(
            '/api/group/',
            {'name': 'Contract group', 'members': [self.member.id]},
            format='json',
        )
        self.assertEqual(group_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(set(group_response.data), {'id', 'name', 'members'})
        self.assertEqual(group_response.data['members'], [self.member.id])

        message_response = self.client.post(
            '/api/message/',
            {
                'alert': alert_response.data['id'],
                'title': 'Contract message',
                'text': 'Proceed',
            },
            format='json',
        )
        self.assertEqual(message_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(set(message_response.data), {
            'id', 'sender', 'alert', 'group', 'title', 'text', 'latitude', 'longitude', 'timestamp',
        })
        self.assertIsNone(message_response.data['group'])
        self.assertIsNone(message_response.data['latitude'])
        self.assertIsNone(message_response.data['longitude'])

    def test_authentication_and_device_registration_failures_remain_machine_readable(self):
        anonymous = APIClient()
        unauthorized = anonymous.get('/api/alerts/')
        self.assertEqual(unauthorized.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertIn('detail', unauthorized.data)

        invalid_device = self.client.post('/api/notifications/token', {}, format='json')
        self.assertEqual(invalid_device.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertTrue(invalid_device.data)


class RealtimeMessageContractTests(TransactionTestCase):
    def setUp(self):
        self.dispatcher = User.objects.create_user(username='socket-dispatcher')
        self.dispatcher.userprofile.role = UserProfile.Role.EMERGENCY_DISPATCHER
        self.dispatcher.userprofile.save(update_fields=['role'])
        self.volunteer = User.objects.create_user(username='socket-volunteer')
        self.alert = Alert.objects.create(
            title='Socket incident',
            location=Point(34.8, 32.1, srid=4326),
        )
        AlertAssignment.objects.create(
            alert=self.alert,
            user=self.volunteer,
            dispatched_by=self.dispatcher,
        )
        session = SessionStore()
        session['_auth_user_id'] = str(self.volunteer.id)
        session['_auth_user_backend'] = 'django.contrib.auth.backends.ModelBackend'
        session['_auth_user_hash'] = self.volunteer.get_session_auth_hash()
        session.save()
        self.session_key = session.session_key

    def test_assigned_volunteer_receives_an_alert_message(self):
        message = Message.objects.create(
            sender=self.dispatcher,
            alert=self.alert,
            title='Proceed',
            text='Approach from the north.',
        )

        async def receive_and_disconnect():
            from config.asgi import application

            communicator = WebsocketCommunicator(
                application,
                '/ws/messages/',
                headers=[(b'cookie', f'sessionid={self.session_key}'.encode())],
            )
            connected, protocol = await communicator.connect()
            self.assertTrue(connected)
            self.assertIsNone(protocol)
            await sync_to_async(publish_message_created)(message.id)
            payload = await communicator.receive_json_from(timeout=1)
            await communicator.disconnect()
            return payload

        payload = async_to_sync(receive_and_disconnect)()
        self.assertEqual(payload['type'], 'message.created')
        self.assertEqual(payload['message']['id'], message.id)
        self.assertEqual(payload['message']['alert'], self.alert.id)

    def test_volunteer_does_not_receive_an_unassigned_alert_message(self):
        private_alert = Alert.objects.create(
            title='Private socket incident',
            location=Point(34.81, 32.11, srid=4326),
        )
        message = Message.objects.create(
            sender=self.dispatcher,
            alert=private_alert,
            title='Private',
            text='Do not expose.',
        )

        async def assert_nothing_and_disconnect():
            from config.asgi import application

            communicator = WebsocketCommunicator(
                application,
                '/ws/messages/',
                headers=[(b'cookie', f'sessionid={self.session_key}'.encode())],
            )
            connected, _ = await communicator.connect()
            self.assertTrue(connected)
            await sync_to_async(publish_message_created)(message.id)
            received = await communicator.receive_nothing(timeout=0.2)
            await communicator.disconnect()
            return received

        self.assertTrue(async_to_sync(assert_nothing_and_disconnect)())

    def test_assigned_volunteer_can_connect_with_a_jwt(self):
        token = str(RefreshToken.for_user(self.volunteer).access_token)

        async def connect_and_disconnect():
            from config.asgi import application

            communicator = WebsocketCommunicator(
                application,
                f'/ws/messages/?token={token}',
            )
            connected, _ = await communicator.connect()
            await communicator.disconnect()
            return connected

        self.assertTrue(async_to_sync(connect_and_disconnect)())
