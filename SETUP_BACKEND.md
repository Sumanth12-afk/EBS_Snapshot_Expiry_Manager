# Setup Remote State Backend

## Step-by-Step Guide

### Step 1: Deploy Backend Infrastructure

```bash
cd terraform-backend
terraform init
terraform apply
```

Type `yes` when prompted.

### Step 2: Get Backend Configuration

```bash
terraform output backend_config
```

**Copy the output!** It will look like:

```hcl
terraform {
  backend "s3" {
    bucket         = "ebs-snapshot-manager-tfstate-123456789012"
    key            = "ebs-snapshot-manager/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "ebs-snapshot-manager-tfstate-lock"
  }
}
```

### Step 3: Create Backend Config File

Create `terraform/backend.tf` and paste the output from Step 2.

### Step 4: Migrate State (If Already Deployed)

```bash
cd ../terraform
terraform init -migrate-state
```

Type `yes` to migrate your existing state to S3.

### Step 5: Verify

```bash
# Check S3 bucket
aws s3 ls s3://ebs-snapshot-manager-tfstate-YOUR_ACCOUNT_ID/

# Check DynamoDB table
aws dynamodb describe-table --table-name ebs-snapshot-manager-tfstate-lock --region ap-south-1
```

---

## Quick Commands

```bash
# Deploy backend
cd terraform-backend && terraform init && terraform apply

# Show backend config
cd terraform-backend && terraform output backend_config

# Migrate main terraform
cd terraform && terraform init -migrate-state

# Deploy main infrastructure
cd terraform && terraform apply
```

---

## Destroy Everything

```bash
# 1. Destroy main infrastructure first
cd terraform
terraform destroy

# 2. Then destroy backend infrastructure
cd ../terraform-backend
terraform destroy
```

**Note**: You must destroy the main infrastructure BEFORE destroying the backend, otherwise you'll lose your state file!

---

## Benefits

✅ **Team Collaboration**: Multiple people can work on the same infrastructure  
✅ **State Locking**: Prevents concurrent modifications  
✅ **Versioning**: Can rollback state if needed  
✅ **Backup**: State automatically backed up in S3  
✅ **Encryption**: State encrypted at rest  
✅ **Easy Cleanup**: Destroy everything with Terraform commands

