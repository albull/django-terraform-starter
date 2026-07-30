"""WSGI config. Exposes the WSGI callable as a module-level ``application``.

Kept for tooling / gunicorn compatibility. The production server runs ASGI
(Daphne) via ``config.asgi``.
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

application = get_wsgi_application()
