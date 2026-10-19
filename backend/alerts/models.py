from django.db import models
from django.contrib.auth.models import User
from django.contrib.gis.db import models as gis_models
from django.contrib.gis.geos import Point


class UserProfile(models.Model):
    class Role(models.TextChoices):
        MANAGER = 'manager', 'Manager'
        EMERGENCY_DISPATCHER = 'emergency_dispatcher', 'Emergency dispatcher'
        USER = 'user', 'Volunteer'

    user = models.OneToOneField(User, on_delete=models.CASCADE)
    display_name = models.CharField(max_length=150, blank=True)
    phone = models.CharField(max_length=32, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    role = models.CharField(max_length=50, choices=Role.choices, default=Role.USER)

    def __str__(self):
        return f"{self.user.username} - {self.role}"


class Group(models.Model):
    name = models.CharField(max_length=100, unique=True)
    members = models.ManyToManyField(User, related_name='user_groups')

    def __str__(self):
        return self.name


class Message(models.Model):
    sender = models.ForeignKey(User, on_delete=models.CASCADE)
    alert = models.ForeignKey(
        'Alert',
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='messages',
    )
    group = models.ForeignKey(
        Group,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='messages',
    )
    title = models.CharField(max_length=255)
    text = models.TextField(blank=True)
    voice_file = models.FileField(upload_to='voices/', null=True, blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.title} by {self.sender.username}"


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    token = models.CharField(max_length=255, unique=True)  # Push notification token

    def __str__(self):
        return f"Token for {self.user.username}"


class DeviceRegistration(models.Model):
    class Platform(models.TextChoices):
        ANDROID = 'android', 'Android'
        IOS = 'ios', 'iOS'
        OTHER = 'other', 'Other'

    user_uid = models.CharField(max_length=128)
    device_id = models.CharField(max_length=256)
    push_token = models.TextField()
    platform = models.CharField(max_length=10, choices=Platform.choices, default=Platform.OTHER)
    device_model = models.CharField(max_length=128, blank=True)
    last_seen = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = [('user_uid', 'device_id')]
        indexes = [models.Index(fields=['user_uid'], name='alerts_devi_user_ui_93e336_idx')]

    def __str__(self):
        return f'{self.user_uid} / {self.platform} / {self.device_model}'


class Alert(models.Model):
    class Status(models.TextChoices):
        OPEN = "OPEN", "Open"
        DISPATCHED = "DISPATCHED", "Dispatched"
        ACCEPTED = "ACCEPTED", "Accepted"
        IN_PROGRESS = "IN_PROGRESS", "In Progress"
        RESOLVED = "RESOLVED", "Resolved"
        CANCELLED = "CANCELLED", "Cancelled"

    class Priority(models.TextChoices):
        LOW = "LOW", "Low"
        MEDIUM = "MEDIUM", "Medium"
        HIGH = "HIGH", "High"
        CRITICAL = "CRITICAL", "Critical"

    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    location = gis_models.PointField(geography=False)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.OPEN,
    )
    priority = models.CharField(
        max_length=10,
        choices=Priority.choices,
        default=Priority.MEDIUM,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    @property
    def latitude(self):
        return self.location.y if self.location else None

    @property
    def longitude(self):
        return self.location.x if self.location else None

    def __str__(self):
        return f"{self.title} ({self.status})"


class AlertAssignment(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending response'
        ACCEPTED = 'ACCEPTED', 'Accepted'
        DECLINED = 'DECLINED', 'Declined'
        ARRIVED = 'ARRIVED', 'Arrived on scene'

    alert = models.ForeignKey(
        Alert,
        on_delete=models.CASCADE,
        related_name='assignments',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='alert_assignments',
    )
    dispatched_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        null=True,
        related_name='dispatched_alert_assignments',
    )
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PENDING,
    )
    dispatched_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=['alert', 'user'],
                name='unique_alert_assignment_per_user',
            ),
        ]
        ordering = ['-updated_at']

    def __str__(self):
        return f'{self.alert_id} -> {self.user_id} ({self.status})'
