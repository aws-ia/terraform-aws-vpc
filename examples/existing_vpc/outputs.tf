output "vpc_id" {
  description = "Injected VPC ID returned through the module's stable Tier 1 handle."
  value       = module.vpc.vpc_id
}

output "internet_gateway_id" {
  description = "Injected Internet Gateway ID returned by the module."
  value       = module.vpc.internet_gateway_id
}

output "subnet_ids" {
  description = "Module-created subnet IDs grouped by caller-owned key and AZ."
  value       = module.vpc.subnet_ids_by_group_by_az
}

output "route_table_ids" {
  description = "Effective route table IDs, including the shared injected public table."
  value       = module.vpc.route_table_ids_by_group_by_az
}

output "nat_gateway_ids" {
  description = "Module-created Regional NAT Gateway ID repeated by AZ."
  value       = module.vpc.nat_gateway_ids
}

output "nat_gateway_evidence" {
  description = "Regional NAT resource, address-ownership, and route evidence."
  value = {
    availability_modes       = toset([for nat in values(module.vpc.resources.nat_gateways) : nat.availability_mode])
    external_eip_count       = length(aws_eip.nat)
    module_managed_eip_count = length(module.vpc.resources.eips)
    nat_gateway_count        = length(module.vpc.resources.nat_gateways)
    nat_route_count          = length(module.vpc.resources.routes.nat)
  }
}

output "external_eip_allocation_ids" {
  description = "Caller-owned EIP allocation IDs passed to eip.mode=existing."
  value       = { for az, eip in aws_eip.nat : az => eip.id }
}

output "module_ownership" {
  description = "Counts proving which boundary resources the module did not create."
  value = {
    vpcs                  = length(module.vpc.resources.vpc.created)
    internet_gateways     = length(module.vpc.resources.internet_gateway)
    elastic_ips           = length(module.vpc.resources.eips)
    injected_route_tables = module.vpc.resources.injected_route_table_ids
  }
}
