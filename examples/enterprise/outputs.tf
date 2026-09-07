output "vpc_id" {
  description = "ID of the enterprise VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs by group and Availability Zone."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "subnet_cidrs" {
  description = "IPv4 CIDRs by group and Availability Zone."
  value       = module.vpc.subnet_cidrs_by_group_by_az
}

output "subnet_ipv6_cidrs" {
  description = "IPv6 CIDRs by group and Availability Zone."
  value       = module.vpc.subnet_ipv6_cidrs_by_group_by_az
}

output "subnets_by_role" {
  description = "Subnet IDs grouped by semantic role."
  value       = module.vpc.subnet_ids_by_semantic_role
}

output "nat_gateway_ids" {
  description = "Regional NAT Gateway ID repeated by Availability Zone."
  value       = module.vpc.nat_gateway_ids
}

output "nat_public_ips" {
  description = "Regional NAT Gateway public IPs keyed by Availability Zone and allocation ID."
  value       = module.vpc.nat_public_ips
}

output "nat_gateway_evidence" {
  description = "Regional NAT resource, address-ownership, and route evidence."
  value = {
    availability_modes = toset([for nat in values(module.vpc.resources.nat_gateways) : nat.availability_mode])
    managed_eip_count  = length(module.vpc.resources.eips)
    nat_gateway_count  = length(module.vpc.resources.nat_gateways)
    nat_route_count    = length(module.vpc.resources.routes.nat)
  }
}

output "route_tables" {
  description = "Route table IDs by subnet group and Availability Zone."
  value       = module.vpc.route_table_ids_by_group_by_az
}

output "gateway_endpoints" {
  description = "Gateway endpoint IDs and route-table association count."
  value = {
    ids               = module.vpc.gateway_endpoint_ids
    association_count = length(module.vpc.gateway_endpoint_route_table_association_ids)
  }
}

output "network_acl_controls" {
  description = "Tier-specific Network ACL IDs, rules, and subnet associations."
  value = {
    ids               = module.vpc.network_acl_ids_by_group
    rule_count        = length(module.vpc.network_acl_rule_ids)
    association_count = length(module.vpc.network_acl_association_ids)
  }
}

output "eigw_id" {
  description = "ID of the egress-only Internet Gateway."
  value       = module.vpc.egress_only_igw_id
}

output "flow_log_ids" {
  description = "VPC Flow Log IDs by stable flow-log key."
  value       = module.vpc.flow_log_ids
}

output "lattice_association_id" {
  description = "ID of the VPC Lattice service-network association."
  value       = module.vpc.vpc_lattice_service_network_association_id
}
