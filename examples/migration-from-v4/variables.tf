variable "aws_region" {
  description = "AWS Region containing the copied v4 state used for migration rehearsal."
  type        = string
  default     = "us-east-1"
}

variable "v4_flow_log_group_name" {
  description = "Exact physical CloudWatch log-group name captured from v4 state and used by v5 configuration plus the declarative import block."
  type        = string
  default     = "migration-example-vpc-flow-logs-20260812123456789000000001"

  validation {
    condition     = length(trimspace(var.v4_flow_log_group_name)) > 0
    error_message = "v4_flow_log_group_name must be the non-empty physical name captured from v4 state."
  }
}
