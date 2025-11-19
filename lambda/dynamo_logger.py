"""
DynamoDB Logger Module
Handles writing snapshot metadata and scan reports to DynamoDB.
"""

import os
import boto3
from datetime import datetime, timezone
from typing import Dict, Any
from decimal import Decimal


class DynamoLogger:
    """Logs snapshot data and reports to DynamoDB."""
    
    def __init__(self):
        self.table_name = os.environ.get('DYNAMODB_TABLE_NAME', 'ebs-snapshot-reports')
        self.dynamodb = boto3.resource('dynamodb')
        self.table = self.dynamodb.Table(self.table_name)
    
    def convert_floats_to_decimal(self, obj: Any) -> Any:
        """Convert float values to Decimal for DynamoDB compatibility."""
        if isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, dict):
            return {k: self.convert_floats_to_decimal(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [self.convert_floats_to_decimal(item) for item in obj]
        return obj
    
    def log_snapshot(self, snapshot_data: Dict[str, Any]) -> bool:
        """Log individual snapshot record to DynamoDB."""
        try:
            # Convert floats to Decimal
            item = self.convert_floats_to_decimal(snapshot_data)
            
            # Add TTL (30 days retention for snapshot records)
            ttl = int((datetime.now(timezone.utc).timestamp() + (30 * 24 * 60 * 60)))
            item['TTL'] = ttl
            item['RecordType'] = 'SNAPSHOT'
            
            self.table.put_item(Item=item)
            print(f"Logged snapshot to DynamoDB: {snapshot_data['SnapshotId']}")
            return True
            
        except Exception as e:
            print(f"Error logging snapshot to DynamoDB: {str(e)}")
            return False
    
    def log_summary(self, summary_data: Dict[str, Any]) -> bool:
        """Log scan summary to DynamoDB."""
        try:
            # Convert floats to Decimal
            item = self.convert_floats_to_decimal(summary_data)
            
            # Add metadata
            now = datetime.now(timezone.utc)
            item['SnapshotId'] = f"SUMMARY_{now.strftime('%Y%m%d_%H%M%S')}"
            item['ProcessedAt'] = now.isoformat()  # Required range key
            item['RecordType'] = 'SUMMARY'
            
            # TTL (90 days retention for summary records)
            ttl = int((now.timestamp() + (90 * 24 * 60 * 60)))
            item['TTL'] = ttl
            
            self.table.put_item(Item=item)
            print(f"Logged summary to DynamoDB")
            return True
            
        except Exception as e:
            print(f"Error logging summary to DynamoDB: {str(e)}")
            return False
    
    def query_old_snapshots(self, days: int = 90) -> list:
        """Query snapshots older than specified days."""
        try:
            # This is a scan operation - in production, consider using GSI
            response = self.table.scan(
                FilterExpression='RecordType = :type AND AgeDays > :days',
                ExpressionAttributeValues={
                    ':type': 'SNAPSHOT',
                    ':days': days
                }
            )
            return response.get('Items', [])
            
        except Exception as e:
            print(f"Error querying old snapshots: {str(e)}")
            return []

