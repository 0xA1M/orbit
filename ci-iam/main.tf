# account id and region, read from the caller, never hardcoded in tracked files
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# trust: only this repo's workflows may assume the role, via GitHub OIDC
data "aws_iam_policy_document" "github_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_oidc.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/*",
        "repo:${var.github_org}/${var.github_repo}:environment:*",
      ]
    }
  }
}

# OIDC handshake endpoint: GitHub mints the tokens, AWS trusts this URL
resource "aws_iam_openid_connect_provider" "github_oidc" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  tags = var.tags
}

# the single role every workflow assumes; permissions come from the attachments below
resource "aws_iam_role" "orbit_ci_role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.github_trust.json

  tags = var.tags
}

# push + pull orbit/* images; GetAuthorizationToken takes no resource scope
# so it stays "*" while the rest is scoped to our repos
resource "aws_iam_policy" "orbit_ci_ecr" {
  name        = "orbit-ci-ecr"
  description = "Push and pull orbit/* images for CI"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:repository/orbit/*"
      },
    ]
  })

  tags = var.tags
}

# force-new-deployment updates plus status reads; no task-def writes here,
# those stay in Terraform
resource "aws_iam_policy" "orbit_ci_ecs" {
  name        = "orbit-ci-ecs"
  description = "Redeploy and describe orbit ECS services for CI"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTasks",
          "ecs:ListServices",
        ]
        Resource = [
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:cluster/orbit-*",
          "arn:aws:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/orbit-ecs-cluster/*",
        ]
      },
    ]
  })

  tags = var.tags
}

# deliberately broad except IAM, which is scoped to orbit roles only
resource "aws_iam_policy" "orbit_ci_tofu" {
  name        = "orbit-ci-tofu"
  description = "Full lifecycle of the orbit stack for CI applies and destroys"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "State"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket}",
          "arn:aws:s3:::${var.state_bucket}/orbit/*",
        ]
      },
      {
        Sid    = "Infra"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "acm:*",
          "ecr:*",
          "ecs:*",
          "logs:*",
          "servicediscovery:*",
          "sns:*",
          "cloudwatch:*",
          "sts:GetCallerIdentity",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMScoped"
        Effect = "Allow"
        Action = [
          "iam:*"
        ]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/orbit-*",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/*-execution",
        ]
      },
    ]
  })

  tags = var.tags
}

# one attachment per policy so a set can detach independently
resource "aws_iam_role_policy_attachment" "orbit_ci_ecr" {
  role       = aws_iam_role.orbit_ci_role.name
  policy_arn = aws_iam_policy.orbit_ci_ecr.arn
}

resource "aws_iam_role_policy_attachment" "orbit_ci_ecs" {
  role       = aws_iam_role.orbit_ci_role.name
  policy_arn = aws_iam_policy.orbit_ci_ecs.arn
}

resource "aws_iam_role_policy_attachment" "orbit_ci_tofu" {
  role       = aws_iam_role.orbit_ci_role.name
  policy_arn = aws_iam_policy.orbit_ci_tofu.arn
}
