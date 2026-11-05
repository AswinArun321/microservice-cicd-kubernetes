variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
  default     = "microservice-eks-dev"
}

variable "cluster_version" {
  type        = string
  description = "Kubernetes control plane version"
  default     = "1.31"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster and nodes are provisioned"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the EKS control plane and managed node group"
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to access the public EKS API endpoint"
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group"
  default     = ["t3.medium"]
}

variable "desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 3
}

variable "admin_principal_arn" {
  type        = string
  description = "ARN of the IAM user or role to grant cluster-admin access entry (leave empty to use caller identity)"
  default     = ""
}

variable "eks_deploy_role_arn" {
  type        = string
  description = "ARN of the GitHub Actions deploy IAM role to grant namespace-scoped access entry"
  default     = ""
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "dev"
}
