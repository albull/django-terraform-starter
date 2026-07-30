#!/bin/bash

# Helper script for applying all modules in dependency order

if [ $# -eq 0 ]; then
    echo "Requires a terraform workspace name"
    exit 0
fi

apply_module() {
    local module_name=$1
    local workspace=$2

    echo "Applying $module_name"
    pushd ../$module_name > /dev/null
    eval ../terraform-scripts/terraform-init.sh
    eval "terraform workspace select $workspace"
    eval ../terraform-scripts/terraform-apply.sh -auto-approve
    popd > /dev/null
}

apply_module common $1
apply_module network $1
apply_module rds $1
apply_module cache $1
apply_module ecs $1
apply_module resource-groups $1
