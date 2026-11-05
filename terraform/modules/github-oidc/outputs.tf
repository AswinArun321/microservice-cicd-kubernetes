output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider"
  value       = local.oidc_provider_arn
}

output "ecr_push_role_arn" {
  description = "ARN of the IAM role used by CI to push images to ECR"
  value       = aws_iam_role.ecr_push.arn
}

output "eks_deploy_role_arn" {
  description = "ARN of the IAM role used by CD to deploy applications to EKS"
  value       = aws_iam_role.eks_deploy.arn
}
