variable "name" {
  description = "Name to give the VPC Flow Logs and optional resources."
  type        = string
}

variable "flow_log_definition" {
  description = "Definition of the Flow Logs (FL) to create. Can define pre-existing log_destination / iam_role_arn or theyll be created, default is Cloud Watch."
  type        = any
}

variable "vpc_id" {
  description = "VPC ID to create flow logs for."
  type        = string
}

variable "tags" {
  description = "Tags."
  type        = map(string)
  default     = null
}
