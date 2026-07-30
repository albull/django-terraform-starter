# ECR module

This module provides an ECR (Elastic Container Registry) for the web application.

## One-Time Initial Application Infrastructure Setup

There need only be one ECR Docker image repository between environments, and to duplicate identical builds across environments would be less cost effective. For that reason, this module only applies to the dev environment within an application.

Set up only a `APPLICATION-NAME-dev.tfvars` file, and in it list all of the environment AWS accounts for `APPLICATION-NAME`.

Before running the first deploy of a Rails application, make sure the startup script `run-app.sh` in the application repo will create the database.

## Manually Build and Deploy a Docker Image

1. Select an appropriate, incremental version number (like `v0.0.1`) for the ECR image tag.
2. Make sure assets are compiled: `rake assets:clean && rake assets:precompile` OR `rake assets:clean && vite build --mode production` if using vite.
3. Build Docker image:
   ```
   docker build --platform linux/amd64 --no-cache --build-arg RUBY_VERSION=3.2.1 --build-arg NODE_MAJOR=20 -f Dockerfile .
   ```
4. Authenticate with ECR: `aws ecr get-login-password --profile myapp-dev --region us-west-2 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com`
5. Send to ECR: `AWS_PROFILE=myapp-dev docker push <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/myapp-dev:VERSION`
6. Terraform apply the changes in the `ecs` directory using the latest version tag.
