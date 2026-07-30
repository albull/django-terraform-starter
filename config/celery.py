"""Celery application. Enables `celery -A config worker ...`."""

import os

from celery import Celery

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

app = Celery("django_terraform_starter")
# Read CELERY_* settings from Django settings.
app.config_from_object("django.conf:settings", namespace="CELERY")
# Auto-discover tasks.py in installed apps.
app.autodiscover_tasks()
