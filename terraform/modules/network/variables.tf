variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets (minimum 2 AZs for EKS)"
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets (used when enable_private_subnets is true)"
  default     = ["10.20.10.0/24", "10.20.20.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "List of availability zones in the region"
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster for resource discovery tags"
  default     = "microservice-eks-dev"
}

variable "enable_nat" {
  type        = bool
  description = "Whether to provision a NAT Gateway (set to false for cost-controlled demo mode)"
  default     = false
}

variable "enable_private_subnets" {
  type        = bool
  description = "Whether to provision private subnets (set to false for demo mode)"
  default     = false
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "dev"
}

