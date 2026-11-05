# Terraform remote state configured with native Amazon S3 object locking (Terraform >= 1.10)
# Update bucket name to match output from terraform/bootstrap/
terraform {
  backend "s3" {
    bucket       = "microservice-tfstate-ap-south-1-REPLACE_ME"
    key          = "dev/terraform.tfstate"
    region       = "ap-south-1"
    encrypt      = true
    use_lockfile = true
  }
}
