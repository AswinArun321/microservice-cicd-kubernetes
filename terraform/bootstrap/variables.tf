variable "aws_region" {
  type        = string
  description = "AWS region for the Terraform state S3 bucket"
  default     = "ap-south-1"
}

variable "bucket_name_prefix" {
  type        = string
  description = "Prefix for the state bucket name to ensure global uniqueness"
  default     = "microservice-tfstate"
}

variable "project_name" {
  type        = string
  description = "Project name tag"
  default     = "microservice-cicd-kubernetes"
}
