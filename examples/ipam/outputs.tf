output "public_subnets" {
  description = "Map of public subnet attributes grouped by az."
  value       = module.vpc.public_subnet_attributes_by_az
}

output "private_subnets" {
  description = "Map of private subnet attributes grouped by az."
  value       = module.vpc.private_subnet_attributes_by_az
}
