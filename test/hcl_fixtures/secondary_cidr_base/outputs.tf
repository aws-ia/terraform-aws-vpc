output "vpc_id" {
  description = "vpc id"
  value       = module.vpc.vpc_attributes.id

}

output "natgw_id_1" {
  value       = module.vpc.nat_gateway_attributes_by_az[data.aws_availability_zones.current.names[0]].id
  description = "nat gateway attributes"
}

output "natgw_id_2" {
  value       = module.vpc.nat_gateway_attributes_by_az[data.aws_availability_zones.current.names[1]].id
  description = "nat gateway attributes"
}
