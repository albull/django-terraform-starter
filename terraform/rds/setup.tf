provider "aws" {}

terraform {
  backend "s3" {
    key     = "rds/terraform.tfstate"
    encrypt = true
  }

  required_providers {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.0.0"
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

data "terraform_remote_state" "common" {
  backend   = "s3"
  workspace = terraform.workspace
  config = {
    bucket  = var.state_bucket
    key     = "common/terraform.tfstate"
    profile = "myapp-terraform"
  }
}
