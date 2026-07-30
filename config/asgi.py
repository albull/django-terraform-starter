"""ASGI config. Exposes the ASGI callable as a module-level ``application``.

Uses Channels' ProtocolTypeRouter so both HTTP and WebSocket protocols are served.
Add WebSocket URL routes to ``core.routing.websocket_urlpatterns`` as needed.
"""

import os

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

# Initialize Django ASGI application early to populate the app registry before
# importing anything that touches ORM models / routing.
django_asgi_app = get_asgi_application()

from core.routing import websocket_urlpatterns  # noqa: E402

application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": AllowedHostsOriginValidator(
            URLRouter(websocket_urlpatterns)
        ),
    }
)
