from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [('alerts', '0006_alertassignment_and_roles')]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='display_name',
            field=models.CharField(blank=True, max_length=150),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='phone',
            field=models.CharField(blank=True, max_length=32),
        ),
    ]
