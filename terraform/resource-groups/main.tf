locals {
  module_name = "resource-groups"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

module "rg_terraform" {
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-terraform"
  tag_key   = "Terraform"
  tag_value = "true"
}

module "rg_module_ecr" {
  count     = var.has_ecr ? 1 : 0
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-ecr"
  tag_key   = "Module"
  tag_value = data.terraform_remote_state.ecr[0].outputs.module_name
}

module "rg_module_ecs" {
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-ecs"
  tag_key   = "Module"
  tag_value = data.terraform_remote_state.ecs.outputs.module_name
}

module "rg_module_network" {
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-network"
  tag_key   = "Module"
  tag_value = data.terraform_remote_state.network.outputs.module_name
}

module "rg_module_rds" {
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-rds"
  tag_key   = "Module"
  tag_value = data.terraform_remote_state.rds.outputs.module_name
}

module "rg_module_common" {
  source    = "./resource-group"
  rg_name   = "${terraform.workspace}-common"
  tag_key   = "Module"
  tag_value = data.terraform_remote_state.common.outputs.module_name
}