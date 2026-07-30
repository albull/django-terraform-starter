# terraform — AWS ECS infrastructure

AWS infrastructure for the Django app in the repository root: VPC, RDS (Postgres),
ElastiCache (Redis), ECR, ECS (Fargate) for the `web` + `jobs` services, and an ALB.

> **Placeholders to replace before applying.** This starter uses `myapp` as the
> project name throughout. Do a project-wide find/replace of `myapp` → your name,
> then fill in the `<ACCOUNT_ID>`, `<GITHUB_ORG>/<GITHUB_REPO>`, `<YOUR_SSO_START_URL>`,
> and `example.com` domain placeholders in `*/vars/*.tfvars` and the READMEs.
> Workspaces are named `myapp-dev` / `myapp-prod`; the shared state profile is
> `myapp-terraform`.

## Development

Requires `terraform` and Mozilla's SOPS for secret management. We use custom terraform scripts wrapping standard commands to set common variables including environment specific configuration. See `terraform-scripts` for details.

## One-Time Global Infrastructure Setup

This is where we will set up our master terraform infrastructure that will host all terraform files. Everything associated with this master state uses the name `myapp-terraform`. This will be shared between infra repos.

1. Set up a master terraform AWS account via AWS Organizations. This is where all infrastructure state associated with this repository will live.

2. Configure your `~/.aws/config` for programmatic access to this account under a profile of the same name:

```
[profile myapp-terraform]
sso_account_id = <myapp-terraform-account-id>
sso_role_name = AdministratorAccess
region = us-west-2
output = json
sso_start_url = <YOUR_SSO_START_URL>
sso_region = us-west-2
sso_registration_scopes = sso:account:access
```

3. Confirm you are able to access this AWS account on the CLI, ie: `aws ecs --region us-west-2 --profile myapp-terraform list-clusters`

4. Perform the one-time terraform backend setup for this repo described in the `terraform-backend` README.

5. Can delete the default VPC/subnets/internet-gateways provided by AWS, if desired.

## One-Time Initial Application Infrastructure Setup

The ECR module only needs to be applied once per application. See the ECR README for an explanation.

## One-Time Initial Application-Environment Infrastructure Setup

This is how we stand up a new application or service using the infrastructure components defined in this repository. Applications are environment-specific and can be identified by the name structure `APPLICATION-ENV-NAME`. For consistency, use standard env suffixes `-dev` and `-prod`.

1. Set up your new AWS account(s) via AWS Organizations using the naming scheme described above. Use IAM Identity center to add the appropriate group(s) and permission set(s) to the account.

2. Configure your `~/.aws/config` for programmatic access, setting up profiles for each account of the same name:

```
[profile APPLICATION-ENV-NAME]
sso_account_id = <APPLICATION-ENV-NAME_ACCOUNT_ID>
sso_role_name = AdministratorAccess
region = us-west-2
output = json
sso_start_url = <YOUR_SSO_START_URL>
sso_region = us-west-2
sso_registration_scopes = sso:account:access

additional profiles...
```

3. Confirm you are able to access these AWS accounts on the CLI, ie: `aws ecs --region us-west-2 --profile APPLICATION-ENV-NAME list-clusters`

4. Add new `.tfvars` and secrets in all modules but `terraform-backend` (initial global config only) and `ecr` (`--dev` only), add new workspaces to each module `terraform workspace new APPLICATION-ENV-NAME`, init, and apply as usual.

## Initial Dev Setup

1. Get the Terraform KMS key UUID from the master terraform AWS account (`myapp-terraform-state` key alias).

2. Initialize your backend state in `terraform-backend` after you grab the key ID from the management console:

```
terraform init \
    --backend-config="bucket=myapp-terraform-state" \
    --backend-config="dynamodb_table=myapp-terraform-state" \
    --backend-config="kms_key_id=UUID_FROM_KMS" 
    --backend-config="profile=myapp-terraform" \
    --backend-config="region=us-west-2"
```

3. `cd` into each module directory and initialize your local state (pull from the remote in s3): `../terraform-scripts/terraform-init.sh`

4. You're all set up! Check out the below Usage section to learn how we create and modify modules.

## Usage

### Writing new modules

As you write new modules, you must initialize the backend state before you can set a non-default workspace. Do this with our custom script: `../terraform-scripts/terraform-init.sh`. You will then have to create new workspaces for each environment this new module should be applied to: `terraform workspace new APPLICATION-ENV-NAME`.

### Modifying existing modules

Apply existing modules individually (execute inside the module's directory):

1. Select the appropriate terraform workspace if not already selected: `terraform workspace select APPLICATION-ENV-NAME`
2. Apply with our custom script: `../terraform-scripts/terraform-apply.sh`.

### Deploying the application manually

See the ECR README for instructions.

### Adding a new SOPS secret

1. Get the KMS secrets key ARN in `../terraform-backend/`: `terraform output sops_kms_key_arn`
2. Initialize the module: `../terraform-scripts/terraform-init.sh`
3. Create `vars/APPLICATION-ENV-NAME-secrets.json`: `sops -k KMS-KEY-HERE --aws-profile myapp-terraform vars/APPLICATION-ENV-NAME-secrets.json`
4. Add the following variables:

```json
{
  "secret_name_here": "SECRET_HERE"
}
```

5. You can generate a new password with something like: `openssl rand -hex 32`.

## Connecting to an ECS container

Requires `jq` and the [Session Manager Plugin for AWS CLI](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html).

1. `aws ecs execute-command --region us-east-2 --profile APPLICATION-ENV-NAME --cluster APPLICATION-ENV-NAME-app --interactive --command "/bin/sh" --task $(aws ecs list-tasks --region us-east-2 --profile APPLICATION-ENV-NAME --cluster APPLICATION-ENV-NAME-app | jq -r ".taskArns | .[0]" | tail -c 33)`

## Helpful Aliases

```bash
alias tf="terraform"
alias tfie="../terraform-scripts/terraform-init.sh"
alias tfae="../terraform-scripts/terraform-apply.sh"
alias tfde="../terraform-scripts/terraform-destroy.sh"
alias tfo="terraform output"
alias tfws="terraform workspace select"
alias tfwsh="terraform workspace show"
alias vac="vim ~/.aws/credentials"
```

## About

Includes the following modules:

- `network`: A VPC within which the app and database are to be run
- `ecs`: Resources for running the webapp container and providing a load balancer endpoint to the application
- `rds`: A PostgreSQL database module
- `ecr`: A module for the Docker repository
- `resource-groups`: A module that defines resource groups for making it easier to find the resources from the AWS console
- `common`: Module for utility resources. Contains a SNS topic for monitoring use.

## Module Dependencies

The modules depend on each other via Terraform remote state, by referencing the output variables. Because of this, the `apply` of each module needs initially to be run in dependency order. Also, when the output value of a module changes, the dependee module needs to be applied for the change to propagate.
