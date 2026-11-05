variable "repository_names" {
  type        = list(string)
  description = "List of ECR repository names to create"
  default     = ["auth-service", "api-service", "worker-service"]
}

variable "image_tag_mutability" {
  type        = string
  description = "Tag mutability setting for ECR repositories (IMMUTABLE or MUTABLE)"
  default     = "IMMUTABLE"
}

variable "keep_last_image_count" {
  type        = number
  description = "Number of tagged images to keep in lifecycle policy"
  default     = 10
}

variable "environment" {
  type        = string
  description = "Environment identifier"
  default     = "dev"
}
