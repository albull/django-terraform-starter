# Github OpenID Connect Provider
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd", "7560D6F40FA55195F740EE2B1B7C0B4836CBE103"]

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-github-oidc-provider"
  })
}

# CI/CD deploy role with attached policy for Github OIDC access
resource "aws_iam_role" "ecs-deploy-role" {
  name = "${terraform.workspace}-ecs-deploy-role"
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
            "token.actions.githubusercontent.com:sub" = [
              "repo:${var.repo}:ref:refs/heads/*",
              "repo:${var.repo}:ref:refs/tags/*",
              "repo:${var.repo}:pull_request",
              "repo:${var.repo}:environment:*"
            ]
          }
        }
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-deploy-role"
  })

}

resource "aws_iam_policy" "ecs-deploy" {
  name        = "${terraform.workspace}-ecs-deploy"
  description = "Allows access to ECS for deploys"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
        ]
        Resource = [
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:service/${terraform.workspace}-web/${terraform.workspace}-web",
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:service/${terraform.workspace}-jobs/${terraform.workspace}-jobs"
        ]
      },
      {
        Sid    = "EcsTasks"
        Effect = "Allow"
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = "*"
      },
      {
        Sid    = "EcsTaskExecutionRole"
        Effect = "Allow"
        Action = [
          "iam:PassRole",
        ]
        Resource = [
          aws_iam_role.app-task-execution.arn,
          aws_iam_role.app-task.arn
        ]
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-deploy"
  })
}

# CI/CD trust relationship policy attachment
resource "aws_iam_role_policy_attachment" "ecs-deploy-policy-attachment" {
  role       = aws_iam_role.ecs-deploy-role.name
  policy_arn = aws_iam_policy.ecs-deploy.arn
}

# Additional permissions needed for GitHub Actions workflows
resource "aws_iam_policy" "ecs-deploy-additional" {
  name        = "${terraform.workspace}-ecs-deploy-additional"
  description = "Additional permissions for ECS deploys with migrations"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRPermissions"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:us-west-2:${data.aws_caller_identity.current.account_id}:repository/${terraform.workspace}",
          "*"
        ]
      },
      {
        Sid    = "ECSTasksAndClusters"
        Effect = "Allow"
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:DescribeClusters",
          "ecs:ListTasks",
          "ecs:StopTask"
        ]
        Resource = [
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:cluster/${terraform.workspace}-web",
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:cluster/${terraform.workspace}-jobs",
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:task/*",
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:task-definition/${terraform.workspace}-web:*",
          "arn:aws:ecs:us-west-2:${data.aws_caller_identity.current.account_id}:task-definition/${terraform.workspace}-jobs:*"
        ]
      },
      {
        Sid    = "LogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:us-west-2:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${terraform.workspace}:*"
        ]
      }
    ]
  })

  tags = merge(local.default_tags, {
    Name = "${terraform.workspace}-ecs-deploy-additional"
  })
}

# Attach the additional policy to the existing role
resource "aws_iam_role_policy_attachment" "ecs-deploy-additional-policy-attachment" {
  role       = aws_iam_role.ecs-deploy-role.name
  policy_arn = aws_iam_policy.ecs-deploy-additional.arn
}
