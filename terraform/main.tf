# ============================================================================
# EBS Snapshot Expiry Manager - Main Terraform Configuration
# ============================================================================

locals {
  function_name = "${var.project_name}-${var.environment}"
  
  lambda_environment_variables = {
    RETENTION_DAYS           = tostring(var.retention_days)
    ENABLE_AUTO_DELETE       = tostring(var.enable_auto_delete)
    ENABLE_GLACIER_ARCHIVE   = tostring(var.enable_glacier_archive)
    SCAN_REGIONS             = var.scan_regions
    DYNAMODB_TABLE_NAME      = aws_dynamodb_table.snapshot_reports.name
    GMAIL_USER               = var.gmail_user
    GMAIL_PASSWORD_SECRET    = var.gmail_password_secret_name
    ALERT_RECEIVER           = var.alert_receiver
    EBS_SNAPSHOT_COST_PER_GB = tostring(var.snapshot_cost_per_gb)
    GLACIER_VAULT_NAME       = var.glacier_vault_name
  }
}

# ============================================================================
# Lambda Function Package
# ============================================================================

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_function.zip"
}

# ============================================================================
# CloudWatch Events (EventBridge) Rule
# ============================================================================

resource "aws_cloudwatch_event_rule" "snapshot_scanner_schedule" {
  name                = "${local.function_name}-schedule"
  description         = "Triggers EBS Snapshot Expiry Manager daily"
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.snapshot_scanner_schedule.name
  target_id = "LambdaFunction"
  arn       = aws_lambda_function.snapshot_manager.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.snapshot_manager.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.snapshot_scanner_schedule.arn
}

# ============================================================================
# CloudWatch Log Group
# ============================================================================

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 30

  tags = {
    Name = "${local.function_name}-logs"
  }
}

# ============================================================================
# Optional: Glacier Vault for Snapshot Archival
# ============================================================================

resource "aws_glacier_vault" "snapshot_archive" {
  count = var.enable_glacier_vault ? 1 : 0

  name = var.glacier_vault_name

  tags = {
    Name = "${var.project_name}-glacier-vault"
  }
}

