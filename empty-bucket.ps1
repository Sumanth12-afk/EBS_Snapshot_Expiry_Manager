# Empty S3 Bucket Script
# This removes all objects and versions from the Terraform state bucket

$bucket = "ebs-snapshot-manager-tfstate-135459819872"

Write-Host "Emptying bucket: $bucket" -ForegroundColor Yellow

# Get all object versions
Write-Host "Fetching object versions..." -ForegroundColor Cyan
$versions = aws s3api list-object-versions --bucket $bucket | ConvertFrom-Json

# Delete all object versions
if ($versions.Versions) {
    Write-Host "Deleting $($versions.Versions.Count) object versions..." -ForegroundColor Cyan
    foreach ($version in $versions.Versions) {
        Write-Host "  Deleting: $($version.Key) (Version: $($version.VersionId))"
        aws s3api delete-object --bucket $bucket --key $version.Key --version-id $version.VersionId | Out-Null
    }
}

# Delete all delete markers
if ($versions.DeleteMarkers) {
    Write-Host "Deleting $($versions.DeleteMarkers.Count) delete markers..." -ForegroundColor Cyan
    foreach ($marker in $versions.DeleteMarkers) {
        Write-Host "  Deleting marker: $($marker.Key) (Version: $($marker.VersionId))"
        aws s3api delete-object --bucket $bucket --key $marker.Key --version-id $marker.VersionId | Out-Null
    }
}

Write-Host "Bucket emptied successfully!" -ForegroundColor Green
Write-Host "Now run: terraform destroy" -ForegroundColor Yellow

