output "vpc_id" {
  description = "ID of the private-NAT VPC."
  value       = module.vpc.vpc_id
}

output "subnet_ids" {
  description = "Workload, NAT host, and TGW attachment subnet IDs by AZ."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "private_nat_gateway_ids" {
  description = "Private NAT Gateway IDs by AZ."
  value       = module.vpc.nat_gateway_ids
}

output "private_nat_ips" {
  description = "Private translation IPs assigned to the NAT Gateways."
  value       = module.vpc.nat_private_ips
}

output "nat_public_ips" {
  description = "Public IP map, expected to be empty for private NAT."
  value       = module.vpc.nat_public_ips
}

output "transit_gateway_attachment_ids" {
  description = "Transit Gateway attachment IDs by stable caller key."
  value       = module.vpc.transit_gateway_attachment_ids
}

output "route_counts" {
  description = "Route counts proving the workload-to-private-NAT-to-TGW chain."
  value = {
    workload_to_nat = length(module.vpc.resources.routes.nat)
    nat_to_tgw      = length(module.vpc.resources.routes.tgw_attachment)
    internet        = length(module.vpc.resources.routes.igw_ipv4)
  }
}
