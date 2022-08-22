# defaults.tf sets defaults for complex object types
# https://github.com/aws-ia/standards-terraform/issues/13

locals {
  # defaults for var.vpc_flow_logs
  flow_logs_definition = {
    # defaults are null
    log_destination = try(var.vpc_flow_logs.log_destination, null)
    iam_role_arn    = try(var.vpc_flow_logs.iam_role_arn, null)
    # should this be removed?
    kms_key_id = try(var.vpc_flow_logs.kms_key_id, null)

    # sensiblie defaults that can all be overridden
    log_destination_type = var.vpc_flow_logs.log_destination_type == null ? "cloud-watch-logs" : var.vpc_flow_logs.log_destination_type
    retention_in_days    = try(var.vpc_flow_logs.retention_in_days, null)
    traffic_type         = var.vpc_flow_logs.traffic_type == null ? "ALL" : var.vpc_flow_logs.traffic_type
    destination_options = can(var.vpc_flow_logs.destination_options) ? {
      file_format                = "plain-text"
      hive_compatible_partitions = false
      per_hour_partition         = false
    } : var.vpc_flow_logs.destination_options
  }
}
