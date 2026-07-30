#!/usr/bin/bash

die () {
    echo >&2 "$@"
    exit 1
}

TF_ENV=$(terraform workspace show)
echo $TF_ENV | grep -E -q '^defaults' && die "You must select a workspace"
printf "Applying Terraform workspace: %s\n" "$TF_ENV" "\n\n\n"

TERRAFORM_BACKEND_DIR=$(pwd)/../terraform-backend

pushd $TERRAFORM_BACKEND_DIR > /dev/null
STATE_BUCKET=$(terraform output state_bucket | tr -d '"')

# Make KMS key for SOPS available
export SOPS_KMS_ARN=$(terraform output sops_kms_key_arn | tr -d '"')
popd > /dev/null

export AWS_PROFILE=$TF_ENV
export AWS_DEFAULT_REGION=us-west-2

export TF_VAR_state_bucket=$STATE_BUCKET

terraform fmt
terraform destroy \
          -var-file=vars/$TF_ENV.tfvars \
          "$@"
