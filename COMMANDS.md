# Deployment Commands

## Prerequisites Check

```bash
aws --version
terraform --version
python --version
aws sts get-caller-identity
```

## Step 1: Create Gmail App Password Secret

```bash
# Visit: https://myaccount.google.com/apppasswords
# Create app password, then run:

aws secretsmanager create-secret \
  --name ebs/gmail-app-password \
  --secret-string '{"password":"your-16-char-password"}' \
  --region ap-south-1
```

## Step 2: Configure Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

**Edit these values:**
- `gmail_user = "your-email@gmail.com"`
- `alert_receiver = "your-email@gmail.com"`
- `aws_region = "ap-south-1"`
- `enable_auto_delete = false`

## Step 3: Deploy

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## Step 4: Test

```bash
cd ..
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --region ap-south-1 \
  response.json

cat response.json
```

## View Logs

```bash
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --follow --region ap-south-1
```

## Check DynamoDB

```bash
aws dynamodb scan \
  --table-name ebs-snapshot-manager-reports-prod \
  --max-items 5 \
  --region ap-south-1
```

## Enable Auto-Delete (After Testing)

```bash
cd terraform
nano terraform.tfvars
```

Change: `enable_auto_delete = true`

```bash
terraform apply
```

## Cleanup / Destroy

### Option 1: Standard Terraform Destroy

```bash
cd terraform
terraform destroy
```

### Option 2: Cleanup Script (When Terraform Fails)

If `terraform destroy` fails due to S3 state issues or missing state file:

**Windows (PowerShell):**
```bash
.\cleanup-all.ps1
```

**Linux/Mac (Bash):**
```bash
chmod +x cleanup-all.sh
./cleanup-all.sh
```

The cleanup script will:
- Delete Lambda function
- Remove EventBridge rules and targets
- Delete DynamoDB tables (reports + state lock)
- Remove IAM roles and policies
- Delete Gmail secret from Secrets Manager
- Delete CloudWatch Log Groups
- Clean up local Terraform files

---

## Empty S3 Bucket (If Needed)

If the S3 state bucket has versioning and won't delete:

**Windows (PowerShell):**
```bash
.\empty-bucket.ps1
```

**Linux/Mac (Bash):**
```bash
chmod +x empty-bucket.sh
./empty-bucket.sh
```

Then run:
```bash
cd terraform-backend
terraform destroy
```

---

## One-Line Deploy (After terraform.tfvars is configured)

```bash
cd terraform && terraform init && terraform plan && terraform apply && cd .. && aws lambda invoke --function-name ebs-snapshot-manager-prod --region ap-south-1 response.json && cat response.json
```

---

## Quick Commands Reference

```bash
# Invoke Lambda
aws lambda invoke --function-name ebs-snapshot-manager-prod --region ap-south-1 response.json

# View recent logs
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --since 1h --region ap-south-1

# Check Lambda status
aws lambda get-function --function-name ebs-snapshot-manager-prod --region ap-south-1

# View Terraform outputs
cd terraform && terraform output

# Query old snapshots from DynamoDB
aws dynamodb query \
  --table-name ebs-snapshot-manager-reports-prod \
  --index-name RecordTypeIndex \
  --key-condition-expression "RecordType = :type" \
  --expression-attribute-values '{":type":{"S":"SUMMARY"}}' \
  --region ap-south-1

# Verify cleanup completed
aws lambda list-functions --region ap-south-1
aws dynamodb list-tables --region ap-south-1
```

