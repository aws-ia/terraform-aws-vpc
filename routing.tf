# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Route Tables + Routes (Phase 2)
#
# Design: create one route table per subnet group/AZ, or inject one existing
# shared table for a group. Routes are co-located: each subnet group declares
# its routing intent and resources are materialized here from that declaration.
#
# Route keys follow the pattern: "name/az/destination" for stable identity.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Route Tables ──────────────────────────────────────────────────────────
# One per subnet group per AZ — enables per-AZ NAT routing without coupling.

resource "aws_route_table" "main" {
  for_each = local.route_table_map

  vpc_id = local.vpc_id

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.route_table_name
  })
}

# ─── Route Table Associations ──────────────────────────────────────────────
# Each subnet is associated with its group's AZ-specific route table.

resource "aws_route_table_association" "main" {
  for_each = local.subnet_map

  subnet_id      = local.subnet_ids[each.key]
  route_table_id = local.route_table_id_by_subnet[each.key]

  depends_on = [terraform_data.isolated_injected_route_table_validation]
}

# ─── Internet Gateway Routes ──────────────────────────────────────────────

resource "aws_route" "igw_ipv4" {
  for_each = local.routes_igw

  route_table_id         = each.value.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.igw_id
}

resource "aws_route" "igw_ipv6" {
  for_each = local.routes_igw_ipv6

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = local.igw_id
}

# ─── NAT Gateway Routes ───────────────────────────────────────────────────

resource "aws_route" "nat" {
  for_each = local.routes_nat

  route_table_id         = each.value.route_table_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = each.value.nat_gw_id
}

# DNS64 requires this more-specific NAT64 route in addition to enable_dns64.
resource "aws_route" "nat64" {
  for_each = local.routes_nat64

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = "64:ff9b::/96"
  nat_gateway_id              = each.value.nat_gw_id
}

# ─── Egress-Only IGW Routes (IPv6) ────────────────────────────────────────

resource "aws_route" "eigw" {
  for_each = local.routes_eigw

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = local.eigw_id
}

# ─── Generic caller-keyed routes ──────────────────────────────────────────

resource "aws_route" "custom" {
  for_each = local.routes_custom

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = each.value.destination.type == "ipv4_cidr" ? each.value.destination.value : null
  destination_ipv6_cidr_block = each.value.destination.type == "ipv6_cidr" ? each.value.destination.value : null
  destination_prefix_list_id  = each.value.destination.type == "prefix_list" ? each.value.destination.value : null

  vpc_peering_connection_id = each.value.target.type == "vpc_peering" ? each.value.target.id : null
  vpc_endpoint_id           = each.value.target.type == "vpc_endpoint" ? each.value.target.id : null
  network_interface_id      = each.value.target.type == "network_interface" ? each.value.target.id : null
  gateway_id                = each.value.target.type == "virtual_private_gateway" ? each.value.target.id : null
  local_gateway_id          = each.value.target.type == "local_gateway" ? each.value.target.id : null
  carrier_gateway_id        = each.value.target.type == "carrier_gateway" ? each.value.target.id : null
}

# This late-bound surface is intentionally terminal in the dependency graph:
# var.routes may reach only this resource and validation-only terraform_data
# resources. Do not feed it into subnets, route tables, or module outputs.
resource "aws_route" "top_level" {
  for_each = local.top_level_routes

  route_table_id              = each.value.route_table_id
  destination_cidr_block      = each.value.destination.type == "ipv4_cidr" ? each.value.destination.value : null
  destination_ipv6_cidr_block = each.value.destination.type == "ipv6_cidr" ? each.value.destination.value : null
  destination_prefix_list_id  = each.value.destination.type == "prefix_list" ? each.value.destination.value : null

  vpc_peering_connection_id = each.value.target_type == "vpc_peering" ? each.value.target_id : null
  vpc_endpoint_id           = each.value.target_type == "vpc_endpoint" ? each.value.target_id : null
  network_interface_id      = each.value.target_type == "network_interface" ? each.value.target_id : null
  gateway_id                = each.value.target_type == "virtual_private_gateway" ? each.value.target_id : null
  local_gateway_id          = each.value.target_type == "local_gateway" ? each.value.target_id : null
  carrier_gateway_id        = each.value.target_type == "carrier_gateway" ? each.value.target_id : null

  depends_on = [
    terraform_data.injected_route_table_identity_validation,
    terraform_data.isolated_injected_route_table_validation,
    terraform_data.route_table_routing_compatibility_validation,
    terraform_data.top_level_routes_validation,
  ]
}

# ─── Transit Gateway Routes ───────────────────────────────────────────────

resource "aws_route" "tgw" {
  for_each = local.routes_tgw

  route_table_id             = each.value.route_table_id
  destination_cidr_block     = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id = startswith(each.value.destination, "pl-") ? each.value.destination : null
  transit_gateway_id         = each.value.tgw_id

  depends_on = [terraform_data.attachment_contract_validation, aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route" "tgw_ipv6" {
  for_each = local.routes_tgw_ipv6

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id  = startswith(each.value.destination, "pl-") ? each.value.destination : null
  transit_gateway_id          = each.value.tgw_id

  depends_on = [terraform_data.attachment_contract_validation, aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route" "tgw_attachment" {
  for_each = local.routes_tgw_attachments

  route_table_id             = each.value.route_table_id
  destination_cidr_block     = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id = startswith(each.value.destination, "pl-") ? each.value.destination : null
  transit_gateway_id         = each.value.tgw_id

  depends_on = [terraform_data.attachment_contract_validation, aws_ec2_transit_gateway_vpc_attachment.this]
}

resource "aws_route" "tgw_attachment_ipv6" {
  for_each = local.routes_tgw_attachments_ipv6

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id  = startswith(each.value.destination, "pl-") ? each.value.destination : null
  transit_gateway_id          = each.value.tgw_id

  depends_on = [terraform_data.attachment_contract_validation, aws_ec2_transit_gateway_vpc_attachment.this]
}

# ─── Core Network Routes ──────────────────────────────────────────────────

resource "aws_route" "cwan" {
  for_each = local.routes_cwan

  route_table_id             = each.value.route_table_id
  destination_cidr_block     = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id = startswith(each.value.destination, "pl-") ? each.value.destination : null
  core_network_arn           = each.value.core_network_arn

  depends_on = [terraform_data.core_network_readiness]
}

resource "aws_route" "cwan_ipv6" {
  for_each = local.routes_cwan_ipv6

  route_table_id              = each.value.route_table_id
  destination_ipv6_cidr_block = startswith(each.value.destination, "pl-") ? null : each.value.destination
  destination_prefix_list_id  = startswith(each.value.destination, "pl-") ? each.value.destination : null
  core_network_arn            = each.value.core_network_arn

  depends_on = [terraform_data.core_network_readiness]
}
