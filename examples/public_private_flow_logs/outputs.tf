
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

output "log_name" {
  description = "Name of the flow log."
  value       = module.vpc.flow_log_attributes.tags["Name"]
}

output "vpc_attributes" {
  description = "Output of all VPC attributes."
  value       = module.vpc.vpc_attributes
}
