variable "region" {
  type = string
}

variable "profile" {
  type = string
}

provider "aws" {
  region  = var.region
  profile = var.profile
}


variable "create_vpc_flow_logs" {
  type    = bool
  default = true
}

variable "log_destination_type" {
  type    = string
  default = "cloud-watch-logs"
}

variable "log_destination" {
  type    = string
  default = null
}

variable "flog_log_iam_role_arn" {
  type    = string
  default = null
}

module "aws-ia_vpc" {
  source                = "../../"
  create_vpc_flow_logs  = var.create_vpc_flow_logs
  log_destination_type  = var.log_destination_type
  log_destination       = var.log_destination
  flog_log_iam_role_arn = var.flog_log_iam_role_arn
}

output "flow_log_id" {
  value = module.aws-ia_vpc.flow_log_id
}

output "flow_log_arn" {
  value = module.aws-ia_vpc.flow_log_arn
}

output "flow_log_destination" {
  value = module.aws-ia_vpc.flow_log_destination
}