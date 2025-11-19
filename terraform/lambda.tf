# ============================================================================
# AWS Lambda Function for EBS Snapshot Management
# ============================================================================

resource "aws_lambda_function" "snapshot_manager" {
  filename         = data.archive_file.lambda_package.output_path
  function_name    = local.function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "snapshot_manager.lambda_handler"
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  runtime          = "python3.11"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory

  environment {
    variables = local.lambda_environment_variables
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy.lambda_logging,
    aws_iam_role_policy.ec2_snapshot_operations,
    aws_iam_role_policy.dynamodb_access,
    aws_iam_role_policy.secrets_manager_access
  ]

  tags = {
    Name = "${var.project_name}-lambda"
  }
}

# ============================================================================
# Lambda Function Alias (for versioning)
# ============================================================================

resource "aws_lambda_alias" "snapshot_manager_live" {
  name             = "live"
  description      = "Live version of snapshot manager"
  function_name    = aws_lambda_function.snapshot_manager.arn
  function_version = "$LATEST"
}

