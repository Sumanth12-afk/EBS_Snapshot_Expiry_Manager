"""
Gmail Notifier Module
Sends email alerts via Gmail SMTP with snapshot scan reports.
"""

import os
import smtplib
import boto3
import json
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Dict, List, Any
from datetime import datetime


class GmailNotifier:
    """Handles Gmail SMTP notifications."""
    
    def __init__(self):
        self.gmail_user = os.environ.get('GMAIL_USER')
        self.alert_receiver = os.environ.get('ALERT_RECEIVER')
        self.password_secret_name = os.environ.get('GMAIL_PASSWORD_SECRET', 'ebs/gmail-app-password')
        self.gmail_password = self._get_gmail_password()
        self.smtp_server = 'smtp.gmail.com'
        self.smtp_port = 587
    
    def _get_gmail_password(self) -> str:
        """Retrieve Gmail app password from AWS Secrets Manager."""
        try:
            secrets_client = boto3.client('secretsmanager')
            response = secrets_client.get_secret_value(SecretId=self.password_secret_name)
            
            if 'SecretString' in response:
                secret = json.loads(response['SecretString'])
                return secret.get('password', '')
            return ''
            
        except Exception as e:
            print(f"Error retrieving Gmail password from Secrets Manager: {str(e)}")
            return ''
    
    def _build_html_report(self, summary: Dict[str, Any], snapshots: List[Dict[str, Any]]) -> str:
        """Build HTML email report."""
        # Get old snapshots for detailed listing
        old_snapshots = [s for s in snapshots if s['AgeDays'] > summary['retention_policy_days']]
        deleted_snapshots = [s for s in snapshots if s['Status'] == 'DELETED']
        archived_snapshots = [s for s in snapshots if s['Status'] == 'ARCHIVED']
        
        html = f"""
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); 
                           color: white; padding: 20px; border-radius: 5px; }}
                .summary {{ background: #f4f4f4; padding: 15px; margin: 20px 0; border-radius: 5px; }}
                .metric {{ display: inline-block; margin: 10px 20px 10px 0; }}
                .metric-label {{ font-size: 12px; color: #666; }}
                .metric-value {{ font-size: 24px; font-weight: bold; color: #667eea; }}
                .table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
                .table th {{ background: #667eea; color: white; padding: 10px; text-align: left; }}
                .table td {{ padding: 8px; border-bottom: 1px solid #ddd; }}
                .status-deleted {{ color: #e74c3c; font-weight: bold; }}
                .status-archived {{ color: #f39c12; font-weight: bold; }}
                .status-active {{ color: #27ae60; }}
                .footer {{ margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; 
                          font-size: 12px; color: #666; }}
            </style>
        </head>
        <body>
            <div class="header">
                <h1>📊 EBS Snapshot Expiry Report</h1>
                <p>Scan Date: {datetime.fromisoformat(summary['scan_date']).strftime('%B %d, %Y at %H:%M UTC')}</p>
            </div>
            
            <div class="summary">
                <h2>Executive Summary</h2>
                <div class="metric">
                    <div class="metric-label">Total Snapshots</div>
                    <div class="metric-value">{summary['total_snapshots']}</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Old Snapshots (>{summary['retention_policy_days']} days)</div>
                    <div class="metric-value" style="color: #e74c3c;">{summary['old_snapshots_count']}</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Deleted</div>
                    <div class="metric-value" style="color: #e74c3c;">{summary['deleted_count']}</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Archived</div>
                    <div class="metric-value" style="color: #f39c12;">{summary['archived_count']}</div>
                </div>
                <div class="metric">
                    <div class="metric-label">Estimated Savings</div>
                    <div class="metric-value" style="color: #27ae60;">${summary['estimated_savings_usd']}/mo</div>
                </div>
            </div>
            
            <h2>Cost Analysis</h2>
            <ul>
                <li><strong>Total Monthly Cost:</strong> ${summary['total_estimated_cost_usd']}</li>
                <li><strong>Old Snapshots Cost:</strong> ${summary['old_snapshots_cost_usd']}</li>
                <li><strong>Potential Savings:</strong> ${summary['estimated_savings_usd']}</li>
            </ul>
            
            <h2>Configuration</h2>
            <ul>
                <li><strong>Retention Policy:</strong> {summary['retention_policy_days']} days</li>
                <li><strong>Regions Scanned:</strong> {', '.join(summary['regions_scanned'])}</li>
                <li><strong>Auto-Delete:</strong> {'✅ Enabled' if summary['auto_delete_enabled'] else '❌ Disabled'}</li>
                <li><strong>Glacier Archive:</strong> {'✅ Enabled' if summary['glacier_archive_enabled'] else '❌ Disabled'}</li>
            </ul>
        """
        
        # Add detailed snapshot listing if there are old/deleted/archived snapshots
        if old_snapshots or deleted_snapshots or archived_snapshots:
            html += """
            <h2>Detailed Snapshot List</h2>
            <table class="table">
                <thead>
                    <tr>
                        <th>Snapshot ID</th>
                        <th>Volume ID</th>
                        <th>Region</th>
                        <th>Age (days)</th>
                        <th>Size (GB)</th>
                        <th>Cost/mo</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
            """
            
            # Show deleted snapshots first, then archived, then old but active
            for snapshot in deleted_snapshots + archived_snapshots + [s for s in old_snapshots if s['Status'] == 'ACTIVE']:
                status_class = f"status-{snapshot['Status'].lower()}"
                html += f"""
                    <tr>
                        <td>{snapshot['SnapshotId']}</td>
                        <td>{snapshot['VolumeId']}</td>
                        <td>{snapshot['Region']}</td>
                        <td>{snapshot['AgeDays']}</td>
                        <td>{snapshot['SizeGB']}</td>
                        <td>${snapshot['EstimatedCost']}</td>
                        <td class="{status_class}">{snapshot['Status']}</td>
                    </tr>
                """
            
            html += """
                </tbody>
            </table>
            """
        
        html += """
            <div class="footer">
                <p>This is an automated report from EBS Snapshot Expiry Manager.</p>
                <p>For questions or issues, contact your AWS administrator.</p>
            </div>
        </body>
        </html>
        """
        
        return html
    
    def send_report(self, summary: Dict[str, Any], snapshots: List[Dict[str, Any]]) -> bool:
        """Send email report via Gmail SMTP."""
        # Skip if credentials not configured
        if not self.gmail_user or not self.gmail_password or not self.alert_receiver:
            print("Gmail credentials not configured. Skipping email notification.")
            return False
        
        try:
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = f"EBS Snapshot Report: {summary['old_snapshots_count']} Old Snapshots Found | Savings: ${summary['estimated_savings_usd']}/mo"
            msg['From'] = self.gmail_user
            msg['To'] = self.alert_receiver
            
            # Generate HTML content
            html_content = self._build_html_report(summary, snapshots)
            html_part = MIMEText(html_content, 'html')
            msg.attach(html_part)
            
            # Send email
            with smtplib.SMTP(self.smtp_server, self.smtp_port) as server:
                server.starttls()
                server.login(self.gmail_user, self.gmail_password)
                server.send_message(msg)
            
            print(f"Email report sent successfully to {self.alert_receiver}")
            return True
            
        except Exception as e:
            print(f"Error sending email: {str(e)}")
            return False

