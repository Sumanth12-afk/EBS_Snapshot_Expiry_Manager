# 🔒 Security Documentation

## EBS Snapshot Expiry Manager - Security Guide

This document outlines the security architecture, best practices, and compliance considerations for the EBS Snapshot Expiry Manager.

---

## Table of Contents

- [Security Architecture](#security-architecture)
- [IAM Least Privilege](#iam-least-privilege)
- [Data Protection](#data-protection)
- [Network Security](#network-security)
- [Secrets Management](#secrets-management)
- [Audit & Compliance](#audit--compliance)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)

---

## Security Architecture

### Defense in Depth

The solution implements multiple layers of security:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: IAM Least Privilege (Role-Based Access)           │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Secrets Manager (Encrypted Credential Storage)    │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: DynamoDB Encryption at Rest (SSE)                 │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: CloudWatch Logs (Audit Trail)                     │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: VPC Integration (Optional Network Isolation)      │
└─────────────────────────────────────────────────────────────┘
```

### Security Principles

1. **Least Privilege**: Minimal permissions required for operation
2. **Defense in Depth**: Multiple security layers
3. **Encryption**: Data encrypted at rest and in transit
4. **Audit Trail**: Complete logging of all operations
5. **Secrets Protection**: No hardcoded credentials

---

## IAM Least Privilege

### Lambda Execution Role

The Lambda function operates with the minimum required permissions:

#### EC2 Snapshot Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DescribeSnapshots",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ManageSnapshots",
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot",
        "ec2:CopySnapshot",
        "ec2:CreateTags"
      ],
      "Resource": "arn:aws:ec2:*:*:snapshot/*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": ["ap-south-1", "us-east-1"]
        }
      }
    }
  ]
}
```

**Security Notes:**
- `DescribeSnapshots` requires `Resource: "*"` (AWS limitation)
- Delete operations restricted to specific regions
- No permission to create snapshots
- No permission to modify volumes

#### DynamoDB Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:GetItem"
      ],
      "Resource": "arn:aws:dynamodb:REGION:ACCOUNT:table/ebs-snapshot-manager-reports-prod"
    }
  ]
}
```

**Security Notes:**
- Scoped to specific table only
- No permission to delete items
- No permission to modify table structure
- No cross-account access

#### Secrets Manager Permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["secretsmanager:GetSecretValue"],
      "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT:secret:ebs/gmail-app-password*"
    }
  ]
}
```

**Security Notes:**
- Read-only access
- Scoped to specific secret name pattern
- No permission to modify or delete secrets
- Region-scoped

#### Glacier Permissions (Optional)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "glacier:UploadArchive",
        "glacier:InitiateJob",
        "glacier:DescribeJob",
        "glacier:GetJobOutput"
      ],
      "Resource": "arn:aws:glacier:REGION:ACCOUNT:vaults/ebs-snapshot-archive"
    }
  ]
}
```

**Security Notes:**
- Scoped to specific vault
- No permission to delete archives
- No permission to modify vault policies

### Trust Relationship

Lambda execution role trusts only the Lambda service:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

## Data Protection

### Encryption at Rest

#### DynamoDB

- **Encryption**: AWS-managed KMS keys (default)
- **Upgrade Option**: Customer-managed CMK for additional control
- **Point-in-Time Recovery**: Enabled for data resilience

```hcl
resource "aws_dynamodb_table" "snapshot_reports" {
  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn  # Optional: use customer-managed key
  }
  
  point_in_time_recovery {
    enabled = true
  }
}
```

#### AWS Secrets Manager

- **Encryption**: Automatic encryption with AWS-managed keys
- **Rotation**: Configure automatic rotation (recommended)
- **Access Logging**: CloudTrail logs all secret access

```bash
# Enable automatic rotation (30 days)
aws secretsmanager rotate-secret \
  --secret-id ebs/gmail-app-password \
  --rotation-lambda-arn arn:aws:lambda:REGION:ACCOUNT:function:rotation-function
```

#### Glacier Deep Archive

- **Encryption**: AES-256 encryption by default
- **Compliance**: HIPAA, PCI-DSS, SOC compliant
- **Vault Lock**: Optional compliance lock for immutability

### Encryption in Transit

- **Gmail SMTP**: TLS 1.2+ required
- **AWS APIs**: HTTPS/TLS 1.2+ for all AWS service calls
- **Secrets Manager**: TLS encryption for secret retrieval

### Data Retention & TTL

```python
# DynamoDB TTL Configuration
ttl_snapshot = 30 days   # Snapshot records
ttl_summary  = 90 days   # Summary reports
```

**Purpose**: Automatic data expiration for compliance

---

## Network Security

### VPC Integration (Optional)

Deploy Lambda in VPC for additional network isolation:

```hcl
resource "aws_lambda_function" "snapshot_manager" {
  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }
}

resource "aws_security_group" "lambda_sg" {
  name        = "ebs-snapshot-manager-lambda-sg"
  description = "Security group for EBS Snapshot Manager Lambda"
  vpc_id      = var.vpc_id

  # Egress to AWS services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS to AWS APIs"
  }

  # Egress for Gmail SMTP
  egress {
    from_port   = 587
    to_port     = 587
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SMTP to Gmail"
  }
}
```

### VPC Endpoints (Cost Optimization + Security)

Use VPC endpoints to avoid internet gateway:

```hcl
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = var.vpc_id
  service_name    = "com.amazonaws.${var.aws_region}.dynamodb"
  route_table_ids = var.route_table_ids
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = var.private_subnet_ids
}
```

---

## Secrets Management

### Gmail App Password Storage

#### Step 1: Generate Gmail App Password

1. Enable 2-Factor Authentication on Gmail
2. Go to: Google Account → Security → 2-Step Verification → App Passwords
3. Generate new app password for "Mail"

#### Step 2: Store in AWS Secrets Manager

```bash
aws secretsmanager create-secret \
  --name ebs/gmail-app-password \
  --description "Gmail SMTP password for EBS Snapshot Manager" \
  --secret-string '{"password":"abcd efgh ijkl mnop"}' \
  --region ap-south-1 \
  --kms-key-id alias/aws/secretsmanager
```

#### Step 3: Configure Automatic Rotation (Recommended)

```bash
aws secretsmanager rotate-secret \
  --secret-id ebs/gmail-app-password \
  --rotation-lambda-arn arn:aws:lambda:REGION:ACCOUNT:function:gmail-rotation \
  --rotation-rules AutomaticallyAfterDays=30
```

### Best Practices

✅ **Never hardcode credentials** in code or Terraform  
✅ **Use Secrets Manager** for all sensitive data  
✅ **Enable automatic rotation** where possible  
✅ **Audit secret access** via CloudTrail  
✅ **Use resource policies** to restrict access  
✅ **Tag secrets** for governance and cost tracking

---

## Audit & Compliance

### CloudTrail Integration

Enable CloudTrail logging for full audit trail:

```hcl
resource "aws_cloudtrail" "snapshot_manager_trail" {
  name                          = "ebs-snapshot-manager-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::Lambda::Function"
      values = [aws_lambda_function.snapshot_manager.arn]
    }

    data_resource {
      type   = "AWS::DynamoDB::Table"
      values = [aws_dynamodb_table.snapshot_reports.arn]
    }
  }
}
```

### CloudWatch Logs Insights

Query Lambda execution logs:

```sql
fields @timestamp, @message
| filter @message like /DELETED/ or @message like /ARCHIVED/
| sort @timestamp desc
| limit 100
```

### DynamoDB Audit Log

All snapshot operations logged with:

- Snapshot ID
- Action taken (ACTIVE/DELETED/ARCHIVED)
- Timestamp
- Region
- Cost impact

### Compliance Standards

This solution supports:

- **GDPR**: Data retention and deletion policies
- **HIPAA**: Encryption at rest and in transit
- **PCI-DSS**: Audit logging and access controls
- **SOC 2**: Operational security controls
- **AWS Well-Architected**: Security pillar compliance

---

## Incident Response

### Security Event Detection

#### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "unauthorized_api_calls" {
  alarm_name          = "ebs-snapshot-manager-unauthorized-calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "UnauthorizedAPICalls"
  namespace           = "CloudTrailMetrics"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "Alert on unauthorized API calls"
  alarm_actions       = [aws_sns_topic.security_alerts.arn]
}
```

#### GuardDuty Integration

Enable GuardDuty for threat detection:

```bash
aws guardduty create-detector --enable --region ap-south-1
```

### Response Procedures

#### Unauthorized Access Detected

1. **Immediate**: Disable Lambda function
   ```bash
   aws lambda update-function-configuration \
     --function-name ebs-snapshot-manager-prod \
     --environment Variables={ENABLED=false}
   ```

2. **Investigate**: Check CloudTrail logs
   ```bash
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=ResourceName,AttributeValue=ebs-snapshot-manager-prod
   ```

3. **Remediate**: Rotate credentials, update IAM policies

4. **Document**: Create incident report

#### Data Breach Response

1. Notify security team immediately
2. Isolate affected resources
3. Review CloudTrail and CloudWatch logs
4. Assess data exposure scope
5. Follow organizational breach protocol

---

## Security Checklist

### Pre-Deployment

- [ ] Review and customize IAM policies
- [ ] Configure Secrets Manager for Gmail password
- [ ] Enable CloudTrail logging
- [ ] Configure VPC (if required)
- [ ] Set up CloudWatch alarms
- [ ] Enable DynamoDB point-in-time recovery
- [ ] Review retention policies for compliance

### Post-Deployment

- [ ] Verify IAM role has minimum permissions
- [ ] Test secret retrieval
- [ ] Confirm encryption at rest enabled
- [ ] Validate CloudWatch logging
- [ ] Test incident response procedures
- [ ] Document security configuration
- [ ] Schedule security reviews (quarterly)

### Ongoing Maintenance

- [ ] Monitor CloudWatch alarms
- [ ] Review CloudTrail logs (weekly)
- [ ] Audit IAM permissions (monthly)
- [ ] Rotate secrets (30-90 days)
- [ ] Update Lambda runtime (quarterly)
- [ ] Review DynamoDB access patterns
- [ ] Conduct security assessment (annually)

---

## Security Contacts

### Reporting Security Issues

**DO NOT** open public GitHub issues for security vulnerabilities.

**Email**: security@yourcompany.com  
**PGP Key**: Available on request  
**Response Time**: 24-48 hours

### Security Updates

Subscribe to security advisories:
- AWS Security Bulletins
- GitHub Security Advisories
- Terraform Security Releases

---

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Lambda Security](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [DynamoDB Encryption](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/EncryptionAtRest.html)
- [AWS Secrets Manager Best Practices](https://docs.aws.amazon.com/secretsmanager/latest/userguide/best-practices.html)
- [AWS Well-Architected Security Pillar](https://docs.aws.amazon.com/wellarchitected/latest/security-pillar/welcome.html)

---

## Acknowledgments

This security documentation follows:
- OWASP Serverless Top 10
- CIS AWS Foundations Benchmark
- AWS Security Best Practices
- NIST Cybersecurity Framework

---

<p align="center">
  <strong>Security is a shared responsibility. Stay vigilant.</strong>
</p>

