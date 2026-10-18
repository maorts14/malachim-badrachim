from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ('alerts', '0005_rename_alerts_devi_firebas_idx_alerts_devi_firebas_737182_idx'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.AlterField(
            model_name='userprofile',
            name='role',
            field=models.CharField(
                choices=[
                    ('manager', 'Manager'),
                    ('emergency_dispatcher', 'Emergency dispatcher'),
                    ('user', 'Volunteer'),
                ],
                default='user',
                max_length=50,
            ),
        ),
        migrations.CreateModel(
            name='AlertAssignment',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('status', models.CharField(choices=[('PENDING', 'Pending response'), ('ACCEPTED', 'Accepted'), ('DECLINED', 'Declined'), ('ARRIVED', 'Arrived on scene')], default='PENDING', max_length=16)),
                ('dispatched_at', models.DateTimeField(auto_now_add=True)),
                ('responded_at', models.DateTimeField(blank=True, null=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('alert', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='assignments', to='alerts.alert')),
                ('dispatched_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='dispatched_alert_assignments', to=settings.AUTH_USER_MODEL)),
                ('user', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='alert_assignments', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-updated_at']},
        ),
        migrations.AddConstraint(
            model_name='alertassignment',
            constraint=models.UniqueConstraint(fields=('alert', 'user'), name='unique_alert_assignment_per_user'),
        ),
    ]
