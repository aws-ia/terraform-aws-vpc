# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Native VPC Flow Logs (Phase 3)
#
# The module can create or inject the CloudWatch destination and delivery role.
# S3 and Kinesis Data Firehose destinations are external resources injected by
# ARN so their lifecycle, retention, encryption, and ownership remain explicit.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  enabled_flow_logs = {
    for name, cfg in var.flow_logs : name => cfg if cfg.enabled
  }
  flow_logs_to_create = {
    for name, cfg in local.enabled_flow_logs : name => cfg if cfg.create
  }
  flow_log_ids = {
    for name, cfg in local.enabled_flow_logs : name => (
      cfg.create ? aws_flow_log.this[name].id : cfg.id
    )
  }

  cloudwatch_destinations_to_create = {
    for name, cfg in local.flow_logs_to_create : name => cfg
    if cfg.destination_type == "cloudwatch" && cfg.create_destination
  }

  cloudwatch_roles_to_create = {
    for name, cfg in local.flow_logs_to_create : name => cfg
    if cfg.destination_type == "cloudwatch" && cfg.create_iam_role
  }

  resource_name_base = replace(var.vpc.name, "/[^A-Za-z0-9_.-]/", "-")

  # Name tags are controlled exclusively by typed formats. An empty format
  # removes caller-supplied Name keys; provider default_tags remain provider-owned.
  flow_log_name_tags = {
    for name, cfg in local.enabled_flow_logs : name => cfg.name_format == "" ? {} : {
      Name = replace(replace(cfg.name_format, "{vpc}", var.vpc.name), "{key}", name)
    }
  }
  cloudwatch_log_group_name_tags = {
    for name, cfg in local.cloudwatch_destinations_to_create : name => (
      cfg.cloudwatch_options.name_format == null ? cfg.name_format : cfg.cloudwatch_options.name_format
      ) == "" ? {} : {
      Name = replace(replace(
        cfg.cloudwatch_options.name_format == null ? cfg.name_format : cfg.cloudwatch_options.name_format,
        "{vpc}", var.vpc.name,
      ), "{key}", name)
    }
  }

  flow_log_destination_arns = {
    for name, cfg in local.enabled_flow_logs : name => (
      !cfg.create ? cfg.destination_arn :
      cfg.destination_type != "cloudwatch" ? cfg.destination_arn :
      cfg.create_destination
      ? aws_cloudwatch_log_group.flow_logs[name].arn
      : cfg.destination_arn
    )
  }

  flow_log_role_arns = {
    for name, cfg in local.enabled_flow_logs : name => (
      !cfg.create ? cfg.iam_role_arn :
      cfg.destination_type != "cloudwatch" ? null :
      cfg.create_iam_role ? aws_iam_role.flow_logs[name].arn :
      cfg.iam_role_arn
    )
  }
}

# ─── CloudWatch destination and VPC Flow Logs delivery role ───────────────

resource "aws_cloudwatch_log_group" "flow_logs" {
  for_each = local.cloudwatch_destinations_to_create

  name              = coalesce(each.value.cloudwatch_options.name, "/aws/vpc-flow-logs/${local.resource_name_base}/${local.vpc_id}/${each.key}")
  retention_in_days = each.value.cloudwatch_options.retention_in_days
  kms_key_id        = each.value.cloudwatch_options.kms_key_id

  tags = merge(
    { for key, value in merge(var.tags, each.value.tags) : key => value if key != "Name" },
    local.cloudwatch_log_group_name_tags[each.key],
  )
}

resource "aws_iam_role" "flow_logs" {
  for_each = local.cloudwatch_roles_to_create

  name_prefix = each.value.role_name_prefix != null ? each.value.role_name_prefix : substr("${local.resource_name_base}-${each.key}-flow-", 0, 38)
  description = "Allows VPC Flow Logs to publish ${var.vpc.name}/${each.key} logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current[0].account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current[0].partition}:ec2:${data.aws_region.current[0].region}:${data.aws_caller_identity.current[0].account_id}:vpc-flow-log/*"
        }
      }
    }]
  })

  permissions_boundary = each.value.role_permissions_boundary
  tags                 = merge(var.tags, each.value.tags)
}

resource "aws_iam_role_policy" "flow_logs" {
  for_each = local.cloudwatch_roles_to_create

  name = "publish-vpc-flow-logs"
  role = aws_iam_role.flow_logs[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublishToLogGroup"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ]
        Resource = "${local.flow_log_destination_arns[each.key]}:*"
      },
      {
        Sid      = "DescribeLogGroups"
        Effect   = "Allow"
        Action   = "logs:DescribeLogGroups"
        Resource = "*"
      }
    ]
  })
}

# ─── VPC Flow Logs ────────────────────────────────────────────────────────

resource "aws_flow_log" "this" {
  for_each = local.flow_logs_to_create

  vpc_id          = local.vpc_id
  traffic_type    = each.value.traffic_type
  log_destination = local.flow_log_destination_arns[each.key]
  log_destination_type = (
    each.value.destination_type == "cloudwatch" ? "cloud-watch-logs" :
    each.value.destination_type == "s3" ? "s3" :
    "kinesis-data-firehose"
  )
  iam_role_arn               = local.flow_log_role_arns[each.key]
  deliver_cross_account_role = each.value.deliver_cross_account_role_arn
  log_format                 = each.value.log_format
  max_aggregation_interval   = each.value.max_aggregation_interval

  dynamic "destination_options" {
    for_each = each.value.destination_type == "s3" ? [each.value.s3_options] : []

    content {
      file_format                = destination_options.value.file_format
      hive_compatible_partitions = destination_options.value.hive_compatible_partitions
      per_hour_partition         = destination_options.value.per_hour_partition
    }
  }

  tags = merge(
    { for key, value in merge(var.tags, each.value.tags) : key => value if key != "Name" },
    local.flow_log_name_tags[each.key],
  )

  lifecycle {
    precondition {
      condition = (
        each.value.destination_type != "cloudwatch" ||
        local.flow_log_role_arns[each.key] != null
      )
      error_message = "CloudWatch flow logs require an IAM role; provide iam_role_arn or allow the module to create it."
    }
  }

  depends_on = [aws_iam_role_policy.flow_logs]
}
