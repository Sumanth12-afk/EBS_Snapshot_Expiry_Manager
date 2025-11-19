# 🚀 Quick Start Guide

## EBS Snapshot Expiry Manager - 5-Minute Setup

Get started with EBS Snapshot Expiry Manager in under 5 minutes!

---

## Prerequisites Checklist

- [ ] AWS Account
- [ ] AWS CLI configured (`aws configure`)
- [ ] Terraform ≥ 1.5.0 installed
- [ ] Gmail account with 2FA enabled
- [ ] 5-10 minutes of your time

---

## Step 1: Gmail App Password (2 minutes)

1. Go to https://myaccount.google.com/apppasswords
2. Create password for "Mail" → "Other (Custom name)"
3. Name it: **EBS Snapshot Manager**
4. Copy the 16-character password

---

## Step 2: Store Password in AWS (1 minute)

```bash
aws secretsmanager create-secret \
  --name ebs/gmail-app-password \
  --secret-string '{"password":"your-16-char-password"}' \
  --region ap-south-1
```

✅ Password stored securely!

---

## Step 3: Configure Terraform (1 minute)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region         = "ap-south-1"
retention_days     = 90
enable_auto_delete = false  # Start safe!
scan_regions       = "ap-south-1"
gmail_user         = "your-email@gmail.com"
alert_receiver     = "your-email@gmail.com"
```

---

## Step 4: Deploy! (2-3 minutes)

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply
```

**Expected Output:**
```
Apply complete! Resources: 12 added, 0 changed, 0 destroyed.

Outputs:
lambda_function_name = "ebs-snapshot-manager-prod"
dynamodb_table_name  = "ebs-snapshot-manager-reports-prod"
eventbridge_schedule = "cron(0 6 * * ? *)"
```

✅ **Deployed successfully!**

---

## Step 5: Test It (30 seconds)

```bash
# Manual test
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --region ap-south-1 \
  response.json

# Check result
cat response.json
```

**Success looks like:**
```json
{
  "statusCode": 200,
  "body": "{\"total_snapshots\": 10, \"old_snapshots_count\": 3, ...}"
}
```

---

## What Happens Next?

### Automated Daily Scans
- Lambda runs daily at **6 AM UTC**
- Scans all your EBS snapshots
- Identifies snapshots older than **90 days**
- Sends you an **email report**

### Your Email Report Will Include:
- 📊 Total snapshots found
- ⏰ Old snapshots count
- 💰 Estimated costs and savings
- 📝 Detailed snapshot listing

### Safety First!
- **Auto-delete is OFF by default**
- No snapshots will be deleted yet
- Review reports for 1-2 weeks first
- Then enable auto-delete if desired

---

## Enable Auto-Delete (When Ready)

After reviewing reports and confirming accuracy:

```hcl
# Edit terraform.tfvars
enable_auto_delete = true
```

```bash
# Apply change
terraform apply
```

⚠️ **Warning**: This will delete snapshots older than retention period!

---

## Common Commands

```bash
# View recent logs
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --follow

# Check DynamoDB records
aws dynamodb scan \
  --table-name ebs-snapshot-manager-reports-prod \
  --max-items 5

# Manual invoke
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  response.json

# View Terraform outputs
cd terraform && terraform output
```

---

## Using the Makefile (Optional)

If you have `make` installed:

```bash
# Deploy everything
make deploy

# View logs
make logs

# Invoke Lambda
make invoke

# Show status
make status

# Clean up
make clean
```

---

## Costs

**Monthly Cost**: ~**$1-2/month**

Breakdown:
- Lambda: $0.10
- DynamoDB: $0.50
- Secrets Manager: $0.40
- CloudWatch Logs: $0.05

**Potential Savings**: $200-500/month (or more!)

---

## Troubleshooting

### Issue: Email not received

**Solution:**
1. Check Gmail App Password is correct
2. Verify email addresses in `terraform.tfvars`
3. Check CloudWatch logs for SMTP errors

```bash
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --since 1h | grep -i "email\|smtp"
```

### Issue: Permission denied errors

**Solution:**
1. Verify AWS CLI has proper permissions
2. Check IAM user has required policies
3. Ensure AWS credentials are configured

```bash
aws sts get-caller-identity
```

### Issue: Terraform errors

**Solution:**
```bash
# Clean and reinitialize
cd terraform
rm -rf .terraform
terraform init
terraform plan
```

---

## Next Steps

1. ✅ **Monitor**: Check your email for first report
2. 📊 **Review**: Examine CloudWatch logs and DynamoDB records
3. ⚙️ **Customize**: Adjust retention period if needed
4. 🔄 **Enable**: Turn on auto-delete when comfortable
5. 🌍 **Expand**: Add more regions to scan

---

## Getting Help

- **Documentation**: See [README.md](README.md)
- **Deployment Guide**: See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
- **Configuration**: See [docs/CONFIGURATION_GUIDE.md](docs/CONFIGURATION_GUIDE.md)
- **Testing**: See [docs/TESTING.md](docs/TESTING.md)
- **Security**: See [SECURITY.md](SECURITY.md)
- **GitHub Issues**: Report problems
- **Email**: support@yourcompany.com

---

## Complete Uninstall

If you want to remove everything:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. All resources will be deleted.

---

## Success Checklist

- [ ] Gmail App Password created and stored in AWS
- [ ] Terraform variables configured
- [ ] Infrastructure deployed successfully
- [ ] Lambda function tested manually
- [ ] Email notification received
- [ ] CloudWatch logs show successful execution
- [ ] DynamoDB records created
- [ ] Scheduled EventBridge rule enabled

---

## You're All Set! 🎉

Your EBS Snapshot Expiry Manager is now:
- ✅ Scanning snapshots daily
- ✅ Tracking costs
- ✅ Sending email reports
- ✅ Ready to optimize your AWS costs

**Estimated Setup Time**: 5 minutes  
**Estimated Monthly Savings**: $200-500+  
**Maintenance Required**: None (fully automated!)

---

<p align="center">
  <strong>Questions? Check the <a href="README.md">README</a> or <a href="https://github.com/your-org/ebs-snapshot-expiry-manager/issues">open an issue</a>!</strong>
</p>

