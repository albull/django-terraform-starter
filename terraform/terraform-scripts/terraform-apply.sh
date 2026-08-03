#!/bin/bash

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
popd > /dev/null

# Secrets are age-encrypted (see ../.sops.yaml); the carlpett/sops provider reads this
# key file to decrypt vars/$TF_ENV-secrets.json at plan/apply time.
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
[ -f "$SOPS_AGE_KEY_FILE" ] || die "No age key at $SOPS_AGE_KEY_FILE — run ../setup-sops.sh"

export AWS_PROFILE=$TF_ENV
export AWS_DEFAULT_REGION=us-west-2

export TF_VAR_state_bucket=$STATE_BUCKET

terraform fmt
terraform apply \
          -var-file=vars/$TF_ENV.tfvars \
          "$@"
