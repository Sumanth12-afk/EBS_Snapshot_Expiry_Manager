# ============================================================================
# Terraform Outputs
# ============================================================================

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.snapshot_manager.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.snapshot_manager.arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.snapshot_reports.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = aws_dynamodb_table.snapshot_reports.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.snapshot_scanner_schedule.name
}

output "eventbridge_schedule" {
  description = "Schedule expression for the EventBridge rule"
  value       = aws_cloudwatch_event_rule.snapshot_scanner_schedule.schedule_expression
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "glacier_vault_name" {
  description = "Name of the Glacier vault (if enabled)"
  value       = var.enable_glacier_vault ? aws_glacier_vault.snapshot_archive[0].name : "Not enabled"
}

output "configuration_summary" {
  description = "Summary of configuration"
  value = {
    retention_days        = var.retention_days
    auto_delete_enabled   = var.enable_auto_delete
    glacier_enabled       = var.enable_glacier_archive
    scan_regions          = var.scan_regions
    schedule              = var.schedule_expression
  }
}

