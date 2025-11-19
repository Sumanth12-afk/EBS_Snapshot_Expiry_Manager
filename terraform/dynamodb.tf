# ============================================================================
# DynamoDB Table for Snapshot Reports
# ============================================================================

resource "aws_dynamodb_table" "snapshot_reports" {
  name           = "${var.project_name}-reports-${var.environment}"
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "SnapshotId"
  range_key      = "ProcessedAt"

  # Attributes
  attribute {
    name = "SnapshotId"
    type = "S"
  }

  attribute {
    name = "ProcessedAt"
    type = "S"
  }

  attribute {
    name = "RecordType"
    type = "S"
  }

  attribute {
    name = "Status"
    type = "S"
  }

  # Global Secondary Index for querying by RecordType
  global_secondary_index {
    name            = "RecordTypeIndex"
    hash_key        = "RecordType"
    range_key       = "ProcessedAt"
    projection_type = "ALL"
  }

  # Global Secondary Index for querying by Status
  global_secondary_index {
    name            = "StatusIndex"
    hash_key        = "Status"
    range_key       = "ProcessedAt"
    projection_type = "ALL"
  }

  # TTL Configuration
  ttl {
    attribute_name = "TTL"
    enabled        = true
  }

  # Point-in-time Recovery
  point_in_time_recovery {
    enabled = true
  }

  # Server-side Encryption
  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-dynamodb"
  }
}

