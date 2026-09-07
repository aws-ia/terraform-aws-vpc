# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — VPC Block Public Access and DHCP options
# ─────────────────────────────────────────────────────────────────────────────

locals {
  vpc_block_public_access_options_id = !var.vpc_block_public_access.enabled ? null : (
    var.vpc_block_public_access.create
    ? try(aws_vpc_block_public_access_options.this[0].id, null)
    : var.vpc_block_public_access.id
  )

  vpc_block_public_access_exclusions_to_create = {
    for name, exclusion in var.vpc_block_public_access.exclusions : name => exclusion
    if var.vpc_block_public_access.enabled && exclusion.create
  }

  vpc_block_public_access_exclusion_ids = !var.vpc_block_public_access.enabled ? {} : {
    for name, exclusion in var.vpc_block_public_access.exclusions : name => (
      exclusion.create
      ? aws_vpc_block_public_access_exclusion.this[name].id
      : exclusion.id
    )
  }

  dhcp_options_id = !var.dhcp_options.enabled ? null : (
    var.dhcp_options.create
    ? try(aws_vpc_dhcp_options.this[0].id, null)
    : var.dhcp_options.id
  )
}

resource "aws_vpc_block_public_access_options" "this" {
  count = var.vpc_block_public_access.enabled && var.vpc_block_public_access.create ? 1 : 0

  internet_gateway_block_mode = var.vpc_block_public_access.internet_gateway_block_mode
}

resource "aws_vpc_block_public_access_exclusion" "this" {
  for_each = local.vpc_block_public_access_exclusions_to_create

  internet_gateway_exclusion_mode = each.value.internet_gateway_exclusion_mode
  vpc_id                          = each.value.target == "vpc" ? local.vpc_id : null
  subnet_id = each.value.target == "subnet" ? (
    each.value.subnet_key != null
    ? try(local.subnet_ids[each.value.subnet_key], null)
    : each.value.subnet_id
  ) : null

  tags = merge(var.tags, each.value.tags, {
    Name = "${var.vpc.name}-${each.key}-bpa-exclusion"
  })

  lifecycle {
    precondition {
      condition = each.value.target != "subnet" || each.value.subnet_key == null || contains(
        keys(local.subnet_map),
        each.value.subnet_key,
      )
      error_message = "BPA exclusion '${each.key}' references an unknown subnet_key. Use the stable '<group>/<az>' key."
    }
  }

  depends_on = [aws_vpc_block_public_access_options.this]
}

resource "aws_vpc_dhcp_options" "this" {
  count = var.dhcp_options.enabled && var.dhcp_options.create ? 1 : 0

  domain_name                       = var.dhcp_options.domain_name
  domain_name_servers               = var.dhcp_options.domain_name_servers
  ntp_servers                       = var.dhcp_options.ntp_servers
  netbios_name_servers              = var.dhcp_options.netbios_name_servers
  netbios_node_type                 = var.dhcp_options.netbios_node_type
  ipv6_address_preferred_lease_time = var.dhcp_options.ipv6_address_preferred_lease_time

  tags = merge(var.tags, var.dhcp_options.tags, {
    Name = "${var.vpc.name}-dhcp-options"
  })
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.dhcp_options.enabled ? 1 : 0

  vpc_id          = local.vpc_id
  dhcp_options_id = local.dhcp_options_id
}
