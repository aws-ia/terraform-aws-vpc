#tfsec:ignore:aws-s3-encryption-customer-key tfsec:ignore:aws-s3-enable-bucket-logging tfsec:ignore:aws-s3-enable-versioning
resource "aws_s3_bucket" "flow_logs" {
  bucket_prefix = "vpc-flow-logs-${var.name}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#tfsec:ignore:aws-s3-encryption-customer-key
resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.bucket

  rule {
    id = "transition"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 60
    }

    status = "Enabled"
  }
}
