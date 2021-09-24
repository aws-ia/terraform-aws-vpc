variable "namespace" {
  description = "Namespace, which could be your organiation name, e.g. amazon"
  default     = "myorg"
}

variable "env" {
  description = "Environment, e.g. 'sit', 'uat', 'prod' etc"
  default     = "dev"
}

variable "account" {
  description = "Account, which could be AWS Account Name or Number"
  default     = "test"
}

variable "name" {
  description = "vpc name"
  default     = "vpc1"
}

variable "delimiter" {
  description = "Delimiter, which could be used between name, namespace and env"
  default     = "-"
}

variable "tags" {
  default     = {}
  description = "Tags, which could be used for additional tags"
}

variable "enable_dns_hostnames" {
  description = "Should be true to enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Should be true to enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"
}

variable "cidr" {
  description = "The CIDR block for the VPC. Default value is a valid CIDR, but not acceptable by AWS and should be overridden"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.128.0/20", "10.0.144.0/20", "10.0.160.0/20"]
}

variable "private_subnet_a_cidrs" {
  description = "A list of private subnets inside the VPC"
  type        = list(string)
  default     = ["10.0.96.0/19", "10.0.232.0/22", "10.0.236.0/22"]
}

variable "public_subnet_tags" {
  type        = map(string)
  default     = { "Name" = "Public Subnet" }
  description = "Public Subnet Tags"
}

variable "private_subnet_tags" {
  type        = map(string)
  default     = { "Name" = "Private Subnet" }
  description = "Private Subnet Tags"
}

variable "create_vpc" {
  description = "Controls if VPC should be created (it affects almost all resources)"
  type        = bool
  default     = true
}

variable "create_vpc_flow_logs" {
  description = "Controls if VPC logs should be created for the VPC"
  type        = bool
  default     = false
}

variable "log_destination" {
  description = "The ARN of the flow log logging destination. If log_destination_type set to s3, provide the ARN of your bucket. Otherwise, a bucket will be created for you. If log_destination_type is set to cloud-watch-logs, provide ARN of log group otherwise log group will be created for you."
  type        = string
  default     = null
}

variable "flog_log_iam_role_arn" {
  description = "The ARN for the IAM role that's used to post flow logs to a CloudWatch Logs log group."
  type        = string
  default     = null
}

variable "log_destination_type" {
  description = "The type of the logging destination for flow log. Valid values: cloud-watch-logs, s3"
  type        = string
  default     = "cloud-watch-logs"
}

variable "traffic_type" {
  description = "The type of traffic to capture in the flow log."
  type        = string
  default     = "ALL"
}

variable "log_format" {
  description = "The fields to include in the flow log record, in the order in which they should appear."
  type        = string
  default     = null
}

variable "enriched_meta_data" {
  description = "Controls if VPC logs should have enriched meta data fields."
  type        = bool
  default     = true
}