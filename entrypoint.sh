#!/bin/bash
set -e

MODE="${1:-web}"
echo "Starting django-terraform-starter in ${MODE} mode..."

# Development mode (hot reloading, skip collectstatic) — toggled by DEBUG.
if [ "${DEBUG:-0}" = "1" ] || [ "${DEBUG:-0}" = "true" ]; then
    echo "Running in development mode..."
    case "${MODE}" in
        "web")
            uv run python manage.py migrate --noinput
            # runserver gives Django's autoreloader for fast local iteration.
            exec uv run python manage.py runserver 0.0.0.0:8000
            ;;
        "jobs")
            # Worker + beat in one process for local dev. --concurrency=2 keeps memory low.
            exec uv run celery -A config worker --beat --loglevel=info \
                --concurrency=2 --scheduler django_celery_beat.schedulers:DatabaseScheduler
            ;;
        *)
            echo "Usage: $0 {web|jobs}"
            exit 1
            ;;
    esac
else
    # Production mode (migrations with retry, collectstatic, Daphne/ASGI).
    echo "Running in production mode..."
    case "${MODE}" in
        "web")
            for attempt in {1..5}; do
                echo "Migration attempt $attempt of 5"
                if uv run python manage.py migrate --noinput; then
                    echo "Migrations completed successfully!"
                    break
                elif [ "$attempt" -eq 5 ]; then
                    echo "All migration attempts failed. Exiting."
                    exit 1
                else
                    sleep $((2 ** attempt))
                fi
            done

            uv run python manage.py collectstatic --noinput
            exec uv run daphne -b 0.0.0.0 -p 8000 config.asgi:application
            ;;
        "jobs")
            exec uv run celery -A config worker --beat --loglevel=info \
                --scheduler django_celery_beat.schedulers:DatabaseScheduler
            ;;
        *)
            echo "Usage: $0 {web|jobs}"
            exit 1
            ;;
    esac
fi
