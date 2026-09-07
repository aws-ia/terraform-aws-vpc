output "vpc_id" {
  description = "ID of the centralized inspection VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Public, firewall, and TGW attachment subnet IDs by AZ."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "route_table_ids" {
  description = "Route table IDs consumed by the Network Firewall routing composition."
  value       = module.vpc.route_table_ids_by_group_by_az
}

output "nat_gateway_ids" {
  description = "Public NAT Gateway IDs by AZ for post-inspection internet egress."
  value       = module.vpc.nat_gateway_ids
}

output "transit_gateway_attachment_ids" {
  description = "Appliance-mode Transit Gateway attachment IDs by stable caller key."
  value       = module.vpc.transit_gateway_attachment_ids
}

output "network_firewall_inputs" {
  description = "Tier 1 values ready for aws-ia/networkfirewall/aws centralized_inspection_with_egress."
  value       = local.network_firewall_composition
}

output "route_evidence" {
  description = "Route counts and TGW destination fields proving NAT egress and prefix-list return routing."
  value = {
    internet_routes = length(module.vpc.resources.routes.igw_ipv4)
    nat_routes      = length(module.vpc.resources.routes.nat)
    tgw_routes      = length(module.vpc.resources.routes.tgw_attachment)
    tgw_destinations = {
      for key, route in module.vpc.resources.routes.tgw_attachment : key => {
        cidr_block     = route.destination_cidr_block != "" ? route.destination_cidr_block : null
        prefix_list_id = route.destination_prefix_list_id != "" ? route.destination_prefix_list_id : null
      }
    }
  }
}
