output "kms_key_id" {
  value = aws_kms_key.terraform.arn
}

output "dynamodb_table" {
  value = aws_dynamodb_table.terraform.name
}

output "state_bucket" {
  value = aws_s3_bucket.terraform.id
}

# Secrets are encrypted with age (see ../.sops.yaml and ../setup-sops.sh), not KMS,
# so no SOPS key is provisioned here.
