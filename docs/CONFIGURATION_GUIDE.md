# ⚙️ Configuration Guide

## EBS Snapshot Expiry Manager - Advanced Configuration

This guide covers advanced configuration options, customization, and optimization strategies.

---

## Table of Contents

- [Retention Policy Configuration](#retention-policy-configuration)
- [Multi-Region Configuration](#multi-region-configuration)
- [Email Notification Customization](#email-notification-customization)
- [Scheduling Options](#scheduling-options)
- [Lambda Optimization](#lambda-optimization)
- [DynamoDB Configuration](#dynamodb-configuration)
- [Glacier Archival Setup](#glacier-archival-setup)
- [Cost Optimization](#cost-optimization)
- [Environment-Specific Configuration](#environment-specific-configuration)

---

## Retention Policy Configuration

### Basic Retention Policies

```hcl
# terraform.tfvars

# Development: 30 days
retention_days = 30

# Production: 90 days (default)
retention_days = 90

# Compliance: 180 days
retention_days = 180

# Regulatory: 365 days (1 year)
retention_days = 365
```

### Tag-Based Retention (Custom Implementation)

Modify `lambda/snapshot_manager.py` to implement tag-based policies:

```python
def get_retention_policy(snapshot: Dict) -> int:
    """Determine retention based on snapshot tags."""
    tags = {tag['Key']: tag['Value'] for tag in snapshot.get('Tags', [])}
    
    # Priority-based retention
    if tags.get('Compliance') == 'Required':
        return 365  # 1 year
    elif tags.get('Environment') == 'Production':
        return 180  # 6 months
    elif tags.get('Environment') == 'Development':
        return 30   # 30 days
    else:
        return int(os.environ.get('RETENTION_DAYS', '90'))
```

### Volume-Based Retention

Different policies for different volume types:

```python
def get_retention_by_volume_type(snapshot: Dict) -> int:
    """Retention based on volume type."""
    volume_id = snapshot.get('VolumeId')
    
    if not volume_id:
        return 90
    
    ec2 = boto3.client('ec2')
    volume = ec2.describe_volumes(VolumeIds=[volume_id])['Volumes'][0]
    volume_type = volume.get('VolumeType')
    
    retention_map = {
        'gp3': 90,      # General Purpose SSD
        'io1': 180,     # Provisioned IOPS (critical)
        'io2': 180,     # Provisioned IOPS (critical)
        'st1': 60,      # Throughput Optimized HDD
        'sc1': 30       # Cold HDD
    }
    
    return retention_map.get(volume_type, 90)
```

---

## Multi-Region Configuration

### Basic Multi-Region Setup

```hcl
# Single region
scan_regions = "ap-south-1"

# Multiple regions (comma-separated)
scan_regions = "ap-south-1,us-east-1,us-west-2,eu-west-1"

# All major regions
scan_regions = "us-east-1,us-east-2,us-west-1,us-west-2,ap-south-1,ap-southeast-1,eu-west-1,eu-central-1"
```

### Region-Specific Retention Policies

Modify Lambda code for region-specific policies:

```python
REGION_RETENTION_POLICIES = {
    'us-east-1': 90,      # Production region
    'us-west-2': 90,      # Production region
    'ap-south-1': 60,     # Development region
    'eu-west-1': 180      # Compliance region
}

def get_retention_for_region(region: str) -> int:
    return REGION_RETENTION_POLICIES.get(region, 90)
```

### Parallel Region Scanning

For faster execution with many regions, implement parallel scanning:

```python
from concurrent.futures import ThreadPoolExecutor, as_completed

def scan_all_regions_parallel(regions: List[str]) -> List[Dict]:
    """Scan multiple regions in parallel."""
    results = []
    
    with ThreadPoolExecutor(max_workers=4) as executor:
        future_to_region = {
            executor.submit(scan_region, region): region 
            for region in regions
        }
        
        for future in as_completed(future_to_region):
            region = future_to_region[future]
            try:
                snapshots = future.result()
                results.extend(snapshots)
            except Exception as e:
                print(f"Error scanning {region}: {e}")
    
    return results
```

---

## Email Notification Customization

### Email Configuration

```hcl
# Basic configuration
gmail_user     = "alerts@yourcompany.com"
alert_receiver = "finops@yourcompany.com"

# Multiple receivers (requires code modification)
alert_receiver = "finops@company.com,ops@company.com,cto@company.com"
```

### Custom Email Templates

Modify `lambda/gmail_notifier.py` to customize email format:

```python
def _build_html_report(self, summary: Dict, snapshots: List[Dict]) -> str:
    """Custom email template with company branding."""
    html = f"""
    <html>
    <head>
        <style>
            body {{ 
                font-family: 'Segoe UI', Arial, sans-serif; 
                background: #f5f5f5;
            }}
            .header {{ 
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px;
                text-align: center;
            }}
            .logo {{ 
                max-width: 200px;
                margin-bottom: 20px;
            }}
            /* Add your custom styles */
        </style>
    </head>
    <body>
        <div class="header">
            <img src="https://your-company.com/logo.png" class="logo">
            <h1>EBS Snapshot Report</h1>
        </div>
        <!-- Your custom content -->
    </body>
    </html>
    """
    return html
```

### Conditional Email Sending

Only send emails when action is taken:

```python
def should_send_email(summary: Dict) -> bool:
    """Send email only if snapshots were deleted or archived."""
    return (summary['deleted_count'] > 0 or 
            summary['archived_count'] > 0 or
            summary['old_snapshots_count'] > 10)
```

---

## Scheduling Options

### EventBridge Schedule Expressions

```hcl
# Daily at 6 AM UTC
schedule_expression = "cron(0 6 * * ? *)"

# Daily at 2 AM local time (adjust for timezone)
schedule_expression = "cron(0 2 * * ? *)"

# Every 12 hours
schedule_expression = "rate(12 hours)"

# Weekly on Sunday at midnight
schedule_expression = "cron(0 0 ? * SUN *)"

# Monthly on 1st day at 3 AM
schedule_expression = "cron(0 3 1 * ? *)"

# Weekdays only (Mon-Fri) at 7 AM
schedule_expression = "cron(0 7 ? * MON-FRI *)"
```

### Multiple Schedules

Create multiple EventBridge rules for different scenarios:

```hcl
# Daily full scan
resource "aws_cloudwatch_event_rule" "daily_scan" {
  name                = "${local.function_name}-daily-scan"
  schedule_expression = "cron(0 6 * * ? *)"
}

# Weekly compliance report
resource "aws_cloudwatch_event_rule" "weekly_report" {
  name                = "${local.function_name}-weekly-report"
  schedule_expression = "cron(0 0 ? * SUN *)"
}
```

---

## Lambda Optimization

### Memory and Timeout Configuration

```hcl
# Small deployments (<100 snapshots)
lambda_timeout = 300   # 5 minutes
lambda_memory  = 256   # MB

# Medium deployments (100-500 snapshots)
lambda_timeout = 600   # 10 minutes
lambda_memory  = 512   # MB (default)

# Large deployments (500+ snapshots)
lambda_timeout = 900   # 15 minutes (max)
lambda_memory  = 1024  # MB

# Very large deployments (1000+ snapshots)
lambda_timeout = 900
lambda_memory  = 2048  # More memory = faster CPU
```

### Environment Variables

```hcl
# Performance tuning
BATCH_SIZE          = "100"    # Process snapshots in batches
MAX_WORKERS         = "4"      # Parallel processing threads
ENABLE_CACHING      = "true"   # Cache EC2 describe calls
LOG_LEVEL           = "INFO"   # DEBUG for troubleshooting
```

### Lambda Layers

Create a Lambda Layer for dependencies:

```bash
# Create layer
mkdir -p layer/python
pip install boto3 -t layer/python
cd layer
zip -r lambda-layer.zip python

# Upload to Lambda
aws lambda publish-layer-version \
  --layer-name ebs-snapshot-manager-dependencies \
  --zip-file fileb://lambda-layer.zip \
  --compatible-runtimes python3.11
```

Add to Terraform:

```hcl
resource "aws_lambda_function" "snapshot_manager" {
  # ... other configuration
  
  layers = [
    "arn:aws:lambda:ap-south-1:ACCOUNT:layer:ebs-snapshot-manager-dependencies:1"
  ]
}
```

---

## DynamoDB Configuration

### On-Demand vs Provisioned Capacity

```hcl
# On-Demand (default) - Automatic scaling
dynamodb_billing_mode = "PAY_PER_REQUEST"

# Provisioned - Fixed capacity
dynamodb_billing_mode   = "PROVISIONED"
read_capacity_units     = 5
write_capacity_units    = 5
```

### Auto-Scaling (Provisioned Mode)

```hcl
resource "aws_appautoscaling_target" "dynamodb_table_write" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.snapshot_reports.name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_table_write_policy" {
  name               = "DynamoDBWriteCapacityUtilization"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_table_write.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_table_write.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_table_write.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}
```

### TTL Configuration

```python
# Customize TTL in dynamo_logger.py
TTL_SNAPSHOT_RECORDS = 30   # days
TTL_SUMMARY_RECORDS  = 90   # days
TTL_AUDIT_RECORDS    = 365  # days (1 year)
```

---

## Glacier Archival Setup

### Enable Glacier Vault

```hcl
enable_glacier_vault   = true
enable_glacier_archive = true
glacier_vault_name     = "ebs-snapshot-archive"
```

### Vault Lock Policy (Compliance)

```hcl
resource "aws_glacier_vault_lock" "archive_lock" {
  complete_lock = true
  vault_name    = aws_glacier_vault.snapshot_archive.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyDeleteBeforeRetention"
        Effect = "Deny"
        Principal = "*"
        Action = "glacier:DeleteArchive"
        Resource = aws_glacier_vault.snapshot_archive.arn
        Condition = {
          DateLessThan = {
            "aws:CurrentTime" = "2030-01-01T00:00:00Z"
          }
        }
      }
    ]
  })
}
```

### Glacier Retrieval Configuration

```python
# glacier_archiver.py

RETRIEVAL_TIERS = {
    'EXPEDITED': {  # 1-5 minutes, expensive
        'time': '5 minutes',
        'cost_per_gb': 0.03
    },
    'STANDARD': {   # 3-5 hours, moderate
        'time': '4 hours',
        'cost_per_gb': 0.01
    },
    'BULK': {       # 5-12 hours, cheapest
        'time': '12 hours',
        'cost_per_gb': 0.0025
    }
}
```

---

## Cost Optimization

### Reduce Lambda Execution Time

```python
# Use pagination for large snapshot lists
def scan_region(region: str, max_results: int = 1000):
    ec2_client = boto3.client('ec2', region_name=region)
    paginator = ec2_client.get_paginator('describe_snapshots')
    
    for page in paginator.paginate(OwnerIds=['self'], MaxResults=max_results):
        yield page['Snapshots']
```

### Batch DynamoDB Writes

```python
def batch_write_snapshots(snapshots: List[Dict]):
    """Write multiple items in batch."""
    with self.table.batch_writer() as batch:
        for snapshot in snapshots:
            batch.put_item(Item=snapshot)
```

### Use VPC Endpoints

```hcl
# Avoid NAT Gateway costs
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id          = var.vpc_id
  service_name    = "com.amazonaws.${var.aws_region}.dynamodb"
  route_table_ids = var.route_table_ids
}
```

---

## Environment-Specific Configuration

### Development Environment

```hcl
# terraform/environments/dev.tfvars
environment            = "dev"
retention_days         = 30
enable_auto_delete     = false
lambda_memory          = 256
schedule_expression    = "cron(0 8 * * ? *)"  # 8 AM daily
scan_regions           = "ap-south-1"
```

### Staging Environment

```hcl
# terraform/environments/staging.tfvars
environment            = "staging"
retention_days         = 60
enable_auto_delete     = true
lambda_memory          = 512
schedule_expression    = "cron(0 6 * * ? *)"
scan_regions           = "ap-south-1,us-east-1"
```

### Production Environment

```hcl
# terraform/environments/prod.tfvars
environment            = "prod"
retention_days         = 90
enable_auto_delete     = true
enable_glacier_archive = true
lambda_memory          = 1024
schedule_expression    = "cron(0 3 * * ? *)"  # 3 AM daily
scan_regions           = "ap-south-1,us-east-1,us-west-2,eu-west-1"
```

Deploy specific environment:

```bash
terraform plan -var-file="environments/prod.tfvars"
terraform apply -var-file="environments/prod.tfvars"
```

---

## Advanced Features

### Cross-Account Snapshot Management

```python
def assume_cross_account_role(account_id: str, role_name: str):
    """Assume role in another AWS account."""
    sts_client = boto3.client('sts')
    
    response = sts_client.assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role_name}",
        RoleSessionName="EBSSnapshotManager"
    )
    
    return boto3.Session(
        aws_access_key_id=response['Credentials']['AccessKeyId'],
        aws_secret_access_key=response['Credentials']['SecretAccessKey'],
        aws_session_token=response['Credentials']['SessionToken']
    )
```

### Snapshot Tagging Before Deletion

```python
def tag_snapshot_before_deletion(snapshot_id: str, region: str):
    """Tag snapshot as pending deletion."""
    ec2_client = boto3.client('ec2', region_name=region)
    
    ec2_client.create_tags(
        Resources=[snapshot_id],
        Tags=[
            {'Key': 'DeletionScheduled', 'Value': 'true'},
            {'Key': 'DeletionDate', 'Value': datetime.now().isoformat()}
        ]
    )
```

---

## Configuration Best Practices

✅ Start with `enable_auto_delete = false` for testing  
✅ Use separate configurations for dev/staging/prod  
✅ Monitor Lambda execution time and adjust timeout  
✅ Review CloudWatch logs weekly  
✅ Test email notifications before production  
✅ Document custom retention policies  
✅ Use tags for granular snapshot management  
✅ Enable DynamoDB point-in-time recovery  
✅ Configure CloudWatch alarms for failures  
✅ Regular review of cost and savings metrics

---

## Support

For configuration assistance:
- **Documentation**: [Full Documentation](../README.md)
- **GitHub Issues**: Report configuration issues
- **Email**: support@yourcompany.com

