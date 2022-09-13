output "private_subnet_attributes_by_az" {
  description = "Map of all private subnets containing their attributes."
  value       = module.shared_services_vpc.private_subnet_attributes_by_az

}

output "public_subnet_attributes_by_az" {
  description = "Map of all public subnets containing their attributes."
  value       = module.shared_services_vpc.public_subnet_attributes_by_az

}

output "rt_attributes_by_type_by_az" {
  description = "Map of route tables by type => az => route table attributes."
  value       = module.shared_services_vpc.rt_attributes_by_type_by_az
}

output "nat_gateway_attributes_by_az" {
  description = "Map of nat gateway resource attributes by AZ."
  value       = module.shared_services_vpc.nat_gateway_attributes_by_az
}
