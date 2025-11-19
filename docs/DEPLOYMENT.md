# 📦 Deployment Guide

## EBS Snapshot Expiry Manager - Complete Deployment Instructions

This guide provides step-by-step instructions for deploying the EBS Snapshot Expiry Manager from scratch.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Architecture Overview](#architecture-overview)
- [Step 1: Prepare AWS Account](#step-1-prepare-aws-account)
- [Step 2: Configure Gmail SMTP](#step-2-configure-gmail-smtp)
- [Step 3: Clone and Configure](#step-3-clone-and-configure)
- [Step 4: Deploy with Terraform](#step-4-deploy-with-terraform)
- [Step 5: Validate Deployment](#step-5-validate-deployment)
- [Step 6: Enable Auto-Delete (Production)](#step-6-enable-auto-delete-production)
- [Step 7: Configure Monitoring](#step-7-configure-monitoring)
- [Troubleshooting](#troubleshooting)
- [Rollback Procedure](#rollback-procedure)

---

## Prerequisites

### Required Tools

- **AWS CLI** ≥ 2.0
- **Terraform** ≥ 1.5.0
- **Python** 3.11+ (for local testing)
- **Git**
- **jq** (optional, for JSON parsing)

### AWS Requirements

- AWS Account with appropriate permissions
- IAM user/role with:
  - EC2 full access (or snapshot-specific permissions)
  - Lambda full access
  - DynamoDB full access
  - IAM role creation
  - EventBridge/CloudWatch Events
  - Secrets Manager access

### Estimated Deployment Time

- **First-time deployment**: 15-20 minutes
- **Subsequent deployments**: 5-10 minutes

---

## Architecture Overview

```
GitHub Repo → Local Clone → Terraform Init → AWS Resources
                                    ↓
                         [Lambda + DynamoDB + EventBridge]
                                    ↓
                            Daily Automation
```

---

## Step 1: Prepare AWS Account

### 1.1 Configure AWS CLI

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: ap-south-1
# Default output format: json
```

Verify configuration:

```bash
aws sts get-caller-identity
```

Expected output:
```json
{
  "UserId": "AIDAEXAMPLE",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### 1.2 Verify IAM Permissions

Test required permissions:

```bash
# Test EC2 permissions
aws ec2 describe-snapshots --owner-ids self --max-results 1

# Test Lambda permissions
aws lambda list-functions --max-items 1

# Test DynamoDB permissions
aws dynamodb list-tables

# Test Secrets Manager permissions
aws secretsmanager list-secrets --max-results 1
```

---

## Step 2: Configure Gmail SMTP

### 2.1 Generate Gmail App Password

1. **Enable 2-Factor Authentication**
   - Go to: https://myaccount.google.com/security
   - Enable 2-Step Verification

2. **Create App Password**
   - Go to: https://myaccount.google.com/apppasswords
   - Select "Mail" and "Other (Custom name)"
   - Name it: "EBS Snapshot Manager"
   - Copy the 16-character password (e.g., `abcd efgh ijkl mnop`)

### 2.2 Store in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name ebs/gmail-app-password \
  --description "Gmail SMTP password for EBS Snapshot Manager" \
  --secret-string '{"password":"YOUR_APP_PASSWORD_HERE"}' \
  --region ap-south-1
```

Verify secret creation:

```bash
aws secretsmanager describe-secret --secret-id ebs/gmail-app-password
```

### 2.3 Test Secret Retrieval

```bash
aws secretsmanager get-secret-value --secret-id ebs/gmail-app-password --query SecretString --output text | jq .
```

---

## Step 3: Clone and Configure

### 3.1 Clone Repository

```bash
cd ~/projects
git clone https://github.com/your-org/ebs-snapshot-expiry-manager.git
cd ebs-snapshot-expiry-manager
```

### 3.2 Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region  = "ap-south-1"
environment = "prod"

# Snapshot Retention Policy
retention_days = 90

# Automation Settings (START WITH FALSE FOR SAFETY)
enable_auto_delete     = false
enable_glacier_archive = false
enable_glacier_vault   = false

# Multi-Region Scanning
scan_regions = "ap-south-1,us-east-1"

# Gmail Configuration
gmail_user                 = "alerts@yourcompany.com"
alert_receiver             = "finops@yourcompany.com"
gmail_password_secret_name = "ebs/gmail-app-password"

# Lambda Configuration
lambda_timeout = 900  # 15 minutes
lambda_memory  = 512  # MB

# Scheduling (Daily at 6 AM UTC)
schedule_expression = "cron(0 6 * * ? *)"
```

### 3.3 Review Lambda Code (Optional)

```bash
cd ../lambda
cat snapshot_manager.py
```

---

## Step 4: Deploy with Terraform

### 4.1 Initialize Terraform

```bash
cd terraform
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### 4.2 Validate Configuration

```bash
terraform validate
```

### 4.3 Plan Deployment

```bash
terraform plan -out=tfplan
```

Review the plan output carefully. Expected resources:
- 1 Lambda function
- 1 IAM role + 4-5 policies
- 1 DynamoDB table
- 1 EventBridge rule
- 1 CloudWatch Log Group
- Lambda permission for EventBridge

### 4.4 Apply Configuration

```bash
terraform apply tfplan
```

Confirm with `yes` when prompted.

Deployment takes approximately 2-3 minutes.

### 4.5 Capture Outputs

```bash
terraform output
```

Save these values:

```
lambda_function_name = "ebs-snapshot-manager-prod"
dynamodb_table_name  = "ebs-snapshot-manager-reports-prod"
eventbridge_schedule = "cron(0 6 * * ? *)"
```

---

## Step 5: Validate Deployment

### 5.1 Verify Lambda Function

```bash
aws lambda get-function --function-name ebs-snapshot-manager-prod
```

### 5.2 Manual Test Invocation

```bash
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --log-type Tail \
  --region ap-south-1 \
  response.json

cat response.json
```

Expected response:
```json
{
  "statusCode": 200,
  "body": "{\"scan_date\": \"2025-11-19T...\", \"total_snapshots\": 10, ...}"
}
```

### 5.3 Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --follow
```

### 5.4 Verify DynamoDB Records

```bash
aws dynamodb scan \
  --table-name ebs-snapshot-manager-reports-prod \
  --max-items 5
```

### 5.5 Check Email Notification

- Verify email received at configured `alert_receiver` address
- Email should contain snapshot summary and cost analysis

---

## Step 6: Enable Auto-Delete (Production)

⚠️ **WARNING**: Only enable after thorough testing in read-only mode.

### 6.1 Review Test Results

- Verify snapshot detection accuracy
- Confirm retention policy is correct
- Review cost estimates

### 6.2 Enable Auto-Delete

Edit `terraform.tfvars`:

```hcl
enable_auto_delete = true
```

### 6.3 Apply Changes

```bash
terraform plan
terraform apply
```

### 6.4 Test Auto-Delete

Manually invoke Lambda:

```bash
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --region ap-south-1 \
  response.json
```

Check logs for deletion confirmations:

```bash
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --since 5m
```

---

## Step 7: Configure Monitoring

### 7.1 Create CloudWatch Alarm for Errors

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name ebs-snapshot-manager-errors \
  --alarm-description "Alert on Lambda function errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=ebs-snapshot-manager-prod \
  --evaluation-periods 1 \
  --treat-missing-data notBreaching
```

### 7.2 Create SNS Topic for Alerts

```bash
aws sns create-topic --name ebs-snapshot-manager-alerts

aws sns subscribe \
  --topic-arn arn:aws:sns:ap-south-1:ACCOUNT_ID:ebs-snapshot-manager-alerts \
  --protocol email \
  --notification-endpoint ops@yourcompany.com
```

### 7.3 Add Alarm Action

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name ebs-snapshot-manager-errors \
  --alarm-actions arn:aws:sns:ap-south-1:ACCOUNT_ID:ebs-snapshot-manager-alerts \
  # ... other parameters from 7.1
```

---

## Troubleshooting

### Issue 1: Terraform Init Fails

**Error**: `Failed to query available provider packages`

**Solution**:
```bash
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
```

### Issue 2: Lambda Timeout

**Error**: `Task timed out after 900.00 seconds`

**Solution**: Increase timeout or reduce scan regions

```hcl
lambda_timeout = 900  # Already at max
scan_regions = "ap-south-1"  # Reduce regions
```

### Issue 3: Permission Denied

**Error**: `AccessDenied` in CloudWatch logs

**Solution**: Verify IAM policies

```bash
aws iam get-role-policy \
  --role-name ebs-snapshot-manager-lambda-role-prod \
  --policy-name ebs-snapshot-manager-ec2-snapshots
```

### Issue 4: Email Not Sending

**Error**: No email received

**Solution**:
1. Verify Gmail App Password in Secrets Manager
2. Check SMTP logs in CloudWatch
3. Test SMTP connectivity

```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/ebs-snapshot-manager-prod \
  --filter-pattern "SMTP"
```

### Issue 5: DynamoDB Throttling

**Error**: `ProvisionedThroughputExceededException`

**Solution**: Already using PAY_PER_REQUEST mode. If issue persists, contact AWS support.

---

## Rollback Procedure

### Complete Rollback

```bash
cd terraform
terraform destroy
```

Confirm with `yes`.

### Partial Rollback (Disable Lambda Only)

```bash
aws lambda update-function-configuration \
  --function-name ebs-snapshot-manager-prod \
  --environment Variables={ENABLED=false}
```

### Disable EventBridge Rule

```bash
aws events disable-rule --name ebs-snapshot-manager-prod-schedule
```

---

## Post-Deployment Checklist

- [ ] Lambda function deployed successfully
- [ ] DynamoDB table created
- [ ] EventBridge rule configured
- [ ] Manual Lambda test completed
- [ ] Email notification received
- [ ] CloudWatch logs populated
- [ ] IAM permissions verified
- [ ] Monitoring alarms configured
- [ ] Documentation updated
- [ ] Team notified of deployment

---

## Next Steps

1. **Monitor First Week**: Check daily email reports
2. **Review Cost Impact**: Monitor AWS Cost Explorer
3. **Adjust Retention**: Modify `retention_days` if needed
4. **Enable Auto-Delete**: After testing period (1-2 weeks)
5. **Expand Regions**: Add more regions to `scan_regions`
6. **Configure Glacier**: Enable archival for compliance

---

## Support

For deployment issues:
- **GitHub Issues**: https://github.com/your-org/ebs-snapshot-expiry-manager/issues
- **Email**: support@yourcompany.com
- **Slack**: #aws-automation

---

## Version History

- **v1.0.0** (2025-11-19): Initial deployment guide

