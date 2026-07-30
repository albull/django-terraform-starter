provider "aws" {}

terraform {
  backend "s3" {
    key     = "ecs/terraform.tfstate"
    encrypt = true
  }

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0"
    }
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

data "terraform_remote_state" "rds" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "rds/terraform.tfstate"
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

data "terraform_remote_state" "cache" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "cache/terraform.tfstate"
    profile = "myapp-terraform"
  }
}
