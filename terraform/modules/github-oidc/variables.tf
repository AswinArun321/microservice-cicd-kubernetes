variable "github_repo" {
  type        = string
  description = "GitHub repository in format owner/repo (e.g. AswinArun321/microservice-cicd-kubernetes)"
  default     = "AswinArun321/microservice-cicd-kubernetes"
}

variable "ecr_repository_arns" {
  type        = list(string)
  description = "List of ECR repository ARNs for push permissions"
  default     = []
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster for deployment permissions"
  default     = "microservice-eks-dev"
}

variable "aws_region" {
  type        = string
  description = "AWS region for cluster ARN construction"
  default     = "ap-south-1"
}

variable "create_oidc_provider" {
  type        = bool
  description = "Whether to create the GitHub Actions OIDC provider (false if already exists in account)"
  default     = true
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "ARN of existing GitHub OIDC provider if create_oidc_provider is false"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "dev"
}
