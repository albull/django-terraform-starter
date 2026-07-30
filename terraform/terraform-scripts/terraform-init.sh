#!/bin/bash

TERRAFORM_BACKEND_DIR=$(pwd)/../terraform-backend

# Bucket for storing state files, DynamoDB table for protecting concurrent state file modifications and
# KMS key arn for encrypting state file at rest
pushd $TERRAFORM_BACKEND_DIR > /dev/null
STATE_BUCKET=$(terraform output state_bucket | tr -d '"')
DYNAMODB_TABLE=$(terraform output dynamodb_table | tr -d '"')
KMS_KEY_ID=$(terraform output sops_kms_key_id | tr -d '"')
popd > /dev/null

terraform fmt

terraform init \
          -backend-config="bucket=$STATE_BUCKET" \
          -backend-config="dynamodb_table=$DYNAMODB_TABLE" \
          -backend-config="region=us-west-2" \
          -backend-config="kms_key_id=$KMS_KEY_ID" \
          -backend-config="profile=myapp-terraform" \
          "$@"