output "vpc_id" {
  description = "ID of the example VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs grouped by the caller-owned subnet key."
  value       = module.vpc.subnet_ids_by_group
}

output "subnet_ipv6_cidrs" {
  description = "IPv6 CIDRs by subnet group and Availability Zone; IPv4-only subnets return null."
  value       = module.vpc.subnet_ipv6_cidrs_by_group_by_az
}

output "subnets_by_role" {
  description = "Subnet IDs grouped by semantic role."
  value       = module.vpc.subnet_ids_by_semantic_role
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs by Availability Zone."
  value       = module.vpc.nat_gateway_ids
}

output "nat_public_ips" {
  description = "NAT Gateway public IPs by Availability Zone."
  value       = module.vpc.nat_public_ips
}

output "route_tables" {
  description = "Route table IDs by subnet group and Availability Zone."
  value       = module.vpc.route_table_ids_by_group_by_az
}

output "eigw_id" {
  description = "ID of the egress-only Internet Gateway."
  value       = module.vpc.egress_only_igw_id
}

output "flow_log_ids" {
  description = "VPC Flow Log IDs by stable flow-log key."
  value       = module.vpc.flow_log_ids
}


output "gateway_endpoints" {
  description = "Gateway endpoint IDs and route-table association count."
  value = {
    ids               = module.vpc.gateway_endpoint_ids
    association_count = length(module.vpc.gateway_endpoint_route_table_association_ids)
  }
}
