output "public_subnets" {
  description = "Map of public subnet attributes grouped by az."
  value       = module.vpc.public_subnet_attributes_by_az
}

output "private_subnets" {
  description = "Map of private subnet attributes grouped by az."
  value       = module.vpc.private_subnet_attributes_by_az
}

## Used for Testing, do not delete

output "public_subnets_tags_length" {
  description = "Count of public subnet tags for a single az."
  value       = length(module.vpc.public_subnet_attributes_by_az[data.aws_availability_zones.current.names[0]].tags)
}

output "private_subnets_tags_length" {
  description = "Count of private subnet tags for a single az."
  value       = length(module.vpc.private_subnet_attributes_by_az["private/${data.aws_availability_zones.current.names[0]}"].tags)
}
