# django-terraform-starter

A batteries-included starter for a Django app that runs as an **ASGI (Daphne)**
server with **Celery** workers, backed by **Postgres** and **Redis**, and deploys
to **AWS ECS (Fargate)** via the Terraform modules in [`terraform/`](terraform/).

```
.
├── config/            # Django project (settings, asgi, wsgi, celery, urls)
├── core/              # A small app: home page, /healthz/ probe, demo Celery task
├── manage.py
├── Dockerfile         # One image; entrypoint arg selects `web` or `jobs`
├── entrypoint.sh      # web = daphne (prod) / runserver (dev); jobs = celery worker+beat
├── docker-compose.yml # Local stack: web + jobs + db + redis
├── pyproject.toml     # uv-managed deps (Python 3.13)
├── .github/workflows/ # CI (lint + test) and deploy (ECR build + ECS roll)
└── terraform/         # VPC, RDS, ElastiCache, ECR, ECS, ALB, monitoring
```

## Local development

Requires Docker. The stack runs the web server, a Celery worker (with beat),
Postgres, and Redis:

```bash
docker compose up
```

Then:

- App: <http://localhost:8000>
- Health check: <http://localhost:8000/healthz/>
- Admin: <http://localhost:8000/admin/> (create a user first, below)

Common commands:

```bash
# Dependencies live in the image's uv venv, so prefix manage.py with `uv run`.
docker compose exec web uv run python manage.py migrate
docker compose exec web uv run python manage.py createsuperuser
docker compose exec web uv run python manage.py test

# Smoke-test the Celery queue end-to-end (enqueues on web, runs on the jobs worker):
docker compose exec web uv run python manage.py shell -c \
  "from core.tasks import ping; print(ping.delay().get(timeout=10))"   # -> pong
```

Host ports live in `docker-compose.override.yml` — edit there to avoid clashes
with other local stacks.

### Running without Docker

```bash
uv sync --dev
cp .env.example .env          # point DATABASE_URL / REDIS_URL at local services
uv run python manage.py migrate
uv run python manage.py runserver
# In another shell, the worker:
uv run celery -A config worker --beat --loglevel=info \
  --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

With no `DATABASE_URL` set, Django falls back to a local SQLite file so
`manage.py check` / tests run with zero infrastructure.

## The image and its two modes

One Docker image runs both services; the entrypoint arg picks the mode:

| Command       | `DEBUG=1` (dev)                      | `DEBUG=0` (prod)                          |
|---------------|--------------------------------------|-------------------------------------------|
| `web` (default) | `manage.py runserver` (autoreload) | migrate + collectstatic + **Daphne** ASGI |
| `jobs`        | celery worker **+ beat**, concurrency 2 | celery worker **+ beat**               |

`web` runs migrations on startup, so deploy `web` before `jobs`.

## Configuration (env vars)

Settings are 12-factor (`config/settings.py`). Locally, `docker compose` supplies
these; in ECS the task definition injects them.

| Var | Purpose |
|-----|---------|
| `DJANGO_SECRET_KEY` | Django secret (SSM `SecureString` in ECS) |
| `DEBUG` | `1` = dev mode (runserver, autoreload) |
| `DATABASE_URL` | Full Postgres URL (local/compose) |
| `DATABASE_HOST/PORT/NAME/USER/PASSWORD` | Discrete DB vars (used by ECS task def) |
| `REDIS_URL` | Celery broker/result backend + Channels layer |
| `DJANGO_ALLOWED_HOSTS` / `ALLOWED_HOSTS` | Comma-separated allowed hosts |

`DATABASE_URL` takes priority; the discrete `DATABASE_*` vars are the fallback the
ECS task definitions use.

## Deploying to AWS

The infrastructure lives in [`terraform/`](terraform/) — read its README for the
full setup. In short:

1. **Rename the placeholders.** Project-wide find/replace `myapp` → your project
   name, then fill the `<ACCOUNT_ID>`, `<GITHUB_ORG>/<GITHUB_REPO>`, SSO URL, and
   `example.com` domain placeholders in `terraform/*/vars/*.tfvars`.
2. **Stand up state + infra** (`terraform-backend` → `network` → `rds` → `cache`
   → `ecr` → `ecs` → `resource-groups`). See `terraform/README.md`.
3. **Wire CI/CD.** `.github/workflows/deploy-dev.yml` builds the image, pushes to
   ECR, and forces a new ECS deployment on `web` + `jobs`. Set its `WORKSPACE`
   and `ECR_REPOSITORY` env values to match your terraform workspace, and add an
   `AWS_DEPLOY_ROLE_ARN` repo secret (the OIDC role created by the `ecs` module).

Runtime secrets (`DJANGO_SECRET_KEY`, DB password) are seeded into SSM Parameter
Store by Terraform from SOPS-encrypted `*-secrets.json` files — the deploy
workflow does **not** handle secrets. See `terraform/.sops.yaml`.

## What was stripped from the source infra

The Terraform is derived from a production ECS repo, with app-specific pieces
removed for a clean starter: the LiveKit recordings S3 bucket + IAM users, the
dedicated `workflow-worker` cluster and its queue-depth autoscaling, and the
`code-sandbox` ECR repo/sidecar. The generic web + jobs services, VPC, RDS,
Redis, ALB, WAF, and CloudWatch alarms remain.
