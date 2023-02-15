locals {
  # does log destination need to be created?
  create_flow_log_destination = (var.flow_log_definition.log_destination == null && var.flow_log_definition.log_destination_type != "none") ? true : false

  # which log destination to use
  log_destination = local.create_flow_log_destination ? (
    var.flow_log_definition.log_destination_type == "cloud-watch-logs" ? module.cloudwatch_log_group[0].log_group.arn : module.s3_log_bucket[0].bucket_flow_logs_attributes.arn # change to s3 when implemented
  ) : var.flow_log_definition.log_destination

  # Use IAM from submodule if if not passed
  iam_role_arn = local.create_flow_log_destination ? (
    var.flow_log_definition.log_destination_type == "cloud-watch-logs" ? module.cloudwatch_log_group[0].iam_role.arn : null # s3: unnecessary, svc creates its own bucket policy
  ) : var.flow_log_definition.iam_role_arn
}

module "cloudwatch_log_group" {
  # if create destination and type = cloud-watch-logs
  count   = (local.create_flow_log_destination && var.flow_log_definition.log_destination_type == "cloud-watch-logs") ? 1 : 0
  source  = "aws-ia/cloudwatch-log-group/aws"
  version = "1.0.0"

  name                  = var.name
  retention_in_days     = var.flow_log_definition.retention_in_days == null ? 180 : var.flow_log_definition.retention_in_days
  kms_key_id            = var.flow_log_definition.kms_key_id
  aws_service_principal = "vpc-flow-logs.amazonaws.com"
  tags                  = var.tags
}

module "s3_log_bucket" {
  # if create destination and type = s3
  count  = (local.create_flow_log_destination && var.flow_log_definition.log_destination_type == "s3") ? 1 : 0
  source = "./modules/s3_log_bucket"

  name = var.name
}

resource "aws_flow_log" "main" {
  log_destination      = local.log_destination
  iam_role_arn         = local.iam_role_arn
  log_destination_type = var.flow_log_definition.log_destination_type
  traffic_type         = var.flow_log_definition.traffic_type
  vpc_id               = var.vpc_id

  dynamic "destination_options" {
    for_each = var.flow_log_definition.log_destination_type == "s3" ? [true] : []

    content {
      file_format                = var.flow_log_definition.destination_options.file_format
      per_hour_partition         = var.flow_log_definition.destination_options.per_hour_partition
      hive_compatible_partitions = var.flow_log_definition.destination_options.hive_compatible_partitions
    }
  }

  tags = merge(
    { Name = var.name },
    var.tags
  )
}
