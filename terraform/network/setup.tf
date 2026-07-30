provider "aws" {}

terraform {
  backend "s3" {
    key     = "network/terraform.tfstate"
    encrypt = true
  }
}