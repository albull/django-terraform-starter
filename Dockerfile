# syntax=docker/dockerfile:1
#
# Application image (the Django web server and Celery worker share one image).
# The runtime mode is selected by the entrypoint arg: `web` or `jobs`.
#
# Build from the repository root:
#     docker build -t django-terraform-starter .
#
# Uses the official uv image so `uv` is on PATH, pinned to Python 3.13.
ARG PYTHON_VERSION=3.13
FROM ghcr.io/astral-sh/uv:python${PYTHON_VERSION}-bookworm-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# System dependencies: build tools, libpq, psql client, tini for PID-1 reaping,
# curl for container health checks.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    postgresql-client \
    curl \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first (cache-friendly): copy only the manifests, then sync.
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project --no-dev

# Copy the project and finish the install.
COPY . .
RUN uv sync --locked --no-dev

RUN chmod +x entrypoint.sh

EXPOSE 8000

# tini as PID 1 reaps zombie children (Celery, subprocesses). Invoke the script via
# bash so it runs even when a bind mount (local dev) shadows the image's +x bit.
ENTRYPOINT ["tini", "--", "bash", "entrypoint.sh"]
CMD ["web"]
