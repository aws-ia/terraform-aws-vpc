# terraform-aws-vpc v5 — Per-subnet-group Network ACLs

locals {
  network_acl_configs = {
    for group, subnet in var.subnets : group => {
      create      = subnet.network_acl.create
      id          = subnet.network_acl.id
      name_format = subnet.network_acl.name_format
      group_name  = coalesce(subnet.name_prefix, group)
      tags        = merge(subnet.tags, subnet.network_acl.tags)
      ingress     = subnet.network_acl.ingress
      egress      = subnet.network_acl.egress
    } if subnet.network_acl != null
  }
  network_acls_to_create = {
    for group, acl in local.network_acl_configs : group => acl if acl.create
  }
  network_acl_ids = {
    for group, acl in local.network_acl_configs : group => (
      acl.create ? aws_network_acl.this[group].id : acl.id
    )
  }
  network_acl_rules = merge([
    for group, acl in local.network_acl_configs : merge(
      {
        for rule_number, rule in acl.ingress : "${group}/ingress/${rule_number}" => merge(rule, {
          group       = group
          egress      = false
          rule_number = try(tonumber(rule_number), 0)
        })
      },
      {
        for rule_number, rule in acl.egress : "${group}/egress/${rule_number}" => merge(rule, {
          group       = group
          egress      = true
          rule_number = try(tonumber(rule_number), 0)
        })
      },
    )
  ]...)
  network_acl_associations = {
    for subnet_key, subnet in local.subnet_map : subnet_key => {
      group          = subnet.name
      network_acl_id = local.network_acl_ids[subnet.name]
      subnet_id      = local.subnet_ids[subnet_key]
    } if contains(keys(local.network_acl_configs), subnet.name)
  }
}

resource "aws_network_acl" "this" {
  for_each = local.network_acls_to_create

  vpc_id = local.vpc_id

  tags = merge(var.tags, each.value.tags, {
    Name = replace(replace(each.value.name_format, "{vpc}", var.vpc.name), "{group}", each.value.group_name)
  })
}

resource "aws_network_acl_rule" "this" {
  for_each = local.network_acl_rules

  network_acl_id = local.network_acl_ids[each.value.group]
  egress         = each.value.egress
  rule_number    = each.value.rule_number
  protocol       = each.value.protocol == "icmpv6" ? "58" : each.value.protocol
  rule_action    = each.value.action

  cidr_block      = each.value.cidr_block
  ipv6_cidr_block = each.value.ipv6_cidr_block
  from_port       = each.value.from_port
  to_port         = each.value.to_port
  icmp_type       = each.value.icmp_type
  icmp_code       = each.value.icmp_code
}

resource "aws_network_acl_association" "this" {
  for_each = local.network_acl_associations

  network_acl_id = each.value.network_acl_id
  subnet_id      = each.value.subnet_id
}
