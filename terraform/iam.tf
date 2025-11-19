# ============================================================================
# IAM Role and Policies for Lambda Function
# ============================================================================

# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-role"
  }
}

# Policy for CloudWatch Logs
resource "aws_iam_role_policy" "lambda_logging" {
  name = "${var.project_name}-lambda-logging"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Policy for EC2 Snapshot Operations
resource "aws_iam_role_policy" "ec2_snapshot_operations" {
  name = "${var.project_name}-ec2-snapshots"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DescribeSnapshots"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSnapshots",
          "ec2:DescribeVolumes",
          "ec2:DescribeTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "ManageSnapshots"
        Effect = "Allow"
        Action = [
          "ec2:DeleteSnapshot",
          "ec2:CopySnapshot",
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*:*:snapshot/*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = split(",", var.scan_regions)
          }
        }
      }
    ]
  })
}

# Policy for DynamoDB Access
resource "aws_iam_role_policy" "dynamodb_access" {
  name = "${var.project_name}-dynamodb"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:GetItem"
        ]
        Resource = aws_dynamodb_table.snapshot_reports.arn
      }
    ]
  })
}

# Policy for Secrets Manager (Gmail Password)
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "${var.project_name}-secrets-manager"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:${var.gmail_password_secret_name}*"
      }
    ]
  })
}

# Policy for Glacier Operations (Optional)
resource "aws_iam_role_policy" "glacier_access" {
  count = var.enable_glacier_archive ? 1 : 0

  name = "${var.project_name}-glacier"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "glacier:UploadArchive",
          "glacier:InitiateJob",
          "glacier:DescribeJob",
          "glacier:GetJobOutput"
        ]
        Resource = "arn:aws:glacier:${var.aws_region}:*:vaults/${var.glacier_vault_name}"
      }
    ]
  })
}

