provider "aws" {}

terraform {
  backend "s3" {
    key     = "terraform-backend/terraform.tfstate"
    encrypt = true
  }
}