variable "kms_key_id" {
  description = "KMS Key ID"
  type        = string
  default     = null
}

variable "vpc_flow_logs" {
  description = "Whether or not to create VPC flow logs and which type. Options: \"cloudwatch\", \"s3\", \"none\"."

  type = object({
    log_destination = optional(string)
    iam_role_arn    = optional(string)
    kms_key_id      = optional(string)

    log_destination_type = string
    retention_in_days    = optional(number)
    tags                 = optional(map(string))
    traffic_type         = optional(string)
    destination_options = optional(object({
      file_format                = optional(string)
      hive_compatible_partitions = optional(bool)
      per_hour_partition         = optional(bool)
    }))
  })
  default = {
    log_destination_type = "cloud-watch-logs"
    retention_in_days    = 180
    kms_key_id           = null
  }
}
