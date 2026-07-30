"""Demo Celery task, proving the worker + broker are wired up.

Run it from a shell to smoke-test the queue:

    docker compose exec web python manage.py shell -c \
        "from core.tasks import ping; print(ping.delay().get(timeout=10))"
"""

from celery import shared_task


@shared_task
def ping() -> str:
    """Return a constant so callers can confirm round-trip execution."""
    return "pong"
