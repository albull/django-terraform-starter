provider "aws" {}

terraform {
  backend "s3" {
    key     = "resource-groups/terraform.tfstate"
    encrypt = true
  }
}

# The ECR module is applied once per application (not per env), so its remote
# state only exists for envs where has_ecr is true. Gate the lookup to match.
data "terraform_remote_state" "ecr" {
  count     = var.has_ecr ? 1 : 0
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "ecr/terraform.tfstate"
    profile = "myapp-terraform"
  }
}

data "terraform_remote_state" "rds" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "rds/terraform.tfstate"
    profile = "myapp-terraform"
  }
}

data "terraform_remote_state" "network" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "network/terraform.tfstate"
    profile = "myapp-terraform"
  }
}

data "terraform_remote_state" "common" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "common/terraform.tfstate"
    profile = "myapp-terraform"
  }
}

data "terraform_remote_state" "ecs" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "ecs/terraform.tfstate"
    profile = "myapp-terraform"
  }
}
