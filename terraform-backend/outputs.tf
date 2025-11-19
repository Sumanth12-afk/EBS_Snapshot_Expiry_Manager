output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_lock.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.terraform_lock.arn
}

output "backend_config" {
  description = "Backend configuration for main Terraform"
  value = <<-EOT
    
    Add this to your terraform/backend.tf:
    
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "ebs-snapshot-manager/terraform.tfstate"
        region         = "${var.aws_region}"
        encrypt        = true
        dynamodb_table = "${aws_dynamodb_table.terraform_lock.name}"
      }
    }
  EOT
}

