from django.contrib import admin
from .models import Alert, AlertAssignment


@admin.register(Alert)
class AlertAdmin(admin.ModelAdmin):
    list_display = ("id", "title", "status", "priority", "created_at")
    list_filter = ("status", "priority", "created_at")
    search_fields = ("title", "description")
    ordering = ("-created_at",)


@admin.register(AlertAssignment)
class AlertAssignmentAdmin(admin.ModelAdmin):
    list_display = ('alert', 'user', 'status', 'dispatched_by', 'updated_at')
    list_filter = ('status',)
    search_fields = ('alert__title', 'user__username')
