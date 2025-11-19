#!/bin/bash
# Complete Cleanup Script for EBS Snapshot Expiry Manager
# This deletes all AWS resources manually

set -e

region="ap-south-1"

echo ""
echo "========================================"
echo "  EBS Snapshot Manager - Full Cleanup"
echo "========================================"
echo ""

# Lambda Function
echo "[1/9] Deleting Lambda function..."
if aws lambda delete-function --function-name ebs-snapshot-manager-prod --region $region 2>/dev/null; then
    echo "  OK - Lambda function deleted"
else
    echo "  SKIP - Lambda function not found"
fi

# EventBridge Rule Target
echo ""
echo "[2/9] Removing EventBridge rule targets..."
if aws events remove-targets --rule ebs-snapshot-manager-prod-schedule --ids LambdaFunction --region $region 2>/dev/null; then
    echo "  OK - EventBridge targets removed"
else
    echo "  SKIP - EventBridge targets not found"
fi

# EventBridge Rule
echo ""
echo "[3/9] Deleting EventBridge rule..."
if aws events delete-rule --name ebs-snapshot-manager-prod-schedule --region $region 2>/dev/null; then
    echo "  OK - EventBridge rule deleted"
else
    echo "  SKIP - EventBridge rule not found"
fi

# DynamoDB Table
echo ""
echo "[4/9] Deleting DynamoDB table..."
if aws dynamodb delete-table --table-name ebs-snapshot-manager-reports-prod --region $region 2>/dev/null; then
    echo "  OK - DynamoDB table deletion initiated"
else
    echo "  SKIP - DynamoDB table not found"
fi

# CloudWatch Log Group
echo ""
echo "[5/9] Deleting CloudWatch Log Group..."
if aws logs delete-log-group --log-group-name /aws/lambda/ebs-snapshot-manager-prod --region $region 2>/dev/null; then
    echo "  OK - CloudWatch Log Group deleted"
else
    echo "  SKIP - Log Group not found"
fi

# IAM Role Policies
echo ""
echo "[6/9] Deleting IAM role policies..."
policies=(
    "ebs-snapshot-manager-lambda-logging"
    "ebs-snapshot-manager-ec2-snapshots"
    "ebs-snapshot-manager-dynamodb"
    "ebs-snapshot-manager-secrets-manager"
)

for policy in "${policies[@]}"; do
    if aws iam delete-role-policy --role-name ebs-snapshot-manager-lambda-role-prod --policy-name "$policy" 2>/dev/null; then
        echo "  OK - Deleted policy: $policy"
    else
        echo "  SKIP - Policy not found: $policy"
    fi
done

# IAM Role
echo ""
echo "[7/9] Deleting IAM role..."
if aws iam delete-role --role-name ebs-snapshot-manager-lambda-role-prod 2>/dev/null; then
    echo "  OK - IAM role deleted"
else
    echo "  SKIP - IAM role not found"
fi

# Gmail Secret
echo ""
echo "[8/9] Deleting Gmail secret..."
if aws secretsmanager delete-secret --secret-id ebs/gmail-app-password --force-delete-without-recovery --region $region 2>/dev/null; then
    echo "  OK - Secret deleted"
else
    echo "  SKIP - Secret not found"
fi

# DynamoDB State Lock Table
echo ""
echo "[9/9] Deleting DynamoDB state lock table..."
if aws dynamodb delete-table --table-name ebs-snapshot-manager-tfstate-lock --region $region 2>/dev/null; then
    echo "  OK - State lock table deletion initiated"
else
    echo "  SKIP - State lock table not found"
fi

# Clean up local Terraform files
echo ""
echo "[Bonus] Cleaning up local Terraform files..."
if [ -d "terraform/.terraform" ]; then
    rm -rf terraform/.terraform
    echo "  OK - Removed terraform/.terraform"
fi
if [ -f "terraform/.terraform.lock.hcl" ]; then
    rm -f terraform/.terraform.lock.hcl
    echo "  OK - Removed terraform/.terraform.lock.hcl"
fi
if [ -f "terraform/backend.tf" ]; then
    rm -f terraform/backend.tf
    echo "  OK - Removed terraform/backend.tf"
fi
if [ -d "terraform-backend/.terraform" ]; then
    rm -rf terraform-backend/.terraform
    echo "  OK - Removed terraform-backend/.terraform"
fi
if [ -f "terraform-backend/.terraform.lock.hcl" ]; then
    rm -f terraform-backend/.terraform.lock.hcl
    echo "  OK - Removed terraform-backend/.terraform.lock.hcl"
fi

echo ""
echo "========================================"
echo "  CLEANUP COMPLETE!"
echo "========================================"
echo ""

echo "All AWS resources have been deleted."
echo "Note: DynamoDB tables may take 1-2 minutes to fully delete."
echo ""

echo "To verify cleanup, run:"
echo "  aws lambda list-functions --region $region"
echo "  aws dynamodb list-tables --region $region"
echo ""

