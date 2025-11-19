variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ebs-snapshot-manager"
}

variable "retention_days" {
  description = "Number of days to retain EBS snapshots"
  type        = number
  default     = 90
}

variable "enable_auto_delete" {
  description = "Enable automatic deletion of old snapshots"
  type        = bool
  default     = false
}

variable "enable_glacier_archive" {
  description = "Enable archiving to Glacier Deep Archive"
  type        = bool
  default     = false
}

variable "scan_regions" {
  description = "Comma-separated list of AWS regions to scan"
  type        = string
  default     = "ap-south-1"
}

variable "gmail_user" {
  description = "Gmail address for sending alerts"
  type        = string
  default     = ""
}

variable "alert_receiver" {
  description = "Email address to receive alerts"
  type        = string
  default     = ""
}

variable "gmail_password_secret_name" {
  description = "AWS Secrets Manager secret name for Gmail app password"
  type        = string
  default     = "ebs/gmail-app-password"
}

variable "schedule_expression" {
  description = "CloudWatch Events schedule expression (cron or rate)"
  type        = string
  default     = "cron(0 6 * * ? *)"  # Daily at 6 AM UTC
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 900  # 15 minutes
}

variable "lambda_memory" {
  description = "Lambda function memory in MB"
  type        = number
  default     = 512
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "snapshot_cost_per_gb" {
  description = "EBS snapshot cost per GB per month in USD"
  type        = number
  default     = 0.05
}

variable "glacier_vault_name" {
  description = "Glacier vault name for snapshot archival"
  type        = string
  default     = "ebs-snapshot-archive"
}

variable "enable_glacier_vault" {
  description = "Create Glacier vault for archival"
  type        = bool
  default     = false
}

