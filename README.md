# 🔄 EBS Snapshot Expiry Manager

![AWS](https://img.shields.io/badge/AWS-Lambda-orange) ![Terraform](https://img.shields.io/badge/IaC-Terraform-purple) ![Python](https://img.shields.io/badge/Python-3.11-blue) ![License](https://img.shields.io/badge/License-MIT-green)

> **Enterprise-grade AWS automation for EBS snapshot lifecycle management, cost optimization, and compliance.**

Automate detection, reporting, and cleanup of outdated EBS snapshots to reduce AWS storage costs and maintain compliance with data retention policies.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Features](#key-features)
- [Tech Stack](#tech-stack)
- [Cost Analysis](#cost-analysis)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Security](#security)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## 🎯 Overview

EBS Snapshot Expiry Manager is an AWS-native serverless solution that automatically manages your EBS snapshot lifecycle. It helps organizations:

- **Reduce AWS storage costs** by identifying and removing outdated snapshots
- **Maintain compliance** with data retention policies
- **Automate snapshot lifecycle** with configurable retention periods
- **Gain visibility** into snapshot usage and associated costs
- **Archive critical data** to Glacier Deep Archive (optional)

### Business Value

- **Cost Savings**: Reduce EBS snapshot storage costs by 40-60%
- **Compliance**: Automated enforcement of retention policies
- **Operational Efficiency**: Zero manual intervention required
- **Audit Trail**: Complete DynamoDB audit log of all snapshot operations
- **Multi-Region**: Centralized management across AWS regions

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     EventBridge (CloudWatch Events)              │
│                    Daily Cron: cron(0 6 * * ? *)                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                ┌────────────────────────┐
                │   AWS Lambda (Python)   │
                │  Snapshot Manager       │
                └────────┬───────┬────────┘
                         │       │
        ┌────────────────┘       └────────────────┐
        ▼                                         ▼
┌───────────────┐                         ┌──────────────┐
│  EC2 Service  │                         │  DynamoDB    │
│  (Snapshots)  │                         │  (Reports)   │
└───────┬───────┘                         └──────────────┘
        │
        ├─── Delete Old Snapshots (optional)
        │
        └─── Copy to Glacier (optional)
                     │
                     ▼
           ┌──────────────────┐
           │ Glacier Vault     │
           │ Deep Archive      │
           └──────────────────┘
                     │
                     ▼
            ┌─────────────────┐
            │  Gmail SMTP     │
            │  Notifications  │
            └─────────────────┘
```

### Component Flow

1. **EventBridge** triggers Lambda daily at configured time
2. **Lambda** scans EBS snapshots across specified regions
3. **Processing Logic** calculates age and determines action:
   - Snapshots > retention period → Delete or Archive
   - All snapshots → Log to DynamoDB
4. **DynamoDB** stores complete audit trail with TTL
5. **Gmail SMTP** sends HTML summary report to stakeholders

---

## 💡 Key Features

### Core Capabilities

✅ **Automated Daily Scanning** - Scheduled via EventBridge  
✅ **Multi-Region Support** - Scan snapshots across AWS regions  
✅ **Configurable Retention** - Set custom retention periods (default: 90 days)  
✅ **Auto-Delete Option** - Automatic cleanup of old snapshots  
✅ **Glacier Archival** - Optional long-term storage  
✅ **DynamoDB Audit Log** - Complete tracking with TTL  
✅ **Email Notifications** - Rich HTML reports via Gmail SMTP  
✅ **Cost Estimation** - Calculate potential savings  
✅ **IAM Least Privilege** - Security-first design  
✅ **Terraform IaC** - Infrastructure as Code deployment

### Advanced Features

- **Conditional Archival**: Archive to Glacier before deletion
- **Cost Analytics**: Per-snapshot and aggregate cost reporting
- **Status Tracking**: ACTIVE / ARCHIVED / DELETED states
- **Point-in-Time Recovery**: DynamoDB PITR enabled
- **Encryption**: At-rest encryption for all data stores
- **Multi-Account Ready**: Easily extend for cross-account scenarios

---

## 🛠️ Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| **Runtime** | Python | 3.11 |
| **IaC** | Terraform | ≥ 1.5.0 |
| **Compute** | AWS Lambda | Serverless |
| **Scheduler** | EventBridge | CloudWatch Events |
| **Database** | DynamoDB | On-Demand |
| **Archival** | Glacier Deep Archive | Optional |
| **Notifications** | Gmail SMTP | TLS 1.2+ |
| **SDK** | Boto3 | Latest |
| **CI/CD** | GitHub Actions | Ready |

---

## 💰 Cost Analysis

### Monthly Cost Breakdown (Example: 500 Snapshots)

| Service | Usage | Cost |
|---------|-------|------|
| **Lambda** | 30 invocations/month @ 15 min | $0.10 |
| **DynamoDB** | 15,000 writes, 1 GB storage | $0.50 |
| **EventBridge** | 30 rule invocations | $0.00 |
| **CloudWatch Logs** | 100 MB logs | $0.05 |
| **Glacier** (Optional) | 10 GB archival | $0.10 |
| **Secrets Manager** | 1 secret | $0.40 |
| **Total** | | **$1.15/month** |

### Cost Savings Potential

- **Before**: 500 snapshots × 20 GB avg × $0.05/GB = **$500/month**
- **After Cleanup**: 300 snapshots × 20 GB avg × $0.05/GB = **$300/month**
- **Monthly Savings**: **$200** (40% reduction)
- **Annual Savings**: **$2,400**
- **ROI**: **17,391%** (Savings / Solution Cost)

> **Note**: Actual savings depend on snapshot count, size, and retention policy.

---

## 🚀 Quick Start

### Prerequisites

- AWS Account with appropriate permissions
- Terraform ≥ 1.5.0 installed
- AWS CLI configured
- Gmail account with App Password (for notifications)
- Python 3.11+ (for local testing)

### 1. Clone Repository

```bash
git clone https://github.com/your-org/ebs-snapshot-expiry-manager.git
cd ebs-snapshot-expiry-manager
```

### 2. Configure Gmail App Password

Create a Gmail App Password for SMTP:

1. Go to Google Account → Security → 2-Step Verification → App Passwords
2. Generate password for "Mail" application
3. Store in AWS Secrets Manager:

```bash
aws secretsmanager create-secret \
  --name ebs/gmail-app-password \
  --secret-string '{"password":"your-app-password-here"}' \
  --region ap-south-1
```

### 3. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region         = "ap-south-1"
retention_days     = 90
enable_auto_delete = false  # Start with false for safety
scan_regions       = "ap-south-1,us-east-1"
gmail_user         = "alerts@yourcompany.com"
alert_receiver     = "finops@yourcompany.com"
```

### 4. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 5. Test Manually (Optional)

Invoke Lambda function to test:

```bash
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --region ap-south-1 \
  response.json

cat response.json
```

---

## ⚙️ Configuration

### Environment Variables

Configure via Terraform variables or Lambda environment:

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `RETENTION_DAYS` | Snapshot retention period | 90 | Yes |
| `ENABLE_AUTO_DELETE` | Enable automatic deletion | false | Yes |
| `ENABLE_GLACIER_ARCHIVE` | Enable Glacier archival | false | No |
| `SCAN_REGIONS` | Comma-separated regions | ap-south-1 | Yes |
| `GMAIL_USER` | Gmail sender address | - | For email |
| `ALERT_RECEIVER` | Email recipient | - | For email |
| `GMAIL_PASSWORD_SECRET` | Secrets Manager secret name | ebs/gmail-app-password | For email |
| `EBS_SNAPSHOT_COST_PER_GB` | Cost per GB per month | 0.05 | No |

### Retention Policies

Common retention configurations:

```hcl
# Short-term (30 days) - Development
retention_days = 30

# Standard (90 days) - Production
retention_days = 90

# Long-term (180 days) - Compliance
retention_days = 180

# Extended (365 days) - Regulatory
retention_days = 365
```

### Schedule Configuration

Modify EventBridge schedule in `terraform.tfvars`:

```hcl
# Daily at 6 AM UTC
schedule_expression = "cron(0 6 * * ? *)"

# Every 12 hours
schedule_expression = "rate(12 hours)"

# Weekly on Sunday at midnight
schedule_expression = "cron(0 0 ? * SUN *)"
```

---

## 📦 Deployment

### Standard Deployment

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Outputs

After deployment, Terraform provides:

```
lambda_function_name = "ebs-snapshot-manager-prod"
dynamodb_table_name  = "ebs-snapshot-manager-reports-prod"
eventbridge_schedule = "cron(0 6 * * ? *)"
```

### Enable Auto-Delete (Production)

After testing in read-only mode:

```hcl
# terraform.tfvars
enable_auto_delete = true
```

```bash
terraform apply
```

### Multi-Region Setup

```hcl
scan_regions = "ap-south-1,us-east-1,us-west-2,eu-west-1"
```

### Uninstall / Cleanup

**Option 1: Terraform Destroy (Standard)**

```bash
cd terraform
terraform destroy
```

**Option 2: Cleanup Script (When Terraform Fails)**

If `terraform destroy` fails or you have state file issues:

**Windows:**
```bash
.\cleanup-all.ps1
```

**Linux/Mac:**
```bash
./cleanup-all.sh
```

The script manually deletes all AWS resources and cleans up local files.

---

## 📊 Usage

### Manual Invocation

```bash
aws lambda invoke \
  --function-name ebs-snapshot-manager-prod \
  --log-type Tail \
  --query 'LogResult' \
  --output text | base64 -d
```

### View DynamoDB Reports

```bash
aws dynamodb scan \
  --table-name ebs-snapshot-manager-reports-prod \
  --filter-expression "RecordType = :type" \
  --expression-attribute-values '{":type":{"S":"SUMMARY"}}' \
  --limit 5
```

### Query Old Snapshots

```bash
aws dynamodb query \
  --table-name ebs-snapshot-manager-reports-prod \
  --index-name RecordTypeIndex \
  --key-condition-expression "RecordType = :type" \
  --filter-expression "AgeDays > :age" \
  --expression-attribute-values '{
    ":type":{"S":"SNAPSHOT"},
    ":age":{"N":"90"}
  }'
```

### Check CloudWatch Logs

```bash
aws logs tail /aws/lambda/ebs-snapshot-manager-prod --follow
```

---

## 🔒 Security

See [SECURITY.md](SECURITY.md) for detailed security documentation.

### Key Security Features

✅ **IAM Least Privilege** - Minimal required permissions  
✅ **Secrets Manager** - Encrypted Gmail password storage  
✅ **DynamoDB Encryption** - At-rest encryption enabled  
✅ **VPC Support** - Optional VPC deployment  
✅ **CloudTrail Integration** - Full audit trail  
✅ **Resource Tagging** - Compliance tracking

### IAM Permissions Summary

```json
{
  "EC2": ["DescribeSnapshots", "DeleteSnapshot", "CopySnapshot"],
  "DynamoDB": ["PutItem", "UpdateItem", "Query", "Scan"],
  "SecretsManager": ["GetSecretValue"],
  "Glacier": ["UploadArchive"] // Optional
}
```

---

## 📈 Monitoring

### CloudWatch Metrics

Custom metrics published by Lambda:

- `SnapshotsScanned`
- `SnapshotsDeleted`
- `SnapshotsArchived`
- `EstimatedSavings`

### CloudWatch Alarms

Create alarms for operational monitoring:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name ebs-snapshot-manager-errors \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=FunctionName,Value=ebs-snapshot-manager-prod
```

### Email Reports

Automated HTML email includes:

- Total snapshots scanned
- Old snapshots count
- Deleted/archived breakdown
- Cost analysis and savings
- Detailed snapshot listing

---

## 🐛 Troubleshooting

### Common Issues

#### 1. Lambda Timeout

**Symptom**: Function times out with many snapshots

**Solution**: Increase timeout or reduce scan regions

```hcl
lambda_timeout = 900  # 15 minutes
```

#### 2. Email Not Sending

**Symptom**: No email notifications received

**Solution**:
- Verify Gmail App Password in Secrets Manager
- Check `GMAIL_USER` and `ALERT_RECEIVER` values
- Review CloudWatch logs for SMTP errors

#### 3. Permission Denied Errors

**Symptom**: `AccessDenied` errors in logs

**Solution**:
- Verify IAM role has correct policies
- Check region restrictions in IAM policy

#### 4. DynamoDB Throttling

**Symptom**: `ProvisionedThroughputExceededException`

**Solution**:
- Switch to `PAY_PER_REQUEST` billing mode (default)
- Or increase provisioned capacity

#### 5. Terraform Destroy Issues

**Symptom**: `terraform destroy` fails with S3 bucket errors or state file issues

**Solution**: Use the cleanup script for manual resource deletion

**Windows (PowerShell):**
```bash
.\cleanup-all.ps1
```

**Linux/Mac (Bash):**
```bash
./cleanup-all.sh
```

The cleanup script will:
- Delete Lambda function
- Remove EventBridge rules
- Delete DynamoDB tables
- Remove IAM roles and policies
- Delete Secrets Manager secrets
- Clean up CloudWatch Log Groups
- Remove local Terraform files

**Note**: Use this script when:
- S3 state bucket was deleted before main resources
- State file is corrupted or missing
- `terraform destroy` is failing
- You need a quick complete cleanup

---

## 📚 Additional Documentation

- **[SECURITY.md](SECURITY.md)** - Security best practices and compliance
- **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Detailed deployment guide
- **[docs/CONFIGURATION_GUIDE.md](docs/CONFIGURATION_GUIDE.md)** - Advanced configuration
- **[docs/TESTING.md](docs/TESTING.md)** - Testing and validation procedures

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🏆 AWS Partner Ready

This solution is designed for:

- **AWS Partner Central** submission
- **AWS Service Ready** validation
- **AWS Marketplace** listing (optional)
- **Well-Architected Framework** compliance

### Compliance & Standards

✅ AWS Well-Architected Framework  
✅ Cost Optimization Pillar  
✅ Security Best Practices  
✅ Operational Excellence  
✅ Reliability Standards

---

## 📞 Support

For questions, issues, or feature requests:

- **GitHub Issues**: [Report an issue](https://github.com/your-org/ebs-snapshot-expiry-manager/issues)
- **Email**: support@yourcompany.com
- **Documentation**: [Full Documentation](https://github.com/your-org/ebs-snapshot-expiry-manager/wiki)

---

## 🎓 Resources

- [AWS EBS Snapshots Documentation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSSnapshots.html)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)

---

<p align="center">
  Made with ❤️ for AWS cost optimization and compliance
</p>

<p align="center">
  <a href="#-table-of-contents">Back to Top</a>
</p>

