"""
Glacier Archiver Module
Archives EBS snapshots to AWS Glacier Deep Archive for long-term retention.
"""

import os
import boto3
import json
from datetime import datetime, timezone
from typing import Dict, Any


class GlacierArchiver:
    """Handles archiving EBS snapshots to Glacier Deep Archive."""
    
    def __init__(self):
        self.vault_name = os.environ.get('GLACIER_VAULT_NAME', 'ebs-snapshot-archive')
        self.account_id = '-'  # Use current account
    
    def archive_snapshot(self, snapshot_id: str, region: str, size_gb: int, 
                        created_at: datetime) -> Dict[str, Any]:
        """
        Archive snapshot metadata to Glacier.
        
        Note: This creates a metadata record in Glacier. The actual snapshot data
        remains in EBS but is marked for deletion after archival.
        For true archival, consider EBS snapshot copy to a dedicated backup account.
        """
        try:
            glacier_client = boto3.client('glacier', region_name=region)
            
            # Create archive metadata
            metadata = {
                'snapshot_id': snapshot_id,
                'region': region,
                'size_gb': size_gb,
                'original_created_at': created_at.isoformat(),
                'archived_at': datetime.now(timezone.utc).isoformat(),
                'type': 'ebs_snapshot_metadata'
            }
            
            # Upload archive (metadata JSON)
            archive_description = f"EBS Snapshot {snapshot_id} - {size_gb}GB - {created_at.date()}"
            
            response = glacier_client.upload_archive(
                vaultName=self.vault_name,
                archiveDescription=archive_description,
                body=json.dumps(metadata).encode('utf-8')
            )
            
            archive_id = response['archiveId']
            
            print(f"Archived snapshot metadata to Glacier: {snapshot_id} -> {archive_id}")
            
            return {
                'success': True,
                'archive_id': archive_id,
                'snapshot_id': snapshot_id,
                'vault': self.vault_name
            }
            
        except glacier_client.exceptions.ResourceNotFoundException:
            print(f"Glacier vault '{self.vault_name}' not found. Skipping archival.")
            return {
                'success': False,
                'error': 'Vault not found',
                'snapshot_id': snapshot_id
            }
        except Exception as e:
            print(f"Error archiving snapshot {snapshot_id} to Glacier: {str(e)}")
            return {
                'success': False,
                'error': str(e),
                'snapshot_id': snapshot_id
            }
    
    def retrieve_archive(self, archive_id: str, region: str) -> Dict[str, Any]:
        """
        Initiate retrieval of archived snapshot metadata.
        Note: Glacier retrievals can take 12-48 hours.
        """
        try:
            glacier_client = boto3.client('glacier', region_name=region)
            
            response = glacier_client.initiate_job(
                vaultName=self.vault_name,
                jobParameters={
                    'Type': 'archive-retrieval',
                    'ArchiveId': archive_id,
                    'Tier': 'Bulk'  # Cheapest option
                }
            )
            
            job_id = response['jobId']
            
            print(f"Initiated Glacier retrieval job: {job_id}")
            
            return {
                'success': True,
                'job_id': job_id,
                'archive_id': archive_id
            }
            
        except Exception as e:
            print(f"Error initiating Glacier retrieval: {str(e)}")
            return {
                'success': False,
                'error': str(e)
            }

