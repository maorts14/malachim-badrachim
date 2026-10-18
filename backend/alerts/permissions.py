from rest_framework.permissions import BasePermission

from .models import UserProfile


def is_dispatcher(user):
    profile = getattr(user, 'userprofile', None)
    return bool(profile and profile.role in {
        UserProfile.Role.MANAGER,
        UserProfile.Role.EMERGENCY_DISPATCHER,
    })


class IsDispatcher(BasePermission):
    message = 'Only managers and emergency dispatchers can perform this action.'

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_authenticated and is_dispatcher(request.user))


class IsManager(BasePermission):
    message = 'Only managers can perform this action.'

    def has_permission(self, request, view):
        profile = getattr(request.user, 'userprofile', None)
        return bool(
            request.user and request.user.is_authenticated and profile
            and profile.role == UserProfile.Role.MANAGER
        )
