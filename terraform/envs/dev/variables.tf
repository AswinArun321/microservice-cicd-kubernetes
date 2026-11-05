variable "aws_region" {
  type        = string
  description = "AWS region for resources"
  default     = "ap-south-1"
}

variable "environment" {
  type        = string
  description = "Environment identifier (dev/staging/prod)"
  default     = "dev"
}

variable "project_name" {
  type        = string
  description = "Project name"
  default     = "microservice-cicd-kubernetes"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository (owner/repo) for OIDC federation"
  default     = "AswinArun321/microservice-cicd-kubernetes"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public subnet CIDRs (2 AZs required for EKS)"
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to deploy subnets in"
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "enable_nat" {
  type        = bool
  description = "Enable NAT Gateway (set to false for cost-controlled demo mode)"
  default     = false
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes version"
  default     = "1.31"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the worker node group"
  default     = ["t3.medium"]
}

variable "desired_node_count" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks permitted to access the public EKS API endpoint"
  default     = ["0.0.0.0/0"]
}

variable "create_oidc_provider" {
  type        = bool
  description = "Whether to create the GitHub Actions OIDC provider in IAM"
  default     = true
}

variable "existing_oidc_provider_arn" {
  type        = string
  description = "Existing GitHub OIDC Provider ARN if create_oidc_provider is false"
  default     = ""
}

