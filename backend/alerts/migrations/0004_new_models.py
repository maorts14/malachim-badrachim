import django.contrib.gis.db.models.fields
from django.db import migrations


class Migration(migrations.Migration):
    """
    Convert Alert coordinates to a PostGIS location field. The other models
    already exist from 0001_initial and must not be created again.
    """

    dependencies = [
        ('alerts', '0003_deviceregistration'),
    ]

    operations = [
        migrations.RemoveField(model_name='alert', name='latitude'),
        migrations.RemoveField(model_name='alert', name='longitude'),
        migrations.AddField(
            model_name='alert',
            name='location',
            field=django.contrib.gis.db.models.fields.PointField(geography=False, srid=4326),
        ),
    ]
