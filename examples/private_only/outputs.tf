output "subnets" {
  description = "Map of subnet types with key/value az = cidr."
  value       = module.vpc.subnets
}

output "subnet_attributes" {
  value = module.vpc.private_subnet_attributes_by_az
}
