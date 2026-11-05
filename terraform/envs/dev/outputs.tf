output "aws_region" {
  description = "Configured AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network.public_subnet_ids
}

output "ecr_repository_urls" {
  description = "ECR repository URLs for each microservice"
  value       = module.ecr.repository_urls
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint URL"
  value       = module.eks.cluster_endpoint
}

output "gha_ecr_push_role_arn" {
  description = "IAM role assumed by GitHub Actions for pushing container images"
  value       = module.github_oidc.ecr_push_role_arn
}

output "gha_eks_deploy_role_arn" {
  description = "IAM role assumed by GitHub Actions for deploying manifests to EKS"
  value       = module.github_oidc.eks_deploy_role_arn
}

output "configure_kubectl_command" {
  description = "AWS CLI command to configure local kubeconfig for the cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

