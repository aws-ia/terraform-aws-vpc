variable "aws_region" {
  description = "AWS Region."
  type        = string
  default     = "eu-west-1"
}

variable "vpc_flow_logs" {
  description = "Whether or not to create VPC flow logs and which type. Options: \"cloudwatch\", \"s3\", \"none\"."

  type = object({
    name_override   = optional(string, "")
    log_destination = optional(string)
    iam_role_arn    = optional(string)
    kms_key_id      = optional(string)

  default = null
}
