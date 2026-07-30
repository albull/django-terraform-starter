"""Views for the starter's core app: a home page and a health check."""

from django.db import connection
from django.http import JsonResponse
from django.shortcuts import render


def home(request):
    """Landing page confirming the stack is wired up."""
    return render(request, "core/home.html")


def healthz(request):
    """Liveness/readiness probe used by the ALB target group.

    Returns 200 when the process is up and the database is reachable, 503
    otherwise. Kept dependency-light so it stays cheap to poll frequently.
    """
    checks = {"app": "ok"}
    status = 200
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        checks["database"] = "ok"
    except Exception as exc:  # noqa: BLE001 — surface any DB error as unhealthy
        checks["database"] = f"error: {exc}"
        status = 503

    return JsonResponse(checks, status=status)
