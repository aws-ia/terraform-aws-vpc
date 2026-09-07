# ─────────────────────────────────────────────────────────────────────────────
# terraform-aws-vpc v5 — Output contract
#
# Tier 1 — Stable handles: semver-protected names, collection keys, and value
# shapes. Additive keys are allowed in minor releases; removals or type changes
# require a major release.
#
# Tier 2 — Deprecated v4 aliases: exact v4 collection keys and full-provider-
# object values. These aliases exist for downstream migration during v5 and are
# removed in v6. Provider object attributes are controlled by the AWS provider.
#
# Tier 3 — Escape hatch: internal resource collections with no semver guarantee.
# Provider objects are complete except flow_log_roles, which is projected to
# arn/id/name/unique_id to avoid evaluating deprecated provider attributes.
# ─────────────────────────────────────────────────────────────────────────────

# ═══════════════════════════════════════════════════════════════════════════════
# TIER 1 — STABLE CONTRACT (semver-protected)
# ═══════════════════════════════════════════════════════════════════════════════

output "vpc_id" {
  description = "The ID of the VPC (created or referenced)."
  value       = local.vpc_id
}

output "vpc_arn" {
  description = "The ARN of the VPC (created or referenced)."
  value       = var.vpc.create ? aws_vpc.main[0].arn : data.aws_vpc.existing[0].arn
}

output "vpc_cidr_block" {
  description = "The primary IPv4 CIDR block of the VPC."
  value       = local.vpc_cidr
}

output "vpc_ipv4_cidr_blocks" {
  description = "IPv4 VPC CIDR blocks by stable addressing key. The primary key is always present; secondary keys match IPv4 addressing.secondary entries. Shape: map(string|null)."
  value = merge(
    { primary = local.vpc_cidr },
    local.secondary_ipv4_cidr_blocks,
  )
}

output "vpc_ipv6_cidr_blocks" {
  description = "IPv6 VPC CIDR blocks by stable addressing.secondary key."
  value       = local.secondary_ipv6_cidr_blocks
}

output "vpc_ipv6_cidr_block" {
  description = "DEPRECATED singular adapter: the IPv6 CIDR under the first sorted secondary key, or null. Use vpc_ipv6_cidr_blocks."
  value       = local.vpc_ipv6_cidr
}

output "azs" {
  description = "List of Availability Zones where subnets were created."
  value       = local.azs
}

output "default_security_group_id" {
  description = "ID of the AWS-created default security group for this VPC, whether or not default_resources manages it."
  value       = local.default_security_group_id
}

output "default_network_acl_id" {
  description = "ID of the AWS-created default network ACL for this VPC, whether or not default_resources manages it."
  value       = local.default_network_acl_id
}

output "default_route_table_id" {
  description = "ID of the AWS-created default route table for a created VPC, or the resolved main/default route table for an injected VPC; always available independently of default_resources management."
  value       = local.default_route_table_id
}

output "main_route_table_id" {
  description = "ID of the VPC's current main route table, which can differ from the originally AWS-created default route table."
  value       = local.main_route_table_id
}

output "default_resource_ids" {
  description = "IDs of the VPC's default security group, network ACL, and route table; always populated, while default_resources controls only lifecycle adoption."
  value = {
    security_group = local.default_security_group_id
    network_acl    = local.default_network_acl_id
    route_table    = local.default_route_table_id
  }
}

# ─── Subnets by group name (the caller's stable map key) ──────────────────

output "subnet_ids_by_group" {
  description = "Subnet IDs by group. Shape: map(group_name, list(subnet_id))."
  value = {
    for name in sort(keys(var.subnets)) : name => [
      for az in local.azs : local.subnet_ids["${name}/${az}"]
    ]
  }
}

output "subnet_ids_by_group_by_az" {
  description = "Subnet IDs by group and AZ. Shape: map(group_name, map(az, subnet_id))."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.subnet_ids["${name}/${az}"]
    }
  }
}

output "subnet_connectivity_by_group_by_az" {
  description = "Effective route capabilities by subnet group and AZ. Role and connectivity are independent axes. nat includes IPv4 NAT and DNS64/NAT64; internet is true for IGW, NAT/NAT64, or EIGW."
  value       = local.subnet_connectivity_by_group_by_az
}

output "subnet_ids_with_nat_by_az" {
  description = "Subnet IDs with an IPv4 NAT or DNS64/NAT64 route, grouped by AZ. Shape: map(az, list(subnet_id))."
  value = {
    for az in local.azs : az => [
      for name in sort(keys(var.subnets)) : local.subnet_ids["${name}/${az}"]
      if local.subnet_connectivity_by_group_by_az[name][az].nat
    ]
  }
}

output "subnet_ids_without_internet_by_az" {
  description = "Subnet IDs with no direct IGW, NAT/NAT64, or EIGW route, grouped by AZ. Transit and gateway-endpoint routes do not count as Internet access. Shape: map(az, list(subnet_id))."
  value = {
    for az in local.azs : az => [
      for name in sort(keys(var.subnets)) : local.subnet_ids["${name}/${az}"]
      if !local.subnet_connectivity_by_group_by_az[name][az].internet
    ]
  }
}

output "subnet_cidrs_by_group" {
  description = "Subnet IPv4 CIDRs by group. Shape: map(group_name, list(cidr|null))."
  value = {
    for name in sort(keys(var.subnets)) : name => [
      for az in local.azs : local.subnet_ipv4_cidrs["${name}/${az}"]
    ]
  }
}

output "subnet_cidrs_by_group_by_az" {
  description = "Subnet IPv4 CIDRs by group and AZ. Shape: map(group_name, map(az, cidr|null))."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.subnet_ipv4_cidrs["${name}/${az}"]
    }
  }
}

output "subnet_ipv6_cidrs_by_group_by_az" {
  description = "Subnet IPv6 CIDRs by group and AZ. Shape: map(group_name, map(az, cidr|null)); the value is null when a subnet has no IPv6 association."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => (
        local.subnet_ipv6_cidrs["${name}/${az}"] == "" ? null : local.subnet_ipv6_cidrs["${name}/${az}"]
      )
    }
  }
}

output "subnet_arns_by_group_by_az" {
  description = "Subnet ARNs by group and AZ. Shape: map(group_name, map(az, arn))."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.subnet_arns["${name}/${az}"]
    }
  }
}

# ─── Subnets by semantic role ─────────────────────────────────────────────
# All groups sharing a role are aggregated. The per-AZ variants return lists
# because v5 permits multiple groups with the same semantic role.

output "subnet_ids_by_semantic_role" {
  description = "Subnet IDs by semantic role. Shape: map(role, list(subnet_id))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => flatten([
      for name in sort(keys(var.subnets)) : [
        for az in local.azs : local.subnet_ids["${name}/${az}"]
      ] if var.subnets[name].role == role
    ])
  }
}

output "subnet_ids_by_semantic_role_by_az" {
  description = "Subnet IDs by semantic role and AZ. Shape: map(role, map(az, list(subnet_id)))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => {
      for az in local.azs : az => [
        for name in sort(keys(var.subnets)) : local.subnet_ids["${name}/${az}"]
        if var.subnets[name].role == role
      ]
    }
  }
}

output "subnet_cidrs_by_semantic_role" {
  description = "Subnet IPv4 CIDRs by semantic role. Shape: map(role, list(cidr|null))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => flatten([
      for name in sort(keys(var.subnets)) : [
        for az in local.azs : local.subnet_ipv4_cidrs["${name}/${az}"]
      ] if var.subnets[name].role == role
    ])
  }
}

output "subnet_cidrs_by_semantic_role_by_az" {
  description = "Subnet IPv4 CIDRs by semantic role and AZ. Shape: map(role, map(az, list(cidr|null)))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => {
      for az in local.azs : az => [
        for name in sort(keys(var.subnets)) : local.subnet_ipv4_cidrs["${name}/${az}"]
        if var.subnets[name].role == role
      ]
    }
  }
}

# ─── Route tables ─────────────────────────────────────────────────────────

output "route_table_ids_by_group" {
  description = "Route table IDs by subnet group. Shape: map(group_name, list(route_table_id))."
  value = {
    for name in sort(keys(var.subnets)) : name => [
      for az in local.azs : local.route_table_id_by_subnet["${name}/${az}"]
    ]
  }
}

output "route_table_ids_by_group_by_az" {
  description = "Route table IDs by subnet group and AZ. Shape: map(group_name, map(az, route_table_id))."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.route_table_id_by_subnet["${name}/${az}"]
    }
  }
}

output "route_table_ids_by_semantic_role" {
  description = "Route table IDs by semantic role. Shape: map(role, list(route_table_id))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => flatten([
      for name in sort(keys(var.subnets)) : [
        for az in local.azs : local.route_table_id_by_subnet["${name}/${az}"]
      ] if var.subnets[name].role == role
    ])
  }
}

output "route_table_ids_by_semantic_role_by_az" {
  description = "Route table IDs by semantic role and AZ. Shape: map(role, map(az, list(route_table_id)))."
  value = {
    for role in ["public", "private", "isolated", "transit_gateway", "core_network"] :
    role => {
      for az in local.azs : az => [
        for name in sort(keys(var.subnets)) : local.route_table_id_by_subnet["${name}/${az}"]
        if var.subnets[name].role == role
      ]
    }
  }
}

# ─── NAT and gateways ─────────────────────────────────────────────────────

output "nat_gateway_ids" {
  description = "NAT Gateway IDs by configured AZ. Regional mode repeats its one VPC-level ID for every AZ; none returns an empty map. Shape: map(az, nat_gateway_id)."
  value       = var.nat_gateway.mode == "none" ? {} : local.nat_gateway_ids
}

output "nat_public_ips" {
  description = "Created public NAT IPs. Zonal keys are AZs; regional keys are '<az>/<allocation-id>' so every scaled address is preserved. Empty for injected/private NAT."
  value = (
    var.nat_gateway.mode == "none" || var.nat_gateway.connectivity_type == "private" || local.nat_inject_mode ? {} :
    var.nat_gateway.mode == "regional" ? {
      for address in aws_nat_gateway.main["nat/regional"].regional_nat_gateway_address :
      "${address.availability_zone}/${address.allocation_id}" => address.public_ip
      } : {
      for key, nat in aws_nat_gateway.main : split("/", key)[1] => nat.public_ip
    }
  )
}

output "nat_private_ips" {
  description = "Created zonal NAT private IPs by AZ. Regional provider addresses expose no private IP; injected NAT returns an empty map."
  value = local.nat_inject_mode || var.nat_gateway.mode == "regional" ? {} : {
    for key, nat in aws_nat_gateway.main : split("/", key)[1] => nat.private_ip
  }
}

output "nat_eip_allocation_ids" {
  description = "Effective public NAT EIP allocation IDs. Zonal keys are AZs; regional keys are '<az>/<allocation-id>'. Empty for injected/private NAT."
  value = (
    var.nat_gateway.mode == "none" || var.nat_gateway.connectivity_type == "private" || local.nat_inject_mode ? {} :
    var.nat_gateway.mode == "regional" ? {
      for address in aws_nat_gateway.main["nat/regional"].regional_nat_gateway_address :
      "${address.availability_zone}/${address.allocation_id}" => address.allocation_id
      } : {
      for key, nat in aws_nat_gateway.main : split("/", key)[1] => nat.allocation_id
    }
  )
}

output "regional_nat_gateway_route_table_id" {
  description = "AWS-managed route table ID for a created Regional NAT Gateway, or null for zonal/injected NAT."
  value = var.nat_gateway.mode == "regional" && !local.nat_inject_mode ? (
    aws_nat_gateway.main["nat/regional"].route_table_id
  ) : null
}

output "regional_nat_gateway_addresses_by_az" {
  description = "Created Regional NAT Gateway address records grouped by configured AZ; empty for zonal or injected NAT."
  value = var.nat_gateway.mode == "regional" && !local.nat_inject_mode ? {
    for az in local.azs : az => [
      for address in aws_nat_gateway.main["nat/regional"].regional_nat_gateway_address : {
        allocation_id        = address.allocation_id
        association_id       = address.association_id
        availability_zone_id = address.availability_zone_id
        network_interface_id = address.network_interface_id
        public_ip            = address.public_ip
        status               = address.status
      } if address.availability_zone == az
    ]
  } : {}
}

output "internet_gateway_id" {
  description = "Internet Gateway ID (created or injected), or null when no IGW is needed."
  value       = local.igw_id
}

output "egress_only_igw_id" {
  description = "Egress-only Internet Gateway ID (created or injected), or null when unused."
  value       = local.eigw_id
}

output "secondary_cidr_association_ids" {
  description = "Secondary IPv4 and IPv6 CIDR association IDs by stable caller-owned key."
  value       = local.secondary_cidr_association_ids
}

output "secondary_ipv4_cidr_association_ids" {
  description = "Secondary IPv4 CIDR association IDs by stable caller-owned key."
  value       = local.secondary_ipv4_cidr_association_ids
}

output "secondary_ipv6_cidr_association_ids" {
  description = "Secondary IPv6 CIDR association IDs by stable caller-owned key."
  value       = local.secondary_ipv6_cidr_association_ids
}

output "network_acl_ids_by_group" {
  description = "Created or injected Network ACL IDs by stable subnet-group key; groups without network_acl are absent."
  value       = local.network_acl_ids
}

output "network_acl_rule_ids" {
  description = "Managed Network ACL rule IDs keyed '<group>/<ingress|egress>/<rule-number>'."
  value = {
    for key, rule in aws_network_acl_rule.this : key => rule.id
  }
}

output "network_acl_association_ids" {
  description = "Managed Network ACL association IDs keyed by stable '<group>/<az>' subnet identity."
  value = {
    for key, association in aws_network_acl_association.this : key => association.id
  }
}

output "gateway_endpoint_ids" {
  description = "Gateway VPC endpoint IDs by stable caller-owned gateway_endpoints key."
  value       = local.gateway_endpoint_ids_by_key
}

output "gateway_endpoint_route_table_association_ids" {
  description = "Gateway endpoint route-table association IDs keyed '<group>/<az-or-injected>/gateway-endpoint/<service>'."
  value = {
    for key, association in aws_vpc_endpoint_route_table_association.gateway : key => association.id
  }
}

output "vpc_block_public_access_options_id" {
  description = "VPC Block Public Access regional options ID (created or injected), or null when disabled."
  value       = local.vpc_block_public_access_options_id
}

output "vpc_block_public_access_exclusion_ids" {
  description = "VPC Block Public Access exclusion IDs by stable key."
  value       = local.vpc_block_public_access_exclusion_ids
}

output "dhcp_options_id" {
  description = "DHCP option set ID associated with the VPC (created or injected), or null when disabled."
  value       = local.dhcp_options_id
}

# ─── Attachments, Flow Logs, and VPC Lattice ─────────────────────────────

output "transit_gateway_attachment_ids" {
  description = "Transit Gateway VPC attachment IDs by caller-owned attachment key. The deprecated singular adapter uses key 'vpc'. Shape: map(attachment_key, attachment_id)."
  value       = local.transit_gateway_attachment_ids
}

output "transit_gateway_attachment_id" {
  description = "DEPRECATED: scalar adapter for one Transit Gateway VPC attachment, or null when absent. Use transit_gateway_attachment_ids."
  value       = local.transit_gateway_attachment_id
}

output "core_network_attachment_id" {
  description = "Cloud WAN Core Network VPC attachment ID, or null when the role is absent."
  value       = local.core_network_attachment_id
}

output "core_network_attachment_accepter_id" {
  description = "Cloud WAN attachment accepter ID (created or injected), or null when acceptance is not managed."
  value       = local.core_network_accepter_id
}

output "flow_log_ids" {
  description = "VPC Flow Log IDs by the stable flow_logs map key. Shape: map(key, flow_log_id)."
  value       = local.flow_log_ids
}

output "flow_log_destination_arns" {
  description = "VPC Flow Log destination ARNs by stable flow_logs map key."
  value       = local.flow_log_destination_arns
}

output "flow_log_role_arns" {
  description = "CloudWatch delivery role ARNs by flow-log key; null for S3 and Firehose."
  value       = local.flow_log_role_arns
}

output "vpc_lattice_service_network_association_id" {
  description = "VPC Lattice Service Network VPC association ID, or null when disabled."
  value       = local.vpc_lattice_association_id
}

# ═══════════════════════════════════════════════════════════════════════════════
# TIER 2 — DEPRECATED v4-COMPATIBLE ALIASES (removed in v6)
#
# Names, outer collection keys, and full-object/scalar shapes match v4 outputs.
# For exact compatibility, keep migrated reserved group names `public`,
# `transit_gateway`, and `core_network`, and use `default` as the migrated v4
# Flow Log key. Prefer Tier 1 for all new integrations.
# ═══════════════════════════════════════════════════════════════════════════════

output "vpc_attributes" {
  description = "DEPRECATED: v4-compatible full VPC object. Use vpc_id/vpc_arn/vpc_cidr_block. Removed in v6."
  value       = local.create_vpc ? aws_vpc.main[0] : data.aws_vpc.existing[0]
}

output "private_subnet_attributes_by_az" {
  description = "DEPRECATED: v4-compatible map of full private subnet objects keyed '<group>/<az>'. Use Tier 1 subnet outputs. Removed in v6."
  value = {
    for key, subnet in aws_subnet.main : key => subnet
    if !contains(["public", "transit_gateway", "core_network"], split("/", key)[0])
  }
}

output "public_subnet_attributes_by_az" {
  description = "DEPRECATED: v4-compatible map of full public subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6."
  value = contains(keys(var.subnets), "public") && var.subnets.public.create ? {
    for az in local.azs : az => aws_subnet.main["public/${az}"]
  } : {}
}

output "tgw_subnet_attributes_by_az" {
  description = "DEPRECATED: v4-compatible map of full TGW subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6."
  value = contains(keys(var.subnets), "transit_gateway") && var.subnets.transit_gateway.create ? {
    for az in local.azs : az => aws_subnet.main["transit_gateway/${az}"]
  } : {}
}

output "core_network_subnet_attributes_by_az" {
  description = "DEPRECATED: v4-compatible map of full Cloud WAN subnet objects keyed by AZ. Use Tier 1 subnet outputs. Removed in v6."
  value = contains(keys(var.subnets), "core_network") && var.subnets.core_network.create ? {
    for az in local.azs : az => aws_subnet.main["core_network/${az}"]
  } : {}
}

output "rt_attributes_by_type_by_az" {
  description = "DEPRECATED: v4-compatible full route-table objects keyed type then AZ or '<group>/<az>' for private. Use Tier 1 route table IDs. Removed in v6."
  value = {
    private = {
      for key, route_table in aws_route_table.main : key => route_table
      if !contains(["public", "transit_gateway", "core_network"], split("/", key)[0])
    }
    public = contains(keys(var.subnets), "public") ? {
      for az in local.azs : az => aws_route_table.main["public/${az}"]
      if var.subnets.public.manage_route_table
    } : {}
    transit_gateway = contains(keys(var.subnets), "transit_gateway") ? {
      for az in local.azs : az => aws_route_table.main["transit_gateway/${az}"]
      if var.subnets.transit_gateway.manage_route_table
    } : {}
    core_network = contains(keys(var.subnets), "core_network") ? {
      for az in local.azs : az => aws_route_table.main["core_network/${az}"]
      if var.subnets.core_network.manage_route_table
    } : {}
  }
}

output "nat_gateway_attributes_by_az" {
  description = "DEPRECATED: v4-compatible map of full created NAT objects keyed by AZ; Regional NAT repeats one object per configured AZ. Use Tier 1 outputs. Removed in v6."
  value = local.nat_inject_mode ? {} : var.nat_gateway.mode == "regional" ? {
    for az in local.azs : az => aws_nat_gateway.main["nat/regional"]
    } : {
    for key, nat_gateway in aws_nat_gateway.main : split("/", key)[1] => nat_gateway
  }
}

output "natgw_id_per_az" {
  description = "DEPRECATED: v4-compatible map(az, object({id=string})); single_az and regional repeat one selected ID. Use nat_gateway_ids. Removed in v6."
  value = var.nat_gateway.mode == "none" ? {} : {
    for az in local.azs : az => {
      id = local.nat_gateway_ids[var.nat_gateway.mode == "single_az" ? var.nat_gateway.az : az]
    }
  }
}

output "internet_gateway" {
  description = "DEPRECATED: v4-compatible full created Internet Gateway object. Use internet_gateway_id. Removed in v6."
  value       = local.create_igw ? aws_internet_gateway.main[0] : null
}

output "egress_only_internet_gateway" {
  description = "DEPRECATED: v4-compatible full Egress-only Internet Gateway object. Use egress_only_igw_id. Removed in v6."
  value       = local.create_eigw ? aws_egress_only_internet_gateway.main[0] : null
}

output "core_network_attachment" {
  description = "DEPRECATED: v4-compatible full Cloud WAN attachment object. Use core_network_attachment_id. Removed in v6."
  value       = try(aws_networkmanager_vpc_attachment.this["vpc"], null)
}

output "vpc_lattice_service_network_association" {
  description = "DEPRECATED: v4-compatible full VPC Lattice association object. Use vpc_lattice_service_network_association_id. Removed in v6."
  value       = try(aws_vpclattice_service_network_vpc_association.this["vpc"], null)
}

output "flow_log_attributes" {
  description = "DEPRECATED: v4-compatible single full Flow Log object. Uses key 'default', or the only configured Flow Log. Use flow_log_ids. Removed in v6."
  value       = try(aws_flow_log.this["default"], one(values(aws_flow_log.this)), null)
}

# Deprecated compatibility aliases that remain during v5 so existing consumers can
# migrate without address churn.
output "subnet_ids_by_role" {
  description = "DEPRECATED: compatibility alias keyed by group name. Use subnet_ids_by_group. Removed in v6."
  value = {
    for name in sort(keys(var.subnets)) : name => [
      for az in local.azs : local.subnet_ids["${name}/${az}"]
    ]
  }
}

output "subnet_ids_by_role_by_az" {
  description = "DEPRECATED: compatibility alias keyed by group name. Use subnet_ids_by_group_by_az. Removed in v6."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.subnet_ids["${name}/${az}"]
    }
  }
}

output "subnet_cidrs_by_role_by_az" {
  description = "DEPRECATED: compatibility alias keyed by group name. Use subnet_cidrs_by_group_by_az. Removed in v6."
  value = {
    for name in sort(keys(var.subnets)) : name => {
      for az in local.azs : az => local.subnet_ipv4_cidrs["${name}/${az}"]
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# TIER 3 — ESCAPE HATCH (complete objects, NO semver guarantee)
# ═══════════════════════════════════════════════════════════════════════════════

output "resources" {
  description = "UNSTABLE: internal resource collections for advanced composition. Provider objects are complete except flow_log_roles (arn/id/name/unique_id only). Shape may change in any release; prefer Tier 1."
  value = {
    vpc = {
      created  = aws_vpc.main
      existing = data.aws_vpc.existing
    }
    secondary_ipv4_cidr_associations = aws_vpc_ipv4_cidr_block_association.secondary
    secondary_ipv6_cidr_associations = aws_vpc_ipv6_cidr_block_association.secondary
    secondary_cidr_association_ids   = local.secondary_cidr_association_ids
    subnets                          = aws_subnet.main
    injected_subnets                 = data.aws_subnet.existing
    subnet_ids                       = local.subnet_ids
    route_tables                     = aws_route_table.main
    injected_route_table_ids         = local.injected_route_table_ids_by_key
    route_table_associations         = aws_route_table_association.main
    network_acls                     = aws_network_acl.this
    network_acl_rules                = aws_network_acl_rule.this
    network_acl_associations         = aws_network_acl_association.this
    network_acl_ids                  = local.network_acl_ids
    default_resources = {
      security_groups = aws_default_security_group.this
      network_acls    = aws_default_network_acl.this
      route_tables    = aws_default_route_table.this
    }
    internet_gateway                    = aws_internet_gateway.main
    egress_only_internet_gateway        = aws_egress_only_internet_gateway.main
    eips                                = aws_eip.nat
    nat_gateways                        = aws_nat_gateway.main
    gateway_endpoints                   = aws_vpc_endpoint.gateway
    gateway_endpoint_route_associations = aws_vpc_endpoint_route_table_association.gateway
    transit_gateway_attachments         = aws_ec2_transit_gateway_vpc_attachment.this
    core_network_attachments            = aws_networkmanager_vpc_attachment.this
    core_network_accepters              = aws_networkmanager_attachment_accepter.this
    core_network_readiness              = terraform_data.core_network_readiness
    injected_attachment_ids = {
      transit_gateway = local.transit_gateway_attachment_id
      core_network    = local.core_network_attachment_id
      core_accepter   = local.core_network_accepter_id
    }
    flow_logs             = aws_flow_log.this
    injected_flow_log_ids = local.flow_log_ids
    flow_log_destinations = aws_cloudwatch_log_group.flow_logs
    flow_log_roles = {
      for key, role in aws_iam_role.flow_logs : key => {
        arn       = role.arn
        id        = role.id
        name      = role.name
        unique_id = role.unique_id
      }
    }
    flow_log_role_policies             = aws_iam_role_policy.flow_logs
    vpc_lattice_associations           = aws_vpclattice_service_network_vpc_association.this
    vpc_lattice_association_id         = local.vpc_lattice_association_id
    vpc_block_public_access_options    = aws_vpc_block_public_access_options.this
    vpc_block_public_access_exclusions = aws_vpc_block_public_access_exclusion.this
    dhcp_options                       = aws_vpc_dhcp_options.this
    dhcp_options_associations          = aws_vpc_dhcp_options_association.this
    routes = {
      igw_ipv4            = aws_route.igw_ipv4
      igw_ipv6            = aws_route.igw_ipv6
      nat                 = aws_route.nat
      nat64               = aws_route.nat64
      eigw                = aws_route.eigw
      custom              = aws_route.custom
      top_level           = aws_route.top_level
      tgw                 = aws_route.tgw
      tgw_ipv6            = aws_route.tgw_ipv6
      tgw_attachment      = aws_route.tgw_attachment
      tgw_attachment_ipv6 = aws_route.tgw_attachment_ipv6
      cwan                = aws_route.cwan
      cwan_ipv6           = aws_route.cwan_ipv6
    }
  }
}
