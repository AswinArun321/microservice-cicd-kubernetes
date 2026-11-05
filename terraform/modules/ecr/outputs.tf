output "repository_urls" {
  description = "Map of service names to their respective ECR repository URLs"
  value       = { for k, v in aws_ecr_repository.services : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of service names to their repository ARNs"
  value       = { for k, v in aws_ecr_repository.services : k => v.arn }
}

