output "bucket_flow_logs_attributes" {
  value = {
    id                          = aws_s3_bucket.flow_logs.id
    arn                         = aws_s3_bucket.flow_logs.arn
    bucket                      = aws_s3_bucket.flow_logs.bucket
    bucket_domain_name          = aws_s3_bucket.flow_logs.bucket_domain_name
    bucket_regional_domain_name = aws_s3_bucket.flow_logs.bucket_regional_domain_name
    region                      = aws_s3_bucket.flow_logs.region
    tags_all                    = aws_s3_bucket.flow_logs.tags_all
  }
  description = "Flow Logs S3 Bucket attributes: id, arn, bucket, domain names, region and tags_all."
}
