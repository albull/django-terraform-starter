locals {
  module_name = "terraform-backend"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

resource "aws_s3_bucket" "terraform" {
  bucket = "myapp-terraform-state"

  force_destroy = true

  tags = merge(local.default_tags, {
    Name = "myapp-terraform-state"
  })
}

resource "aws_s3_bucket_versioning" "terraform" {
  bucket = aws_s3_bucket.terraform.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "version" {
  bucket = aws_s3_bucket.terraform.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "terraform" {
  description         = "Key for encrypting Terraform state files"
  enable_key_rotation = true

  tags = merge(local.default_tags, {
    Name = "terraform-key"
  })
}

resource "aws_kms_alias" "terraform" {
  name          = "alias/myapp-terraform-state"
  target_key_id = aws_kms_key.terraform.key_id
}

resource "aws_s3_bucket_policy" "terraform" {
  bucket = aws_s3_bucket.terraform.id
  policy = jsonencode({
    Version = "2012-10-17"
    Id      = "PutObjPolicy"
    Statement = [
      {
        Sid       = "DenyIncorrectEncryptionHeader"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform.arn}/*"
        Condition = {
          StringNotEquals = {
            "s3:x-amz-server-side-encryption" = "aws:kms"
          }
        }
      },
      {
        Sid       = "DenyUnencryptedObjectUploads"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.terraform.arn}/*"
        Condition = {
          Null = {
            "s3:x-amz-server-side-encryption" = true
          }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_public_access_block" "terraform" {
  bucket = aws_s3_bucket.terraform.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  depends_on = [aws_s3_bucket_policy.terraform]
}

resource "aws_dynamodb_table" "terraform" {
  name = "myapp-terraform-state"

  read_capacity  = 5
  write_capacity = 5

  attribute {
    name = "LockID"
    type = "S"
  }

  hash_key = "LockID"

  tags = merge(local.default_tags, {
    Name = "myapp-terraform-state"
  })
}

resource "aws_kms_key" "sops" {
  description         = "Key for encrypting SOPS files"
  enable_key_rotation = true

  tags = merge(local.default_tags, {
    Name = "terraform-sops"
  })
}

resource "aws_kms_alias" "sops" {
  name          = "alias/myapp-terraform-sops"
  target_key_id = aws_kms_key.sops.key_id
}
