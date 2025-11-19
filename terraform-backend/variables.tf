variable "aws_region" {
  description = "AWS region for backend resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ebs-snapshot-manager"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

