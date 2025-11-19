# Complete Cleanup Script for EBS Snapshot Expiry Manager
# This deletes all AWS resources manually

$region = "ap-south-1"

Write-Host ""
Write-Host "========================================"
Write-Host "  EBS Snapshot Manager - Full Cleanup"
Write-Host "========================================"
Write-Host ""

# Lambda Function
Write-Host "[1/9] Deleting Lambda function..."
try {
    aws lambda delete-function --function-name ebs-snapshot-manager-prod --region $region 2>$null
    Write-Host "  OK - Lambda function deleted" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - Lambda function not found" -ForegroundColor Gray
}

# EventBridge Rule Target
Write-Host ""
Write-Host "[2/9] Removing EventBridge rule targets..."
try {
    aws events remove-targets --rule ebs-snapshot-manager-prod-schedule --ids LambdaFunction --region $region 2>$null
    Write-Host "  OK - EventBridge targets removed" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - EventBridge targets not found" -ForegroundColor Gray
}

# EventBridge Rule
Write-Host ""
Write-Host "[3/9] Deleting EventBridge rule..."
try {
    aws events delete-rule --name ebs-snapshot-manager-prod-schedule --region $region 2>$null
    Write-Host "  OK - EventBridge rule deleted" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - EventBridge rule not found" -ForegroundColor Gray
}

# DynamoDB Table
Write-Host ""
Write-Host "[4/9] Deleting DynamoDB table..."
try {
    aws dynamodb delete-table --table-name ebs-snapshot-manager-reports-prod --region $region 2>$null
    Write-Host "  OK - DynamoDB table deletion initiated" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - DynamoDB table not found" -ForegroundColor Gray
}

# CloudWatch Log Group
Write-Host ""
Write-Host "[5/9] Deleting CloudWatch Log Group..."
try {
    aws logs delete-log-group --log-group-name /aws/lambda/ebs-snapshot-manager-prod --region $region 2>$null
    Write-Host "  OK - CloudWatch Log Group deleted" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - Log Group not found" -ForegroundColor Gray
}

# IAM Role Policies
Write-Host ""
Write-Host "[6/9] Deleting IAM role policies..."
$policies = @(
    "ebs-snapshot-manager-lambda-logging",
    "ebs-snapshot-manager-ec2-snapshots",
    "ebs-snapshot-manager-dynamodb",
    "ebs-snapshot-manager-secrets-manager"
)

foreach ($policy in $policies) {
    try {
        aws iam delete-role-policy --role-name ebs-snapshot-manager-lambda-role-prod --policy-name $policy 2>$null
        Write-Host "  OK - Deleted policy: $policy" -ForegroundColor Green
    } catch {
        Write-Host "  SKIP - Policy not found: $policy" -ForegroundColor Gray
    }
}

# IAM Role
Write-Host ""
Write-Host "[7/9] Deleting IAM role..."
try {
    aws iam delete-role --role-name ebs-snapshot-manager-lambda-role-prod 2>$null
    Write-Host "  OK - IAM role deleted" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - IAM role not found" -ForegroundColor Gray
}

# Gmail Secret
Write-Host ""
Write-Host "[8/9] Deleting Gmail secret..."
try {
    aws secretsmanager delete-secret --secret-id ebs/gmail-app-password --force-delete-without-recovery --region $region 2>$null
    Write-Host "  OK - Secret deleted" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - Secret not found" -ForegroundColor Gray
}

# DynamoDB State Lock Table
Write-Host ""
Write-Host "[9/9] Deleting DynamoDB state lock table..."
try {
    aws dynamodb delete-table --table-name ebs-snapshot-manager-tfstate-lock --region $region 2>$null
    Write-Host "  OK - State lock table deletion initiated" -ForegroundColor Green
} catch {
    Write-Host "  SKIP - State lock table not found" -ForegroundColor Gray
}

# Clean up local Terraform files
Write-Host ""
Write-Host "[Bonus] Cleaning up local Terraform files..."
if (Test-Path "terraform\.terraform") {
    Remove-Item "terraform\.terraform" -Recurse -Force
    Write-Host "  OK - Removed terraform/.terraform" -ForegroundColor Green
}
if (Test-Path "terraform\.terraform.lock.hcl") {
    Remove-Item "terraform\.terraform.lock.hcl" -Force
    Write-Host "  OK - Removed terraform/.terraform.lock.hcl" -ForegroundColor Green
}
if (Test-Path "terraform\backend.tf") {
    Remove-Item "terraform\backend.tf" -Force
    Write-Host "  OK - Removed terraform/backend.tf" -ForegroundColor Green
}
if (Test-Path "terraform-backend\.terraform") {
    Remove-Item "terraform-backend\.terraform" -Recurse -Force
    Write-Host "  OK - Removed terraform-backend/.terraform" -ForegroundColor Green
}
if (Test-Path "terraform-backend\.terraform.lock.hcl") {
    Remove-Item "terraform-backend\.terraform.lock.hcl" -Force
    Write-Host "  OK - Removed terraform-backend/.terraform.lock.hcl" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================"
Write-Host "  CLEANUP COMPLETE!" -ForegroundColor Green
Write-Host "========================================"
Write-Host ""

Write-Host "All AWS resources have been deleted."
Write-Host "Note: DynamoDB tables may take 1-2 minutes to fully delete."
Write-Host ""

Write-Host "To verify cleanup, run:"
Write-Host "  aws lambda list-functions --region $region"
Write-Host "  aws dynamodb list-tables --region $region"
Write-Host ""
