# django-terraform-starter

A batteries-included starter for a Django app that runs as an **ASGI (Daphne)**
server with **Celery** workers, backed by **Postgres** and **Redis**, and deploys
to **AWS ECS (Fargate)** via the Terraform modules in [`terraform/`](terraform/).

> **This is a template, not a deployable app.** It is meant to be cloned (or used
> via GitHub's *Use this template*) as the starting point for a new project. Nothing
> here is wired to a real AWS account or domain — the repo ships with `myapp` and
> `<...>` placeholders that **you**, the person cloning it, fill in for your own
> project. Start with [Making it yours](#making-it-yours) below.

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

## Making it yours

Do this once, right after cloning, before you try to deploy anything. Local
development with `docker compose` works as-is, so you can skip ahead and come back
to this when you're ready to touch AWS.

1. **Pick your project name and find/replace `myapp`.** It appears in the Terraform
   workspaces (`myapp-dev` / `myapp-prod`), the shared state profile
   (`myapp-terraform`), resource names, and the ECR repository name:

   ```bash
   # from the repo root — review the hits first, then replace
   grep -rl myapp . --exclude-dir=.git --exclude-dir=.venv
   grep -rl myapp . --exclude-dir=.git --exclude-dir=.venv | xargs sed -i '' 's/myapp/yourname/g'
   ```

2. **Fill in the placeholders.** These are deliberately left blank because they're
   specific to your AWS org and GitHub repo:

   | Placeholder | Where | What it is |
   |-------------|-------|------------|
   | `<ACCOUNT_ID>` | `terraform/ecs/vars/*.tfvars` | AWS account ID per environment |
   | `<GITHUB_ORG>/<GITHUB_REPO>` | `terraform/ecs/vars/*.tfvars`, `terraform/ecr/vars/*.tfvars` | Your repo, for the GitHub Actions OIDC trust policy |
   | `<YOUR_SSO_START_URL>` | `terraform/README.md` → your `~/.aws/config` | Your IAM Identity Center start URL |
   | `example.com` | `terraform/ecs/vars/*.tfvars`, `terraform/common/alarms.tf` | Your real domain, and the alarm notification email |

   `grep -rn '<ACCOUNT_ID>\|GITHUB_ORG\|example\.com\|YOUR_SSO' terraform/` lists
   every remaining one.

3. **Set up secret encryption.** Requires `brew install sops age`. From `terraform/`,
   run `./setup-sops.sh yourproject` — it generates your age keys, writes `.sops.yaml`,
   and creates encrypted `vars/*-secrets.json` files with random values. Needs no AWS
   account, so you can do it now. See [Secrets](terraform/README.md#secrets-sops--age)
   for what it does and how to onboard teammates.

4. **Rename the repo and this README.** Replace this section with your own project
   notes once the setup is done — nobody cloning *your* repo needs these steps.

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

1. **Do the [Making it yours](#making-it-yours) pass first.** Every module reads the
   project name and account IDs you set there; applying with the placeholders in
   place will fail (or create resources named `myapp`).
2. **Stand up state + infra** (`terraform-backend` → `network` → `rds` → `cache`
   → `ecr` → `ecs` → `resource-groups`). See `terraform/README.md`.
3. **Wire CI/CD.** `.github/workflows/deploy-dev.yml` builds the image, pushes to
   ECR, and forces a new ECS deployment on `web` + `jobs`. Set its `WORKSPACE`
   and `ECR_REPOSITORY` env values to match your terraform workspace, and add an
   `AWS_DEPLOY_ROLE_ARN` repo secret (the OIDC role created by the `ecs` module).

Runtime secrets (`DJANGO_SECRET_KEY`, DB password) are seeded into SSM Parameter
Store by Terraform from age-encrypted `*-secrets.json` files — the deploy
workflow does **not** handle secrets. See
[Secrets](terraform/README.md#secrets-sops--age).

## What's included

The Terraform is extracted from a running production ECS deployment, with
application-specific resources removed so what's left is generic:

- **`network`** — VPC, public/private subnets across 2 AZs, NAT
- **`rds`** — Postgres, with AWS Backup plans and an optional read replica
- **`cache`** — ElastiCache Redis (Celery broker + Channels layer)
- **`ecr`** — one image repository per application, shared across environments
- **`ecs`** — Fargate `web` and `jobs` clusters, ALB, ACM cert, WAF, and the
  GitHub Actions OIDC deploy role
- **`common`** — SNS topic and CloudWatch alarms
- **`resource-groups`** — console grouping for an environment's resources

Sizing in the `*.tfvars` files starts small (`db.t4g.micro`, 256 CPU web tasks) and
is meant to be raised for real workloads.

## License

MIT — see [LICENSE](LICENSE).
