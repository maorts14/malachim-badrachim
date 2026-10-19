from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [('alerts', '0008_message_context')]

    operations = [
        migrations.RenameField(model_name='deviceregistration', old_name='firebase_uid', new_name='user_uid'),
        migrations.RenameField(model_name='deviceregistration', old_name='fcm_token', new_name='push_token'),
        migrations.RemoveIndex(model_name='deviceregistration', name='alerts_devi_firebas_737182_idx'),
        migrations.AddIndex(model_name='deviceregistration', index=models.Index(fields=['user_uid'], name='alerts_devi_user_ui_93e336_idx')),
        migrations.AlterUniqueTogether(name='deviceregistration', unique_together={('user_uid', 'device_id')}),
    ]
