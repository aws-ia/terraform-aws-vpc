# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Core Resources (main.tf)
#
# Phase 1: VPC (create-or-inject) + addressing + subnets + IGW
# All for_each keys follow "name/az" pattern — deterministic and rename-safe.
# ─────────────────────────────────────────────────────────────────────────────

# ─── Data Sources ──────────────────────────────────────────────────────────

data "aws_availability_zones" "current" {
  count = var.availability_zones.names == null ? 1 : 0

  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# For inject mode: read existing VPC to get its CIDR
data "aws_vpc" "existing" {
  count = var.vpc.create ? 0 : 1
  id    = var.vpc.id
}

# A managed VPC may inject pre-existing secondary associations during migration.
# The explicit create flag keeps this lookup cardinality plan-known.
data "aws_vpc" "managed_ipv6_associations" {
  count = var.vpc.create && (
    length(local.injected_secondary_ipv4_cidrs) > 0 ||
    length(local.injected_secondary_ipv6_cidrs) > 0
  ) ? 1 : 0
  id = local.vpc_id
}

data "aws_subnet" "existing" {
  for_each = local.subnets_to_inject

  id = each.value.existing_id
}

# Scalar account identity for constructed Cloud WAN/VPC ARNs. The attachment
# never consumes the full existing-VPC data object, avoiding unknown propagation.
data "aws_caller_identity" "current" {
  count = local.core_network_group != null || length(local.cloudwatch_roles_to_create) > 0 ? 1 : 0
}

# ─── VPC ───────────────────────────────────────────────────────────────────
# create-or-inject: vpc.id == null → create; vpc.id set → use existing

resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  # Primary IPv4: static CIDR or IPAM. IPv6 is always a secondary association.
  cidr_block          = var.addressing.primary.cidr_block
  ipv4_ipam_pool_id   = var.addressing.primary.ipam_pool_id
  ipv4_netmask_length = var.addressing.primary.netmask_length

  instance_tenancy     = var.vpc.instance_tenancy
  enable_dns_hostnames = var.vpc.dns.enable_hostnames
  enable_dns_support   = var.vpc.dns.enable_support

  tags = merge(var.tags, var.vpc.tags, {
    Name = var.vpc.name
  })

  lifecycle {
    # A v4-created VPC stores IPv6 association arguments in this resource state.
    # v5 transfers that association to a standalone keyed resource. Ignoring the
    # legacy embedded fields prevents the provider from disassociating the live
    # prefix while the declarative import transfers Terraform ownership.
    ignore_changes = [
      assign_generated_ipv6_cidr_block,
      ipv6_cidr_block,
      ipv6_ipam_pool_id,
      ipv6_netmask_length,
    ]

    precondition {
      condition = (
        var.addressing.primary.cidr_block != null || var.addressing.primary.ipam_pool_id != null
      )
      error_message = "When creating a VPC, addressing.primary requires either cidr_block or ipam_pool_id."
    }
  }
}

# ─── Secondary IPv4 CIDRs ─────────────────────────────────────────────────
# Supports multiple secondary CIDRs, each via static CIDR or IPAM.

resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  for_each = local.secondary_ipv4_cidrs_to_create

  vpc_id              = local.vpc_id
  cidr_block          = each.value.cidr_block
  ipv4_ipam_pool_id   = each.value.ipam_pool_id
  ipv4_netmask_length = each.value.netmask_length
}

# IPv6 is always represented as a caller-keyed secondary VPC association.
resource "aws_vpc_ipv6_cidr_block_association" "secondary" {
  for_each = local.secondary_ipv6_cidrs_to_create

  vpc_id                           = local.vpc_id
  assign_generated_ipv6_cidr_block = each.value.amazon_assigned ? true : null
  ipv6_cidr_block                  = each.value.cidr_block
  ipv6_ipam_pool_id                = each.value.ipam_pool_id
  ipv6_netmask_length              = each.value.netmask_length
}

# ─── Internet Gateway — create-or-inject ─────────────────────────
# Created only when needed (subnets with IGW routing) and not injected.

resource "terraform_data" "igw_injection_validation" {
  count = local.needs_igw && !var.vpc.igw_create ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.vpc.igw_id != null && length(trimspace(var.vpc.igw_id)) > 0
      error_message = "Internet routing requires either vpc.igw_create=true or vpc.igw_create=false with an injected igw_id."
    }
  }
}

resource "aws_internet_gateway" "main" {
  count = local.create_igw ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, var.vpc.igw_tags, {
    Name = replace(var.vpc.igw_name_format, "{vpc}", var.vpc.name)
  })
}

# ─── Subnets ──────────────────────────────────────────────────────────────
# Single resource with unified for_each over "name/az" keys.
# Eliminates separate aws_subnet.public, .private, .tgw, .cwan resources.

resource "aws_subnet" "main" {
  for_each = local.subnets_to_create

  vpc_id            = local.vpc_id
  availability_zone = each.value.az

  # IPv4 addressing: explicit CIDR or IPAM
  cidr_block          = each.value.cidr_block
  ipv4_ipam_pool_id   = each.value.ipam_pool_id
  ipv4_netmask_length = each.value.netmask_length

  # IPv6
  ipv6_cidr_block                 = each.value.ipv6_cidr
  ipv6_ipam_pool_id               = each.value.ipv6_ipam_pool_id
  ipv6_netmask_length             = each.value.ipv6_netmask_length
  ipv6_native                     = each.value.ipv6_native
  assign_ipv6_address_on_creation = each.value.assign_ipv6

  # Public IP auto-assignment (public role only)
  map_public_ip_on_launch = each.value.map_public_ip

  # DNS64 support for NAT64 (IPv6 → IPv4 translation via NAT GW)
  enable_dns64 = each.value.routing.dns64

  # EC2 rejects false for IPv6-native subnets because they have no IPv4 CIDR.
  enable_resource_name_dns_aaaa_record_on_launch = each.value.ipv6_native ? true : null

  tags = merge(var.tags, each.value.tags, {
    Name = each.value.resource_name
  })

  depends_on = [
    aws_vpc_ipv4_cidr_block_association.secondary,
    aws_vpc_ipv6_cidr_block_association.secondary,
    terraform_data.subnet_secondary_cidr_validation,
    terraform_data.subnet_ipv6_secondary_cidr_validation,
  ]

  lifecycle {
    # A configured calculated source counts as addressing while its provider-
    # derived parent is unknown; the family-specific checks reject calculation
    # failure once that parent resolves.
    precondition {
      condition = (
        each.value.cidr_block != null || each.value.ipam_pool_id != null ||
        each.value.ipv6_cidr != null || each.value.ipv6_ipam_pool_id != null ||
        try(var.subnets[each.value.name].ipv4.netmask, null) != null ||
        contains(keys(local.subnets_with_calculated_ipv6), each.value.name)
      )
      error_message = "Subnet '${each.key}': must have an IPv4 or IPv6 CIDR source."
    }

    precondition {
      condition = (
        try(var.subnets[each.value.name].ipv4.netmask, null) == null ||
        each.value.cidr_block != null
      )
      error_message = "Subnet '${each.key}': calculated IPv4 CIDR does not fit its selected parent; refusing to use the parent CIDR as a subnet."
    }

    precondition {
      condition = (
        !contains(keys(local.subnets_with_calculated_ipv6), each.value.name) ||
        each.value.ipv6_cidr != null
      )
      error_message = "Subnet '${each.key}': calculated IPv6 /64 does not fit its selected parent; refusing to use the parent CIDR as a subnet."
    }
  }
}

# ─── Injected subnet and secondary-CIDR selectors ────────────────────────
resource "terraform_data" "subnet_existing_ids_validation" {
  for_each = {
    for name, cfg in var.subnets : name => cfg if !cfg.create
  }

  lifecycle {
    precondition {
      condition     = toset(keys(each.value.existing_ids)) == toset(local.azs)
      error_message = "Injected subnet group '${each.key}' existing_ids keys must exactly match configured AZs [${join(", ", local.azs)}]; received [${join(", ", sort(keys(each.value.existing_ids)))}]."
    }
  }
}

resource "terraform_data" "subnet_secondary_cidr_validation" {
  # Family-block presence determines cardinality; selector values may be unknown
  # without making for_each unknown.
  for_each = {
    for key, subnet in local.subnet_map : key => subnet
    if var.subnets[subnet.name].ipv4 != null
  }

  input = try(local.secondary_ipv4_cidr_association_ids[each.value.secondary_cidr_key], null)

  lifecycle {
    precondition {
      condition = (
        each.value.secondary_cidr_key == null ||
        contains(keys(local.secondary_ipv4_cidrs), each.value.secondary_cidr_key)
      )
      error_message = "Subnet '${each.key}' references an unknown IPv4 secondary CIDR key."
    }

    precondition {
      condition = (
        each.value.cidr_block == null ||
        try(local.explicit_ipv4_cidrs_within_parent[each.key], false)
      )
      error_message = "Subnet '${each.key}' IPv4 CIDR must be contained in its selected primary or secondary VPC CIDR block."
    }
  }
}

resource "terraform_data" "subnet_ipv6_secondary_cidr_validation" {
  # Every IPv6 block requires a selector, but its value may resolve at apply.
  for_each = {
    for key, subnet in local.subnet_map : key => subnet
    if var.subnets[subnet.name].ipv6 != null
  }

  input = try(local.secondary_ipv6_cidr_association_ids[each.value.ipv6_secondary_cidr_key], null)

  lifecycle {
    precondition {
      condition = (
        each.value.ipv6_secondary_cidr_key != null &&
        contains(keys(local.secondary_ipv6_cidrs), each.value.ipv6_secondary_cidr_key)
      )
      error_message = "Subnet '${each.key}' must reference an existing IPv6 secondary CIDR key."
    }

    precondition {
      condition = (
        each.value.ipv6_cidr == null ||
        try(local.explicit_ipv6_cidrs_within_parent[each.key], false)
      )
      error_message = "Subnet '${each.key}' IPv6 CIDR must be contained in the addressing.secondary IPv6 block selected by secondary_cidr_key."
    }
  }
}

# ─── AZ count discovery must satisfy the requested cardinality ──────────
resource "terraform_data" "availability_zone_count_validation" {
  count = var.availability_zones.count != null ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.discovered_azs) >= var.availability_zones.count
      error_message = "availability_zones.count requests ${var.availability_zones.count} AZs, but only ${length(local.discovered_azs)} eligible AZs were discovered."
    }
  }
}

# ─── VPC/subnet IPv6 contract validation ─────────────────────────────────
resource "terraform_data" "subnet_ipv6_vpc_validation" {
  count = anytrue([for name, cfg in var.subnets : cfg.ipv6 != null]) && length(local.secondary_ipv6_cidrs) == 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.secondary_ipv6_cidrs) > 0
      error_message = "Subnet IPv6 addressing requires at least one addressing.secondary entry with the ipv6 family."
    }
  }
}

resource "terraform_data" "injected_ipv6_association_validation" {
  for_each = local.injected_secondary_ipv6_cidrs

  input = local.secondary_ipv6_cidr_blocks[each.key]

  lifecycle {
    precondition {
      condition     = local.secondary_ipv6_cidr_blocks[each.key] != null
      error_message = "addressing.secondary['${each.key}'].ipv6.association_id does not identify an associated IPv6 CIDR on the VPC."
    }
  }
}

# ─── NAT Gateway precondition resource ───────────────────────────
# Validates that nat_gateway.az is within the resolved AZ list.
# Uses a null_resource with precondition because this is a cross-variable
# invariant that cannot be enforced in variable validation blocks.
# Precondition on resource ensures evaluation even with unknown AZ names.

resource "terraform_data" "nat_gateway_az_validation" {
  count = var.nat_gateway.mode == "single_az" ? 1 : 0

  lifecycle {
    precondition {
      condition     = contains(local.azs, var.nat_gateway.az)
      error_message = "nat_gateway.az '${var.nat_gateway.az}' is not in the configured availability zones (${join(", ", local.azs)}). The NAT Gateway AZ must be one of the AZs where subnets are created."
    }
  }
}

# ─── Calculated CIDR pinning must not overlap across netmasks ─────────────
resource "terraform_data" "cidr_pinning_validation" {
  count = length(local.subnets_with_netmask) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.calculated_subnet_az_capacity >= length(local.azs)
      error_message = "calculated_subnet_az_capacity must be greater than or equal to the number of configured Availability Zones."
    }

    precondition {
      condition     = length(local.pinned_group_overlap_pairs) == 0
      error_message = "Pinned subnet CIDR ranges overlap across netmasks (${join(", ", local.pinned_group_overlap_pairs)}). Choose non-overlapping ipv4.cidr_index values or use explicit CIDRs."
    }

    precondition {
      condition     = length(local.invalid_calculated_ipv4_keys) == 0
      error_message = "Calculated IPv4 CIDRs do not fit the parent VPC prefix for subnet groups: ${join(", ", local.invalid_calculated_ipv4_keys)}. Increase the child prefix, reduce cidr_index, or use explicit cidrs_by_az."
    }

    precondition {
      condition     = length(local.capacity_exceeded_ipv4_groups) == 0
      error_message = "Calculated IPv4 reservations exceed VPC capacity for subnet groups: ${join(", ", local.capacity_exceeded_ipv4_groups)}. The highest cidr_index reservation must fit inside the parent CIDR."
    }
  }
}

resource "terraform_data" "ipv6_cidr_calculation_validation" {
  count = length(local.subnets_with_calculated_ipv6) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.invalid_calculated_ipv6_keys) == 0
      error_message = "Calculated IPv6 /64 CIDRs do not fit the selected VPC association for subnet groups: ${join(", ", local.invalid_calculated_ipv6_keys)}. Select a sufficiently large association or use explicit cidrs_by_az."
    }
  }
}

# ─── NAT Gateway placement validation ────────────────────
# Only created NAT Gateways need a host subnet. Explicit subnet_group is
# validated for existence and semantic compatibility; null uses the documented
# first-compatible-group fallback.

resource "terraform_data" "nat_gateway_subnet_group_validation" {
  count = var.nat_gateway.mode != "none" && var.nat_gateway.mode != "regional" && !local.nat_inject_mode ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.nat_host_group != null && try(contains(keys(var.subnets), local.nat_host_group), false)
      error_message = "nat_gateway.subnet_group must reference an existing subnet group. No compatible default group was found for connectivity_type='${var.nat_gateway.connectivity_type}'."
    }

    precondition {
      condition = try(var.subnets[local.nat_host_group].role, null) == (
        var.nat_gateway.connectivity_type == "private" ? "private" : "public"
      )
      error_message = "nat_gateway.subnet_group '${local.nat_host_group}' must have role '${var.nat_gateway.connectivity_type == "private" ? "private" : "public"}' for connectivity_type='${var.nat_gateway.connectivity_type}'."
    }
  }
}

# ─── Precondition: routing.nat_gateway=true requires nat_gateway.mode != none ─
# Catches the misconfiguration where a subnet requests NAT routing but no NAT
# Gateways are configured. Fires at plan time.

resource "terraform_data" "nat_routing_requires_nat_gateway" {
  count = var.nat_gateway.mode == "none" && anytrue([
    for k, v in var.subnets : try(v.routing.nat_gateway, false)
  ]) ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.nat_gateway.mode != "none"
      error_message = "One or more subnet groups have routing.nat_gateway = true, but nat_gateway.mode = 'none'. Set nat_gateway.mode to 'single_az', 'all_azs', or 'regional', or remove the NAT routing from subnets: ${join(", ", [for k, v in var.subnets : k if try(v.routing.nat_gateway, false)])}."
    }
  }
}

# ─── Precondition: DNS64 requires a NAT Gateway for NAT64 ────────────────
resource "terraform_data" "dns64_requires_nat_gateway" {
  count = var.nat_gateway.mode == "none" && anytrue([
    for k, v in var.subnets : try(v.routing.dns64, false)
  ]) ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.nat_gateway.mode != "none"
      error_message = "One or more subnet groups enable routing.dns64, but nat_gateway.mode = 'none'. DNS64 requires a NAT Gateway and the managed 64:ff9b::/96 NAT64 route."
    }
  }
}

# ─── Injected route-table physical identity ──────────────────────────────
resource "terraform_data" "injected_route_table_identity_validation" {
  count = length(local.injected_route_table_ids_by_key) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition = alltrue([
        for key, groups in local.injected_route_table_groups_by_key :
        length(distinct([for group in groups : var.subnets[group].route_table_id])) == 1
      ])
      error_message = "All subnet groups sharing one route_table_key must use the same route_table_id."
    }

    precondition {
      condition     = length(distinct(values(local.injected_route_table_ids_by_key))) == length(local.injected_route_table_ids_by_key)
      error_message = "One injected route_table_id cannot use multiple route_table_key values; reuse the same physical identity key across groups."
    }
  }
}

resource "terraform_data" "isolated_injected_route_table_validation" {
  input = local.isolated_injected_route_tables_without_opt_in

  lifecycle {
    precondition {
      condition     = length(local.isolated_injected_route_tables_without_opt_in) == 0
      error_message = "role='isolated' with manage_route_table=false requires isolated_accepts_uninspected_route_table=true. The AWS provider omits route classes from its route-table data source, so the module cannot guarantee isolation for an unmanaged table. Caller opt-in accepts responsibility for every existing and future route. Affected subnet groups: ${join(", ", sort(keys(local.isolated_injected_route_tables_without_opt_in)))}."
    }
  }
}

# ─── Shared injected route table cannot select a per-AZ NAT target ────────
resource "terraform_data" "route_table_routing_compatibility_validation" {
  input = {
    destination_conflicts    = local.route_destination_conflicts
    generic_route_collisions = local.generic_route_destination_collisions
    isolated_conflicts       = local.isolated_shared_route_table_conflicts
  }

  lifecycle {
    precondition {
      condition     = length(local.isolated_shared_route_table_conflicts) == 0
      error_message = "An isolated subnet group may share an injected route table only with groups whose effective routing is also isolated. Conflicting route_table_key values: ${join(", ", sort(keys(local.isolated_shared_route_table_conflicts)))}. Gateway endpoint associations remain allowed."
    }

    precondition {
      condition     = length(local.route_destination_conflicts) == 0
      error_message = "Each physical route table may have at most one target per destination. Conflicts: ${join(", ", flatten([for key, destinations in local.route_destination_conflicts : [for destination in destinations : "${key}=${destination}"]]))}."
    }

    precondition {
      condition     = length(local.duplicate_generic_route_keys_by_table) == 0
      error_message = "Generic route keys are state identity and must be unique per physical injected route table. Duplicates: ${join(", ", flatten([for key, route_keys in local.duplicate_generic_route_keys_by_table : [for route_key in route_keys : "${key}=${route_key}"]]))}."
    }

    precondition {
      condition = length(local.generic_route_destination_collisions) == 0
      error_message = "Generic route destinations must be unique per physical route table. Collisions: ${join("; ", flatten([
        for table_key, destinations in local.generic_route_destination_collisions : [
          for destination, sources in destinations : "${table_key} ${destination}: ${join(" vs ", sources)}"
        ]
      ]))}."
    }
  }
}

resource "terraform_data" "top_level_routes_validation" {
  input = {
    gateway_endpoint_coexistence_conflicts = local.top_level_route_gateway_endpoint_coexistence_conflicts
    invalid_groups                         = local.invalid_top_level_route_groups
    isolation_conflicts                    = local.top_level_route_isolation_conflicts
    middlebox_subnet_cidr_conflicts        = local.top_level_route_middlebox_subnet_cidr_conflicts
    missing_azs                            = local.top_level_route_missing_azs
    shared_table_zonal_target_conflicts    = local.top_level_route_shared_table_zonal_target_conflicts
  }

  lifecycle {
    precondition {
      condition     = length(local.invalid_top_level_route_groups) == 0
      error_message = "Top-level routes reference unknown from_group values: ${join(", ", [for route_key, group in local.invalid_top_level_route_groups : "${route_key}=${group}"])}. Declare each group in var.subnets."
    }

    precondition {
      condition     = length(local.top_level_route_missing_azs) == 0
      error_message = "Top-level routes using ids_by_az must provide a target for every AZ in from_group. Missing AZs: ${join(", ", [for route_key, azs in local.top_level_route_missing_azs : "${route_key}=[${join(", ", azs)}]"])}."
    }

    precondition {
      condition = length(local.top_level_route_middlebox_subnet_cidr_conflicts) == 0
      error_message = "Top-level middlebox routes that are more specific than the VPC local route must exactly match a module-managed subnet CIDR. Conflicts: ${join(", ", [
        for route_key, conflict in local.top_level_route_middlebox_subnet_cidr_conflicts :
        "${route_key}=${conflict.destination} overlaps [${join(", ", conflict.managed_subnets)}]"
      ])}."
    }

    precondition {
      condition     = length(local.top_level_route_shared_table_zonal_target_conflicts) == 0
      error_message = "Top-level routes using ids_by_az require module-managed per-AZ route tables. An injected route table is one shared physical table and cannot select a different target by AZ. Use target.id for one shared target or set manage_route_table=true. Conflicts: ${join(", ", [for route_key, group in local.top_level_route_shared_table_zonal_target_conflicts : "${route_key}=${group}"])}."
    }

    precondition {
      condition     = length(local.top_level_route_gateway_endpoint_coexistence_conflicts) == 0
      error_message = "Top-level prefix_list routes cannot share a physical route table with S3 or DynamoDB gateway endpoint associations unless acknowledge_gateway_endpoint_coexistence=true. Gateway endpoint service-managed prefix-list IDs are not plan-known here, so distinct destinations cannot be proven. Set the acknowledgement only after independently verifying a different prefix list. Conflicts: ${join(", ", [for route_key, table_keys in local.top_level_route_gateway_endpoint_coexistence_conflicts : "${route_key}=[${join(", ", table_keys)}]"])}."
    }

    precondition {
      condition     = length(local.top_level_route_isolation_conflicts) == 0
      error_message = "Top-level routes cannot target isolated subnet groups or physical route tables shared with an isolated group. Conflicts: ${join(", ", [for route_key, group in local.top_level_route_isolation_conflicts : "${route_key}=${group}"])}."
    }
  }
}

resource "terraform_data" "injected_route_table_all_az_nat_validation" {
  for_each = var.nat_gateway.mode == "all_azs" ? {
    for name, cfg in var.subnets : name => cfg
    if !cfg.manage_route_table && (
      try(cfg.routing.nat_gateway, false) || try(cfg.routing.dns64, false)
    )
  } : {}

  lifecycle {
    precondition {
      condition     = var.nat_gateway.mode != "all_azs"
      error_message = "Subnet group '${each.key}' injects one shared route_table_id but requests NAT/NAT64 with nat_gateway.mode='all_azs'. A shared route table cannot select a different NAT Gateway per AZ; use single_az mode or module-created per-AZ route tables."
    }
  }
}

# ─── EIGW create-or-inject and IPv6 requirements ─────────────────────────
resource "terraform_data" "eigw_injection_validation" {
  count = local.needs_eigw && !var.vpc.eigw_create ? 1 : 0

  lifecycle {
    precondition {
      condition     = var.vpc.eigw_id != null && length(trimspace(var.vpc.eigw_id)) > 0
      error_message = "Egress-only routing requires either vpc.eigw_create=true or vpc.eigw_create=false with an injected eigw_id."
    }
  }
}

resource "terraform_data" "eigw_requires_ipv6" {
  count = local.needs_eigw && length(local.secondary_ipv6_cidrs) == 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.secondary_ipv6_cidrs) > 0
      error_message = "One or more subnet groups have routing.egress_only_igw = true, but no secondary IPv6 association is configured."
    }
  }
}

# ─── Explicit subnet CIDR keys vs AZ set validation ─────────────
# Explicit maps must name exactly the configured AZs. No list position can
# silently reassign a CIDR when an AZ is inserted or reordered.

resource "terraform_data" "cidrs_az_count_validation" {
  for_each = local.subnets_with_cidrs_by_az

  lifecycle {
    precondition {
      condition     = toset(keys(each.value.ipv4.cidrs_by_az)) == toset(local.azs)
      error_message = "Subnet group '${each.key}' ipv4.cidrs_by_az keys must exactly match configured AZs: ${join(", ", local.azs)}."
    }
  }
}

# ─── Contract closure: create-mode VPC requires an IPv4 source ────────────
# AWS VPCs always require IPv4 addressing. Existing VPC mode can discover the
# primary IPv4 CIDR from data.aws_vpc.existing.
resource "terraform_data" "vpc_ipv4_addressing_validation" {
  count = local.create_vpc ? 1 : 0

  lifecycle {
    precondition {
      condition = (
        (var.addressing.primary.cidr_block != null ? 1 : 0) +
        (var.addressing.primary.ipam_pool_id != null ? 1 : 0) == 1
      )
      error_message = "Creating a VPC requires exactly one IPv4 source: addressing.primary.cidr_block or addressing.primary.ipam_pool_id."
    }
  }
}

# ─── Contract closure: explicit IPv6 CIDRs match the AZ set ───────────────
resource "terraform_data" "ipv6_cidrs_az_count_validation" {
  for_each = {
    for name, cfg in var.subnets : name => cfg
    if try(cfg.ipv6.cidrs_by_az, null) != null
  }

  lifecycle {
    precondition {
      condition     = toset(keys(each.value.ipv6.cidrs_by_az)) == toset(local.azs)
      error_message = "Subnet group '${each.key}' ipv6.cidrs_by_az keys must exactly match configured AZs: ${join(", ", local.azs)}."
    }
  }
}

# ─── Contract closure: injected NAT IDs cover exactly the selected AZs ────
resource "terraform_data" "nat_gateway_existing_ids_validation" {
  count = local.nat_inject_mode ? 1 : 0

  lifecycle {
    precondition {
      condition     = toset(keys(var.nat_gateway.existing_ids)) == (var.nat_gateway.mode == "regional" ? toset(["regional"]) : local.nat_az_set)
      error_message = "nat_gateway.existing_ids keys must match the selected zonal AZ set, or exactly { regional = nat_gateway_id } when mode = 'regional'."
    }
  }
}

# ─── Contract closure: existing EIP allocations cover the selected AZs ───
resource "terraform_data" "nat_gateway_eip_allocation_ids_validation" {
  count = (
    var.nat_gateway.mode != "none" &&
    !local.nat_inject_mode &&
    var.nat_gateway.connectivity_type == "public" &&
    try(var.nat_gateway.eip.mode, "create") == "existing"
  ) ? 1 : 0

  lifecycle {
    precondition {
      condition     = toset(keys(var.nat_gateway.eip.allocation_ids)) == local.nat_az_set
      error_message = "nat_gateway.eip.allocation_ids keys must exactly match the NAT AZ set selected by nat_gateway.mode and nat_gateway.az."
    }
  }
}
