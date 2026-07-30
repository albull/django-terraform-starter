locals {
  module_name = "ecr"
  default_tags = {
    Workspace = terraform.workspace
    Module    = local.module_name
    Terraform = "true"
  }
}

resource "aws_ecr_repository" "app" {
  name                 = terraform.workspace
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app"
  })
}

resource "aws_ecr_repository" "test" {
  name                 = "test"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-app-test"
  })
}

resource "aws_ecr_registry_scanning_configuration" "app" {
  scan_type = "BASIC"
  rule {
    scan_frequency = "SCAN_ON_PUSH"
    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        action = {
          type = "expire"
        }
        selection = {
          countType     = "imageCountMoreThan"
          countNumber   = 10
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "test" {
  repository = aws_ecr_repository.test.name
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 images"
        action = {
          type = "expire"
        }
        selection = {
          countType     = "imageCountMoreThan"
          countNumber   = 10
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
        }
      }
    ]
  })
}

resource "aws_ecr_repository_policy" "access_policy" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    Id = "RepositoryAccessPolicy"
    Statement = [{
      Action = [
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeRegistry",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages",
        "ecr:ListTagsForResource",
        "ecr:PutImage"
      ]
      Effect = "Allow"
      Principal = {
        AWS = var.access_accounts
      }
      Sid = "AllowApplicationAccessAccountsAccess"
    }]
    Version = "2012-10-17"
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecr-builder-role" {
  name = "${terraform.workspace}-ecr-builder-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GithubOIDC"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.repo}:*"
          }
        }
      }
    ],
    Version = "2012-10-17"
  })
  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecr-builder-role"
  })
}

resource "aws_iam_policy" "ecr-builder" {
  name        = "${terraform.workspace}-ecr-builder"
  description = "Policy for the ECR builder"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EcrAuth"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "EcrReadWrite"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeImages",
          "ecr:UploadLayerPart",
          "ecr:ListImages",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ]
        Resource = [
          aws_ecr_repository.app.arn,
          aws_ecr_repository.test.arn
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "ecr-builder-policy-attachment" {
  role       = aws_iam_role.ecr-builder-role.name
  policy_arn = aws_iam_policy.ecr-builder.arn
}
