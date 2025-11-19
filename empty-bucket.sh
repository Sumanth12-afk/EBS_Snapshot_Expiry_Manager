#!/bin/bash
# Empty S3 Bucket Script
# This removes all objects and versions from the Terraform state bucket

set -e

bucket="ebs-snapshot-manager-tfstate-135459819872"

echo "Emptying bucket: $bucket"
echo ""

# Get all object versions
echo "Fetching object versions..."
versions=$(aws s3api list-object-versions --bucket $bucket 2>/dev/null || echo '{}')

# Delete all object versions
version_count=$(echo "$versions" | jq -r '.Versions | length')
if [ "$version_count" != "null" ] && [ "$version_count" -gt 0 ]; then
    echo "Deleting $version_count object versions..."
    echo "$versions" | jq -r '.Versions[] | "\(.Key) \(.VersionId)"' | while read key version_id; do
        echo "  Deleting: $key (Version: $version_id)"
        aws s3api delete-object --bucket $bucket --key "$key" --version-id "$version_id" >/dev/null
    done
fi

# Delete all delete markers
marker_count=$(echo "$versions" | jq -r '.DeleteMarkers | length')
if [ "$marker_count" != "null" ] && [ "$marker_count" -gt 0 ]; then
    echo "Deleting $marker_count delete markers..."
    echo "$versions" | jq -r '.DeleteMarkers[] | "\(.Key) \(.VersionId)"' | while read key version_id; do
        echo "  Deleting marker: $key (Version: $version_id)"
        aws s3api delete-object --bucket $bucket --key "$key" --version-id "$version_id" >/dev/null
    done
fi

echo ""
echo "Bucket emptied successfully!"
echo "Now run: terraform destroy"
echo ""

