output "vpc_id" {
  description = "ID of the isolated VPC."
  value       = module.vpc.vpc_id
}

output "isolated_subnet_ids" {
  description = "Isolated subnet IDs grouped by caller-owned key and AZ."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "vpc_block_public_access_options_id" {
  description = "Regional VPC Block Public Access options ID."
  value       = module.vpc.vpc_block_public_access_options_id
}

output "dhcp_options_id" {
  description = "Custom DHCP option set associated with the VPC."
  value       = module.vpc.dhcp_options_id
}

output "egress_resources" {
  description = "Stable handles proving that the topology has no Internet or NAT gateways."
  value = {
    internet_gateway_id = module.vpc.internet_gateway_id
    nat_gateway_ids     = module.vpc.nat_gateway_ids
    egress_only_igw_id  = module.vpc.egress_only_igw_id
  }
}

output "route_counts" {
  description = "Managed egress-route counts, all expected to be zero."
  value = {
    internet = length(module.vpc.resources.routes.igw_ipv4)
    nat      = length(module.vpc.resources.routes.nat)
    eigw     = length(module.vpc.resources.routes.eigw)
  }
}


output "default_resource_hardening" {
  description = "Adopted default resources and their managed collection counts."
  value = {
    ids                  = module.vpc.default_resource_ids
    security_group_count = length(module.vpc.resources.default_resources.security_groups)
    network_acl_count    = length(module.vpc.resources.default_resources.network_acls)
    route_table_count    = length(module.vpc.resources.default_resources.route_tables)
  }
}


output "network_acl_controls" {
  description = "Per-group NACL IDs plus explicit stateless rule and subnet-association counts."
  value = {
    ids               = module.vpc.network_acl_ids_by_group
    rule_count        = length(module.vpc.network_acl_rule_ids)
    association_count = length(module.vpc.network_acl_association_ids)
  }
}
