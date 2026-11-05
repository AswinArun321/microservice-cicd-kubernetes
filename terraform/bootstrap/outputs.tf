output "state_bucket_name" {
  description = "Name of the created S3 remote state bucket"
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the remote state bucket"
  value       = aws_s3_bucket.state.arn
}

output "aws_region" {
  description = "Region where the state bucket is deployed"
  value       = var.aws_region
}

