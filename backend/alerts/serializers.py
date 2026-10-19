from django.conf import settings
from django.contrib.auth import authenticate
from django.contrib.auth.models import User
from django.contrib.gis.geos import Point
from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from .models import (
    Alert,
    AlertAssignment,
    DeviceRegistration,
    UserProfile,
    Group,
    Message,
    Notification,
)


class DeviceRegistrationSerializer(serializers.Serializer):
    push_token = serializers.CharField()
    device_id = serializers.CharField(max_length=256)
    platform = serializers.ChoiceField(choices=DeviceRegistration.Platform.values)
    device_model = serializers.CharField(max_length=128, required=False, allow_blank=True, default='')


class UserInfoSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source='get_full_name', read_only=True)
    role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'name', 'role', 'is_staff']

    def get_role(self, user):
        profile = getattr(user, 'userprofile', None)
        return profile.role if profile else None


class RegisterSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, min_length=8)
    full_name = serializers.CharField(required=False, allow_blank=True, default='')
    invite_code = serializers.CharField(required=False, allow_blank=True, default='', write_only=True)

    def validate_email(self, value):
        email = value.strip().lower()
        if User.objects.filter(username__iexact=email).exists() or User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return email

    def validate_invite_code(self, value):
        if settings.REGISTRATION_INVITE_CODE and value != settings.REGISTRATION_INVITE_CODE:
            raise serializers.ValidationError('Invalid invite code.')
        return value

    def create(self, validated_data):
        full_name = validated_data.pop('full_name')
        validated_data.pop('invite_code')
        parts = full_name.split()
        return User.objects.create_user(
            username=validated_data['email'], email=validated_data['email'], password=validated_data['password'],
            first_name=parts[0] if parts else '', last_name=' '.join(parts[1:]),
        )


class SessionLoginSerializer(serializers.Serializer):
    username = serializers.CharField(help_text='Email address or username')
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        identifier = attrs['username'].strip()
        user = User.objects.filter(username__iexact=identifier).first() or User.objects.filter(email__iexact=identifier).first()
        if user is None:
            raise serializers.ValidationError('Invalid credentials.')
        authenticated = authenticate(username=user.username, password=attrs['password'])
        if authenticated is None or not authenticated.is_active:
            raise serializers.ValidationError('Invalid credentials.')
        if not authenticated.is_staff:
            raise serializers.ValidationError('This account cannot access the dispatcher panel.')
        attrs['user'] = authenticated
        return attrs


class UserProfileSerializer(serializers.ModelSerializer):
    # `id` identifies the profile row.  Dispatch endpoints intentionally accept
    # Django account IDs, so clients need this explicit field rather than
    # assuming those two primary keys happen to match.
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    email = serializers.EmailField(source='user.email', read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'id',
            'user_id',
            'username',
            'email',
            'display_name',
            'phone',
            'role',
            'latitude',
            'longitude',
        ]
        read_only_fields = ['id']


class GroupSerializer(serializers.ModelSerializer):
    members = serializers.PrimaryKeyRelatedField(many=True, queryset=User.objects.all())

    class Meta:
        model = Group
        fields = ['id', 'name', 'members']


class MessageSerializer(serializers.ModelSerializer):
    sender = serializers.SerializerMethodField()
    voice_url = serializers.SerializerMethodField()
    alert = serializers.PrimaryKeyRelatedField(
        queryset=Alert.objects.all(), required=False, allow_null=True,
    )
    group = serializers.PrimaryKeyRelatedField(
        queryset=Group.objects.all(), required=False, allow_null=True,
    )

    class Meta:
        model = Message
        fields = [
            'id',
            'sender',
            'alert',
            'group',
            'title',
            'text',
            'voice_file',
            'voice_url',
            'latitude',
            'longitude',
            'timestamp',
        ]
        read_only_fields = ['id', 'timestamp', 'sender']

    @extend_schema_field({
        'type': 'object',
        'properties': {
            'id': {'type': 'integer'},
            'username': {'type': 'string'},
            'email': {'type': 'string', 'format': 'email'},
            'role': {'type': 'string', 'nullable': True},
        },
    })
    def get_sender(self, obj):
        profile = getattr(obj.sender, "userprofile", None)
        return {
            "id": obj.sender.id,
            "username": obj.sender.username,
            "email": obj.sender.email,
            "role": profile.role if profile else None,
        }

    @extend_schema_field({'type': 'string', 'format': 'uri', 'nullable': True})
    def get_voice_url(self, obj):
        if obj.voice_file:
            return obj.voice_file.url
        return None


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'token']
        read_only_fields = ['id', 'user']


class AlertSerializer(serializers.ModelSerializer):
    latitude = serializers.FloatField()
    longitude = serializers.FloatField()
    assignments = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = Alert
        fields = [
            "id",
            "title",
            "description",
            "latitude",
            "longitude",
            "status",
            "priority",
            "created_at",
            "updated_at",
            "assignments",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]

    @extend_schema_field({
        'type': 'array',
        'items': {
            'type': 'object',
            'properties': {
                'user_id': {'type': 'integer'},
                'username': {'type': 'string'},
                'status': {'type': 'string'},
                'dispatched_at': {'type': 'string', 'format': 'date-time'},
                'responded_at': {'type': 'string', 'format': 'date-time', 'nullable': True},
            },
        },
    })
    def get_assignments(self, obj):
        assignments = getattr(obj, '_prefetched_assignments', None)
        if assignments is None:
            assignments = obj.assignments.select_related('user').all()
        return [
            {
                'user_id': assignment.user_id,
                'username': assignment.user.username,
                'status': assignment.status,
                'dispatched_at': assignment.dispatched_at,
                'responded_at': assignment.responded_at,
            }
            for assignment in assignments
        ]

    def to_representation(self, instance):
        data = super().to_representation(instance)
        data["latitude"] = instance.latitude
        data["longitude"] = instance.longitude
        return data

    def validate_latitude(self, value):
        if not (-90 <= value <= 90):
            raise serializers.ValidationError("Latitude must be between -90 and 90.")
        return value

    def validate_longitude(self, value):
        if not (-180 <= value <= 180):
            raise serializers.ValidationError("Longitude must be between -180 and 180.")
        return value

    def create(self, validated_data):
        latitude = validated_data.pop("latitude")
        longitude = validated_data.pop("longitude")
        validated_data["location"] = Point(longitude, latitude, srid=4326)
        return super().create(validated_data)

    def update(self, instance, validated_data):
        latitude = validated_data.pop("latitude", None)
        longitude = validated_data.pop("longitude", None)

        if latitude is not None and longitude is not None:
            instance.location = Point(longitude, latitude, srid=4326)
        elif latitude is not None or longitude is not None:
            raise serializers.ValidationError(
                "Both latitude and longitude must be provided together."
            )

        return super().update(instance, validated_data)
