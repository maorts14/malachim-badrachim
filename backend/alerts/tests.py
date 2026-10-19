from django.contrib.auth.models import User
from django.contrib.gis.geos import Point
from django.contrib.sessions.backends.db import SessionStore
from django.test import TransactionTestCase
from rest_framework import status
from rest_framework.test import APITestCase
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
