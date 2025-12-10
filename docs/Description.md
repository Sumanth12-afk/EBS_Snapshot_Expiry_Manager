EBS Snapshot Expiry Manager

## What the Solution Does

This solution automatically identifies and deletes stale or expired EBS snapshots based on retention policies.

## Why It Exists

Manual snapshot cleanup is often ignored, leading to:

- Waste storage costs
- Compliance issues
- Unmanageable backup inventory

This system ensures backups remain clean and cost-effective.

## Use Cases

- Automated backup hygiene
- FinOps cost optimization
- Organizations with nightly/weekly snapshot jobs
- Disaster recovery environments

## High-Level Architecture

- EventBridge daily triggers
- Lambda scans EBS snapshots across regions
- Expired snapshots are deleted
- Summary logs stored in S3
- Notifications sent via SNS

## Features

- Automated snapshot lifecycle enforcement
- Multi-region scanning
- Configurable retention periods
- Secure deletion with auditing
- Cost savings reporting

## Benefits

- Reduced storage costs
- Better compliance with retention policies
- No manual cleanup required
- Improved backup hygiene

## Business Problem It Solves

AWS environments accumulate years of old snapshots, costing thousands of dollars in unused storage. This manager prevents snapshot sprawl automatically.

## How It Works (Non-Code Workflow)

Daily trigger activates cleanup logic. System finds snapshots older than your policy. Expired snapshots are safely deleted. Notifications and logs are stored for audit.

## Additional Explanation

Retention rules are fully customizable, making this suitable for different compliance standards.
