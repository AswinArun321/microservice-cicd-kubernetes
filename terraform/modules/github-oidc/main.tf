data "aws_caller_identity" "current" {}

# GitHub OIDC Identity Provider
resource "aws_iam_openid_connect_provider" "github" {
  count           = var.create_oidc_provider ? 1 : 0
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f8d7046fe5"]

  tags = {
    Name = "github-actions-oidc"
  }
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.existing_oidc_provider_arn
  eks_cluster_arn   = "arn:aws:eks:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
}

# 1. Role: gha-ecr-push (Used strictly by build-and-push job on default branch)
data "aws_iam_policy_document" "ecr_push_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
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
        "repo:${var.github_repo}:ref:refs/heads/master",
        "repo:${var.github_repo}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "gha-ecr-push-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_assume_role.json
  description        = "Scoped IAM role assumed by GitHub Actions to push container images to ECR"

  tags = {
    Purpose = "CI-ECR-Push"
  }
}

resource "aws_iam_policy" "ecr_push_policy" {
  name        = "gha-ecr-push-policy-${var.environment}"
  description = "Allows GitHub Actions runner to authenticate and push to specific ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushOperations"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = length(var.ecr_repository_arns) > 0 ? var.ecr_repository_arns : ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.ecr_push.name
  policy_arn = aws_iam_policy.ecr_push_policy.arn
}

# 2. Role: gha-eks-deploy (Used strictly by CD deploy job in environment 'dev')
data "aws_iam_policy_document" "eks_deploy_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
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
        "repo:${var.github_repo}:environment:dev",
        "repo:${var.github_repo}:ref:refs/heads/master",
        "repo:${var.github_repo}:ref:refs/heads/main"
      ]
    }
  }
}

resource "aws_iam_role" "eks_deploy" {
  name               = "gha-eks-deploy-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.eks_deploy_assume_role.json
  description        = "Scoped IAM role assumed by GitHub Actions to deploy to EKS namespace"

  tags = {
    Purpose = "CD-EKS-Deploy"
  }
}

resource "aws_iam_policy" "eks_deploy_policy" {
  name        = "gha-eks-deploy-policy-${var.environment}"
  description = "Allows describing EKS cluster; Kubernetes API access is granted via EKS Access Entry"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EKSClusterDescribe"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = local.eks_cluster_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_deploy" {
  role       = aws_iam_role.eks_deploy.name
  policy_arn = aws_iam_policy.eks_deploy_policy.arn
}
