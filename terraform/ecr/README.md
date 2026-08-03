# ECR module

This module provides an ECR (Elastic Container Registry) for the web application.

## One-Time Initial Application Infrastructure Setup

There need only be one ECR Docker image repository between environments, and to duplicate identical builds across environments would be less cost effective. For that reason, this module only applies to the dev environment within an application.

Set up only a `APPLICATION-NAME-dev.tfvars` file, and in it list all of the environment AWS accounts for `APPLICATION-NAME`.

> `myapp` and `<ACCOUNT_ID>` below are placeholders — substitute your own project
> name and account ID (see [Making it yours](../../README.md#making-it-yours)).

## Manually Build and Deploy a Docker Image

Normally CI does this (`.github/workflows/deploy-dev.yml`); these are the manual
equivalents for the first push or for debugging.

1. Select an appropriate, incremental version number (like `v0.0.1`) for the ECR image tag.
2. Build the image (static assets are collected at container start by `entrypoint.sh`,
   so there's no separate asset build step):
   ```
   docker build --platform linux/amd64 --no-cache -f Dockerfile .
   ```
3. Authenticate with ECR: `aws ecr get-login-password --profile myapp-dev --region us-west-2 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com`
4. Tag and push: `AWS_PROFILE=myapp-dev docker push <ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/myapp-dev:VERSION`
5. Terraform apply the changes in the `ecs` directory using the latest version tag.
