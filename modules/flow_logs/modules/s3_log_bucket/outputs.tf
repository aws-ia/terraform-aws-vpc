output "bucket_flow_logs_attributes" {
  value       = aws_s3_bucket.flow_logs
  description = "Flow Logs S3 Bucket resource attributes. Full output of aws_s3_bucket."
}
