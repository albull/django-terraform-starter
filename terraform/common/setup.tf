provider "aws" {}

terraform {
  backend "s3" {
    key     = "common/terraform.tfstate"
    encrypt = true
  }
}
