"""
EBS Snapshot Expiry Manager - Main Lambda Handler
Scans, analyzes, and manages EBS snapshots based on retention policies.
"""

import json
import os
import boto3
from datetime import datetime, timezone
from typing import List, Dict, Any
from dynamo_logger import DynamoLogger
from gmail_notifier import GmailNotifier
from glacier_archiver import GlacierArchiver


class SnapshotManager:
    """Manages EBS snapshot lifecycle and retention policies."""
    
    def __init__(self):
        self.retention_days = int(os.environ.get('RETENTION_DAYS', '90'))
        self.enable_auto_delete = os.environ.get('ENABLE_AUTO_DELETE', 'false').lower() == 'true'
        self.enable_glacier = os.environ.get('ENABLE_GLACIER_ARCHIVE', 'false').lower() == 'true'
        self.scan_regions = os.environ.get('SCAN_REGIONS', 'ap-south-1').split(',')
        self.snapshot_cost_per_gb = float(os.environ.get('EBS_SNAPSHOT_COST_PER_GB', '0.05'))
        
        self.dynamo_logger = DynamoLogger()
        self.gmail_notifier = GmailNotifier()
        self.glacier_archiver = GlacierArchiver() if self.enable_glacier else None
        
    def scan_region(self, region: str) -> List[Dict[str, Any]]:
        """Scan all EBS snapshots in a specific region."""
        ec2_client = boto3.client('ec2', region_name=region)
        
        try:
            # Get all snapshots owned by this account
            response = ec2_client.describe_snapshots(OwnerIds=['self'])
            snapshots = response.get('Snapshots', [])
            
            print(f"Found {len(snapshots)} snapshots in {region}")
            return snapshots
            
        except Exception as e:
            print(f"Error scanning region {region}: {str(e)}")
            return []
    
    def calculate_snapshot_age(self, start_time: datetime) -> int:
        """Calculate snapshot age in days."""
        now = datetime.now(timezone.utc)
        age = now - start_time
        return age.days
    
    def estimate_cost(self, size_gb: int) -> float:
        """Estimate monthly cost for a snapshot."""
        return size_gb * self.snapshot_cost_per_gb
    
    def process_snapshot(self, snapshot: Dict[str, Any], region: str) -> Dict[str, Any]:
        """Process a single snapshot and determine action."""
        snapshot_id = snapshot['SnapshotId']
        volume_id = snapshot.get('VolumeId', 'N/A')
        start_time = snapshot['StartTime']
        size_gb = snapshot['VolumeSize']
        description = snapshot.get('Description', '')
        
        age_days = self.calculate_snapshot_age(start_time)
        estimated_cost = self.estimate_cost(size_gb)
        
        # Determine snapshot status and action
        status = 'ACTIVE'
        action_taken = 'NONE'
        
        if age_days > self.retention_days:
            if self.enable_glacier and self.glacier_archiver:
                # Archive to Glacier
                archive_result = self.glacier_archiver.archive_snapshot(
                    snapshot_id, region, size_gb, start_time
                )
                if archive_result['success']:
                    status = 'ARCHIVED'
                    action_taken = 'ARCHIVED_TO_GLACIER'
            
            if self.enable_auto_delete:
                # Delete snapshot
                delete_result = self.delete_snapshot(snapshot_id, region)
                if delete_result:
                    status = 'DELETED'
                    action_taken = 'DELETED'
        
        # Build result record
        result = {
            'SnapshotId': snapshot_id,
            'VolumeId': volume_id,
            'Region': region,
            'CreatedAt': start_time.isoformat(),
            'AgeDays': age_days,
            'SizeGB': size_gb,
            'Description': description,
            'Status': status,
            'ActionTaken': action_taken,
            'EstimatedCost': round(estimated_cost, 2),
            'ProcessedAt': datetime.now(timezone.utc).isoformat()
        }
        
        return result
    
    def delete_snapshot(self, snapshot_id: str, region: str) -> bool:
        """Delete an EBS snapshot."""
        ec2_client = boto3.client('ec2', region_name=region)
        
        try:
            ec2_client.delete_snapshot(SnapshotId=snapshot_id)
            print(f"Deleted snapshot: {snapshot_id} in {region}")
            return True
        except Exception as e:
            print(f"Error deleting snapshot {snapshot_id}: {str(e)}")
            return False
    
    def generate_summary(self, results: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Generate summary statistics from scan results."""
        total_snapshots = len(results)
        old_snapshots = [r for r in results if r['AgeDays'] > self.retention_days]
        deleted_snapshots = [r for r in results if r['Status'] == 'DELETED']
        archived_snapshots = [r for r in results if r['Status'] == 'ARCHIVED']
        
        total_cost = sum(r['EstimatedCost'] for r in results)
        old_cost = sum(r['EstimatedCost'] for r in old_snapshots)
        savings = sum(r['EstimatedCost'] for r in deleted_snapshots)
        
        summary = {
            'scan_date': datetime.now(timezone.utc).isoformat(),
            'retention_policy_days': self.retention_days,
            'regions_scanned': self.scan_regions,
            'total_snapshots': total_snapshots,
            'old_snapshots_count': len(old_snapshots),
            'deleted_count': len(deleted_snapshots),
            'archived_count': len(archived_snapshots),
            'total_estimated_cost_usd': round(total_cost, 2),
            'old_snapshots_cost_usd': round(old_cost, 2),
            'estimated_savings_usd': round(savings, 2),
            'auto_delete_enabled': self.enable_auto_delete,
            'glacier_archive_enabled': self.enable_glacier
        }
        
        return summary
    
    def run(self) -> Dict[str, Any]:
        """Main execution method."""
        print(f"Starting EBS Snapshot Expiry Manager")
        print(f"Retention Policy: {self.retention_days} days")
        print(f"Auto Delete: {self.enable_auto_delete}")
        print(f"Glacier Archive: {self.enable_glacier}")
        print(f"Scanning regions: {', '.join(self.scan_regions)}")
        
        all_results = []
        
        # Scan all configured regions
        for region in self.scan_regions:
            print(f"\nScanning region: {region}")
            snapshots = self.scan_region(region)
            
            for snapshot in snapshots:
                result = self.process_snapshot(snapshot, region)
                all_results.append(result)
                
                # Log to DynamoDB
                self.dynamo_logger.log_snapshot(result)
        
        # Generate summary
        summary = self.generate_summary(all_results)
        print(f"\nScan Summary: {json.dumps(summary, indent=2)}")
        
        # Log summary to DynamoDB
        self.dynamo_logger.log_summary(summary)
        
        # Send email notification
        self.gmail_notifier.send_report(summary, all_results)
        
        return {
            'statusCode': 200,
            'body': json.dumps(summary)
        }


def lambda_handler(event, context):
    """AWS Lambda handler function."""
    try:
        manager = SnapshotManager()
        result = manager.run()
        return result
    except Exception as e:
        print(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


if __name__ == "__main__":
    # For local testing
    lambda_handler({}, None)

