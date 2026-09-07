# terraform-aws-vpc v5 — opt-in adoption of AWS-created default resources
#
# AWS creates these resources with every VPC. The provider resources adopt them
# by ID and reconcile their mutable rules/routes; they do not create replacements.

data "aws_security_group" "default" {
  for_each = local.create_vpc ? {} : { default = true }

  name   = "default"
  vpc_id = local.vpc_id
}

data "aws_network_acls" "default" {
  for_each = local.create_vpc ? {} : { default = true }

  vpc_id = local.vpc_id

  filter {
    name   = "default"
    values = ["true"]
  }
}

data "aws_route_table" "default" {
  for_each = local.create_vpc ? {} : { default = true }

  vpc_id = local.vpc_id

  filter {
    name   = "association.main"
    values = ["true"]
  }
}

locals {
  default_security_group_id = local.create_vpc ? aws_vpc.main[0].default_security_group_id : data.aws_security_group.default["default"].id
  default_network_acl_id    = local.create_vpc ? aws_vpc.main[0].default_network_acl_id : one(data.aws_network_acls.default["default"].ids)
  default_route_table_id    = local.create_vpc ? aws_vpc.main[0].default_route_table_id : data.aws_route_table.default["default"].id
  main_route_table_id       = local.create_vpc ? aws_vpc.main[0].main_route_table_id : data.aws_vpc.existing[0].main_route_table_id

  default_resource_names = {
    security_group = replace(replace(var.default_resources.name_format, "{vpc}", var.vpc.name), "{resource}", "default-security-group")
    network_acl    = replace(replace(var.default_resources.name_format, "{vpc}", var.vpc.name), "{resource}", "default-network-acl")
    route_table    = replace(replace(var.default_resources.name_format, "{vpc}", var.vpc.name), "{resource}", "default-route-table")
  }
}

resource "aws_default_security_group" "this" {
  for_each = var.default_resources.manage_security_group ? { default = true } : {}

  vpc_id  = local.vpc_id
  ingress = []
  egress  = []

  tags = merge(var.tags, var.default_resources.tags, {
    Name = local.default_resource_names.security_group
  })
}

resource "aws_default_network_acl" "this" {
  for_each = var.default_resources.manage_network_acl ? { default = true } : {}

  default_network_acl_id = local.default_network_acl_id

  tags = merge(var.tags, var.default_resources.tags, {
    Name = local.default_resource_names.network_acl
  })
}

resource "aws_default_route_table" "this" {
  for_each = var.default_resources.manage_route_table ? { default = true } : {}

  default_route_table_id = local.default_route_table_id
  propagating_vgws       = []
  route                  = []

  tags = merge(var.tags, var.default_resources.tags, {
    Name = local.default_resource_names.route_table
  })
}
