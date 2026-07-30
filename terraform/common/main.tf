locals {
  module_name = "common"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

# Used for looking up our own account ID
data "aws_caller_identity" "current" {}
