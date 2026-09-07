# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — NAT Gateways + EIPs (Phase 2)
#
# Create-or-inject pattern:
#   - nat_gateway.existing_ids set → use existing NAT GWs (no EIP/NAT creation)
#   - nat_gateway.existing_ids null → create NAT GWs + EIPs per mode
#
# EIP sourcing: create (new) | byoip_pool (BYO pool) | existing (allocation_ids)
# Connectivity type: public (default) | private (no EIP needed)
# Availability mode: zonal resources use "nat/<az>"; regional uses "nat/regional".
# ─────────────────────────────────────────────────────────────────────────────

# ─── Elastic IPs for NAT Gateways ─────────────────────────────────────────
# Created only for public NAT in module-owned EIP modes:
#   - zonal eip.mode = "create" or "byoip_pool"
#   - regional eip.mode = "byoip_pool" (manual address mode)
# Regional eip.mode = "create" delegates IP/AZ management to AWS; existing mode
# always keeps EIP lifecycle caller-owned.

resource "aws_eip" "nat" {
  for_each = local.nat_eips_to_create

  domain           = "vpc"
  public_ipv4_pool = var.nat_gateway.eip.public_ipv4_pool

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })
}

# ─── NAT Gateways ─────────────────────────────────────────────────────────
# Created only when existing_ids is not set (create mode). Zonal Gateways use
# nat_gateway.subnet_group or the documented first-compatible-group fallback.
# Regional creates one VPC-level Gateway with no host subnet.

resource "aws_nat_gateway" "main" {
  for_each = local.nat_gateways_to_create

  allocation_id     = each.value.allocation_id
  availability_mode = each.value.availability_mode
  connectivity_type = each.value.connectivity_type
  subnet_id         = each.value.subnet_id
  vpc_id            = each.value.vpc_id

  dynamic "availability_zone_address" {
    for_each = each.value.availability_zone_addresses

    content {
      allocation_ids    = availability_zone_address.value
      availability_zone = availability_zone_address.key
    }
  }

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.name
  })

  depends_on = [aws_internet_gateway.main]
}

# ─── Egress-Only Internet Gateway (IPv6) ──────────────────────────────────
# Created when any subnet has routing.egress_only_igw = true.

resource "aws_egress_only_internet_gateway" "main" {
  count = local.create_eigw ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, var.vpc.eigw_tags, {
    Name = replace(var.vpc.eigw_name_format, "{vpc}", var.vpc.name)
  })
}
