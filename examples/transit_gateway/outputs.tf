output "tgw_subnets_tags_length" {
  description = "Count of tgw subnet tags for a single az."
  value       = length(module.vpc.tgw_subnet_attributes_by_az[data.aws_availability_zones.current.names[0]].tags)
}

output "private_subnets_tags_length" {
  description = "Count of private subnet tags for a single az."
  value       = length(module.vpc.private_subnet_attributes_by_az["truly_private/${data.aws_availability_zones.current.names[0]}"].tags)
}
