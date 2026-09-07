output "vpc_id" {
  description = "ID of the dual-stack VPC."
  value       = module.vpc.vpc_id
}

output "vpc_ipv6_cidr_blocks" {
  description = "Amazon-provided VPC IPv6 CIDRs by stable secondary key."
  value       = module.vpc.vpc_ipv6_cidr_blocks
}

output "subnet_ipv6_cidrs" {
  description = "Deterministic /64 CIDRs by subnet group and Availability Zone."
  value       = module.vpc.subnet_ipv6_cidrs_by_group_by_az
}

output "ipv6_native_subnet_ids" {
  description = "IDs of the IPv6-native subnet group."
  value       = module.vpc.subnet_ids_by_group["ipv6-native"]
}

output "egress_only_igw_id" {
  description = "ID of the egress-only Internet Gateway."
  value       = module.vpc.egress_only_igw_id
}

output "nat_gateway_evidence" {
  description = "Regional NAT resource, address-ownership, and IPv4 route evidence."
  value = {
    availability_modes = toset([for nat in values(module.vpc.resources.nat_gateways) : nat.availability_mode])
    managed_eip_count  = length(module.vpc.resources.eips)
    nat_gateway_count  = length(module.vpc.resources.nat_gateways)
    nat_route_count    = length(module.vpc.resources.routes.nat)
  }
}

output "ipv6_route_counts" {
  description = "Managed IPv6 route counts proving IGW, EIGW, and NAT64 paths."
  value = {
    internet_gateway = length(module.vpc.resources.routes.igw_ipv6)
    egress_only_igw  = length(module.vpc.resources.routes.eigw)
    nat64            = length(module.vpc.resources.routes.nat64)
  }
}
