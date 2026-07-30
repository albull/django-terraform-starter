# terraform-backend

Module for creating resources for Terraform backend state with Terraform. State is stored in S3, with concurrent operations prevented by a lock in DynamoDB table.

## One-Time Global Infrastructure Setup

Performed once globally. Shared backend for all envs (that's how workspaces work). Set up terraform's own state tracking infrastructure:

1.  Temporarily comment out the terraform backend definition in `setup.tf` to create the bucket this definition will reference.
2.  Create the infrastructure:

    ```bash
    terraform init
    AWS_PROFILE=myapp-terraform terraform apply
    ```

3.  Uncomment the commented-out backend definition in `setup.tf`.
4.  Get the Terraform KMS key UUID from the master terraform AWS account (`myapp-terraform-state` key alias).
5.  Re-initialize the local terraform state to point to the remote state you just set up:

    ```bash
    terraform init \
        -backend-config="bucket=myapp-terraform-state" \
        -backend-config="dynamodb_table=myapp-terraform-state" \
        -backend-config="kms_key_id=UUID_FROM_PREVIOUS_STEP" \
        -backend-config="profile=myapp-terraform" \
        -backend-config="region=us-west-2"
    ```
